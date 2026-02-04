import SpriteKit

@MainActor
final class PlayerNode {
    let sprite: SKSpriteNode

    init() {
        let width = PlayerState.width * TileAtlas.tileSize
        let height = PlayerState.height * TileAtlas.tileSize

        #if os(macOS)
        let color = NSColor.cyan
        #else
        let color = UIColor.cyan
        #endif

        sprite = SKSpriteNode(color: color, size: CGSize(width: width, height: height))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.zPosition = 10
    }

    func updatePosition(player: PlayerState) {
        sprite.position = CGPoint(
            x: player.positionX * TileAtlas.tileSize,
            y: player.positionY * TileAtlas.tileSize
        )
    }
}
