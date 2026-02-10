import SwiftUI
import SpriteKit

struct GameView: View {
    let simulation: GameSimulation
    let coordinator: GameCoordinator?
    let scene: GameScene
    var onPause: () -> Void
    @State private var showControls = false

    init(simulation: GameSimulation, coordinator: GameCoordinator? = nil, onPause: @escaping () -> Void) {
        self.simulation = simulation
        self.coordinator = coordinator
        self.onPause = onPause

        let scene = GameScene()
        scene.scaleMode = .resizeFill
        scene.configure(simulation: simulation, coordinator: coordinator)
        self.scene = scene
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // Top-left: pause and help buttons
            VStack {
                HStack(spacing: 8) {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { showControls.toggle() }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title2)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    #if os(iOS)
                    Button(action: {
                        if let coordinator {
                            coordinator.sendCommand(.jump)
                        } else {
                            simulation.process(.jump)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom-center: hotbar
                HotbarView(inventory: simulation.inventory)
                    .padding(.bottom, 16)
            }

            if showControls {
                ControlsOverlay(onDismiss: { showControls = false })
            }
        }
    }
}
