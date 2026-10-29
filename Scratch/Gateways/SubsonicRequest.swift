import Foundation

enum SubsonicRequestError: Error, Equatable {
    case unbuildableURL
}

/// One call to the OpenSubsonic API (PROD-3). Every request to the server is built here, signed
/// with token authentication and asking for JSON (SRV-4).
struct SubsonicRequest: Equatable {
    static let apiVersion = "1.16.1"
    static let clientName = "Scratch"

    /// Query values may hold anything but these, which servers would read as structure: `+` in
    /// particular decodes as a space, so a username with `+` would never authenticate.
    private static let queryValueAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&=;"))

    var method: String
    var parameters: [URLQueryItem] = []

    /// A track's audio at the given quality (TRANS-4). `estimateContentLength` gives AVPlayer a
    /// length for a transcoded stream, which it needs for the duration and seeking.
    static func stream(trackID: String, quality: StreamQuality) -> SubsonicRequest {
        var parameters = [
            URLQueryItem(name: "id", value: trackID),
            URLQueryItem(name: "format", value: quality.format.rawValue),
        ]
        if quality.format != .original, let maxBitRate = quality.maxBitRate {
            parameters.append(URLQueryItem(name: "maxBitRate", value: String(maxBitRate)))
        }
        parameters.append(URLQueryItem(name: "estimateContentLength", value: "true"))
        return SubsonicRequest(method: "stream", parameters: parameters)
    }

    func url(baseURL: URL, credentials: SubsonicCredentials) throws(SubsonicRequestError) -> URL {
        let endpoint = baseURL.appending(path: "rest").appending(path: method)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw .unbuildableURL
        }
        let items = [
            URLQueryItem(name: "u", value: credentials.username),
            URLQueryItem(name: "t", value: credentials.token),
            URLQueryItem(name: "s", value: credentials.salt),
            URLQueryItem(name: "v", value: Self.apiVersion),
            URLQueryItem(name: "c", value: Self.clientName),
            URLQueryItem(name: "f", value: "json"),
        ] + parameters
        components.percentEncodedQueryItems = try items.map { item throws(SubsonicRequestError) in
            guard let name = item.name.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed),
                  let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed)
            else { throw .unbuildableURL }
            return URLQueryItem(name: name, value: value)
        }
        guard let url = components.url else { throw .unbuildableURL }
        return url
    }
}
