import SwiftUI

struct PauseMenuView: View {
    var isClient: Bool = false
    var isMultiplayer: Bool = false
    var onResume: () -> Void
    var onSave: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Paused")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    Button("Resume") {
                        onResume()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !isClient {
                        Button("Save Game") {
                            onSave()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button(isMultiplayer ? "Disconnect" : "Quit to Title") {
                        onQuit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
