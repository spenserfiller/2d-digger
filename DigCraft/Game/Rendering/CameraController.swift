import SpriteKit

@MainActor
final class CameraController {
    let cameraNode: SKCameraNode
    private let lerpFactor: CGFloat = 0.1
    private var viewSize: CGSize = .zero

    init() {
        cameraNode = SKCameraNode()
    }

    func setViewSize(_ size: CGSize) {
        viewSize = size
    }

    func update(playerPosition: CGPoint) {
        let targetX = playerPosition.x
        let targetY = playerPosition.y

        // Smooth lerp
        let newX = cameraNode.position.x + (targetX - cameraNode.position.x) * lerpFactor
        let newY = cameraNode.position.y + (targetY - cameraNode.position.y) * lerpFactor

        // Clamp to world bounds
        let worldPixelWidth = CGFloat(World.widthInTiles) * TileAtlas.tileSize
        let worldPixelHeight = CGFloat(World.heightInTiles) * TileAtlas.tileSize

        let halfViewW = viewSize.width / 2
        let halfViewH = viewSize.height / 2

        let clampedX = max(halfViewW, min(worldPixelWidth - halfViewW, newX))
        let clampedY = max(halfViewH, min(worldPixelHeight - halfViewH, newY))

        cameraNode.position = CGPoint(x: clampedX, y: clampedY)
    }

    func snapTo(playerPosition: CGPoint) {
        let worldPixelWidth = CGFloat(World.widthInTiles) * TileAtlas.tileSize
        let worldPixelHeight = CGFloat(World.heightInTiles) * TileAtlas.tileSize

        let halfViewW = viewSize.width / 2
        let halfViewH = viewSize.height / 2

        let clampedX = max(halfViewW, min(worldPixelWidth - halfViewW, playerPosition.x))
        let clampedY = max(halfViewH, min(worldPixelHeight - halfViewH, playerPosition.y))

        cameraNode.position = CGPoint(x: clampedX, y: clampedY)
    }
}
