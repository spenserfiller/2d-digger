import Foundation
import Network
import Observation

@Observable
final class ClientSession: @unchecked Sendable {
    // MARK: - Browsing

    private var browser: NWBrowser?
    private(set) var discoveredHosts: [(name: String, endpoint: NWEndpoint)] = []

    // MARK: - Connection

    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private let queue = DispatchQueue(label: "com.digcraft.client")

    weak var delegate: ClientSessionDelegate?

    private(set) var isConnected = false

    // MARK: - Browse

    func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_digcraft._tcp", domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.discoveredHosts = results.compactMap { result in
                    switch result.endpoint {
                    case .service(let name, _, _, _):
                        return (name: name, endpoint: result.endpoint)
                    default:
                        return nil
                    }
                }
            }
        }

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[Client] Browser ready")
            case .failed(let error):
                print("[Client] Browser failed: \(error)")
            default:
                break
            }
        }

        browser?.start(queue: queue)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    // MARK: - Connect

    func connect(to endpoint: NWEndpoint) {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        connection = NWConnection(to: endpoint, using: params)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                print("[Client] Connected to host")
                Task { @MainActor in
                    self.isConnected = true
                    self.delegate?.clientSessionDidConnect(self)
                }
                self.receiveLoop()
            case .failed(let error):
                print("[Client] Connection failed: \(error)")
                Task { @MainActor in
                    self.isConnected = false
                    self.delegate?.clientSession(self, didDisconnectWithError: error)
                }
            case .cancelled:
                Task { @MainActor in
                    self.isConnected = false
                    self.delegate?.clientSession(self, didDisconnectWithError: nil)
                }
            default:
                break
            }
        }

        connection?.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    func sendToHost(_ message: NetMessage) {
        guard let connection else { return }
        let data = MessageCoder.encode(message)
        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                print("[Client] Send error: \(error)")
            }
        })
    }

    func stop() {
        stopBrowsing()
        disconnect()
    }

    // MARK: - Private

    private func receiveLoop() {
        guard let connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data {
                self.receiveBuffer.append(data)

                var buffer = self.receiveBuffer
                let messages = MessageCoder.decodeAll(from: &buffer)
                self.receiveBuffer = buffer

                for message in messages {
                    Task { @MainActor in
                        self.delegate?.clientSession(self, didReceive: message)
                    }
                }
            }

            if let error {
                print("[Client] Receive error: \(error)")
                Task { @MainActor in
                    self.isConnected = false
                    self.delegate?.clientSession(self, didDisconnectWithError: error)
                }
                return
            }

            if isComplete {
                Task { @MainActor in
                    self.isConnected = false
                    self.delegate?.clientSession(self, didDisconnectWithError: nil)
                }
                return
            }

            self.receiveLoop()
        }
    }
}

// MARK: - Delegate Protocol

protocol ClientSessionDelegate: AnyObject {
    @MainActor func clientSessionDidConnect(_ session: ClientSession)
    @MainActor func clientSession(_ session: ClientSession, didReceive message: NetMessage)
    @MainActor func clientSession(_ session: ClientSession, didDisconnectWithError error: Error?)
}
