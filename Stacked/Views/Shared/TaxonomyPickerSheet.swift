//
//  TaxonomyPickerSheet.swift
//  Stacked
//
//  Picker for Location, Format, or Binding with inline "Add new".
//  Presented via navigation push to avoid nested sheets inside AddBookSheet.
//

import SwiftUI

enum TaxonomyKind {
    case location
    case format
    case binding

    var title: String {
        switch self {
        case .location: return "Location"
        case .format: return "Format"
        case .binding: return "Binding"
        }
    }

    var addTitle: String {
        switch self {
        case .location: return "New Location"
        case .format: return "New Format"
        case .binding: return "New Binding"
        }
    }

    var lowercaseName: String {
        switch self {
        case .location: return "location"
        case .format: return "format"
        case .binding: return "binding"
        }
    }
}

struct TaxonomyPickerView: View {
    let kind: TaxonomyKind
    @Binding var selectedLocation: StorageLocation?
    @Binding var selectedFormat: ItemFormat?
    @Binding var selectedBinding: ItemBinding?

    @Environment(HouseholdManager.self) private var householdManager
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var addEditor: NameEditorTarget?

    private var locations: [StorageLocation] { householdManager.locations }
    private var formats: [ItemFormat] { householdManager.formats }
    private var bindings: [ItemBinding] { householdManager.bindings }

    var body: some View {
        listContent
            .navigationTitle("Select \(kind.title)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(item: $addEditor) { target in
                NameEditorSheet(target: target)
            }
    }

    private var listContent: some View {
        List {
            switch kind {
            case .location:
                ForEach(locations) { location in
                    optionRow(title: location.name, isSelected: selectedLocation?.id == location.id) {
                        selectedLocation = location
                        dismiss()
                    }
                }
            case .format:
                ForEach(formats) { format in
                    optionRow(title: format.name, isSelected: selectedFormat?.id == format.id) {
                        selectedFormat = format
                        dismiss()
                    }
                }
            case .binding:
                ForEach(bindings) { binding in
                    optionRow(title: binding.name, isSelected: selectedBinding?.id == binding.id) {
                        selectedBinding = binding
                        dismiss()
                    }
                }
            }

            Button {
                addEditor = NameEditorTarget(title: kind.addTitle, initialName: "") { name in
                    insertAndSelect(name: name)
                }
            } label: {
                Label("Add new…", systemImage: "plus")
            }
        }
    }

    private func optionRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    @MainActor
    private func insertAndSelect(name: String) {
        guard let household = householdManager.activeHousehold else { return }
        switch kind {
        case .location:
            if let location = TaxonomyService.findOrCreateLocation(name: name, household: household, in: context) {
                selectedLocation = location
                PersistenceController.shared.save()
                dismiss()
            }
        case .format:
            if let format = TaxonomyService.findOrCreateFormat(name: name, household: household, in: context) {
                selectedFormat = format
                PersistenceController.shared.save()
                dismiss()
            }
        case .binding:
            if let binding = TaxonomyService.findOrCreateBinding(name: name, household: household, in: context) {
                selectedBinding = binding
                PersistenceController.shared.save()
                dismiss()
            }
        }
    }
}

struct TaxonomyPickerRow: View {
    let label: String
    let value: String
    let placeholder: String
    let isEditing: Bool
    let action: () -> Void

    var body: some View {
        LabeledContent(label) {
            if isEditing {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(value.isEmpty ? placeholder : value)
                            .foregroundStyle(value.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .multilineTextAlignment(.trailing)
                }
                .buttonStyle(.plain)
            } else {
                Text(value.isEmpty ? "—" : value)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension TaxonomyKind: Identifiable {
    var id: Self { self }
}
