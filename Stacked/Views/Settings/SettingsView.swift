//
//  SettingsView.swift
//  Stacked
//
//  Manage Locations and Formats: add, rename, delete, and choose the default.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \StorageLocation.createdAt) private var locations: [StorageLocation]
    @Query(sort: \ItemFormat.createdAt) private var formats: [ItemFormat]

    @State private var editor: NameEditorTarget?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(locations) { location in
                        row(
                            name: location.name,
                            isDefault: location.isDefault,
                            canDelete: locations.count > 1,
                            onRename: { editor = renameLocation(location) },
                            onMakeDefault: location.isDefault ? nil : { makeDefaultLocation(location) },
                            onDelete: locations.count > 1 ? { deleteLocation(location) } : nil
                        )
                    }
                    Button {
                        editor = addLocation()
                    } label: {
                        Label("Add location", systemImage: "plus")
                    }
                } header: {
                    Text("Locations")
                } footer: {
                    Text("Where items are stored (e.g. Home Library, Office). New items go to the default location.")
                }

                Section {
                    ForEach(formats) { format in
                        row(
                            name: format.name,
                            isDefault: format.isDefault,
                            canDelete: true,
                            onRename: { editor = renameFormat(format) },
                            onMakeDefault: format.isDefault ? nil : { makeDefaultFormat(format) },
                            onDelete: { deleteFormat(format) }
                        )
                    }
                    Button {
                        editor = addFormat()
                    } label: {
                        Label("Add format", systemImage: "plus")
                    }
                } header: {
                    Text("Formats")
                } footer: {
                    Text("The kind of item (e.g. Book, Journal, Magazine). New items use the default format.")
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $editor) { target in
                NameEditorSheet(target: target)
            }
        }
    }

    // MARK: Row

    @ViewBuilder
    private func row(
        name: String,
        isDefault: Bool,
        canDelete: Bool,
        onRename: @escaping () -> Void,
        onMakeDefault: (() -> Void)?,
        onDelete: (() -> Void)?
    ) -> some View {
        HStack {
            Text(name)
            if isDefault {
                Text("Default")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(.tint.opacity(0.2)))
                    .foregroundStyle(.tint)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onRename)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .swipeActions(edge: .leading) {
            if let onMakeDefault {
                Button("Default", action: onMakeDefault).tint(.blue)
            }
        }
        .contextMenu {
            Button { onRename() } label: { Label("Rename", systemImage: "pencil") }
            if let onMakeDefault {
                Button { onMakeDefault() } label: { Label("Make default", systemImage: "star") }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    // MARK: Location actions

    private func addLocation() -> NameEditorTarget {
        NameEditorTarget(title: "New Location", initialName: "") { name in
            let isFirst = locations.isEmpty
            modelContext.insert(StorageLocation(name: name, isDefault: isFirst))
            try? modelContext.save()
        }
    }

    private func renameLocation(_ location: StorageLocation) -> NameEditorTarget {
        NameEditorTarget(title: "Rename Location", initialName: location.name) { name in
            location.name = name
            try? modelContext.save()
        }
    }

    private func makeDefaultLocation(_ location: StorageLocation) {
        for other in locations { other.isDefault = false }
        location.isDefault = true
        try? modelContext.save()
    }

    private func deleteLocation(_ location: StorageLocation) {
        guard locations.count > 1 else { return }
        let wasDefault = location.isDefault
        modelContext.delete(location)
        if wasDefault, let next = locations.first(where: { $0.persistentModelID != location.persistentModelID }) {
            next.isDefault = true
        }
        try? modelContext.save()
    }

    // MARK: Format actions

    private func addFormat() -> NameEditorTarget {
        NameEditorTarget(title: "New Format", initialName: "") { name in
            let isFirst = formats.isEmpty
            modelContext.insert(ItemFormat(name: name, isDefault: isFirst))
            try? modelContext.save()
        }
    }

    private func renameFormat(_ format: ItemFormat) -> NameEditorTarget {
        NameEditorTarget(title: "Rename Format", initialName: format.name) { name in
            format.name = name
            try? modelContext.save()
        }
    }

    private func makeDefaultFormat(_ format: ItemFormat) {
        for other in formats { other.isDefault = false }
        format.isDefault = true
        try? modelContext.save()
    }

    private func deleteFormat(_ format: ItemFormat) {
        let wasDefault = format.isDefault
        modelContext.delete(format)
        if wasDefault, let next = formats.first(where: { $0.persistentModelID != format.persistentModelID }) {
            next.isDefault = true
        }
        try? modelContext.save()
    }
}

// MARK: - Name editor

struct NameEditorTarget: Identifiable {
    let id = UUID()
    let title: String
    let initialName: String
    let onSave: (String) -> Void
}

private struct NameEditorSheet: View {
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
