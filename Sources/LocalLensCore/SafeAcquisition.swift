import Foundation

// MARK: - Result

/// A body that the policy approved, together with the path taken to reach it.
///
/// `requestedURL` and `finalURL` are both kept because a redirect must remain
/// visible to the caller: silently reporting only the final URL would hide that
/// the request left the origin the user asked for.
public struct AcquisitionResult: Equatable, Sendable {
    public let requestedURL: URL
    public let finalURL: URL
    public let statusCode: Int
    public let contentType: String
    public let body: Data
    /// Redirect targets in the order they were followed.
    public let redirects: [URL]

    public init(
        requestedURL: URL,
        finalURL: URL,
        statusCode: Int,
        contentType: String,
        body: Data,
        redirects: [URL]
    ) {
        self.requestedURL = requestedURL
        self.finalURL = finalURL
        self.statusCode = statusCode
        self.contentType = contentType
        self.body = body
        self.redirects = redirects
    }

    public var byteCount: Int { body.count }
}

// MARK: - Policy-checked fetch

/// The only sanctioned way to retrieve a document.
///
/// It is a free function namespace rather than a type with stored state because
/// every dependency (transport, resolver, policy) is injected per call, which
/// keeps the boundary testable without a network or a DNS lookup.
public enum SafeAcquisition {
    /// Fetches `url`, refusing any destination the policy does not approve.
    ///
    /// Redirects are followed manually instead of by the transport, so every
    /// hop is validated before a request is issued; a permitted origin cannot
    /// bounce the request into a private address.
    public static func fetch(
        _ url: URL,
        transport: any SearchTransport,
        resolver: any HostResolver,
        policy: AcquisitionPolicy = .default
    ) async throws -> AcquisitionResult {
        try await policy.validate(url, resolver: resolver)

        var current = url
        var redirects: [URL] = []
        var visited: Set<String> = [Self.canonicalKey(url)]

        while true {
            let request = SearchRequest(
                url: current,
                method: "GET",
                headers: ["Accept": policy.allowedContentTypes.sorted().joined(separator: ", ")],
                timeoutSeconds: policy.timeoutSeconds
            )

            let response: SearchResponse
            do {
                response = try await transport.send(request)
            } catch is CancellationError {
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .timedOut {
                throw AcquisitionError.timeout(url: current)
            } catch let failure as TransportFailure {
                if Self.indicatesTimeout(failure.reason) {
                    throw AcquisitionError.timeout(url: current)
                }
                throw AcquisitionError.transportFailure(reason: failure.reason)
            } catch {
                throw AcquisitionError.transportFailure(reason: String(describing: error))
            }

            switch response.statusCode {
            case 200..<300:
                let contentType = try Self.requireAllowedContentType(response, url: current, policy: policy)
                guard response.body.count <= policy.maxBytes else {
                    throw AcquisitionError.responseTooLarge(
                        limit: policy.maxBytes,
                        observed: response.body.count
                    )
                }
                return AcquisitionResult(
                    requestedURL: url,
                    finalURL: current,
                    statusCode: response.statusCode,
                    contentType: contentType,
                    body: response.body,
                    redirects: redirects
                )

            case 300..<400:
                guard redirects.count < policy.maxRedirects else {
                    throw AcquisitionError.tooManyRedirects(limit: policy.maxRedirects, url: current)
                }
                guard
                    let location = Self.header(response.headers, "location"),
                    let target = URL(string: location, relativeTo: current)?.absoluteURL
                else {
                    throw AcquisitionError.redirectWithoutLocation(url: current)
                }
                let key = Self.canonicalKey(target)
                guard !visited.contains(key) else {
                    throw AcquisitionError.redirectLoop(url: target)
                }
                // The hop is approved before it is requested, exactly like the
                // original URL.
                try await policy.validate(target, resolver: resolver)
                visited.insert(key)
                redirects.append(target)
                current = target

            default:
                throw AcquisitionError.httpStatus(code: response.statusCode, url: current)
            }
        }
    }

    // MARK: Helpers

    private static func requireAllowedContentType(
        _ response: SearchResponse,
        url: URL,
        policy: AcquisitionPolicy
    ) throws -> String {
        guard let raw = header(response.headers, "content-type") else {
            throw AcquisitionError.missingContentType(url: url)
        }
        let mediaType = raw
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        guard !mediaType.isEmpty else {
            throw AcquisitionError.missingContentType(url: url)
        }
        guard policy.allowedContentTypes.contains(mediaType) else {
            throw AcquisitionError.unsupportedContentType(contentType: mediaType, url: url)
        }
        return mediaType
    }

    static func header(_ headers: [String: String], _ name: String) -> String? {
        let wanted = name.lowercased()
        for (field, value) in headers where field.lowercased() == wanted {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    /// A redirect loop must be detected on the same notion of identity a
    /// resolver uses, so the key drops the default port, the case of the host,
    /// a trailing root dot, and an empty path.
    static func canonicalKey(_ url: URL) -> String {
        let scheme = (url.scheme ?? "").lowercased()
        let host = AcquisitionPolicy.normalizedHost(url.host ?? "")
        let port = url.port ?? AcquisitionPolicy.defaultPort(for: scheme)
        let defaultPort = AcquisitionPolicy.defaultPort(for: scheme)
        let portPart = (port == nil || port == defaultPort) ? "" : ":\(port!)"
        // `URL.path` drops a trailing slash, so `/a/` and `/a` collapse to the
        // same key and a server's legitimate redirect from `/a` to `/a/` is
        // misread as a loop (observed on developer.apple.com, swift.org, and a
        // personal blog). The percent-encoded path from `URLComponents` keeps
        // the trailing slash, so only a genuinely repeated URL is a loop;
        // `maxRedirects` still bounds a pathological ping-pong.
        let encodedPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath
        let path = (encodedPath?.isEmpty ?? true) ? "/" : encodedPath!
        let query = url.query.map { "?\($0)" } ?? ""
        return "\(scheme)://\(host)\(portPart)\(path)\(query)"
    }

    /// `URLSessionSearchTransport` collapses `URLError` into a reason string,
    /// so the wrapped form has to stay recognisable as a timeout.
    static func indicatesTimeout(_ reason: String) -> Bool {
        let lowered = reason.lowercased()
        return lowered.contains("timedout") || lowered.contains("-1001") || lowered.contains("timeout")
    }
}
