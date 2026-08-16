//
//  CloudKitIdentityService.swift
//  Stacked
//
//  Resolves the signed-in iCloud user's record name and display name.
//

import Foundation
import CloudKit

@MainActor
@Observable
final class CloudKitIdentityService {
    static let shared = CloudKitIdentityService()

    private(set) var recordName: String?
    private(set) var displayName: String = "You"
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    var isSignedIn: Bool { accountStatus == .available }

    private var container: CKContainer {
        CKContainer(identifier: PersistenceController.cloudKitContainerID)
    }

    func refresh() async {
        do {
            accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                recordName = nil
                displayName = "You"
                return
            }
            let userID = try await container.userRecordID()
            recordName = userID.recordName
            if let components = try? await container.userIdentity(forUserRecordID: userID)?.nameComponents {
                let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
                if !formatted.isEmpty {
                    displayName = formatted.components(separatedBy: " ").first ?? formatted
                }
            }
        } catch {
            accountStatus = .couldNotDetermine
        }
    }

    func applyProvenance(to book: Book) {
        book.addedAt = Date()
        book.addedByCloudRecordName = recordName ?? ""
        book.addedByDisplayName = displayName
    }

    func addedByLine(for book: Book) -> String {
        let who: String
        if let recordName, book.addedByCloudRecordName == recordName {
            who = "You"
        } else if book.addedByDisplayName.isEmpty {
            who = "Someone"
        } else {
            who = book.addedByDisplayName
        }
        let date = (book.addedAt ?? book.createdAt ?? Date()).formatted(date: .long, time: .omitted)
        return "\(who) added on \(date)"
    }
}
