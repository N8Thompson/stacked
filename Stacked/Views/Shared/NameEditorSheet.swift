//
//  NameEditorSheet.swift
//  Stacked
//
//  Simple name editor used in Settings and taxonomy picker "Add new" flows.
//

import SwiftUI

struct NameEditorTarget: Identifiable {
    let id = UUID()
    let title: String
    let initialName: String
    let onSave: (String) -> Void
}

struct NameEditorSheet: View {
    let target: NameEditorTarget
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
            .navigationTitle(target.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        target.onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { name = target.initialName }
        }
        .presentationDetents([.height(180)])
    }
}
