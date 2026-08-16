//
//  DeleteCopiesSheet.swift
//  Stacked
//
//  Lets the user choose how many copies to remove (when more than one exists)
//  before confirming a destructive delete.
//

import SwiftUI

struct DeleteCopiesSheet: View {
    @ObservedObject var book: Book
    let onDeletedAll: () -> Void

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var removeCount = 1
    @State private var confirmDeleteAll = false

    private var copyCount: Int { Int(book.copies) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                CoverImageView(book: book, maxWidth: 90, maxHeight: 130)
                Text(book.title).font(.headline).multilineTextAlignment(.center)

                if copyCount > 1 {
                    Text("You have \(copyCount) copies. How many do you want to remove?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    CountStepper(count: $removeCount, range: 1...copyCount)

                    if CopyDeletionPolicy.showsCollapsedRemoveAll(copyCount: copyCount, removeCount: removeCount) {
                        Button(role: .destructive) {
                            confirmDeleteAll = true
                        } label: {
                            Text("Remove all copies")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(role: .destructive) {
                            removeCopies()
                        } label: {
                            Text("Remove \(removeCount) cop\(removeCount == 1 ? "y" : "ies")")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(role: .destructive) {
                            confirmDeleteAll = true
                        } label: {
                            Text("Remove all copies")
                                .frame(maxWidth: .infinity)
                        }
                    }
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
            .alert("Remove all copies?", isPresented: $confirmDeleteAll) {
                Button("Remove all", role: .destructive) { deleteEntire() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes this title from your library.")
            }
        }
    }

    private func removeCopies() {
        switch CopyDeletionPolicy.action(copyCount: copyCount, removeCount: removeCount) {
        case .deleteEntry:
            confirmDeleteAll = true
        case .removeCopies(let count):
            book.copies -= Int32(count)
            PersistenceController.shared.save()
            dismiss()
        }
    }

    private func deleteEntire() {
        context.delete(book)
        PersistenceController.shared.save()
        dismiss()
        onDeletedAll()
    }
}
