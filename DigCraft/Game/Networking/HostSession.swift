import Foundation
import Network

protocol HostSessionDelegate: AnyObject {
    @MainActor func hostSession(_ session: HostSession, didReceive message: NetMessage, from playerId: PlayerId)
    @MainActor func hostSession(_ session: HostSession, playerConnected playerId: PlayerId)
    @MainActor func hostSession(_ session: HostSession, playerDisconnected playerId: PlayerId)
}

final class HostSession: @unchecked Sendable {
    private var listener: NWListener?
    private var connections: [PlayerId: NWConnection] = [:]
    private var receiveBuffers: [PlayerId: Data] = [:]
    private var nextPlayerId: UInt8 = 1
    private let queue = DispatchQueue(label: "com.digcraft.host")

    weak var delegate: HostSessionDelegate?

    var connectedPlayerIds: [PlayerId] {
        Array(connections.keys)
    }

    var playerCount: Int {
        connections.count + 1 // +1 for host
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            listener = try NWListener(using: params)

            let service = NWListener.Service(name: nil, type: "_digcraft._tcp")
            listener?.service = service

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("[Host] Listening on port \(self?.listener?.port?.rawValue ?? 0)")
                case .failed(let error):
                    print("[Host] Listener failed: \(error)")
                    self?.stop()
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.start(queue: queue)
        } catch {
            print("[Host] Failed to create listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        receiveBuffers.removeAll()
    }

    func send(_ message: NetMessage, to playerId: PlayerId) {
        guard let connection = connections[playerId] else { return }
        let data = MessageCoder.encode(message)
        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                print("[Host] Send error to \(playerId.rawValue): \(error)")
            }
        })
    }

    func broadcast(_ message: NetMessage) {
        let data = MessageCoder.encode(message)
        for (_, connection) in connections {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    print("[Host] Broadcast send error: \(error)")
                }
            })
        }
    }

    func broadcast(_ message: NetMessage, except excludeId: PlayerId) {
        let data = MessageCoder.encode(message)
        for (id, connection) in connections where id != excludeId {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    print("[Host] Broadcast send error: \(error)")
                }
            })
        }
    }

    // MARK: - Private

    private func handleNewConnection(_ connection: NWConnection) {
        let playerId = PlayerId(rawValue: nextPlayerId)
        nextPlayerId += 1

        connections[playerId] = connection
        receiveBuffers[playerId] = Data()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[Host] Player \(playerId.rawValue) connected")
                Task { @MainActor in
                    self?.delegate?.hostSession(self!, playerConnected: playerId)
                }
            case .failed(let error):
                print("[Host] Player \(playerId.rawValue) connection failed: \(error)")
                self?.disconnectPlayer(playerId)
            case .cancelled:
                self?.disconnectPlayer(playerId)
            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveLoop(for: playerId)
    }

    private func receiveLoop(for playerId: PlayerId) {
        guard let connection = connections[playerId] else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data {
                self.receiveBuffers[playerId, default: Data()].append(data)

                var buffer = self.receiveBuffers[playerId] ?? Data()
                let messages = MessageCoder.decodeAll(from: &buffer)
                self.receiveBuffers[playerId] = buffer

                for message in messages {
                    Task { @MainActor in
                        self.delegate?.hostSession(self, didReceive: message, from: playerId)
                    }
                }
            }

            if let error {
                print("[Host] Receive error from player \(playerId.rawValue): \(error)")
                self.disconnectPlayer(playerId)
                return
            }

            if isComplete {
                self.disconnectPlayer(playerId)
                return
            }

            self.receiveLoop(for: playerId)
        }
    }

    private func disconnectPlayer(_ playerId: PlayerId) {
        connections[playerId]?.cancel()
        connections.removeValue(forKey: playerId)
        receiveBuffers.removeValue(forKey: playerId)

        Task { @MainActor in
            self.delegate?.hostSession(self, playerDisconnected: playerId)
        }
    }
}
