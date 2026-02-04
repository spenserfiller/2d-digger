import Foundation

enum SaveManager {
    private static var saveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("digcraft_save.json")
    }

    static var hasSaveFile: Bool {
        FileManager.default.fileExists(atPath: saveURL.path)
    }

    static func save(simulation: GameSimulation) {
        let generator = WorldGenerator(seed: simulation.seed)
        let originalWorld = generator.generate()

        // Compute tile deltas
        var deltas: [TileDelta] = []
        for y in 0..<World.heightInTiles {
            for x in 0..<World.widthInTiles {
                let current = simulation.world.tileAt(x: x, y: y)
                let original = originalWorld.tileAt(x: x, y: y)
                if current != original {
                    deltas.append(TileDelta(x: x, y: y, tileType: current))
                }
            }
        }

        let saveData = SaveData(
            seed: simulation.seed,
            tileDeltas: deltas,
            player: simulation.player,
            inventory: simulation.inventory
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(saveData)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("Save failed: \(error)")
        }
    }

    static func load() -> SaveData? {
        do {
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            return try decoder.decode(SaveData.self, from: data)
        } catch {
            print("Load failed: \(error)")
            return nil
        }
    }

    static func deleteSave() {
        try? FileManager.default.removeItem(at: saveURL)
    }
}
