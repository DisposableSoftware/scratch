/// How a request to the server failed.
enum ServerError: Error, Equatable {
    /// No answer: no network, wrong host or port, TLS failure, timeout.
    case unreachable
    /// Subsonic error 40.
    case wrongCredentials
    /// Something answered, but not with a Subsonic response.
    case notSubsonic
    /// Any other Subsonic error, with the server's own message.
    case failed(code: Int, message: String)
}

extension ServerError {
    /// Subsonic errors 40 (wrong username or password) and 41 (token authentication not
    /// supported): the saved credentials won't work again (SRV-6).
    var rejectsCredentials: Bool {
        switch self {
        case .wrongCredentials: true
        case .failed(let code, _): code == 41
        default: false
        }
    }
}

/// Why connecting to a server failed (SRV-3).
enum ConnectError: Error, Equatable {
    case invalidAddress(ServerAddressError)
    case server(ServerError)
    case couldNotSave
}

/// Saving or deleting the stored server failed.
enum StorageError: Error, Equatable {
    case keychain(status: Int32)
}
