import Testing
@testable import DigCraft

struct WorldGeneratorTests {
    @Test func sameSeedProducesSameWorld() {
        let gen1 = WorldGenerator(seed: 12345)
        let gen2 = WorldGenerator(seed: 12345)
        let world1 = gen1.generate()
        let world2 = gen2.generate()

        // Check a sampling of tiles
        for x in stride(from: 0, to: World.widthInTiles, by: 17) {
            for y in stride(from: 0, to: World.heightInTiles, by: 13) {
                #expect(world1.tileAt(x: x, y: y) == world2.tileAt(x: x, y: y),
                       "Mismatch at (\(x), \(y))")
            }
        }
    }

    @Test func differentSeedsProduceDifferentWorlds() {
        let world1 = WorldGenerator(seed: 1).generate()
        let world2 = WorldGenerator(seed: 2).generate()

        var differences = 0
        for x in stride(from: 0, to: World.widthInTiles, by: 8) {
            for y in stride(from: 0, to: World.heightInTiles, by: 8) {
                if world1.tileAt(x: x, y: y) != world2.tileAt(x: x, y: y) {
                    differences += 1
                }
            }
        }
        #expect(differences > 0, "Different seeds should produce different worlds")
    }

    @Test func surfaceHasGrass() {
        let gen = WorldGenerator(seed: 42)
        let world = gen.generate()

        // Check multiple columns for grass at surface
        var grassFound = 0
        for x in stride(from: 0, to: World.widthInTiles, by: 10) {
            for y in stride(from: World.heightInTiles - 1, through: 0, by: -1) {
                let tile = world.tileAt(x: x, y: y)
                if tile == .grass {
                    grassFound += 1
                    break
                } else if tile.isSolid {
                    break // found solid but not grass - unexpected
                }
            }
        }
        #expect(grassFound > 0, "Should find grass at surface")
    }

    @Test func layerCorrectness() {
        let gen = WorldGenerator(seed: 42)
        let world = gen.generate()
        let centerX = World.widthInTiles / 2

        // Find surface
        var surfaceY = 0
        for y in stride(from: World.heightInTiles - 1, through: 0, by: -1) {
            if world.tileAt(x: centerX, y: y).isSolid {
                surfaceY = y
                break
            }
        }

        // Above surface should be air
        if surfaceY + 1 < World.heightInTiles {
            #expect(world.tileAt(x: centerX, y: surfaceY + 1) == .air)
        }

        // Surface should be grass
        #expect(world.tileAt(x: centerX, y: surfaceY) == .grass)

        // Below surface should be dirt (first few layers)
        if surfaceY > 1 {
            let belowSurface = world.tileAt(x: centerX, y: surfaceY - 1)
            #expect(belowSurface == .dirt, "Expected dirt below surface, got \(belowSurface)")
        }

        // Deep below should be stone or ore
        if surfaceY > 25 {
            let deepTile = world.tileAt(x: centerX, y: surfaceY - 25)
            #expect(deepTile == .stone || deepTile == .oreCopper,
                   "Expected stone or ore deep below, got \(deepTile)")
        }
    }

    @Test func orePercentageInStoneLayer() {
        let gen = WorldGenerator(seed: 42)
        let world = gen.generate()

        var stoneCount = 0
        var oreCount = 0

        for y in 0..<50 { // Bottom 50 rows should be stone layer
            for x in 0..<World.widthInTiles {
                let tile = world.tileAt(x: x, y: y)
                if tile == .stone { stoneCount += 1 }
                if tile == .oreCopper { oreCount += 1 }
            }
        }

        let total = stoneCount + oreCount
        guard total > 0 else { return }
        let orePercent = Double(oreCount) / Double(total) * 100
        #expect(orePercent > 1 && orePercent < 6,
               "Ore percentage \(orePercent)% should be roughly 3%")
    }
}
