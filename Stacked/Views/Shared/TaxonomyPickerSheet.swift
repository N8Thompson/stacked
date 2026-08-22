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

    @Environment(OrgManager.self) private var orgManager
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var addEditor: NameEditorTarget?
    @State private var showPaywall = false
    @State private var contributionError: String?

    private var locations: [StorageLocation] { orgManager.locations }
    private var formats: [ItemFormat] { orgManager.formats }
    private var bindings: [ItemBinding] { orgManager.bindings }

    var body: some View {
        listContent
            .navigationTitle("Select \(kind.title)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(item: $addEditor) { target in
                NameEditorSheet(target: target)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: "The free library includes \(EntitlementPolicy.freeLocationLimit) locations. Upgrade to Stacked + to add more. Your existing locations stay.")
            }
            .alert("Can't add to this collection", isPresented: Binding(
                get: { contributionError != nil },
                set: { if !$0 { contributionError = nil } }
            )) {
                Button("OK", role: .cancel) { contributionError = nil }
            } message: {
                Text(contributionError ?? "")
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
                guard subscriptions.canContributeToCurrentOrg else {
                    contributionError = "The collection owner's Stacked + access must be active before participants can add organization options."
                    return
                }
                if kind == .location,
                   !EntitlementPolicy.canAddLocation(
                       isPlus: subscriptions.currentOrgHasPlusAccess,
                       currentLocations: locations.count
                   ) {
                    showPaywall = true
                    return
                }
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
        guard let org = orgManager.activeOrg else { return }
        switch kind {
        case .location:
            if let location = TaxonomyService.findOrCreateLocation(name: name, org: org, in: context) {
                selectedLocation = location
                PersistenceController.shared.save()
                dismiss()
            }
        case .format:
            if let format = TaxonomyService.findOrCreateFormat(name: name, org: org, in: context) {
                selectedFormat = format
                PersistenceController.shared.save()
                dismiss()
            }
        case .binding:
            if let binding = TaxonomyService.findOrCreateBinding(name: name, org: org, in: context) {
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
