//
//  TaxonomyDeleteSheet.swift
//  Stacked
//
//  Confirms taxonomy deletion and reassigns affected titles when needed.
//

import SwiftUI

struct TaxonomyDeleteRequest: Identifiable {
    enum Target {
        case location(StorageLocation)
        case format(ItemFormat)
        case binding(ItemBinding)
    }

    let id = UUID()
    let target: Target

    var kind: TaxonomyKind {
        switch target {
        case .location: return .location
        case .format: return .format
        case .binding: return .binding
        }
    }

    var name: String {
        switch target {
        case .location(let location): return location.name
        case .format(let format): return format.name
        case .binding(let binding): return binding.name
        }
    }

    var titleCount: Int {
        switch target {
        case .location(let location): return location.titleCount
        case .format(let format): return format.titleCount
        case .binding(let binding): return binding.titleCount
        }
    }
}

struct TaxonomyDeleteSheet: View {
    let request: TaxonomyDeleteRequest
    let locations: [StorageLocation]
    let formats: [ItemFormat]
    let bindings: [ItemBinding]
    let onDelete: (TaxonomyDeleteRequest, StorageLocation?, ItemFormat?, ItemBinding?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedLocationID: UUID?
    @State private var selectedFormatID: UUID?
    @State private var selectedBindingID: UUID?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(message)
                    .font(.body)
                    .foregroundStyle(StackedTheme.Text.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if request.titleCount > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reassign titles")
                            .font(.headline)
                            .foregroundStyle(StackedTheme.Text.primary)

                        Text(replacementLabel)
                            .font(.caption)
                            .foregroundStyle(StackedTheme.Text.tertiary)

                        replacementPicker
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(StackedTheme.Surface.track)
                            )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Delete \(request.kind.title)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        submit()
                    }
                    .disabled(!canDelete)
                }
            }
            .onAppear(perform: selectInitialReplacement)
        }
        #if os(iOS)
        .presentationDetents([.height(request.titleCount > 0 ? 340 : 220)])
        .presentationDragIndicator(.visible)
        #else
        .frame(width: 500, height: request.titleCount > 0 ? 300 : 200)
        #endif
    }

    private var message: String {
        let titleWord = request.titleCount == 1 ? "title" : "titles"
        if request.titleCount > 0 {
            return "\(request.name) is being used on \(request.titleCount) \(titleWord). Please choose a new \(request.kind.lowercaseName) to assign to those titles."
        }
        return "Delete \"\(request.name)\"?"
    }

    private var replacementLabel: String {
        switch request.target {
        case .location: return "New location"
        case .format: return "New format"
        case .binding: return "New binding"
        }
    }

    @ViewBuilder
    private var replacementPicker: some View {
        switch request.target {
        case .location(let location):
            Picker("New location", selection: $selectedLocationID) {
                ForEach(locations.filter { $0.id != location.id }) { option in
                    Text(option.name).tag(Optional(option.id))
                }
            }
            #if os(macOS)
            .labelsHidden()
            #endif
        case .format(let format):
            Picker("New format", selection: $selectedFormatID) {
                ForEach(formats.filter { $0.id != format.id }) { option in
                    Text(option.name).tag(Optional(option.id))
                }
            }
            #if os(macOS)
            .labelsHidden()
            #endif
        case .binding(let binding):
            Picker("New binding", selection: $selectedBindingID) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(bindings.filter { $0.id != binding.id }) { option in
                    Text(option.name).tag(Optional(option.id))
                }
            }
            #if os(macOS)
            .labelsHidden()
            #endif
        }
    }

    private var canDelete: Bool {
        guard request.titleCount > 0 else { return true }
        switch request.target {
        case .location:
            return selectedLocationID != nil
        case .format:
            return selectedFormatID != nil
        case .binding:
            return true
        }
    }

    private func selectInitialReplacement() {
        switch request.target {
        case .location(let location):
            selectedLocationID = locations.first { $0.id != location.id }?.id
        case .format(let format):
            selectedFormatID = formats.first { $0.id != format.id && $0.isDefault }?.id
                ?? formats.first { $0.id != format.id }?.id
        case .binding(let binding):
            if let replacement = bindings.first(where: { $0.id != binding.id && $0.isDefault }) {
                selectedBindingID = replacement.id
            } else {
                selectedBindingID = bindings.first { $0.id != binding.id }?.id
            }
        }
    }

    private func submit() {
        let replacementLocation = locations.first { $0.id == selectedLocationID }
        let replacementFormat = formats.first { $0.id == selectedFormatID }
        let replacementBinding: ItemBinding?
        if case .binding = request.target {
            replacementBinding = bindings.first { $0.id == selectedBindingID }
        } else {
            replacementBinding = nil
        }
        onDelete(request, replacementLocation, replacementFormat, replacementBinding)
        dismiss()
    }
}
