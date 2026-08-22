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
    let initialIconName: String?
    let iconCategories: [SymbolCategory]
    let onSave: (String, String?) -> Void

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.initialName = initialName
        self.initialIconName = nil
        self.iconCategories = []
        self.onSave = { name, _ in onSave(name) }
    }

    init(
        title: String,
        initialName: String,
        initialIconName: String,
        iconCategories: [SymbolCategory],
        onSave: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.initialIconName = initialIconName
        self.iconCategories = iconCategories
        self.onSave = { name, iconName in
            onSave(name, iconName ?? initialIconName)
        }
    }
}

struct NameEditorSheet: View {
    let target: NameEditorTarget
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool
    @State private var name: String = ""
    @State private var iconName = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
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

                if target.initialIconName != nil {
                    symbolBrowser
                } else {
                    Spacer(minLength: 0)
                }
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
                        target.onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            target.initialIconName == nil ? nil : iconName
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = target.initialName
                iconName = target.initialIconName ?? ""
                if target.initialIconName == nil {
                    DispatchQueue.main.async {
                        isFieldFocused = true
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents(
            target.initialIconName == nil
                ? [.height(220)]
                : [.medium, .large]
        )
        .presentationDragIndicator(.visible)
        #else
        .frame(
            width: target.initialIconName == nil ? 380 : 520,
            height: target.initialIconName == nil ? 180 : 560
        )
        #endif
    }

    private var symbolBrowser: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(target.iconCategories) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StackedTheme.Text.secondary)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 48), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(category.icons, id: \.self) { symbol in
                                Button {
                                    iconName = symbol
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(
                                                symbol == iconName
                                                    ? StackedTheme.accentMuted
                                                    : StackedTheme.Surface.muted
                                            )
                                        Image(systemName: symbol)
                                            .font(.title3)
                                            .foregroundStyle(StackedTheme.accent)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if symbol == iconName {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(StackedTheme.Text.primary)
                                                .padding(3)
                                        }
                                    }
                                    .frame(height: 48)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(searchableName(for: symbol))
                                .accessibilityAddTraits(symbol == iconName ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func searchableName(for symbol: String) -> String {
        symbol
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
    }
}
