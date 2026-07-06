//
//  ChipRow.swift
//  Stacked
//
//  Horizontally scrolling, selectable filter chips.
//

import SwiftUI

struct Chip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption2)
                }
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(StackedTheme.Gradient.accent)
                } else {
                    Capsule().fill(StackedTheme.Surface.track)
                }
            }
            .foregroundStyle(isSelected ? StackedTheme.Text.onAccent : StackedTheme.Text.primary)
        }
        .buttonStyle(.plain)
    }
}
