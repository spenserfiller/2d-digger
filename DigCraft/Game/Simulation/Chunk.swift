import Foundation

struct ChunkCoord: Hashable, Codable, Sendable {
    let x: Int
    let y: Int
}

struct Chunk: Sendable {
    static let size = 32

    private var tiles: [TileType]

    init(fill: TileType = .air) {
        tiles = [TileType](repeating: fill, count: Chunk.size * Chunk.size)
    }

    subscript(localX: Int, localY: Int) -> TileType {
        get {
            precondition(localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size)
            return tiles[localY * Chunk.size + localX]
        }
        set {
            precondition(localX >= 0 && localX < Chunk.size && localY >= 0 && localY < Chunk.size)
            tiles[localY * Chunk.size + localX] = newValue
        }
    }
}
