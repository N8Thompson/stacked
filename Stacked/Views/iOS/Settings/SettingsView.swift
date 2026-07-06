//
//  SettingsView.swift
//  Stacked
//

import SwiftUI

#if os(iOS)
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(HouseholdManager.self) private var householdManager

    @State private var editor: NameEditorTarget?
    @State private var deleteRequest: TaxonomyDeleteRequest?
    @State private var taxonomyError: String?

    var body: some View {
        NavigationStack {
            Form {
                SettingsContent(
                    editor: $editor,
                    deleteRequest: $deleteRequest,
                    taxonomyError: $taxonomyError
                )
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
        .sheet(item: $editor) { target in
            NameEditorSheet(target: target)
        }
        .sheet(item: $deleteRequest) { request in
            TaxonomyDeleteSheet(
                request: request,
                locations: householdManager.locations,
                formats: householdManager.formats,
                bindings: householdManager.bindings,
                onDelete: { request, location, format, binding in
                    TaxonomyService.performDelete(
                        request,
                        replacementLocation: location,
                        replacementFormat: format,
                        replacementBinding: binding,
                        locations: householdManager.locations,
                        formats: householdManager.formats,
                        bindings: householdManager.bindings,
                        in: context
                    )
                }
            )
        }
        .alert("Can't delete", isPresented: Binding(
            get: { taxonomyError != nil },
            set: { if !$0 { taxonomyError = nil } }
        )) {
            Button("OK", role: .cancel) { taxonomyError = nil }
        } message: {
            Text(taxonomyError ?? "")
        }
    }
}
#endif
