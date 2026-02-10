import Foundation

// MARK: - Protocol Version

let digCraftProtocolVersion: UInt16 = 1

// MARK: - Net Message Envelope

enum NetMessage: Codable, Sendable {
    // Client → Host
    case joinRequest(JoinRequest)
    case commandBatch(CommandBatch)
    case ping(PingMessage)

    // Host → Client
    case joinAccept(JoinAccept)
    case joinReject(JoinReject)
    case tileDeltaBatch(TileDeltaBatch)
    case playerStates(PlayerStatesMessage)
    case playerJoined(PlayerJoinedMessage)
    case playerLeft(PlayerLeftMessage)
    case inventoryUpdate(InventoryUpdateMessage)
    case pong(PongMessage)
}

// MARK: - Client → Host Messages

struct JoinRequest: Codable, Sendable {
    let clientName: String
    let protocolVersion: UInt16
}

struct CommandBatch: Codable, Sendable {
    let playerId: PlayerId
    let commands: [GameCommand]
    let lastAckedServerTick: UInt64
}

struct PingMessage: Codable, Sendable {
    let sentAt: UInt64
}

// MARK: - Host → Client Messages

struct JoinAccept: Codable, Sendable {
    let assignedId: PlayerId
    let worldSeed: Int32
    let serverTick: UInt64
    let existingPlayers: [PlayerId: PlayerState]
    let existingInventories: [PlayerId: Inventory]
    let tileDeltas: [TileDelta]
}

struct JoinReject: Codable, Sendable {
    let reason: String
}

struct TileChange: Codable, Sendable {
    let x: Int
    let y: Int
    let newType: TileType
}

struct TileDeltaBatch: Codable, Sendable {
    let serverTick: UInt64
    let changes: [TileChange]
}

struct PlayerStatesMessage: Codable, Sendable {
    let serverTick: UInt64
    let players: [PlayerId: PlayerState]
}

struct PlayerJoinedMessage: Codable, Sendable {
    let playerId: PlayerId
    let playerName: String
    let initialState: PlayerState
}

struct PlayerLeftMessage: Codable, Sendable {
    let playerId: PlayerId
}

struct InventoryUpdateMessage: Codable, Sendable {
    let playerId: PlayerId
    let inventory: Inventory
}

struct PongMessage: Codable, Sendable {
    let clientSentAt: UInt64
    let serverReceivedAt: UInt64
}
