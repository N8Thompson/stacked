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
    @FocusState private var isFieldFocused: Bool
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name", text: $name)
                    .focused($isFieldFocused)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(StackedTheme.Surface.track)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { isFieldFocused = true }

                Spacer(minLength: 0)
            }
            .padding(20)
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
            .onAppear {
                name = target.initialName
                DispatchQueue.main.async {
                    isFieldFocused = true
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        #else
        .frame(width: 380, height: 180)
        #endif
    }
}
