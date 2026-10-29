import SwiftUI

/// Shows whatever the RootPresenter holds. Until routing sets a screen, a spinner.
struct RootView: View {
    @ObservedObject var presenter: RootPresenter

    /// The flavour and accent (LOOK-2, LOOK-4), applied to everything below, sheets included.
    @ObservedObject var display: DisplayState

    private var theme: Theme { Theme(flavour: display.flavour, accent: display.accent) }

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
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .environment(\.theme, theme)
    }

    private var sheetShown: Binding<Bool> {
        Binding(get: { presenter.sheet != nil }, set: { if !$0 { presenter.sheet = nil } })
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { presenter.alert != nil }, set: { if !$0 { presenter.alert = nil } })
    }
}
