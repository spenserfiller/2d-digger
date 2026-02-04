import Testing
@testable import DigCraft

struct PhysicsTests {
    @Test func gravityApplied() {
        var player = PlayerState()
        player.positionX = 128
        player.positionY = 150
        player.velocityY = 0

        // Create empty world (all air)
        var world = World()
        // Add a floor at y=100
        for x in 0..<World.widthInTiles {
            world.setTile(x: x, y: 100, to: .stone)
        }

        let initialY = player.positionY
        PhysicsSystem.update(player: &player, world: world, dt: 1.0 / 60.0)

        #expect(player.positionY < initialY, "Player should fall due to gravity")
    }

    @Test func playerLandsOnGround() {
        var player = PlayerState()
        player.positionX = 128.5
        player.positionY = 102
        player.velocityY = -5

        var world = World()
        for x in 120..<140 {
            world.setTile(x: x, y: 100, to: .stone)
        }

        // Run physics for many frames until settled
        for _ in 0..<120 {
            PhysicsSystem.update(player: &player, world: world, dt: 1.0 / 60.0)
        }

        #expect(player.isOnGround, "Player should be on ground")
        #expect(player.positionY >= 101, "Player should rest on top of stone at y=100 (so positionY >= 101)")
    }

    @Test func horizontalCollision() {
        var player = PlayerState()
        player.positionX = 125.5
        player.positionY = 101
        player.velocityX = PhysicsSystem.moveSpeed
        player.isOnGround = true

        var world = World()
        // Floor
        for x in 120..<140 {
            world.setTile(x: x, y: 100, to: .stone)
        }
        // Wall at x=130
        for y in 101..<105 {
            world.setTile(x: 130, y: y, to: .stone)
        }

        // Run physics to move towards wall
        for _ in 0..<120 {
            PhysicsSystem.update(player: &player, world: world, dt: 1.0 / 60.0)
            player.velocityX = PhysicsSystem.moveSpeed // keep pushing
        }

        #expect(player.positionX < 130, "Player should be stopped by wall")
    }

    @Test func jumpSetsVelocity() {
        let sim = GameSimulation(seed: 42)
        let initialY = sim.player.positionY

        // Let player settle on ground first
        for _ in 0..<60 {
            sim.update(deltaTime: 1.0 / 60.0)
        }
        _ = sim.consumeEvents()

        sim.process(.jump)
        #expect(sim.player.velocityY == PhysicsSystem.jumpVelocity)
    }

    @Test func terminalVelocityCapped() {
        var player = PlayerState()
        player.positionX = 128
        player.positionY = 180
        player.velocityY = 0

        let world = World() // Empty world, player falls

        // Run for many frames
        for _ in 0..<300 {
            PhysicsSystem.update(player: &player, world: world, dt: 1.0 / 60.0)
        }

        #expect(player.velocityY >= PhysicsSystem.terminalVelocity,
               "Velocity should be capped at terminal velocity")
    }
}
