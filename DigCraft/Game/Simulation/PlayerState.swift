import Foundation

struct AABB: Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var minX: Double { x }
    var maxX: Double { x + width }
    var minY: Double { y }
    var maxY: Double { y + height }

    func intersects(_ other: AABB) -> Bool {
        minX < other.maxX && maxX > other.minX &&
        minY < other.maxY && maxY > other.minY
    }

    /// Returns the range of tile columns this AABB overlaps
    var tileRangeX: ClosedRange<Int> {
        Int(floor(minX))...Int(floor(maxX - 0.001))
    }

    /// Returns the range of tile rows this AABB overlaps
    var tileRangeY: ClosedRange<Int> {
        Int(floor(minY))...Int(floor(maxY - 0.001))
    }
}

struct PlayerState: Sendable, Codable {
    static let width: Double = 0.8
    static let height: Double = 1.8

    var positionX: Double = 0
    var positionY: Double = 0
    var velocityX: Double = 0
    var velocityY: Double = 0
    var isOnGround: Bool = false

    var aabb: AABB {
        AABB(
            x: positionX - PlayerState.width / 2,
            y: positionY,
            width: PlayerState.width,
            height: PlayerState.height
        )
    }

    /// The tile coordinate the player is standing on
    var tileX: Int { Int(floor(positionX)) }
    var tileY: Int { Int(floor(positionY)) }
}
