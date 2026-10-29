/// Decides which screen comes next (ARCH-11). A pure function of the step, the flow data and the
/// session; it never navigates.
struct AppRouter {
    let sessionState: SessionState

    func nextStep(from current: AppStep, with data: AppFlowData) -> AppStep? {
        let signedIn = sessionState.account != nil
        switch current {
        case .launch:
            return signedIn ? .library : .setup
        case .setup:
            return signedIn ? .library : nil
        case .library:
            return signedIn ? nil : .setup
        }
    }
}
