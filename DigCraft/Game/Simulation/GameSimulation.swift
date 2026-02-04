import Foundation
import Observation

@Observable
final class GameSimulation: @unchecked Sendable {
    // MARK: - State
    var world: World
    var player: PlayerState
    var inventory: Inventory
    let seed: Int32

    // MARK: - Events
    private(set) var pendingEvents: [GameEvent] = []

    // MARK: - Fixed timestep
    private static let fixedDT: Double = 1.0 / 60.0
    private var accumulator: Double = 0

    // MARK: - Movement state
    private var moveDirection: MoveDirection? = nil

    // MARK: - Dig range
    static let digRange: Double = 5.0

    init(seed: Int32) {
        self.seed = seed
        let generator = WorldGenerator(seed: seed)
        self.world = generator.generate()
        self.player = PlayerState()
        self.inventory = Inventory()

        // Spawn player at world center on surface
        let spawnX = World.widthInTiles / 2
        let spawnY = generator.surfaceY(at: spawnX, world: world)
        player.positionX = Double(spawnX) + 0.5
        player.positionY = Double(spawnY)
    }

    // MARK: - Command Processing

    func process(_ command: GameCommand) {
        switch command {
        case .move(let direction):
            moveDirection = direction
        case .stopMove:
            moveDirection = nil
        case .jump:
            if player.isOnGround {
                player.velocityY = PhysicsSystem.jumpVelocity
                player.isOnGround = false
            }
        case .dig(let tileX, let tileY):
            dig(at: tileX, tileY: tileY)
        case .place(let tileX, let tileY):
            place(at: tileX, tileY: tileY)
        case .selectHotbar(let index):
            inventory.selectSlot(index)
            pendingEvents.append(.inventoryChanged)
        }
    }

    // MARK: - Update

    func update(deltaTime: Double) {
        accumulator += deltaTime

        while accumulator >= GameSimulation.fixedDT {
            fixedUpdate(dt: GameSimulation.fixedDT)
            accumulator -= GameSimulation.fixedDT
        }
    }

    private func fixedUpdate(dt: Double) {
        // Apply movement input
        switch moveDirection {
        case .left:
            player.velocityX = -PhysicsSystem.moveSpeed
        case .right:
            player.velocityX = PhysicsSystem.moveSpeed
        case nil:
            player.velocityX *= PhysicsSystem.friction
            if abs(player.velocityX) < 0.1 {
                player.velocityX = 0
            }
        }

        PhysicsSystem.update(player: &player, world: world, dt: dt)
        pendingEvents.append(.playerMoved(x: player.positionX, y: player.positionY))
    }

    // MARK: - Actions

    private func dig(at tileX: Int, tileY: Int) {
        // Range check
        let dx = Double(tileX) + 0.5 - player.positionX
        let dy = Double(tileY) + 0.5 - (player.positionY + PlayerState.height / 2)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= GameSimulation.digRange else { return }

        let existing = world.tileAt(x: tileX, y: tileY)
        guard existing.isSolid else { return }

        if let coord = world.setTile(x: tileX, y: tileY, to: .air) {
            inventory.add(existing)
            pendingEvents.append(.tileChanged(x: tileX, y: tileY, newType: .air))
            pendingEvents.append(.chunkDirty(coord))
            pendingEvents.append(.inventoryChanged)
        }
    }

    private func place(at tileX: Int, tileY: Int) {
        // Range check
        let dx = Double(tileX) + 0.5 - player.positionX
        let dy = Double(tileY) + 0.5 - (player.positionY + PlayerState.height / 2)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= GameSimulation.digRange else { return }

        // Must be air
        guard world.tileAt(x: tileX, y: tileY) == .air else { return }

        // Check player collision - don't place where player is
        let tileAABB = AABB(x: Double(tileX), y: Double(tileY), width: 1, height: 1)
        guard !player.aabb.intersects(tileAABB) else { return }

        guard let tileType = inventory.removeSelected() else { return }

        if let coord = world.setTile(x: tileX, y: tileY, to: tileType) {
            pendingEvents.append(.tileChanged(x: tileX, y: tileY, newType: tileType))
            pendingEvents.append(.chunkDirty(coord))
            pendingEvents.append(.inventoryChanged)
        }
    }

    // MARK: - Event Consumption

    func consumeEvents() -> [GameEvent] {
        let events = pendingEvents
        pendingEvents = []
        return events
    }

    // MARK: - Save/Load Support

    func restore(player: PlayerState, inventory: Inventory) {
        self.player = player
        self.inventory = inventory
    }
}
