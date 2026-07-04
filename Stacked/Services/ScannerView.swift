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
    /// Called with recognized text (for .text) or the barcode payload (for .barcode).
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
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasReportedBarcode = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report(item)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // Auto-report the first barcode found; text is reported on tap.
            guard !hasReportedBarcode else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    hasReportedBarcode = true
                    onScan(payload)
                    return
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
