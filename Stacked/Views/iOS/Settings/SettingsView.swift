//
//  SettingsView.swift
//  Stacked
//

import SwiftUI

#if os(iOS)
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(OrgManager.self) private var orgManager

    @State private var editor: NameEditorTarget?
    @State private var deleteRequest: TaxonomyDeleteRequest?
    @State private var taxonomyError: String?
    @State private var sheet: SettingsSheet?

    var body: some View {
        NavigationStack {
            Form {
                SettingsContent(
                    editor: $editor,
                    deleteRequest: $deleteRequest,
                    taxonomyError: $taxonomyError,
                    sheet: $sheet
                )
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
        .settingsDestinationSheets($sheet)
        .sheet(item: simpleNameEditor) { target in
            NameEditorSheet(target: target)
        }
        .fullScreenCover(item: formatEditor) { target in
            NameEditorSheet(target: target)
        }
        .sheet(item: $deleteRequest) { request in
            TaxonomyDeleteSheet(
                request: request,
                locations: orgManager.locations,
                formats: orgManager.formats,
                bindings: orgManager.bindings,
                onDelete: { request, location, format, binding in
                    TaxonomyService.performDelete(
                        request,
                        replacementLocation: location,
                        replacementFormat: format,
                        replacementBinding: binding,
                        locations: orgManager.locations,
                        formats: orgManager.formats,
                        bindings: orgManager.bindings,
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

    private var simpleNameEditor: Binding<NameEditorTarget?> {
        Binding(
            get: {
                guard editor?.initialIconName == nil else { return nil }
                return editor
            },
            set: { if $0 == nil { editor = nil } }
        )
    }

    private var formatEditor: Binding<NameEditorTarget?> {
        Binding(
            get: {
                guard editor?.initialIconName != nil else { return nil }
                return editor
            },
            set: { if $0 == nil { editor = nil } }
        )
    }
}
#endif
