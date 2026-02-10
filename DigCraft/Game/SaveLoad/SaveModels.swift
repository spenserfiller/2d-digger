import Foundation

struct TileDelta: Codable, Sendable {
    let x: Int
    let y: Int
    let tileType: TileType
}

struct SaveData: Codable, Sendable {
    let seed: Int32
    let tileDeltas: [TileDelta]
    let player: PlayerState
    let inventory: Inventory

    // Multi-player support (optional for backward compat)
    let players: [PlayerId: PlayerState]?
    let inventories: [PlayerId: Inventory]?

    init(seed: Int32, tileDeltas: [TileDelta], player: PlayerState, inventory: Inventory,
         players: [PlayerId: PlayerState]? = nil, inventories: [PlayerId: Inventory]? = nil) {
        self.seed = seed
        self.tileDeltas = tileDeltas
        self.player = player
        self.inventory = inventory
        self.players = players
        self.inventories = inventories
    }

    // Custom decoding to handle both old format (no players/inventories) and new format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seed = try container.decode(Int32.self, forKey: .seed)
        tileDeltas = try container.decode([TileDelta].self, forKey: .tileDeltas)
        player = try container.decode(PlayerState.self, forKey: .player)
        inventory = try container.decode(Inventory.self, forKey: .inventory)
        players = try container.decodeIfPresent([PlayerId: PlayerState].self, forKey: .players)
        inventories = try container.decodeIfPresent([PlayerId: Inventory].self, forKey: .inventories)
    }
}
