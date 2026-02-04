import SpriteKit

@MainActor
final class ChunkRenderer {
    private var tileMapNodes: [ChunkCoord: SKTileMapNode] = [:]
    private var dirtyChunks: Set<ChunkCoord> = []
    private let atlas: TileAtlas
    private weak var parentNode: SKNode?

    init(atlas: TileAtlas, parentNode: SKNode) {
        self.atlas = atlas
        self.parentNode = parentNode
    }

    func buildAll(world: World) {
        for cy in 0..<World.heightInChunks {
            for cx in 0..<World.widthInChunks {
                let coord = ChunkCoord(x: cx, y: cy)
                buildChunkNode(coord: coord, world: world)
            }
        }
    }

    func markDirty(_ coord: ChunkCoord) {
        dirtyChunks.insert(coord)
    }

    func markAllDirty() {
        for cy in 0..<World.heightInChunks {
            for cx in 0..<World.widthInChunks {
                dirtyChunks.insert(ChunkCoord(x: cx, y: cy))
            }
        }
    }

    func rebuildDirtyChunks(world: World) {
        for coord in dirtyChunks {
            rebuildChunk(coord: coord, world: world)
        }
        dirtyChunks.removeAll()
    }

    private func buildChunkNode(coord: ChunkCoord, world: World) {
        let tileSize = CGSize(width: TileAtlas.tileSize, height: TileAtlas.tileSize)
        let tileMap = SKTileMapNode(
            tileSet: atlas.tileSet,
            columns: Chunk.size,
            rows: Chunk.size,
            tileSize: tileSize
        )
        tileMap.anchorPoint = .zero

        // Position: chunk coord * chunk pixel size
        let pixelX = CGFloat(coord.x * Chunk.size) * TileAtlas.tileSize
        let pixelY = CGFloat(coord.y * Chunk.size) * TileAtlas.tileSize
        tileMap.position = CGPoint(x: pixelX, y: pixelY)

        fillTileMap(tileMap, coord: coord, world: world)

        parentNode?.addChild(tileMap)
        tileMapNodes[coord] = tileMap
    }

    private func rebuildChunk(coord: ChunkCoord, world: World) {
        guard let tileMap = tileMapNodes[coord] else { return }
        fillTileMap(tileMap, coord: coord, world: world)
    }

    private func fillTileMap(_ tileMap: SKTileMapNode, coord: ChunkCoord, world: World) {
        let baseX = coord.x * Chunk.size
        let baseY = coord.y * Chunk.size

        for localY in 0..<Chunk.size {
            for localX in 0..<Chunk.size {
                let worldX = baseX + localX
                let worldY = baseY + localY
                let tile = world.tileAt(x: worldX, y: worldY)
                let group = atlas.group(for: tile)
                tileMap.setTileGroup(group, forColumn: localX, row: localY)
            }
        }
    }
}
