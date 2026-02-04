import Foundation

enum GameEvent: Sendable {
    case tileChanged(x: Int, y: Int, newType: TileType)
    case chunkDirty(ChunkCoord)
    case playerMoved(x: Double, y: Double)
    case inventoryChanged
}
