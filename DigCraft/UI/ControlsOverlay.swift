import SwiftUI

struct ControlsOverlay: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Controls")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                #if os(macOS)
                controlRow("A / D", "Move left / right")
                controlRow("W / Space", "Jump")
                controlRow("Left Click", "Dig tile")
                controlRow("Right Click", "Place tile")
                controlRow("1 - 5", "Select hotbar slot")
                controlRow("Esc", "Pause")
                #else
                controlRow("Drag left side", "Move left / right")
                controlRow("Tap right side", "Dig tile")
                controlRow("Arrow button", "Jump")
                #endif
            }
            .padding(30)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func controlRow(_ key: String, _ action: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 140, alignment: .leading)
            Text(action)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
