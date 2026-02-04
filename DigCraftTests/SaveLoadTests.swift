import Testing
import Foundation
@testable import DigCraft

struct SaveLoadTests {
    @Test func tileDeltaCodable() throws {
        let delta = TileDelta(x: 10, y: 20, tileType: .oreCopper)
        let data = try JSONEncoder().encode(delta)
        let decoded = try JSONDecoder().decode(TileDelta.self, from: data)
        #expect(decoded.x == 10)
        #expect(decoded.y == 20)
        #expect(decoded.tileType == .oreCopper)
    }

    @Test func playerStateCodable() throws {
        var player = PlayerState()
        player.positionX = 128.5
        player.positionY = 130.0
        player.velocityX = 3.0
        player.velocityY = -2.0
        player.isOnGround = true

        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(PlayerState.self, from: data)
        #expect(decoded.positionX == 128.5)
        #expect(decoded.positionY == 130.0)
        #expect(decoded.velocityX == 3.0)
        #expect(decoded.velocityY == -2.0)
        #expect(decoded.isOnGround == true)
    }

    @Test func inventoryCodable() throws {
        var inventory = Inventory()
        inventory.add(.dirt, count: 10)
        inventory.add(.stone, count: 5)
        inventory.selectSlot(1)

        let data = try JSONEncoder().encode(inventory)
        let decoded = try JSONDecoder().decode(Inventory.self, from: data)
        #expect(decoded.slots[0]?.tileType == .dirt)
        #expect(decoded.slots[0]?.count == 10)
        #expect(decoded.slots[1]?.tileType == .stone)
        #expect(decoded.slots[1]?.count == 5)
        #expect(decoded.selectedIndex == 1)
    }

    @Test func saveDataCodable() throws {
        var player = PlayerState()
        player.positionX = 100
        player.positionY = 130

        var inventory = Inventory()
        inventory.add(.dirt, count: 3)

        let saveData = SaveData(
            seed: 42,
            tileDeltas: [TileDelta(x: 5, y: 10, tileType: .air)],
            player: player,
            inventory: inventory
        )

        let data = try JSONEncoder().encode(saveData)
        let decoded = try JSONDecoder().decode(SaveData.self, from: data)
        #expect(decoded.seed == 42)
        #expect(decoded.tileDeltas.count == 1)
        #expect(decoded.tileDeltas[0].tileType == .air)
        #expect(decoded.player.positionX == 100)
        #expect(decoded.inventory.slots[0]?.tileType == .dirt)
    }

    @Test func deltaEncodingCapturesChanges() {
        let sim = GameSimulation(seed: 42)

        // Dig a tile to create a change
        let tileX = Int(sim.player.positionX)
        let tileY = Int(sim.player.positionY) - 1
        sim.process(.dig(tileX: tileX, tileY: tileY))

        // Regenerate original world and compute deltas manually
        let originalWorld = WorldGenerator(seed: sim.seed).generate()
        var deltas: [TileDelta] = []
        for y in 0..<World.heightInTiles {
            for x in 0..<World.widthInTiles {
                let current = sim.world.tileAt(x: x, y: y)
                let original = originalWorld.tileAt(x: x, y: y)
                if current != original {
                    deltas.append(TileDelta(x: x, y: y, tileType: current))
                }
            }
        }

        #expect(deltas.count >= 1, "Should have at least one delta from digging")
        #expect(deltas.contains { $0.x == tileX && $0.y == tileY && $0.tileType == .air })
    }

    @Test func restoreFromDeltas() {
        let seed: Int32 = 42
        let sim = GameSimulation(seed: seed)

        // Dig a tile
        let tileX = Int(sim.player.positionX)
        let tileY = Int(sim.player.positionY) - 1
        let originalTile = sim.world.tileAt(x: tileX, y: tileY)
        sim.process(.dig(tileX: tileX, tileY: tileY))

        // Create a new simulation and apply delta
        let sim2 = GameSimulation(seed: seed)
        #expect(sim2.world.tileAt(x: tileX, y: tileY) == originalTile)

        sim2.world.setTile(x: tileX, y: tileY, to: .air)
        #expect(sim2.world.tileAt(x: tileX, y: tileY) == .air)
    }
}
