import SwiftUI

/// Shows whatever the RootPresenter holds. Until routing sets a screen, a spinner.
struct RootView: View {
    @ObservedObject var presenter: RootPresenter

    var body: some View {
        Group {
            if let screen = presenter.screen {
                screen
            } else {
                ProgressView()
            }
        }
        .sheet(isPresented: sheetShown) {
            presenter.sheet
        }
        .alert(
            presenter.alert?.title ?? "",
            isPresented: alertShown,
            presenting: presenter.alert
        ) { _ in
            Button("OK") {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private var sheetShown: Binding<Bool> {
        Binding(get: { presenter.sheet != nil }, set: { if !$0 { presenter.sheet = nil } })
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { presenter.alert != nil }, set: { if !$0 { presenter.alert = nil } })
    }
}
