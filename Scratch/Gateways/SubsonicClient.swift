import Foundation

/// Sends a SubsonicRequest and reads the `subsonic-response` envelope, turning every failure into
/// a ServerError. Shared by the Gateways that talk to the server.
struct SubsonicClient {
    let session: NetworkSession

    func send<Payload: Decodable>(
        _ request: SubsonicRequest,
        to server: SavedServer,
        as payload: Payload.Type
    ) async throws(ServerError) -> Payload {
        try await send(request, baseURL: server.account.baseURL, credentials: server.credentials, as: payload)
    }

    func send<Payload: Decodable>(
        _ request: SubsonicRequest,
        baseURL: URL,
        credentials: SubsonicCredentials,
        as payload: Payload.Type
    ) async throws(ServerError) -> Payload {
        let url: URL

        do {
            url = try request.url(baseURL: baseURL, credentials: credentials)
        } catch {
            throw .notSubsonic
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.send(URLRequest(url: url))
        } catch {
            throw .unreachable
        }

        let decoder = JSONDecoder()

        // Read the status first: a failed response carries no payload to decode.
        guard let status = try? decoder.decode(Envelope<Status>.self, from: data).response else {
            // A proxy's error page while the server is down means the server can't be reached.
            if let http = response as? HTTPURLResponse, (502...504).contains(http.statusCode) {
                throw .unreachable
            }

            throw .notSubsonic
        }

        if let error = status.error {
            throw error.code == 40 ? .wrongCredentials : .failed(code: error.code, message: error.message ?? "")
        }

        guard status.status == "ok" else { throw .failed(code: 0, message: "") }

        do {
            return try decoder.decode(Envelope<Payload>.self, from: data).response
        } catch {
            throw .notSubsonic
        }
    }
}

extension SubsonicClient {
    /// For calls that answer with a file, like `getCoverArt`. A failure comes back as a JSON
    /// envelope instead, and maps to the same errors as `send`.
    func sendForImage(_ request: SubsonicRequest, to server: SavedServer) async throws(ServerError) -> Data {
        let url: URL

        do {
            url = try request.url(baseURL: server.account.baseURL, credentials: server.credentials)
        } catch {
            throw .notSubsonic
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.send(URLRequest(url: url))
        } catch {
            throw .unreachable
        }

        if let status = try? JSONDecoder().decode(Envelope<Status>.self, from: data).response, let error = status.error {
            throw error.code == 40 ? .wrongCredentials : .failed(code: error.code, message: error.message ?? "")
        }

        guard let http = response as? HTTPURLResponse else { throw .notSubsonic }

        if (502...504).contains(http.statusCode) { throw .unreachable }

        // Any 200 that isn't a Subsonic error is the file, whatever its Content-Type says (some
        // servers send none, or application/octet-stream). Bytes that aren't an image just fail
        // to decode, and the row keeps its placeholder.
        guard http.statusCode == 200, !data.isEmpty else { throw .notSubsonic }

        return data
    }
}

/// The empty payload, for calls like `ping` that only report status.
struct NoPayload: Decodable {}

private struct Envelope<Response: Decodable>: Decodable {
    let response: Response

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }
}

private struct Status: Decodable {
    struct APIError: Decodable {
        let code: Int
        let message: String?
    }

    let status: String
    let error: APIError?
}
