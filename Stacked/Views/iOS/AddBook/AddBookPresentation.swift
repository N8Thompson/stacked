//
//  AddBookPresentation.swift
//  Stacked
//

import SwiftUI

#if os(iOS)
private struct AddBookSheetPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let preselection: AddPreselection

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            AddBookSheet(preselection: preselection)
        }
    }
}

extension View {
    func addBookSheet(isPresented: Binding<Bool>, preselection: AddPreselection) -> some View {
        modifier(AddBookSheetPresenter(isPresented: isPresented, preselection: preselection))
    }
}
#endif
