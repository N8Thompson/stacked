//
//  CountStepper.swift
//  Stacked
//
//  A large +/- count control used when adding or deleting copies. Mirrors the
//  reference screenshot's minus / count / plus layout.
//

import SwiftUI

struct CountStepper: View {
    @Binding var count: Int
    var range: ClosedRange<Int> = 1...999

    var body: some View {
        HStack(spacing: 16) {
            stepButton(systemImage: "minus", enabled: count > range.lowerBound) {
                count = max(range.lowerBound, count - 1)
            }

            Text("\(count)")
                .font(.title2.weight(.semibold).monospacedDigit())
                .frame(minWidth: 44)

            stepButton(systemImage: "plus", enabled: count < range.upperBound) {
                count = min(range.upperBound, count + 1)
            }
        }
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 40, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
