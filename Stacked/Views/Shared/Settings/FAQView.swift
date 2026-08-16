//
//  FAQView.swift
//  Stacked
//

import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("Answers to the questions that come up when sharing, moving, or upgrading a library.")
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
            }

            Section("Sharing") {
                FAQItem(
                    question: "Can I transfer collection ownership to someone else?",
                    answer: "CloudKit cannot transfer ownership of a shared collection. To make someone else the owner, send them a Stacked backup from Move or share collection. They import it into their own library, add you from User management, then you leave the original shared collection."
                )
                FAQItem(
                    question: "What happens if I leave a shared collection?",
                    answer: "You lose access to that live collection. The owner's library stays, including books you added."
                )
                FAQItem(
                    question: "What's the difference between sharing and a backup?",
                    answer: "Sharing is one live collection that everyone edits together. A Stacked backup is an independent copy. After import, the two libraries do not stay in sync."
                )
                FAQItem(
                    question: "What's the difference between inviting someone and a share link?",
                    answer: "A direct invite adds a specific person. A share link lets anyone with the link join with full access. Turning off the link removes people who joined that way. Directly invited people keep access until you remove them."
                )
            }

            Section("Library") {
                FAQItem(
                    question: "Why can't I add another title?",
                    answer: "The free library includes \(EntitlementPolicy.freeUniqueTitleLimit) unique titles. You can still add copies of titles you already own, import a backup, and manage existing books. Stacked + unlocks unlimited titles. Existing titles are never hidden or deleted."
                )
                FAQItem(
                    question: "What does Use only on this device do?",
                    answer: "This iPhone keeps a local copy and stops sending new changes to iCloud. Your iCloud library is not deleted. Reconnect later to merge this device into iCloud or discard local changes."
                )
            }

            Section("Stacked +") {
                FAQItem(
                    question: "What does Stacked + include?",
                    answer: "Unlimited titles and locations, Bluetooth rapid scanning, cost tracking, and sharing a collection with other users. Viewing, editing, and exporting your existing library stay available if a subscription ends."
                )
            }
        }
        .navigationTitle("FAQs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct FAQItem: View {
    let question: String
    let answer: String

    var body: some View {
        DisclosureGroup {
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(StackedTheme.Text.secondary)
                .padding(.vertical, 4)
        } label: {
            Text(question)
                .font(.body.weight(.medium))
                .foregroundStyle(StackedTheme.Text.primary)
        }
    }
}
