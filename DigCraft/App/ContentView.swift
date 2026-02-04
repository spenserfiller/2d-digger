import SwiftUI

enum AppScreen {
    case title
    case game
    case paused
}

struct ContentView: View {
    @State private var screen: AppScreen = .title
    @State private var simulation: GameSimulation?
    @State private var showPauseMenu = false

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleScreenView(
                    onNewGame: startNewGame,
                    onLoadGame: loadGame
                )
            case .game, .paused:
                if let simulation {
                    GameView(simulation: simulation) {
                        showPauseMenu = true
                    }
                    .ignoresSafeArea()

                    if showPauseMenu {
                        PauseMenuView(
                            onResume: {
                                showPauseMenu = false
                            },
                            onSave: {
                                SaveManager.save(simulation: simulation)
                            },
                            onQuit: {
                                showPauseMenu = false
                                self.simulation = nil
                                screen = .title
                            }
                        )
                    }
                }
            }
        }
    }

    private func startNewGame() {
        let seed = Int32.random(in: Int32.min...Int32.max)
        simulation = GameSimulation(seed: seed)
        screen = .game
    }

    private func loadGame() {
        guard let saveData = SaveManager.load() else { return }
        let sim = GameSimulation(seed: saveData.seed)

        // Apply tile deltas
        for delta in saveData.tileDeltas {
            sim.world.setTile(x: delta.x, y: delta.y, to: delta.tileType)
        }

        // Restore player and inventory
        sim.restore(player: saveData.player, inventory: saveData.inventory)

        simulation = sim
        screen = .game
    }
}
