//
//  DeleteCopiesSheet.swift
//  Stacked
//
//  Lets the user choose how many copies to remove (when more than one exists)
//  before confirming a destructive delete.
//

import SwiftUI
import SwiftData

struct DeleteCopiesSheet: View {
    @Bindable var book: Book
    let onDeletedAll: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var removeCount = 1
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                CoverImageView(book: book, maxWidth: 90, maxHeight: 130)
                Text(book.title).font(.headline).multilineTextAlignment(.center)

                if book.copies > 1 {
                    Text("You have \(book.copies) copies. How many do you want to remove?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    CountStepper(count: $removeCount, range: 1...book.copies)

                    Button(role: .destructive) {
                        removeCopies()
                    } label: {
                        Text(removeCount >= book.copies ? "Delete entire entry" : "Remove \(removeCount) cop\(removeCount == 1 ? "y" : "ies")")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("This will permanently remove the item from your library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Text("Delete").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Delete")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete this item?", isPresented: $confirmDeleteAll) {
                Button("Delete", role: .destructive) { deleteEntire() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func removeCopies() {
        if removeCount >= book.copies {
            confirmDeleteAll = true
        } else {
            book.copies -= removeCount
            try? modelContext.save()
            dismiss()
        }
    }

    private func deleteEntire() {
        modelContext.delete(book)
        try? modelContext.save()
        dismiss()
        onDeletedAll()
    }
}
