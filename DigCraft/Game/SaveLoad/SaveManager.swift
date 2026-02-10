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
        let deltas = WorldDeltaComputer.computeTileDeltas(simulation: simulation)

        let isMultiplayer = simulation.players.count > 1

        let saveData: SaveData
        if isMultiplayer {
            saveData = SaveData(
                seed: simulation.seed,
                tileDeltas: deltas,
                player: simulation.player,
                inventory: simulation.inventory,
                players: simulation.players,
                inventories: simulation.inventories
            )
        } else {
            saveData = SaveData(
                seed: simulation.seed,
                tileDeltas: deltas,
                player: simulation.player,
                inventory: simulation.inventory
            )
        }

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
