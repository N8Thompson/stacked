//
//  Backend.swift
//  Stacked
//
//  Compile-time flag selecting where book searches are routed. Flip
//  `Backend.current` to `.proxy(...)` once the sibling backend is deployed.
//

import Foundation

enum Backend {
    /// Talk to ISBNdb directly using the API key stored in the Keychain.
    case directISBNdb
    /// Route through our rate-limiting proxy backend at the given base URL.
    case proxy(baseURL: URL)

    /// The active backend. Currently direct ISBNdb; the proxy is built but not
    /// yet wired up.
    static let current: Backend = .directISBNdb

    // Example for later:
    // static let current: Backend = .proxy(baseURL: URL(string: "https://your-backend.example.com")!)
}
