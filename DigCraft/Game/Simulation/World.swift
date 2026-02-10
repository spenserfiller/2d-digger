import Foundation

struct World: Sendable {
    static let widthInChunks = 8
    static let heightInChunks = 6
    static let widthInTiles = widthInChunks * Chunk.size   // 256
    static let heightInTiles = heightInChunks * Chunk.size  // 192

    private var chunks: [ChunkCoord: Chunk]

    init() {
        chunks = [:]
        for cy in 0..<World.heightInChunks {
            for cx in 0..<World.widthInChunks {
                chunks[ChunkCoord(x: cx, y: cy)] = Chunk()
            }
        }
    }

    func tileAt(x: Int, y: Int) -> TileType {
        guard x >= 0, x < World.widthInTiles, y >= 0, y < World.heightInTiles else {
            return .stone
        }
        let coord = ChunkCoord(x: x / Chunk.size, y: y / Chunk.size)
        guard let chunk = chunks[coord] else { return .air }
        return chunk[x % Chunk.size, y % Chunk.size]
    }

    @discardableResult
    mutating func setTile(x: Int, y: Int, to tile: TileType) -> ChunkCoord? {
        guard x >= 0, x < World.widthInTiles, y >= 0, y < World.heightInTiles else {
            return nil
        }
        let coord = ChunkCoord(x: x / Chunk.size, y: y / Chunk.size)
        chunks[coord]?[x % Chunk.size, y % Chunk.size] = tile
        return coord
    }

    func chunk(at coord: ChunkCoord) -> Chunk? {
        chunks[coord]
    }

    // MARK: - Snapshot Methods

    func chunkSnapshot(at coord: ChunkCoord) -> Chunk? {
        chunks[coord]
    }

    mutating func restoreChunk(at coord: ChunkCoord, chunk: Chunk) {
        chunks[coord] = chunk
    }

    var allChunkCoords: [ChunkCoord] {
        Array(chunks.keys)
    }
}
