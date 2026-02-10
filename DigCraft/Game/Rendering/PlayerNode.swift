import SpriteKit

@MainActor
final class PlayerNode {
    let sprite: SKSpriteNode
    let playerId: PlayerId
    private var nameLabel: SKLabelNode?

    private static let playerColors: [SKColor] = {
        #if os(macOS)
        return [.cyan, .orange, .green, .systemPink]
        #else
        return [.cyan, .orange, .green, .systemPink]
        #endif
    }()

    init(playerId: PlayerId, name: String? = nil) {
        self.playerId = playerId

        let width = PlayerState.width * TileAtlas.tileSize
        let height = PlayerState.height * TileAtlas.tileSize

        let colorIndex = Int(playerId.rawValue) % PlayerNode.playerColors.count
        let color = PlayerNode.playerColors[colorIndex]

        sprite = SKSpriteNode(color: color, size: CGSize(width: width, height: height))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.zPosition = 10

        if let name {
            let label = SKLabelNode(text: name)
            label.fontSize = 10
            label.fontColor = .white
            label.verticalAlignmentMode = .bottom
            label.position = CGPoint(x: 0, y: height + 2)
            sprite.addChild(label)
            nameLabel = label
        }
    }

    func updatePosition(player: PlayerState) {
        sprite.position = CGPoint(
            x: player.positionX * TileAtlas.tileSize,
            y: player.positionY * TileAtlas.tileSize
        )
    }
}
