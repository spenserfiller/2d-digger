aimport Foundation

struct PhysicsSystem: Sendable {
    static let gravity: Double = -30.0       // tiles/s^2
    static let jumpVelocity: Double = 12.0   // tiles/s
    static let moveSpeed: Double = 6.0       // tiles/s
    static let terminalVelocity: Double = -40.0
    static let friction: Double = 0.85

    /// Update player physics for one fixed timestep
    static func update(player: inout PlayerState, world: World, dt: Double) {
        // Apply gravity
        player.velocityY += gravity * dt
        if player.velocityY < terminalVelocity {
            player.velocityY = terminalVelocity
        }

        // Apply friction to horizontal movement when no input
        // (friction is applied externally via stopMove command)

        // Move X axis first, then Y (separate axis collision)
        moveAxis(player: &player, world: world, dx: player.velocityX * dt, dy: 0)
        moveAxis(player: &player, world: world, dx: 0, dy: player.velocityY * dt)
    }

    private static func moveAxis(player: inout PlayerState, world: World, dx: Double, dy: Double) {
        player.positionX += dx
        player.positionY += dy

        let aabb = player.aabb

        // Determine tile range to check
        let minTX = max(0, Int(floor(aabb.minX)))
        let maxTX = min(World.widthInTiles - 1, Int(floor(aabb.maxX)))
        let minTY = max(0, Int(floor(aabb.minY)))
        let maxTY = min(World.heightInTiles - 1, Int(floor(aabb.maxY)))

        for ty in minTY...maxTY {
            for tx in minTX...maxTX {
                guard world.tileAt(x: tx, y: ty).isSolid else { continue }

                let tileAABB = AABB(x: Double(tx), y: Double(ty), width: 1, height: 1)
                let playerAABB = player.aabb

                guard playerAABB.intersects(tileAABB) else { continue }

                if dx != 0 {
                    // Horizontal collision
                    if dx > 0 {
                        player.positionX = Double(tx) - PlayerState.width / 2
                    } else {
                        player.positionX = Double(tx + 1) + PlayerState.width / 2
                    }
                    player.velocityX = 0
                }

                if dy != 0 {
                    // Vertical collision
                    if dy < 0 {
                        player.positionY = Double(ty + 1)
                        player.velocityY = 0
                        player.isOnGround = true
                    } else {
                        player.positionY = Double(ty) - PlayerState.height
                        player.velocityY = 0
                    }
                }
            }
        }

        // Check if still on ground (look one pixel below)
        if dy != 0 {
            player.isOnGround = false
            let feetY = Int(floor(player.positionY - 0.01))
            if feetY >= 0 {
                let leftTX = Int(floor(player.aabb.minX))
                let rightTX = Int(floor(player.aabb.maxX - 0.001))
                for tx in leftTX...rightTX {
                    if world.tileAt(x: tx, y: feetY).isSolid {
                        player.isOnGround = true
                        break
                    }
                }
            }
        }
    }
}
