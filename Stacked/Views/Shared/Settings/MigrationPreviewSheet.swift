//
//  MigrationPreviewSheet.swift
//  Stacked
//

import SwiftUI

struct MigrationPreviewSheet: View {
    let preview: MigrationPreview
    let onImport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(preview.uniqueTitles) unique titles, \(preview.totalCopies) total copies, \(preview.locationCount) locations")
                    .font(.headline)

                Text("This creates an independent copy in your library. Matching ISBNs add copies to titles you already own. Cover art, ratings, and notes are kept. This does not keep the two libraries in sync.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)

                Text("Imported books will show you as the adder with today's date. No catalog lookup is performed.")
                    .font(.footnote)
                    .foregroundStyle(StackedTheme.Text.tertiary)

                Spacer()
            }
            .padding()
            .navigationTitle("Import Stacked backup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
