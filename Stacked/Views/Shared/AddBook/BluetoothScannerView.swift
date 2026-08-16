//
//  BluetoothScannerView.swift
//  Stacked
//
//  Fast add mode for a Bluetooth HID barcode scanner. Captures scans through a
//  focused text field, auto-adds each book (or increments copies), and shows a
//  live "Added books" list with the newest scan on top.
//

import SwiftUI

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
            statusRow
            captureField

            if actions.scannerItems.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .padding(.top, 6)
        .onAppear {
            monitor.start()
            captureFocused = true
        }
        .onDisappear { monitor.stop() }
    }

    // MARK: Status

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(monitor.isConnected ? StackedTheme.Semantic.success : StackedTheme.Text.tertiary)
                .frame(width: 10, height: 10)
            Text(monitor.isConnected ? "Scanner connected" : "Scanner not connected")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(StackedTheme.Text.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    // MARK: Capture field

    private var captureField: some View {
        HStack(spacing: 8) {
            Image(systemName: "barcode.viewfinder")
                .foregroundStyle(.secondary)
            TextField("Listening for scans…", text: $captureText)
                .textFieldStyle(.plain)
                .focused($captureFocused)
                .submitLabel(.done)
                .onSubmit(submit)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                #endif
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(StackedTheme.Surface.track))
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture { captureFocused = true }
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
                isPlus: subscriptions.isPlus
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(StackedTheme.Text.tertiary)
            Text("Scan a book to add it")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(StackedTheme.Text.secondary)
            Text("Each scan is added instantly. Scanning a book you already own adds another copy.")
                .font(.caption)
                .foregroundStyle(StackedTheme.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}
