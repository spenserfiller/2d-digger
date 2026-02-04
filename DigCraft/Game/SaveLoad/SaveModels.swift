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
}
