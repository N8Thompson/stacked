//
//  ScannerView.swift
//  Stacked
//
//  VisionKit DataScanner wrapper for live text and barcode scanning.
//  Available on iOS/iPadOS only; not compiled on macOS.
//

#if os(iOS)
import SwiftUI
import VisionKit

enum ScanMode {
    case text
    case barcode
}

struct ScannerView: UIViewControllerRepresentable {
    let mode: ScanMode
    /// Called when the user taps recognized text, or when a barcode is detected.
    let onScan: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognized: [DataScannerViewController.RecognizedDataType]
        switch mode {
        case .text:
            recognized = [.text()]
        case .barcode:
            recognized = [.barcode(symbologies: [.ean13, .ean8, .upce])]
        }

        let controller = DataScannerViewController(
            recognizedDataTypes: Set(recognized),
            qualityLevel: .balanced,
            recognizesMultipleItems: mode == .text,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.mode = mode
        context.coordinator.onScan = onScan
        if !controller.isScanning {
            try? controller.startScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var mode: ScanMode
        var onScan: (String) -> Void

        init(mode: ScanMode, onScan: @escaping (String) -> Void) {
            self.mode = mode
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch mode {
            case .text:
                guard case .text = item else { return }
            case .barcode:
                guard case .barcode = item else { return }
            }
            report(item)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard mode == .barcode else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload)
                }
            }
        }

        private func report(_ item: RecognizedItem) {
            switch item {
            case .text(let text):
                onScan(text.transcript)
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue { onScan(payload) }
            @unknown default:
                break
            }
        }
    }
}
#endif
