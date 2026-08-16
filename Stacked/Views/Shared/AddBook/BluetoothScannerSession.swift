//
//  BluetoothScannerSession.swift
//  Stacked
//
//  Supporting types for the Bluetooth (HID keyboard) scanner add mode:
//  session items, connection monitoring, and scan feedback sounds.
//

import Foundation
import GameController

#if os(iOS)
import AudioToolbox
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Result of adding a scanned book to the library.
struct AddOutcome {
    let isNewTitle: Bool
    let totalCopies: Int
}

/// One entry in the live scanner session list (newest first).
enum ScannerSessionItem: Identifiable {
    case added(AddedBookInfo)
    case failure(ScanErrorInfo)

    var id: UUID {
        switch self {
        case .added(let info): return info.id
        case .failure(let error): return error.id
        }
    }
}

struct AddedBookInfo: Identifiable {
    let id = UUID()
    let isbn: String
    let title: String
    let authors: String
    let coverURL: String
    let totalCopies: Int
    let isNewTitle: Bool
}

struct ScanErrorInfo: Identifiable {
    let id = UUID()
    let message: String
    let scannedText: String
}

/// Tracks whether a hardware keyboard (the HID barcode scanner) is connected.
@MainActor
@Observable
final class ScannerConnectionMonitor {
    var isConnected = false

    private var observers: [NSObjectProtocol] = []

    func start() {
        updateState()
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateState() }
            }
        )
        observers.append(
            center.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateState() }
            }
        )
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }

    private func updateState() {
        isConnected = GCKeyboard.coalesced != nil
    }
}

/// Audible / haptic feedback for scan outcomes.
enum ScannerFeedback {
    static func success() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1103) // Tink
        #elseif os(macOS)
        NSSound(named: NSSound.Name("Tink"))?.play()
        #endif
    }

    static func failure() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1112) // jbl_cancel — short "dun" cancel tone
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #elseif os(macOS)
        // The "action can't be done" Funk sound.
        NSSound(named: NSSound.Name("Funk"))?.play()
        #endif
    }
}
