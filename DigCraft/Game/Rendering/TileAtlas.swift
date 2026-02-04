import SpriteKit

@MainActor
final class TileAtlas {
    static let tileSize: CGFloat = 16

    private var textures: [TileType: SKTexture] = [:]
    private(set) var tileSet: SKTileSet!
    private(set) var tileGroups: [TileType: SKTileGroup] = [:]
    private var emptyGroup: SKTileGroup!

    init() {
        buildTextures()
        buildTileSet()
    }

    private func buildTextures() {
        let colors: [TileType: (r: CGFloat, g: CGFloat, b: CGFloat)] = [
            .grass: (0.2, 0.7, 0.2),
            .dirt: (0.55, 0.35, 0.15),
            .stone: (0.5, 0.5, 0.5),
            .oreCopper: (0.8, 0.5, 0.2),
        ]

        let size = CGSize(width: TileAtlas.tileSize, height: TileAtlas.tileSize)

        for (tileType, color) in colors {
            let texture = createColorTexture(
                size: size,
                red: color.r, green: color.g, blue: color.b
            )
            textures[tileType] = texture
        }
    }

    private func createColorTexture(size: CGSize, red: CGFloat, green: CGFloat, blue: CGFloat) -> SKTexture {
        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(red: red, green: green, blue: blue, alpha: 1.0).setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return SKTexture(image: image)
        #else
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(red: red, green: green, blue: blue, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
        #endif
    }

    private func buildTileSet() {
        var groups: [SKTileGroup] = []

        for (tileType, texture) in textures {
            texture.filteringMode = .nearest
            let definition = SKTileDefinition(texture: texture, size: CGSize(width: TileAtlas.tileSize, height: TileAtlas.tileSize))
            let group = SKTileGroup(tileDefinition: definition)
            group.name = tileType.displayName
            tileGroups[tileType] = group
            groups.append(group)
        }

        emptyGroup = SKTileGroup.empty()
        groups.append(emptyGroup)

        tileSet = SKTileSet(tileGroups: groups)
    }

    func group(for tileType: TileType) -> SKTileGroup? {
        if tileType == .air { return nil }
        return tileGroups[tileType]
    }
}
