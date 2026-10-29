/// The app's screens, as steps of one flow.
enum AppStep: Equatable {
    case launch
    case setup
    case library
}

/// What the caller knows when it asks for the next step. Nothing yet: the session decides
/// everything so far. Re-authentication (SRV-6) will add to it.
struct AppFlowData: Equatable {}
