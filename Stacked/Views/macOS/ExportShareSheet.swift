//
//  ExportShareSheet.swift
//  Stacked
//

import SwiftUI
import AppKit

#if os(macOS)
struct ExportShareSheet: NSViewControllerRepresentable {
    let items: [Any]

    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: .zero, of: controller.view, preferredEdge: .minY)
        }
        return controller
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
#endif
