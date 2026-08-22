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
    @Environment(OrgManager.self) private var orgManager
    @Environment(OrgSharingService.self) private var sharingService
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    let bookCount: Int
    @State private var errorMessage: String?

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
                        mergeIntoOrg()
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
        .alert("Couldn't add your books", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func mergeIntoOrg() {
        guard let org = orgManager.activeOrg,
              let source = orgManager.privateLibraryCollection(in: context) else {
            sharingService.pendingMergeAfterJoin = false
            dismiss()
            return
        }
        do {
            try CollectionMergeService.mergePrivateIntoOrg(
                source: source,
                targetOrg: org,
                in: context,
                hasPlusAccess: subscriptions.currentOrgHasPlusAccess,
                canContribute: subscriptions.canContributeToCurrentOrg
            )
            sharingService.pendingMergeAfterJoin = false
            orgManager.refresh(in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
