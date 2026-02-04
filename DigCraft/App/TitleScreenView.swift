import SwiftUI

struct TitleScreenView: View {
    var onNewGame: () -> Void
    var onLoadGame: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("DigCraft")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            VStack(spacing: 16) {
                Button("New Game") {
                    onNewGame()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Load Game") {
                    onLoadGame()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!SaveManager.hasSaveFile)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
    }
}
