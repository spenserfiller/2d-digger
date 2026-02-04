import Foundation
import GameplayKit

struct WorldGenerator: Sendable {
    let seed: Int32

    init(seed: Int32) {
        self.seed = seed
    }

    func generate() -> World {
        var world = World()

        let noiseSource = GKPerlinNoiseSource(
            frequency: 0.02,
            octaveCount: 4,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: seed
        )
        let noise = GKNoise(noiseSource)

        let baseSurface = 128
        let surfaceVariation = 16

        for x in 0..<World.widthInTiles {
            // Sample noise at this x position (-1...1 range)
            let noiseValue = noise.value(atPosition: SIMD2<Float>(Float(x), 0))
            let surfaceY = baseSurface + Int(Float(surfaceVariation) * noiseValue)
            let clampedSurfaceY = max(Chunk.size, min(World.heightInTiles - Chunk.size, surfaceY))

            for y in 0..<World.heightInTiles {
                let tile: TileType
                if y > clampedSurfaceY {
                    tile = .air
                } else if y == clampedSurfaceY {
                    tile = .grass
                } else if y > clampedSurfaceY - 20 {
                    tile = .dirt
                } else {
                    // Stone layer with ore
                    if isOre(x: x, y: y, seed: seed) {
                        tile = .oreCopper
                    } else {
                        tile = .stone
                    }
                }
                world.setTile(x: x, y: y, to: tile)
            }
        }

        return world
    }

    /// Deterministic hash to decide if a stone tile should be ore (~3%)
    private func isOre(x: Int, y: Int, seed: Int32) -> Bool {
        var hash = UInt64(bitPattern: Int64(x) &* 374761393)
        hash = hash &+ UInt64(bitPattern: Int64(y) &* 668265263)
        hash = hash &+ UInt64(bitPattern: Int64(seed) &* 2147483647)
        hash = (hash ^ (hash >> 13)) &* 1274126177
        hash = hash ^ (hash >> 16)
        return hash % 100 < 3
    }

    /// Find the surface Y for spawning at a given X
    func surfaceY(at x: Int, world: World) -> Int {
        for y in stride(from: World.heightInTiles - 1, through: 0, by: -1) {
            if world.tileAt(x: x, y: y).isSolid {
                return y + 1
            }
        }
        return World.heightInTiles / 2
    }
}
