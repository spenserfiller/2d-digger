import Testing
import Foundation
@testable import DigCraft

struct SimulationTests {
    @Test func tileTypeProperties() {
        #expect(TileType.air.isSolid == false)
        #expect(TileType.grass.isSolid == true)
        #expect(TileType.dirt.isSolid == true)
        #expect(TileType.stone.isSolid == true)
        #expect(TileType.oreCopper.isSolid == true)
        #expect(TileType.grass.displayName == "Grass")
    }

    @Test func chunkSubscript() {
        var chunk = Chunk()
        #expect(chunk[0, 0] == .air)
        chunk[5, 10] = .stone
        #expect(chunk[5, 10] == .stone)
        #expect(chunk[0, 0] == .air)
    }

    @Test func worldTileAccess() {
        var world = World()
        #expect(world.tileAt(x: 0, y: 0) == .air)

        let coord = world.setTile(x: 10, y: 20, to: .dirt)
        #expect(coord != nil)
        #expect(world.tileAt(x: 10, y: 20) == .dirt)
    }

    @Test func worldOutOfBoundsReturnsSolid() {
        let world = World()
        #expect(world.tileAt(x: -1, y: 0) == .stone)
        #expect(world.tileAt(x: 0, y: -1) == .stone)
        #expect(world.tileAt(x: World.widthInTiles, y: 0) == .stone)
    }

    @Test func inventoryAddAndStack() {
        var inventory = Inventory()
        let added = inventory.add(.dirt)
        #expect(added)
        #expect(inventory.slots[0]?.tileType == .dirt)
        #expect(inventory.slots[0]?.count == 1)

        let stacked = inventory.add(.dirt, count: 5)
        #expect(stacked)
        #expect(inventory.slots[0]?.count == 6)
    }

    @Test func inventoryAddDifferentTypes() {
        var inventory = Inventory()
        let added1 = inventory.add(.dirt)
        let added2 = inventory.add(.stone)
        #expect(added1)
        #expect(added2)
        #expect(inventory.slots[0]?.tileType == .dirt)
        #expect(inventory.slots[1]?.tileType == .stone)
    }

    @Test func inventoryRemoveSelected() {
        var inventory = Inventory()
        inventory.add(.dirt, count: 3)
        let removed = inventory.removeSelected()
        #expect(removed == .dirt)
        #expect(inventory.slots[0]?.count == 2)
    }

    @Test func inventoryRemoveLastItem() {
        var inventory = Inventory()
        inventory.add(.stone)
        let removed = inventory.removeSelected()
        #expect(removed == .stone)
        #expect(inventory.slots[0] == nil)
    }

    @Test func inventoryFull() {
        var inventory = Inventory()
        // Fill all 5 slots with different types (grass through oreCopper)
        let types: [TileType] = [.grass, .dirt, .stone, .oreCopper, .grass]
        for (i, t) in types.enumerated() {
            if i == 4 {
                // Last slot: add a different count so it won't stack with slot 0
                inventory.selectSlot(4)
            }
            inventory.add(t)
        }
        // Now try adding a type that can't stack with any existing slot at max
        // Actually fill all slots with distinct-enough items
        var inv2 = Inventory()
        inv2.add(.grass, count: 64)
        inv2.add(.dirt, count: 64)
        inv2.add(.stone, count: 64)
        inv2.add(.oreCopper, count: 64)
        inv2.add(.grass, count: 64) // This stacks, filling the 5th slot only if first is full
        // Actually, add(.grass, count: 64) would try to stack with slot 0 first
        // Let's just test differently
        var inv3 = Inventory()
        // Fill each slot with max stack of different types
        inv3.slots[0] = InventorySlot(tileType: .grass, count: 64)
        inv3.slots[1] = InventorySlot(tileType: .dirt, count: 64)
        inv3.slots[2] = InventorySlot(tileType: .stone, count: 64)
        inv3.slots[3] = InventorySlot(tileType: .oreCopper, count: 64)
        inv3.slots[4] = InventorySlot(tileType: .grass, count: 64)
        let result = inv3.add(.dirt)
        #expect(result == false)
    }

    @Test func aabbIntersection() {
        let a = AABB(x: 0, y: 0, width: 2, height: 2)
        let b = AABB(x: 1, y: 1, width: 2, height: 2)
        #expect(a.intersects(b))

        let c = AABB(x: 3, y: 3, width: 1, height: 1)
        #expect(!a.intersects(c))
    }

    @Test func gameCommandCodable() throws {
        let command = GameCommand.dig(tileX: 10, tileY: 20)
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(GameCommand.self, from: data)

        if case .dig(let x, let y) = decoded {
            #expect(x == 10)
            #expect(y == 20)
        } else {
            Issue.record("Expected dig command")
        }
    }

    @Test func simulationSpawnsPlayer() {
        let sim = GameSimulation(seed: 42)
        #expect(sim.player.positionX > 0)
        #expect(sim.player.positionY > 0)
    }

    @Test func simulationDigAndPlace() {
        let sim = GameSimulation(seed: 42)

        // Find a solid tile near the player
        let tileX = Int(sim.player.positionX)
        let tileY = Int(sim.player.positionY) - 1  // tile below player

        let originalTile = sim.world.tileAt(x: tileX, y: tileY)
        #expect(originalTile.isSolid)

        // Dig it
        sim.process(.dig(tileX: tileX, tileY: tileY))
        #expect(sim.world.tileAt(x: tileX, y: tileY) == .air)
        #expect(sim.inventory.slots[0] != nil)

        // Place it back
        sim.process(.place(tileX: tileX, tileY: tileY))
        #expect(sim.world.tileAt(x: tileX, y: tileY) == originalTile)
    }
}
