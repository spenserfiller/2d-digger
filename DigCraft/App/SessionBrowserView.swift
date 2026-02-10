import SwiftUI
import Network

struct SessionBrowserView: View {
    @State private var clientSession = ClientSession()
    @State private var isConnecting = false
    @State private var connectingName: String?
    @State private var errorMessage: String?
    @State private var joinHandler: JoinHandler?

    var onJoined: (ClientSession, JoinAccept) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Find Game")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            if isConnecting {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Connecting to \(connectingName ?? "host")...")
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if clientSession.discoveredHosts.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Searching for games...")
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(clientSession.discoveredHosts.enumerated()), id: \.offset) { _, host in
                        Button(action: {
                            connectToHost(name: host.name, endpoint: host.endpoint)
                        }) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                Text(host.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button("Back") {
                clientSession.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
        .onAppear {
            clientSession.startBrowsing()
        }
        .onDisappear {
            if !isConnecting {
                clientSession.stop()
            }
        }
    }

    private func connectToHost(name: String, endpoint: NWEndpoint) {
        isConnecting = true
        connectingName = name
        errorMessage = nil

        clientSession.stopBrowsing()

        let handler = JoinHandler(onAccept: { accept in
            Task { @MainActor in
                onJoined(clientSession, accept)
            }
        }, onReject: { reason in
            Task { @MainActor in
                errorMessage = reason
                isConnecting = false
                joinHandler = nil
                clientSession.startBrowsing()
            }
        }, onError: { error in
            Task { @MainActor in
                errorMessage = error
                isConnecting = false
                joinHandler = nil
                clientSession.startBrowsing()
            }
        })

        // Store to retain
        joinHandler = handler
        clientSession.delegate = handler
        clientSession.connect(to: endpoint)
    }
}

@MainActor
final class JoinHandler: ClientSessionDelegate {
    let onAccept: (JoinAccept) -> Void
    let onReject: (String) -> Void
    let onError: (String) -> Void

    init(onAccept: @escaping (JoinAccept) -> Void,
         onReject: @escaping (String) -> Void,
         onError: @escaping (String) -> Void) {
        self.onAccept = onAccept
        self.onReject = onReject
        self.onError = onError
    }

    func clientSessionDidConnect(_ session: ClientSession) {
        let deviceName: String
        #if os(macOS)
        deviceName = Host.current().localizedName ?? "Mac Player"
        #else
        deviceName = UIDevice.current.name
        #endif
        session.sendToHost(.joinRequest(JoinRequest(
            clientName: deviceName,
            protocolVersion: digCraftProtocolVersion
        )))
    }

    func clientSession(_ session: ClientSession, didReceive message: NetMessage) {
        switch message {
        case .joinAccept(let accept):
            onAccept(accept)
        case .joinReject(let reject):
            onReject(reject.reason)
        default:
            break
        }
    }

    func clientSession(_ session: ClientSession, didDisconnectWithError error: Error?) {
        onError(error?.localizedDescription ?? "Connection lost")
    }
}
