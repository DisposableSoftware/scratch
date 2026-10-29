import Foundation

enum ServerAddressError: Error, Equatable {
    case empty
    case unsupportedScheme(String)
    case missingHost
    case invalid
}

/// What the user typed as the server, turned into its base URL (SRV-2).
enum ServerAddress {
    static func parse(_ text: String) throws(ServerAddressError) -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }

        let withScheme: String
        if trimmed.firstMatch(of: /^[A-Za-z][A-Za-z0-9+.\-]*:\/\//) != nil {
            withScheme = trimmed
        } else if trimmed.firstMatch(of: /^[A-Za-z][A-Za-z0-9+.\-]*:(?!\d)/) != nil
                    || trimmed.firstMatch(of: /^(?i)https?\//) != nil {
            // A mistyped scheme ("http:/host", "https//host") would otherwise become the host.
            throw .invalid
        } else {
            withScheme = "https://" + trimmed
        }
        guard var components = URLComponents(string: withScheme) else { throw .invalid }

        let scheme = components.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { throw .unsupportedScheme(scheme) }
        guard let host = components.host, !host.isEmpty else { throw .missingHost }
        guard components.query == nil, components.fragment == nil, components.user == nil else { throw .invalid }
        if let port = components.port, !(1...65535).contains(port) { throw .invalid }

        components.scheme = scheme
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw .invalid }
        return url
    }
}
