import SpriteKit

final class GameScene: SKScene {
    private var simulation: GameSimulation!
    private var chunkRenderer: ChunkRenderer!
    private var playerNode: PlayerNode!
    private var cameraController: CameraController!
    private var inputMapper: InputMapper!
    private var lastUpdateTime: TimeInterval = 0
    private var debugNode: SKNode?
    var showDebugOverlay: Bool = false {
        didSet { updateDebugOverlay() }
    }

    // World layer node for all tile maps
    let worldNode = SKNode()

    func configure(simulation: GameSimulation) {
        self.simulation = simulation
    }

    override func didMove(to view: SKView) {
        guard simulation != nil else { return }

        backgroundColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        anchorPoint = .zero

        addChild(worldNode)

        // Build tile atlas and chunk renderer
        let atlas = TileAtlas()
        chunkRenderer = ChunkRenderer(atlas: atlas, parentNode: worldNode)
        chunkRenderer.buildAll(world: simulation.world)

        // Player node
        playerNode = PlayerNode()
        playerNode.updatePosition(player: simulation.player)
        worldNode.addChild(playerNode.sprite)

        // Camera
        cameraController = CameraController()
        cameraController.setViewSize(view.frame.size)
        addChild(cameraController.cameraNode)
        camera = cameraController.cameraNode

        let playerPixelPos = CGPoint(
            x: simulation.player.positionX * TileAtlas.tileSize,
            y: simulation.player.positionY * TileAtlas.tileSize
        )
        cameraController.snapTo(playerPosition: playerPixelPos)

        // Input mapper
        inputMapper = InputMapper(scene: self, simulation: simulation)

        // Enable FPS display in debug builds
        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        cameraController?.setViewSize(size)
    }

    override func update(_ currentTime: TimeInterval) {
        guard simulation != nil else { return }

        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(currentTime - lastUpdateTime, 0.1) // cap at 100ms
        }
        lastUpdateTime = currentTime

        // Process held keys
        inputMapper?.updateHeldKeys()

        // Update simulation
        simulation.update(deltaTime: dt)

        // Consume events
        let events = simulation.consumeEvents()
        for event in events {
            switch event {
            case .chunkDirty(let coord):
                chunkRenderer.markDirty(coord)
            case .playerMoved:
                break // handled below
            case .tileChanged:
                break // chunk dirty handles visual update
            case .inventoryChanged:
                break // SwiftUI observes directly
            }
        }

        // Rebuild dirty chunks
        chunkRenderer.rebuildDirtyChunks(world: simulation.world)

        // Update player visual
        playerNode.updatePosition(player: simulation.player)

        // Update camera
        let playerPixelPos = CGPoint(
            x: simulation.player.positionX * TileAtlas.tileSize,
            y: simulation.player.positionY * TileAtlas.tileSize
        )
        cameraController.update(playerPosition: playerPixelPos)
    }

    // MARK: - macOS Input

    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        inputMapper?.keyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        inputMapper?.keyUp(event)
    }

    override func mouseDown(with event: NSEvent) {
        inputMapper?.mouseDown(event, in: self)
    }

    override func rightMouseDown(with event: NSEvent) {
        inputMapper?.rightMouseDown(event, in: self)
    }
    #endif

    // MARK: - iOS Input

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputMapper?.touchesBegan(touches, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputMapper?.touchesMoved(touches, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputMapper?.touchesEnded(touches, in: self)
    }
    #endif

    // MARK: - Debug Overlay

    private func updateDebugOverlay() {
        debugNode?.removeFromParent()
        debugNode = nil

        guard showDebugOverlay else { return }

        let node = SKNode()
        node.zPosition = 100

        // Draw chunk borders
        for cy in 0...World.heightInChunks {
            let y = CGFloat(cy * Chunk.size) * TileAtlas.tileSize
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: CGFloat(World.widthInTiles) * TileAtlas.tileSize, y: y))
            line.path = path
            line.strokeColor = .red
            line.lineWidth = 1
            line.alpha = 0.3
            node.addChild(line)
        }
        for cx in 0...World.widthInChunks {
            let x = CGFloat(cx * Chunk.size) * TileAtlas.tileSize
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: CGFloat(World.heightInTiles) * TileAtlas.tileSize))
            line.path = path
            line.strokeColor = .red
            line.lineWidth = 1
            line.alpha = 0.3
            node.addChild(line)
        }

        // Player AABB outline
        if let sim = simulation {
            let aabb = sim.player.aabb
            let rect = CGRect(
                x: aabb.x * TileAtlas.tileSize,
                y: aabb.y * TileAtlas.tileSize,
                width: aabb.width * TileAtlas.tileSize,
                height: aabb.height * TileAtlas.tileSize
            )
            let aabbNode = SKShapeNode(rect: rect)
            aabbNode.strokeColor = .green
            aabbNode.lineWidth = 1
            aabbNode.fillColor = .clear
            node.addChild(aabbNode)
        }

        worldNode.addChild(node)
        debugNode = node
    }

    // MARK: - Coordinate Conversion

    func tileCoordinate(fromScenePoint point: CGPoint) -> (x: Int, y: Int) {
        let tileX = Int(floor(point.x / TileAtlas.tileSize))
        let tileY = Int(floor(point.y / TileAtlas.tileSize))
        return (tileX, tileY)
    }
}
