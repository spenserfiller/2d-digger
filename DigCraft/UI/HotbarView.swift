import SwiftUI

struct HotbarView: View {
    let inventory: Inventory

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<Inventory.slotCount, id: \.self) { index in
                slotView(index: index)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func slotView(index: Int) -> some View {
        let slot = inventory.slots[index]
        let isSelected = inventory.selectedIndex == index

        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.4))
                .frame(width: 44, height: 44)

            if let slot {
                tileColorView(for: slot.tileType)
                    .frame(width: 28, height: 28)

                Text("\(slot.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(4)
            }
        }
        .frame(width: 44, height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func tileColorView(for tileType: TileType) -> some View {
        let color: Color = switch tileType {
        case .grass: Color(red: 0.2, green: 0.7, blue: 0.2)
        case .dirt: Color(red: 0.55, green: 0.35, blue: 0.15)
        case .stone: Color(red: 0.5, green: 0.5, blue: 0.5)
        case .oreCopper: Color(red: 0.8, green: 0.5, blue: 0.2)
        case .air: Color.clear
        }
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
    }
}
