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
                Text("Imported books will show you as the adder with today's date. No book lookup is performed.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Import library")
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
        .presentationDetents([.medium])
    }
}
