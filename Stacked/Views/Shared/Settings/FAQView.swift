//
//  FAQView.swift
//  Stacked
//

import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @State private var expandedIDs: Set<String> = []
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Answers to the questions that come up when sharing, moving, or upgrading a library.")
                        .font(.subheadline)
                        .foregroundStyle(StackedTheme.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    faqGroup(title: "Sharing", items: sharingItems)
                    faqGroup(title: "Library", items: libraryItems)
                    faqGroup(title: "Stacked +", items: plusItems)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            #else
            List {
                Section {
                    Text("Answers to the questions that come up when sharing, moving, or upgrading a library.")
                        .font(.subheadline)
                        .foregroundStyle(StackedTheme.Text.secondary)
                }

                Section("Sharing") {
                    ForEach(sharingItems) { item in
                        FAQItem(question: item.question, answer: item.answer)
                    }
                }

                Section("Library") {
                    ForEach(libraryItems) { item in
                        FAQItem(question: item.question, answer: item.answer)
                    }
                }

                Section("Stacked +") {
                    ForEach(plusItems) { item in
                        FAQItem(question: item.question, answer: item.answer)
                    }
                }
            }
            #endif
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

    #if os(macOS)
    private func faqGroup(title: String, items: [FAQEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(StackedTheme.Text.primary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    FAQExpandableRow(
                        item: item,
                        isExpanded: expandedIDs.contains(item.id)
                    ) {
                        if expandedIDs.contains(item.id) {
                            expandedIDs.remove(item.id)
                        } else {
                            expandedIDs.insert(item.id)
                        }
                    }

                    if index < items.count - 1 {
                        Divider()
                            .overlay(StackedTheme.Border.subtle)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(StackedTheme.Surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(StackedTheme.Border.subtle, lineWidth: 1)
            )
        }
    }
    #endif

    private var sharingItems: [FAQEntry] {
        [
            FAQEntry(
                question: "Can I transfer collection ownership to someone else?",
                answer: "CloudKit cannot transfer ownership of a shared collection. To make someone else the owner, send them a Stacked backup from Move or share collection. They import it into their own library, add you from User management, then you leave the original shared collection."
            ),
            FAQEntry(
                question: "What happens if I leave a shared collection?",
                answer: "You lose access to that live collection. The owner's library stays, including books you added."
            ),
            FAQEntry(
                question: "What's the difference between sharing and a backup?",
                answer: "Sharing is one live collection that everyone edits together. A Stacked backup is an independent copy. After import, the two libraries do not stay in sync."
            ),
            FAQEntry(
                question: "What's the difference between inviting someone and a share link?",
                answer: "A direct invite adds a specific person. A share link lets anyone with the link join with full access. Turning off the link removes people who joined that way. Directly invited people keep access until you remove them."
            ),
        ]
    }

    private var libraryItems: [FAQEntry] {
        [
            FAQEntry(
                question: "Why can't I add another title?",
                answer: "The free library includes \(EntitlementPolicy.freeUniqueTitleLimit) unique titles. You can still add copies of titles you already own, import a backup, and manage existing books. Stacked + unlocks unlimited titles. Existing titles are never hidden or deleted."
            ),
            FAQEntry(
                question: "What does Use only on this device do?",
                answer: "This device keeps a local copy and stops sending new changes to iCloud. Your iCloud library is not deleted. Reconnect later to merge this device into iCloud or discard local changes."
            ),
        ]
    }

    private var plusItems: [FAQEntry] {
        [
            FAQEntry(
                question: "What does Stacked + include?",
                answer: "Unlimited titles and locations, Bluetooth batch scanning, cost tracking, and sharing a collection with other users. Camera ISBN and text scanning are available separately. Viewing, editing, and exporting your existing library stay available if a subscription ends."
            ),
        ]
    }
}

private struct FAQEntry: Identifiable {
    var id: String { question }
    let question: String
    let answer: String
}

#if os(macOS)
private struct FAQExpandableRow: View {
    let item: FAQEntry
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 10) {
                    Text(item.question)
                        .font(.body.weight(.medium))
                        .foregroundStyle(StackedTheme.Text.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StackedTheme.Text.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.subheadline)
                    .foregroundStyle(StackedTheme.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
            }
        }
        .padding(.vertical, 8)
        .animation(.snappy(duration: 0.2), value: isExpanded)
    }
}
#endif

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
