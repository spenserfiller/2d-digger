import SpriteKit

@MainActor
final class InputMapper {
    private weak var scene: GameScene?
    private weak var simulation: GameSimulation?

    #if os(macOS)
    private var heldKeys: Set<UInt16> = []
    #endif

    #if os(iOS)
    private var moveTouchID: ObjectIdentifier?
    private var moveTouchStart: CGPoint = .zero
    #endif

    init(scene: GameScene, simulation: GameSimulation) {
        self.scene = scene
        self.simulation = simulation
    }

    // MARK: - macOS Keyboard

    #if os(macOS)
    func keyDown(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        heldKeys.insert(event.keyCode)
        handleKeyPress(event.keyCode)
    }

    func keyUp(_ event: NSEvent) {
        heldKeys.remove(event.keyCode)
        handleKeyRelease(event.keyCode)
    }

    private func handleKeyPress(_ keyCode: UInt16) {
        switch keyCode {
        case 0:  // A
            simulation?.process(.move(direction: .left))
        case 2:  // D
            simulation?.process(.move(direction: .right))
        case 13, 49: // W or Space
            simulation?.process(.jump)
        case 18: simulation?.process(.selectHotbar(index: 0)) // 1
        case 19: simulation?.process(.selectHotbar(index: 1)) // 2
        case 20: simulation?.process(.selectHotbar(index: 2)) // 3
        case 21: simulation?.process(.selectHotbar(index: 3)) // 4
        case 23: simulation?.process(.selectHotbar(index: 4)) // 5
        default: break
        }
    }

    private func handleKeyRelease(_ keyCode: UInt16) {
        switch keyCode {
        case 0: // A released
            if heldKeys.contains(2) {
                simulation?.process(.move(direction: .right))
            } else {
                simulation?.process(.stopMove)
            }
        case 2: // D released
            if heldKeys.contains(0) {
                simulation?.process(.move(direction: .left))
            } else {
                simulation?.process(.stopMove)
            }
        default: break
        }
    }

    func updateHeldKeys() {
        // Nothing needed - movement is set on key press/release
    }

    // MARK: - macOS Mouse

    func mouseDown(_ event: NSEvent, in scene: GameScene) {
        let location = event.location(in: scene.worldNode)
        let tileCoord = scene.tileCoordinate(fromScenePoint: location)
        simulation?.process(.dig(tileX: tileCoord.x, tileY: tileCoord.y))
    }

    func rightMouseDown(_ event: NSEvent, in scene: GameScene) {
        let location = event.location(in: scene.worldNode)
        let tileCoord = scene.tileCoordinate(fromScenePoint: location)
        simulation?.process(.place(tileX: tileCoord.x, tileY: tileCoord.y))
    }
    #endif

    // MARK: - iOS Touch

    #if os(iOS)
    func updateHeldKeys() {
        // No held keys on iOS
    }

    func touchesBegan(_ touches: Set<UITouch>, in scene: GameScene) {
        guard let touch = touches.first else { return }
        let viewSize = scene.view?.frame.size ?? CGSize(width: 800, height: 600)
        let viewLocation = touch.location(in: scene.view)

        if viewLocation.x < viewSize.width * 0.3 {
            // Left side: movement
            moveTouchID = ObjectIdentifier(touch)
            moveTouchStart = viewLocation
        } else {
            // Right side: dig
            let sceneLocation = touch.location(in: scene)
            let worldLocation = scene.convert(sceneLocation, to: scene.worldNode)
            let tileCoord = scene.tileCoordinate(fromScenePoint: worldLocation)
            simulation?.process(.dig(tileX: tileCoord.x, tileY: tileCoord.y))
        }
    }

    func touchesMoved(_ touches: Set<UITouch>, in scene: GameScene) {
        for touch in touches {
            guard ObjectIdentifier(touch) == moveTouchID else { continue }
            let viewLocation = touch.location(in: scene.view)
            let dx = viewLocation.x - moveTouchStart.x
            let threshold: CGFloat = 20

            if dx > threshold {
                simulation?.process(.move(direction: .right))
            } else if dx < -threshold {
                simulation?.process(.move(direction: .left))
            } else {
                simulation?.process(.stopMove)
            }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, in scene: GameScene) {
        for touch in touches {
            if ObjectIdentifier(touch) == moveTouchID {
                moveTouchID = nil
                simulation?.process(.stopMove)
            }
        }
    }
    #endif
}

