import SpriteKit

@MainActor
final class InputMapper {
    private weak var scene: GameScene?
    private weak var simulation: GameSimulation?
    private var coordinator: GameCoordinator?

    #if os(macOS)
    private var heldKeys: Set<UInt16> = []
    private var isLeftMouseHeld = false
    private var isRightMouseHeld = false
    private var heldMouseScenePoint: CGPoint?
    #endif

    #if os(iOS)
    private var moveTouchID: ObjectIdentifier?
    private var moveTouchStart: CGPoint = .zero
    private var digTouchID: ObjectIdentifier?
    private var digTouchScenePoint: CGPoint?
    #endif

    init(scene: GameScene, simulation: GameSimulation, coordinator: GameCoordinator? = nil) {
        self.scene = scene
        self.simulation = simulation
        self.coordinator = coordinator
    }

    private func dispatch(_ command: GameCommand) {
        if let coordinator, coordinator.mode.isClient || coordinator.mode.isHost {
            coordinator.sendCommand(command)
        } else {
            simulation?.process(command)
        }
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
            dispatch(.move(direction: .left))
        case 2:  // D
            dispatch(.move(direction: .right))
        case 13, 49: // W or Space
            dispatch(.jump)
        case 18: dispatch(.selectHotbar(index: 0)) // 1
        case 19: dispatch(.selectHotbar(index: 1)) // 2
        case 20: dispatch(.selectHotbar(index: 2)) // 3
        case 21: dispatch(.selectHotbar(index: 3)) // 4
        case 23: dispatch(.selectHotbar(index: 4)) // 5
        default: break
        }
    }

    private func handleKeyRelease(_ keyCode: UInt16) {
        switch keyCode {
        case 0: // A released
            if heldKeys.contains(2) {
                dispatch(.move(direction: .right))
            } else {
                dispatch(.stopMove)
            }
        case 2: // D released
            if heldKeys.contains(0) {
                dispatch(.move(direction: .left))
            } else {
                dispatch(.stopMove)
            }
        default: break
        }
    }

    func updateHeldKeys() {
        // Re-dispatch dig/place while mouse is held
        if let scene, let point = heldMouseScenePoint {
            let worldPoint = scene.convert(point, to: scene.worldNode)
            let tileCoord = scene.tileCoordinate(fromScenePoint: worldPoint)
            if isLeftMouseHeld {
                dispatch(.dig(tileX: tileCoord.x, tileY: tileCoord.y))
            } else if isRightMouseHeld {
                dispatch(.place(tileX: tileCoord.x, tileY: tileCoord.y))
            }
        }
    }

    // MARK: - macOS Mouse

    func mouseDown(_ event: NSEvent, in scene: GameScene) {
        isLeftMouseHeld = true
        heldMouseScenePoint = event.location(in: scene)
        let location = event.location(in: scene.worldNode)
        let tileCoord = scene.tileCoordinate(fromScenePoint: location)
        dispatch(.dig(tileX: tileCoord.x, tileY: tileCoord.y))
    }

    func mouseDragged(_ event: NSEvent, in scene: GameScene) {
        heldMouseScenePoint = event.location(in: scene)
    }

    func mouseUp(_ event: NSEvent) {
        isLeftMouseHeld = false
        heldMouseScenePoint = nil
    }

    func rightMouseDown(_ event: NSEvent, in scene: GameScene) {
        isRightMouseHeld = true
        heldMouseScenePoint = event.location(in: scene)
        let location = event.location(in: scene.worldNode)
        let tileCoord = scene.tileCoordinate(fromScenePoint: location)
        dispatch(.place(tileX: tileCoord.x, tileY: tileCoord.y))
    }

    func rightMouseDragged(_ event: NSEvent, in scene: GameScene) {
        heldMouseScenePoint = event.location(in: scene)
    }

    func rightMouseUp(_ event: NSEvent) {
        isRightMouseHeld = false
        heldMouseScenePoint = nil
    }
    #endif

    // MARK: - iOS Touch

    #if os(iOS)
    func updateHeldKeys() {
        // Re-dispatch dig while touch is held on right side
        if let scene, let point = digTouchScenePoint {
            let worldPoint = scene.convert(point, to: scene.worldNode)
            let tileCoord = scene.tileCoordinate(fromScenePoint: worldPoint)
            dispatch(.dig(tileX: tileCoord.x, tileY: tileCoord.y))
        }
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
            // Right side: dig (hold to keep digging)
            digTouchID = ObjectIdentifier(touch)
            let sceneLocation = touch.location(in: scene)
            digTouchScenePoint = sceneLocation
            let worldLocation = scene.convert(sceneLocation, to: scene.worldNode)
            let tileCoord = scene.tileCoordinate(fromScenePoint: worldLocation)
            dispatch(.dig(tileX: tileCoord.x, tileY: tileCoord.y))
        }
    }

    func touchesMoved(_ touches: Set<UITouch>, in scene: GameScene) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if id == moveTouchID {
                let viewLocation = touch.location(in: scene.view)
                let dx = viewLocation.x - moveTouchStart.x
                let threshold: CGFloat = 20

                if dx > threshold {
                    dispatch(.move(direction: .right))
                } else if dx < -threshold {
                    dispatch(.move(direction: .left))
                } else {
                    dispatch(.stopMove)
                }
            } else if id == digTouchID {
                digTouchScenePoint = touch.location(in: scene)
            }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, in scene: GameScene) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if id == moveTouchID {
                moveTouchID = nil
                dispatch(.stopMove)
            } else if id == digTouchID {
                digTouchID = nil
                digTouchScenePoint = nil
            }
        }
    }
    #endif
}
