//
//  CollectionAccessBanner.swift
//  Stacked
//

import SwiftUI

struct CollectionAccessBanner: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(OrgManager.self) private var orgManager
    @Environment(OrgSharingService.self) private var sharingService
    @Environment(SubscriptionService.self) private var subscriptions

    private var books: [Book] {
        orgManager.allBooks(in: context)
    }

    var body: some View {
        if sharingService.currentRole == .participant,
           !subscriptions.canContributeToCurrentOrg {
            banner(
                icon: "lock.fill",
                title: "Read-only collection",
                message: "The owner's Stacked + access is inactive. You can browse this collection, but you can't add, edit, or delete items."
            )
        } else if sharingService.currentRole != .participant,
                  let remaining = EntitlementPolicy.remainingUniqueTitles(
                    isPlus: subscriptions.isPlus,
                    currentUniqueTitles: EntitlementPolicy.uniqueTitleCount(in: books)
                  ) {
            banner(
                icon: remaining == 0 ? "exclamationmark.circle.fill" : "books.vertical.fill",
                title: remaining == 0 ? "Free title limit reached" : "Free plan",
                message: freePlanMessage(remaining: remaining)
            )
        }
    }

    private func freePlanMessage(remaining: Int) -> String {
        let usage: String
        if remaining == 0 {
            usage = "Your \(EntitlementPolicy.freeUniqueTitleLimit) free titles are in use."
        } else {
            usage = "\(remaining) of \(EntitlementPolicy.freeUniqueTitleLimit) titles remaining."
        }

        if sharingService.currentRole == .owner {
            return usage + " Shared participants are read-only until Stacked + is active."
        }
        return usage
    }

    private func banner(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(StackedTheme.Semantic.star)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StackedTheme.Text.primary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(StackedTheme.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .stackedCardStyle(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }
}
