//
//  AddBookPresentation.swift
//  Stacked
//

import SwiftUI

#if os(macOS)
private struct AddBookSheetPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let preselection: AddPreselection

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                            .onTapGesture { isPresented = false }

                        AddBookSheet(preselection: preselection) {
                            isPresented = false
                        }
                        .macAddBookPanelStyle()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented)
    }
}

extension View {
    func addBookSheet(isPresented: Binding<Bool>, preselection: AddPreselection) -> some View {
        modifier(AddBookSheetPresenter(isPresented: isPresented, preselection: preselection))
    }

    func macAddBookPanelStyle() -> some View {
        self
            .background(StackedTheme.Surface.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(StackedTheme.Border.subtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }
}
#endif
