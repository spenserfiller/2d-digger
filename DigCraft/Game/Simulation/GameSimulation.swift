import Foundation
import Observation

@Observable
final class GameSimulation: @unchecked Sendable {
    // MARK: - State
    var world: World
    var players: [PlayerId: PlayerState] = [:]
    var inventories: [PlayerId: Inventory] = [:]
    var localPlayerId: PlayerId = .host
    let seed: Int32

    // MARK: - Backward-compat computed properties
    var player: PlayerState {
        get { players[localPlayerId] ?? PlayerState() }
        set { players[localPlayerId] = newValue }
    }

    var inventory: Inventory {
        get { inventories[localPlayerId] ?? Inventory() }
        set { inventories[localPlayerId] = newValue }
    }

    // MARK: - Events
    var pendingEvents: [GameEvent] = []

    // MARK: - Fixed timestep
    private static let fixedDT: Double = 1.0 / 60.0
    private var accumulator: Double = 0

    // MARK: - Movement state
    private var moveDirections: [PlayerId: MoveDirection] = [:]

    // MARK: - Tick counter
    private(set) var currentTick: UInt64 = 0

    // MARK: - Dig range
    static let digRange: Double = 5.0

    init(seed: Int32) {
        self.seed = seed
        let generator = WorldGenerator(seed: seed)
        self.world = generator.generate()

        // Add the host player by default (addPlayer handles spawn position)
        addPlayer(id: .host)
    }

    // MARK: - Player Management

    func addPlayer(id: PlayerId) {
        players[id] = PlayerState()
        inventories[id] = Inventory()

        // Spawn at world center surface
        let generator = WorldGenerator(seed: seed)
        let spawnX = World.widthInTiles / 2
        let spawnY = generator.surfaceY(at: spawnX, world: world)
        players[id]!.positionX = Double(spawnX) + 0.5
        players[id]!.positionY = Double(spawnY)
    }

    func removePlayer(id: PlayerId) {
        players.removeValue(forKey: id)
        inventories.removeValue(forKey: id)
        moveDirections.removeValue(forKey: id)
    }

    // MARK: - Command Processing

    func process(_ command: GameCommand, from playerId: PlayerId = .host) {
        switch command {
        case .move(let direction):
            moveDirections[playerId] = direction
        case .stopMove:
            moveDirections[playerId] = nil
        case .jump:
            if players[playerId]?.isOnGround == true {
                players[playerId]?.velocityY = PhysicsSystem.jumpVelocity
                players[playerId]?.isOnGround = false
            }
        case .dig(let tileX, let tileY):
            dig(at: tileX, tileY: tileY, by: playerId)
        case .place(let tileX, let tileY):
            place(at: tileX, tileY: tileY, by: playerId)
        case .selectHotbar(let index):
            inventories[playerId]?.selectSlot(index)
            pendingEvents.append(.inventoryChanged(playerId))
        }
    }

    // MARK: - Update

    func update(deltaTime: Double) {
        accumulator += deltaTime

        while accumulator >= GameSimulation.fixedDT {
            fixedUpdate(dt: GameSimulation.fixedDT)
            accumulator -= GameSimulation.fixedDT
        }
    }

    /// Client-only: runs physics for localPlayerId only (prediction)
    func updateLocalOnly(deltaTime: Double) {
        accumulator += deltaTime

        while accumulator >= GameSimulation.fixedDT {
            fixedUpdateLocalOnly(dt: GameSimulation.fixedDT)
            accumulator -= GameSimulation.fixedDT
        }
    }

    private func fixedUpdate(dt: Double) {
        currentTick += 1

        for id in players.keys {
            // Apply movement input
            switch moveDirections[id] {
            case .left:
                players[id]?.velocityX = -PhysicsSystem.moveSpeed
            case .right:
                players[id]?.velocityX = PhysicsSystem.moveSpeed
            case nil:
                players[id]?.velocityX *= PhysicsSystem.friction
                if abs(players[id]?.velocityX ?? 0) < 0.1 {
                    players[id]?.velocityX = 0
                }
            }

            if var p = players[id] {
                PhysicsSystem.update(player: &p, world: world, dt: dt)
                players[id] = p
                pendingEvents.append(.playerMoved(id, x: p.positionX, y: p.positionY))
            }
        }
    }

    private func fixedUpdateLocalOnly(dt: Double) {
        currentTick += 1
        let id = localPlayerId

        switch moveDirections[id] {
        case .left:
            players[id]?.velocityX = -PhysicsSystem.moveSpeed
        case .right:
            players[id]?.velocityX = PhysicsSystem.moveSpeed
        case nil:
            players[id]?.velocityX *= PhysicsSystem.friction
            if abs(players[id]?.velocityX ?? 0) < 0.1 {
                players[id]?.velocityX = 0
            }
        }

        if var p = players[id] {
            PhysicsSystem.update(player: &p, world: world, dt: dt)
            players[id] = p
            pendingEvents.append(.playerMoved(id, x: p.positionX, y: p.positionY))
        }
    }

    // MARK: - Actions

    private func dig(at tileX: Int, tileY: Int, by playerId: PlayerId) {
        guard let playerState = players[playerId] else { return }

        // Range check
        let dx = Double(tileX) + 0.5 - playerState.positionX
        let dy = Double(tileY) + 0.5 - (playerState.positionY + PlayerState.height / 2)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= GameSimulation.digRange else { return }

        let existing = world.tileAt(x: tileX, y: tileY)
        guard existing.isSolid else { return }

        if let coord = world.setTile(x: tileX, y: tileY, to: .air) {
            inventories[playerId]?.add(existing)
            pendingEvents.append(.tileChanged(x: tileX, y: tileY, newType: .air))
            pendingEvents.append(.chunkDirty(coord))
            pendingEvents.append(.inventoryChanged(playerId))
        }
    }

    private func place(at tileX: Int, tileY: Int, by playerId: PlayerId) {
        guard let playerState = players[playerId] else { return }

        // Range check
        let dx = Double(tileX) + 0.5 - playerState.positionX
        let dy = Double(tileY) + 0.5 - (playerState.positionY + PlayerState.height / 2)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= GameSimulation.digRange else { return }

        // Must be air
        guard world.tileAt(x: tileX, y: tileY) == .air else { return }

        // Check ALL player collisions - don't place where any player is
        let tileAABB = AABB(x: Double(tileX), y: Double(tileY), width: 1, height: 1)
        for (_, pState) in players {
            guard !pState.aabb.intersects(tileAABB) else { return }
        }

        guard let tileType = inventories[playerId]?.removeSelected() else { return }

        if let coord = world.setTile(x: tileX, y: tileY, to: tileType) {
            pendingEvents.append(.tileChanged(x: tileX, y: tileY, newType: tileType))
            pendingEvents.append(.chunkDirty(coord))
            pendingEvents.append(.inventoryChanged(playerId))
        }
    }

    // MARK: - Event Consumption

    func consumeEvents() -> [GameEvent] {
        let events = pendingEvents
        pendingEvents = []
        return events
    }

    /// Returns pending events without consuming them (for coordinator to read)
    func peekEvents() -> [GameEvent] {
        return pendingEvents
    }

    // MARK: - Save/Load Support

    func restore(player: PlayerState, inventory: Inventory) {
        self.players[localPlayerId] = player
        self.inventories[localPlayerId] = inventory
    }

    func restoreMultiplayer(players: [PlayerId: PlayerState], inventories: [PlayerId: Inventory]) {
        self.players = players
        self.inventories = inventories
    }
}
