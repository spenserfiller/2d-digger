import SwiftUI

enum AppScreen {
    case title
    case game
    case paused
    case joinBrowse
}

struct ContentView: View {
    @State private var screen: AppScreen = .title
    @State private var simulation: GameSimulation?
    @State private var coordinator: GameCoordinator?
    @State private var showPauseMenu = false
    @State private var disconnectMessage: String?

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleScreenView(
                    onNewGame: startNewGame,
                    onLoadGame: loadGame,
                    onHostGame: startHostGame,
                    onJoinGame: { screen = .joinBrowse }
                )

            case .joinBrowse:
                SessionBrowserView(
                    onJoined: { session, accept in
                        startClientGame(session: session, accept: accept)
                    },
                    onCancel: {
                        screen = .title
                    }
                )

            case .game, .paused:
                if let simulation {
                    GameView(simulation: simulation, coordinator: coordinator) {
                        showPauseMenu = true
                    }
                    .ignoresSafeArea()

                    if showPauseMenu {
                        PauseMenuView(
                            isClient: coordinator?.mode.isClient == true,
                            isMultiplayer: coordinator?.mode.isMultiplayer == true,
                            onResume: {
                                showPauseMenu = false
                            },
                            onSave: {
                                SaveManager.save(simulation: simulation)
                            },
                            onQuit: {
                                showPauseMenu = false
                                coordinator?.stop()
                                coordinator = nil
                                self.simulation = nil
                                screen = .title
                            }
                        )
                    }
                }
            }
        }
        .onChange(of: coordinator?.disconnectError) { _, error in
            if let error {
                coordinator?.stop()
                coordinator = nil
                simulation = nil
                showPauseMenu = false
                disconnectMessage = error
                screen = .title
            }
        }
        .alert("Disconnected", isPresented: .init(
            get: { disconnectMessage != nil },
            set: { if !$0 { disconnectMessage = nil } }
        )) {
            Button("OK") { disconnectMessage = nil }
        } message: {
            Text(disconnectMessage ?? "")
        }
    }

    private func startNewGame() {
        let seed = Int32.random(in: Int32.min...Int32.max)
        let sim = GameSimulation(seed: seed)
        simulation = sim
        coordinator = nil
        screen = .game
    }

    private func loadGame() {
        guard let saveData = SaveManager.load() else { return }
        let sim = GameSimulation(seed: saveData.seed)

        // Apply tile deltas
        for delta in saveData.tileDeltas {
            sim.world.setTile(x: delta.x, y: delta.y, to: delta.tileType)
        }

        // Restore player(s) and inventory
        if let players = saveData.players, let inventories = saveData.inventories {
            sim.restoreMultiplayer(players: players, inventories: inventories)
        } else {
            sim.restore(player: saveData.player, inventory: saveData.inventory)
        }

        simulation = sim
        coordinator = nil
        screen = .game
    }

    private func startHostGame() {
        let seed = Int32.random(in: Int32.min...Int32.max)
        let sim = GameSimulation(seed: seed)
        let session = HostSession()
        session.start()
        let coord = GameCoordinator(mode: .host(session: session), simulation: sim)
        simulation = sim
        coordinator = coord
        screen = .game
    }

    private func startClientGame(session: ClientSession, accept: JoinAccept) {
        let sim = GameSimulation(seed: accept.worldSeed)

        // Apply tile deltas
        for delta in accept.tileDeltas {
            sim.world.setTile(x: delta.x, y: delta.y, to: delta.tileType)
        }

        // Restore all players and inventories from server state
        sim.restoreMultiplayer(players: accept.existingPlayers, inventories: accept.existingInventories)
        sim.localPlayerId = accept.assignedId

        let coord = GameCoordinator(
            mode: .client(session: session, assignedId: accept.assignedId),
            simulation: sim
        )

        // Re-assign the delegate to the coordinator now
        session.delegate = coord

        simulation = sim
        coordinator = coord
        screen = .game
    }
}
