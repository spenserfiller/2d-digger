import Foundation

struct InventorySlot: Sendable, Codable {
    var tileType: TileType
    var count: Int
}

struct Inventory: Sendable, Codable {
    static let slotCount = 5
    static let maxStack = 64

    var slots: [InventorySlot?]
    var selectedIndex: Int = 0

    init() {
        slots = [InventorySlot?](repeating: nil, count: Inventory.slotCount)
    }

    var selectedSlot: InventorySlot? {
        slots[selectedIndex]
    }

    /// Adds a tile to inventory. Returns true if successful.
    @discardableResult
    mutating func add(_ tileType: TileType, count: Int = 1) -> Bool {
        // Try stacking on existing slot
        for i in 0..<slots.count {
            if let slot = slots[i], slot.tileType == tileType, slot.count + count <= Inventory.maxStack {
                slots[i] = InventorySlot(tileType: tileType, count: slot.count + count)
                return true
            }
        }
        // Try empty slot
        for i in 0..<slots.count {
            if slots[i] == nil {
                slots[i] = InventorySlot(tileType: tileType, count: count)
                return true
            }
        }
        return false
    }

    /// Removes one item from the selected slot. Returns the tile type removed, or nil.
    mutating func removeSelected() -> TileType? {
        guard let slot = slots[selectedIndex] else { return nil }
        let tileType = slot.tileType
        if slot.count <= 1 {
            slots[selectedIndex] = nil
        } else {
            slots[selectedIndex] = InventorySlot(tileType: tileType, count: slot.count - 1)
        }
        return tileType
    }

    mutating func selectSlot(_ index: Int) {
        guard index >= 0 && index < Inventory.slotCount else { return }
        selectedIndex = index
    }
}
