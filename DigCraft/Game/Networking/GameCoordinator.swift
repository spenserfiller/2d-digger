import Foundation
import Observation

enum GameMode: Sendable {
    case singlePlayer
    case host(session: HostSession)
    case client(session: ClientSession, assignedId: PlayerId)

    var isClient: Bool {
        if case .client = self { return true } else { return false }
    }

    var isHost: Bool {
        if case .host = self { return true } else { return false }
    }

    var isMultiplayer: Bool {
        !isSinglePlayer
    }

    var isSinglePlayer: Bool {
        if case .singlePlayer = self { return true } else { return false }
    }
}

@Observable
@MainActor
final class GameCoordinator {
    let mode: GameMode
    private(set) var simulation: GameSimulation

    // Host state
    private var playerNames: [PlayerId: String] = [:]
    private var hostTickCounter: UInt64 = 0
    private static let statesBroadcastInterval: UInt64 = 3 // every 3 ticks (~20Hz)

    // Client state
    private var lastServerPlayerStates: [PlayerId: PlayerState] = [:]
    private var previousServerPlayerStates: [PlayerId: PlayerState] = [:]
    private var interpolationProgress: Double = 0
    private static let interpolationDuration: Double = 1.0 / 20.0 // 20Hz = 50ms between updates

    // Connection state
    var disconnectError: String?

    init(mode: GameMode, simulation: GameSimulation) {
        self.mode = mode
        self.simulation = simulation

        switch mode {
        case .host(let session):
            session.delegate = self
        case .client(let session, _):
            session.delegate = self
        case .singlePlayer:
            break
        }
    }

    // MARK: - Command Dispatch

    func sendCommand(_ command: GameCommand) {
        switch mode {
        case .singlePlayer:
            simulation.process(command)
        case .host:
            simulation.process(command, from: .host)
        case .client(let session, let assignedId):
            // Apply locally for prediction
            simulation.process(command, from: assignedId)
            // Send to host
            let batch = CommandBatch(
                playerId: assignedId,
                commands: [command],
                lastAckedServerTick: simulation.currentTick
            )
            session.sendToHost(.commandBatch(batch))
        }
    }

    // MARK: - Host Tick (called from GameScene after simulation.update)

    func hostTick() {
        guard case .host(let session) = mode else { return }

        hostTickCounter += 1

        // Broadcast tile changes from events
        let events = simulation.peekEvents()
        var tileChanges: [TileChange] = []
        var inventoryUpdates: [PlayerId: Inventory] = [:]

        for event in events {
            switch event {
            case .tileChanged(let x, let y, let newType):
                tileChanges.append(TileChange(x: x, y: y, newType: newType))
            case .inventoryChanged(let playerId):
                if let inv = simulation.inventories[playerId] {
                    inventoryUpdates[playerId] = inv
                }
            default:
                break
            }
        }

        if !tileChanges.isEmpty {
            session.broadcast(.tileDeltaBatch(TileDeltaBatch(
                serverTick: simulation.currentTick,
                changes: tileChanges
            )))
        }

        // Send inventory updates to the owning client
        for (playerId, inv) in inventoryUpdates {
            if playerId != .host {
                session.send(.inventoryUpdate(InventoryUpdateMessage(
                    playerId: playerId,
                    inventory: inv
                )), to: playerId)
            }
        }

        // Broadcast player states at reduced frequency
        if hostTickCounter % GameCoordinator.statesBroadcastInterval == 0 {
            session.broadcast(.playerStates(PlayerStatesMessage(
                serverTick: simulation.currentTick,
                players: simulation.players
            )))
        }
    }

    // MARK: - Client Interpolation

    func updateInterpolation(deltaTime: Double) {
        guard mode.isClient else { return }

        interpolationProgress += deltaTime / GameCoordinator.interpolationDuration
        interpolationProgress = min(interpolationProgress, 1.0)

        // Interpolate remote player positions
        for (id, targetState) in lastServerPlayerStates {
            guard id != simulation.localPlayerId else { continue }
            guard let prevState = previousServerPlayerStates[id] else {
                simulation.players[id] = targetState
                continue
            }

            let t = interpolationProgress
            var interpolated = targetState
            interpolated.positionX = prevState.positionX + (targetState.positionX - prevState.positionX) * t
            interpolated.positionY = prevState.positionY + (targetState.positionY - prevState.positionY) * t
            simulation.players[id] = interpolated
        }
    }

    // MARK: - Stop

    func stop() {
        switch mode {
        case .host(let session):
            session.stop()
        case .client(let session, _):
            session.stop()
        case .singlePlayer:
            break
        }
    }
}

// MARK: - HostSessionDelegate

extension GameCoordinator: HostSessionDelegate {
    nonisolated func hostSession(_ session: HostSession, didReceive message: NetMessage, from playerId: PlayerId) {
        Task { @MainActor in
            self.handleHostMessage(message, from: playerId, session: session)
        }
    }

    nonisolated func hostSession(_ session: HostSession, playerConnected playerId: PlayerId) {
        // Handled in joinRequest message
    }

    nonisolated func hostSession(_ session: HostSession, playerDisconnected playerId: PlayerId) {
        Task { @MainActor in
            let name = self.playerNames[playerId] ?? "Player \(playerId.rawValue)"
            print("[Host] \(name) disconnected")
            self.simulation.removePlayer(id: playerId)
            self.playerNames.removeValue(forKey: playerId)
            session.broadcast(.playerLeft(PlayerLeftMessage(playerId: playerId)))
        }
    }

    @MainActor
    private func handleHostMessage(_ message: NetMessage, from playerId: PlayerId, session: HostSession) {
        switch message {
        case .joinRequest(let request):
            handleJoinRequest(request, from: playerId, session: session)
        case .commandBatch(let batch):
            for command in batch.commands {
                simulation.process(command, from: batch.playerId)
            }
        case .ping(let ping):
            let now = UInt64(Date().timeIntervalSince1970 * 1000)
            session.send(.pong(PongMessage(clientSentAt: ping.sentAt, serverReceivedAt: now)), to: playerId)
        default:
            break
        }
    }

    @MainActor
    private func handleJoinRequest(_ request: JoinRequest, from playerId: PlayerId, session: HostSession) {
        // Validate protocol version
        guard request.protocolVersion == digCraftProtocolVersion else {
            session.send(.joinReject(JoinReject(reason: "Protocol version mismatch")), to: playerId)
            return
        }

        // Check player cap
        guard session.playerCount <= 4 else {
            session.send(.joinReject(JoinReject(reason: "Game is full (max 4 players)")), to: playerId)
            return
        }

        // Add player to simulation
        simulation.addPlayer(id: playerId)
        playerNames[playerId] = request.clientName

        // Compute tile deltas
        let tileDeltas = WorldDeltaComputer.computeTileDeltas(simulation: simulation)

        // Send JoinAccept
        let accept = JoinAccept(
            assignedId: playerId,
            worldSeed: simulation.seed,
            serverTick: simulation.currentTick,
            existingPlayers: simulation.players,
            existingInventories: simulation.inventories,
            tileDeltas: tileDeltas
        )
        session.send(.joinAccept(accept), to: playerId)

        // Broadcast PlayerJoined to other clients
        let joinedMsg = PlayerJoinedMessage(
            playerId: playerId,
            playerName: request.clientName,
            initialState: simulation.players[playerId]!
        )
        session.broadcast(.playerJoined(joinedMsg), except: playerId)

        print("[Host] \(request.clientName) joined as player \(playerId.rawValue)")
    }
}

// MARK: - ClientSessionDelegate

extension GameCoordinator: ClientSessionDelegate {
    nonisolated func clientSessionDidConnect(_ session: ClientSession) {
        // Connection established, JoinRequest sent by SessionBrowserView
    }

    nonisolated func clientSession(_ session: ClientSession, didReceive message: NetMessage) {
        Task { @MainActor in
            self.handleClientMessage(message)
        }
    }

    nonisolated func clientSession(_ session: ClientSession, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            self.disconnectError = error?.localizedDescription ?? "Host disconnected"
        }
    }

    @MainActor
    private func handleClientMessage(_ message: NetMessage) {
        switch message {
        case .playerStates(let statesMsg):
            handlePlayerStates(statesMsg)
        case .tileDeltaBatch(let batch):
            for change in batch.changes {
                if let coord = simulation.world.setTile(x: change.x, y: change.y, to: change.newType) {
                    simulation.pendingEvents.append(.tileChanged(x: change.x, y: change.y, newType: change.newType))
                    simulation.pendingEvents.append(.chunkDirty(coord))
                }
            }
        case .playerJoined(let joined):
            simulation.players[joined.playerId] = joined.initialState
            simulation.inventories[joined.playerId] = Inventory()
        case .playerLeft(let left):
            simulation.removePlayer(id: left.playerId)
        case .inventoryUpdate(let update):
            if update.playerId == simulation.localPlayerId {
                simulation.inventories[update.playerId] = update.inventory
                simulation.pendingEvents.append(.inventoryChanged(update.playerId))
            }
        case .pong:
            break // Could track latency
        default:
            break
        }
    }

    @MainActor
    private func handlePlayerStates(_ statesMsg: PlayerStatesMessage) {
        // Store previous states for interpolation
        previousServerPlayerStates = lastServerPlayerStates
        lastServerPlayerStates = statesMsg.players
        interpolationProgress = 0

        let localId = simulation.localPlayerId

        // For local player: reconcile with server
        if let serverState = statesMsg.players[localId],
           let localState = simulation.players[localId] {
            let dx = serverState.positionX - localState.positionX
            let dy = serverState.positionY - localState.positionY
            let delta = sqrt(dx * dx + dy * dy)

            if delta >= 2.0 {
                // Snap immediately for large deltas
                simulation.players[localId] = serverState
            } else if delta > 0.1 {
                // Lerp toward server position
                let lerpFactor = 0.2
                simulation.players[localId]!.positionX += dx * lerpFactor
                simulation.players[localId]!.positionY += dy * lerpFactor
            }
        }

        // For remote players: set target for interpolation (handled in updateInterpolation)
        for (id, state) in statesMsg.players where id != localId {
            if simulation.players[id] == nil {
                simulation.players[id] = state
            }
        }
    }
}

// MARK: - World Delta Computer

enum WorldDeltaComputer {
    static func computeTileDeltas(simulation: GameSimulation) -> [TileDelta] {
        let generator = WorldGenerator(seed: simulation.seed)
        let originalWorld = generator.generate()

        var deltas: [TileDelta] = []
        for y in 0..<World.heightInTiles {
            for x in 0..<World.widthInTiles {
                let current = simulation.world.tileAt(x: x, y: y)
                let original = originalWorld.tileAt(x: x, y: y)
                if current != original {
                    deltas.append(TileDelta(x: x, y: y, tileType: current))
                }
            }
        }
        return deltas
    }
}
