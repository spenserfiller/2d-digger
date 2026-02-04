import SwiftUI
import SpriteKit

struct GameView: View {
    let simulation: GameSimulation
    let scene: GameScene
    var onPause: () -> Void

    init(simulation: GameSimulation, onPause: @escaping () -> Void) {
        self.simulation = simulation
        self.onPause = onPause

        let scene = GameScene()
        scene.scaleMode = .resizeFill
        scene.configure(simulation: simulation)
        self.scene = scene
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // Top bar with pause button and hotbar
            HStack {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)

                Spacer()

                HotbarView(inventory: simulation.inventory)

                Spacer()

                #if os(iOS)
                Button(action: { simulation.process(.jump) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                #else
                Color.clear.frame(width: 60)
                #endif
            }
            .padding(.top, 8)
        }
    }
}
