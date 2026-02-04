import Foundation

enum TileType: UInt8, Codable, Sendable {
    case air = 0
    case grass = 1
    case dirt = 2
    case stone = 3
    case oreCopper = 4

    var isSolid: Bool {
        self != .air
    }

    var displayName: String {
        switch self {
        case .air: "Air"
        case .grass: "Grass"
        case .dirt: "Dirt"
        case .stone: "Stone"
        case .oreCopper: "Copper Ore"
        }
    }
}
