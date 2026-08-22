//
//  BluetoothScannerView.swift
//  Stacked
//
//  Fast add mode for a Bluetooth HID barcode scanner. Captures scans through a
//  focused text field, auto-adds each book (or increments copies), and shows a
//  live "Added books" list with the newest scan on top.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct BluetoothScannerView: View {
    let actions: AddBookActions
    let locations: [StorageLocation]
    let formats: [ItemFormat]

    @Environment(\.managedObjectContext) private var context
    @Environment(OrgManager.self) private var orgManager
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var monitor = ScannerConnectionMonitor()
    @State private var captureText = ""
    @FocusState private var captureFocused: Bool

    private var provider: BookSearchProvider { BookSearchProviderFactory.make() }

    var body: some View {
        VStack(spacing: 12) {
            hiddenCaptureField

            if !monitor.isConnected {
                disconnectedState
            } else if actions.scannerItems.isEmpty {
                connectedEmptyState
            } else {
                sessionList
            }
        }
        .padding(.top, 6)
        .onAppear {
            monitor.start()
            captureFocused = monitor.isConnected
        }
        .onDisappear { monitor.stop() }
        .onChange(of: monitor.isConnected) { _, isConnected in
            captureFocused = isConnected
        }
    }

    // MARK: Capture field

    private var hiddenCaptureField: some View {
        TextField("", text: $captureText)
            .textFieldStyle(.plain)
            .focused($captureFocused)
            .submitLabel(.done)
            .onSubmit(submit)
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            #endif
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
    }

    private func submit() {
        let raw = captureText
        captureText = ""
        captureFocused = true
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            await actions.processScannerInput(
                raw,
                locations: locations,
                formats: formats,
                orgManager: orgManager,
                context: context,
                provider: provider,
                isPlus: subscriptions.currentOrgHasPlusAccess,
                canContribute: subscriptions.canContributeToCurrentOrg
            )
        }
    }

    // MARK: Session list

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Added books")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StackedTheme.Text.secondary)
                .padding(.horizontal)

            List {
                ForEach(actions.scannerItems) { item in
                    row(for: item)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                actions.removeScannerItem(
                                    item,
                                    orgManager: orgManager,
                                    context: context
                                )
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.2), value: actions.scannerItems.map(\.id))
    }

    @ViewBuilder
    private func row(for item: ScannerSessionItem) -> some View {
        switch item {
        case .added(let info): addedRow(info)
        case .failure(let error): errorRow(error)
        }
    }

    private func addedRow(_ info: AddedBookInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            CoverImageView(urlString: info.coverURL, maxWidth: 40, maxHeight: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StackedTheme.Text.primary)
                    .lineLimit(2)
                if !info.authors.isEmpty {
                    Text(info.authors)
                        .font(.caption)
                        .foregroundStyle(StackedTheme.Text.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(info.isNewTitle ? "Added" : "Copy ×\(info.totalCopies)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StackedTheme.Semantic.success)
        }
        .padding(10)
        .frame(height: 78)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StackedTheme.Surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(StackedTheme.Border.subtle, lineWidth: 1)
        )
    }

    private func errorRow(_ error: ScanErrorInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(StackedTheme.Semantic.destructive)
                .frame(width: 40, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text("Scan failed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StackedTheme.Semantic.destructive)
                Text(error.message)
                    .font(.caption)
                    .foregroundStyle(StackedTheme.Text.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(height: 78)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StackedTheme.Semantic.destructive.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(StackedTheme.Semantic.destructive.opacity(0.35), lineWidth: 1)
        )
    }

    private var connectedEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(StackedTheme.Text.secondary)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(StackedTheme.Semantic.success)
                        .frame(width: 9, height: 9)
                        .offset(x: 5, y: -2)
                }
            Text("Scan a book to add it")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(StackedTheme.Text.primary)
            Text("Each scan is added instantly. Scanning a book you already own adds another copy.")
                .font(.caption)
                .foregroundStyle(StackedTheme.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .contentShape(Rectangle())
        .onTapGesture { captureFocused = true }
    }

    private var disconnectedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(StackedTheme.Text.tertiary)

            Text("Scanner not connected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StackedTheme.Text.primary)

            Text(disconnectedInstructions)
                .font(.caption)
                .foregroundStyle(StackedTheme.Text.tertiary)
                .multilineTextAlignment(.center)

            #if os(macOS)
            Button("Open Bluetooth Settings", action: openBluetoothSettings)
                .buttonStyle(.borderedProminent)
                .tint(StackedTheme.accent)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var disconnectedInstructions: String {
        #if os(iOS)
        "Open Settings → Bluetooth → connect your barcode scanner, then return to Stacked."
        #else
        "Connect a Bluetooth barcode scanner in Bluetooth Settings."
        #endif
    }

    private func openBluetoothSettings() {
        #if os(macOS)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") else {
            return
        }
        NSWorkspace.shared.open(url)
        #endif
    }
}
