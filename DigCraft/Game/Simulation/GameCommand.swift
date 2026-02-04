import Foundation

enum GameCommand: Codable, Sendable {
    case move(direction: MoveDirection)
    case stopMove
    case jump
    case dig(tileX: Int, tileY: Int)
    case place(tileX: Int, tileY: Int)
    case selectHotbar(index: Int)
}

enum MoveDirection: Codable, Sendable {
    case left
    case right
}
