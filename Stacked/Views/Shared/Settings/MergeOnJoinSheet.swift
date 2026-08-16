//
//  MergeOnJoinSheet.swift
//  Stacked
//
//  Shown after accepting a collection invite when the user still has books locally.
//

import SwiftUI
import CoreData

struct MergeOnJoinSheet: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(HouseholdManager.self) private var householdManager
    @Environment(HouseholdSharingService.self) private var sharingService
    @Environment(\.dismiss) private var dismiss

    let bookCount: Int

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("You have \(bookCount) \(bookCount == 1 ? "book" : "books") in your personal library.")
                    .font(.headline)

                Text("Add them to the shared collection so every user can see what you already own, or start fresh and keep them separate for now.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)

                VStack(spacing: 12) {
                    Button {
                        mergeIntoHousehold()
                    } label: {
                        Text("Add my books to shared collection")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StackedTheme.accent)

                    Button("Start fresh") {
                        sharingService.pendingMergeAfterJoin = false
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)

                    Button("Decide later") {
                        dismiss()
                    }
                    .font(.footnote)
                    .foregroundStyle(StackedTheme.Text.secondary)
                    .frame(maxWidth: .infinity)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Join Collection")
            .interactiveDismissDisabled()
        }
        .presentationDetents([.medium, .large])
    }

    private func mergeIntoHousehold() {
        guard let household = householdManager.activeHousehold,
              let source = householdManager.privateLibraryCollection(in: context) else {
            sharingService.pendingMergeAfterJoin = false
            dismiss()
            return
        }
        try? CollectionMergeService.mergePrivateIntoHousehold(
            source: source,
            targetHousehold: household,
            in: context
        )
        sharingService.pendingMergeAfterJoin = false
        dismiss()
    }
}
