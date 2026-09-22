import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Decodes a NUL-terminated C buffer without the deprecated `String(cString:)`.
private func decodeCString(_ buffer: [CChar]) -> String {
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
}

// MARK: - Address classification

/// How an address may be reached. Only `publicRoutable` may be fetched: every
/// other class is a destination a local-first research tool must never open,
/// because it is either the user's own machine, a private network, or a cloud
/// metadata service.
public enum AddressClass: String, Equatable, Sendable {
    case publicRoutable = "public_routable"
    case loopback
    case privateNetwork = "private_network"
    case linkLocal = "link_local"
    case multicast
    case metadataService = "metadata_service"
    case reserved
}

/// A parsed IP literal plus its classification.
///
/// Parsing is deliberately stricter than "does this look like an address":
/// odd but valid IPv4 encodings (decimal, octal, hexadecimal, and the
/// shortened `inet_aton` forms) and IPv6 forms that embed an IPv4 address are
/// normalized first, so a blocked destination cannot be smuggled past the
/// policy by writing it differently. An unparseable value is not "maybe an
/// address"; it is a value the policy must refuse.
public struct IPAddress: Equatable, Sendable {
    public let text: String
    public let classification: AddressClass

    public init?(parsing raw: String) {
        let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }
        let bare = candidate.hasPrefix("[") && candidate.hasSuffix("]")
            ? String(candidate.dropFirst().dropLast())
            : candidate
        guard !bare.isEmpty else { return nil }

        // The lenient `inet_aton` forms are tried first: an address written as
        // `0177.0.0.1` or `0x7f.0.0.1` must be classified by its meaning, not
        // rejected as an unknown host name and resolved instead.
        if let bytes = Self.lenientIPv4Bytes(bare) ?? Self.ipv4Bytes(bare) {
            self.text = Self.ipv4Text(bytes)
            self.classification = Self.classifyIPv4(bytes)
            return
        }

        guard let bytes = Self.ipv6Bytes(bare) else { return nil }
        if let embedded = Self.embeddedIPv4(bytes) {
            self.text = Self.ipv4Text(embedded)
            self.classification = Self.classifyIPv4(embedded)
            return
        }
        self.text = Self.ipv6Text(bytes) ?? bare
        self.classification = Self.classifyIPv6(bytes)
    }

    public var isPublicRoutable: Bool { classification == .publicRoutable }

    // MARK: Literal parsing

    private static func ipv4Bytes(_ text: String) -> [UInt8]? {
        var address = in_addr()
        guard text.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else { return nil }
        let value = UInt32(bigEndian: address.s_addr)
        return [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
    }

    private static func ipv6Bytes(_ text: String) -> [UInt8]? {
        var address = in6_addr()
        guard text.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1 else { return nil }
        return withUnsafeBytes(of: &address) { Array($0) }
    }

    /// `inet_aton` forms that `inet_pton` rejects but that a resolver or a
    /// browser may still honour: `127.1`, `2130706433`, `0x7f.0.0.1`,
    /// `0177.0.0.1`.
    private static func lenientIPv4Bytes(_ text: String) -> [UInt8]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard (1...4).contains(parts.count) else { return nil }

        var values: [UInt64] = []
        for part in parts {
            guard let value = ipv4Component(part) else { return nil }
            values.append(value)
        }

        var bytes: [UInt8] = []
        for (index, value) in values.enumerated() {
            if index == values.count - 1 {
                let remaining = 4 - index
                guard value < (UInt64(1) << UInt64(8 * remaining)) else { return nil }
                for shift in stride(from: (remaining - 1) * 8, through: 0, by: -8) {
                    bytes.append(UInt8((value >> UInt64(shift)) & 0xff))
                }
            } else {
                guard value <= 255 else { return nil }
                bytes.append(UInt8(value))
            }
        }
        return bytes.count == 4 ? bytes : nil
    }

    private static func ipv4Component(_ part: String) -> UInt64? {
        guard !part.isEmpty else { return nil }
        let lowered = part.lowercased()
        if lowered.hasPrefix("0x") {
            return UInt64(lowered.dropFirst(2), radix: 16)
        }
        if lowered.count > 1, lowered.hasPrefix("0") {
            return UInt64(lowered.dropFirst(), radix: 8)
        }
        return UInt64(lowered)
    }

    private static func ipv4Text(_ bytes: [UInt8]) -> String {
        bytes.map(String.init).joined(separator: ".")
    }

    private static func ipv6Text(_ bytes: [UInt8]) -> String? {
        var address = in6_addr()
        withUnsafeMutableBytes(of: &address) { destination in
            bytes.withUnsafeBytes { source in
                destination.copyBytes(from: source)
            }
        }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else {
            return nil
        }
        return decodeCString(buffer)
    }

    /// IPv6 forms whose meaning is an embedded IPv4 address. Classifying the
    /// embedded address is what stops `::ffff:127.0.0.1` or `2002:7f00:1::`
    /// from looking publicly routable.
    private static func embeddedIPv4(_ b: [UInt8]) -> [UInt8]? {
        if b[0...9].allSatisfy({ $0 == 0 }), b[10] == 0xff, b[11] == 0xff {
            return Array(b[12...15])
        }
        if b[0] == 0x00, b[1] == 0x64, b[2] == 0xff, b[3] == 0x9b, b[4...11].allSatisfy({ $0 == 0 }) {
            return Array(b[12...15])
        }
        if b[0] == 0x20, b[1] == 0x02 {
            return Array(b[2...5])
        }
        return nil
    }

    // MARK: Classification

    private static func classifyIPv4(_ b: [UInt8]) -> AddressClass {
        let first = Int(b[0]), second = Int(b[1]), third = Int(b[2]), fourth = Int(b[3])

        if first == 169, second == 254 {
            return (third == 169 && fourth == 254) ? .metadataService : .linkLocal
        }
        switch (first, second) {
        case (127, _): return .loopback
        case (10, _): return .privateNetwork
        case (172, 16...31): return .privateNetwork
        case (192, 168): return .privateNetwork
        default: break
        }
        if first == 0 { return .reserved }
        if first == 100, (64...127).contains(second) { return .reserved }
        if first == 192, second == 0, third == 0 { return .reserved }
        if first == 192, second == 0, third == 2 { return .reserved }
        if first == 192, second == 88, third == 99 { return .reserved }
        if first == 198, (18...19).contains(second) { return .reserved }
        if first == 198, second == 51, third == 100 { return .reserved }
        if first == 203, second == 0, third == 113 { return .reserved }
        if (224...239).contains(first) { return .multicast }
        if first >= 240 { return .reserved }
        return .publicRoutable
    }

    private static func classifyIPv6(_ b: [UInt8]) -> AddressClass {
        if b.allSatisfy({ $0 == 0 }) { return .reserved }
        if b[0...14].allSatisfy({ $0 == 0 }), b[15] == 1 { return .loopback }
        if b[0] == 0xfd, b[1] == 0x00, b[2] == 0x0e, b[3] == 0xc2,
           b[4...13].allSatisfy({ $0 == 0 }), b[14] == 0x02, b[15] == 0x54 {
            return .metadataService
        }
        if (b[0] & 0xfe) == 0xfc { return .privateNetwork }
        if b[0] == 0xfe, (b[1] & 0xc0) == 0x80 { return .linkLocal }
        if b[0] == 0xff { return .multicast }
        if b[0] == 0x01, b[1] == 0x00, b[2...7].allSatisfy({ $0 == 0 }) { return .reserved }
        if b[0] == 0x20, b[1] == 0x01, b[2] == 0x0d, b[3] == 0xb8 { return .reserved }
        if b[0] == 0x20, b[1] == 0x01, b[2] == 0x00, b[3] == 0x00 { return .reserved }
        return .publicRoutable
    }
}

// MARK: - Name resolution boundary

/// The injectable name-resolution boundary. Tests always inject a stub, so no
/// test performs DNS.
public protocol HostResolver: Sendable {
    func addresses(for host: String) async throws -> [String]
}

/// A resolution attempt that produced no usable answer. Callers map it into
/// their own typed error family.
public struct HostResolutionFailure: Error, Equatable, LocalizedError, Sendable {
    public let host: String
    public let reason: String

    public init(host: String, reason: String) {
        self.host = host
        self.reason = reason
    }

    public var errorDescription: String? {
        "Could not resolve \(host): \(reason)."
    }
}

/// The only production resolver. It performs a blocking `getaddrinfo` on a
/// utility queue and returns numeric addresses; it never interprets them,
/// because classification belongs to `AcquisitionPolicy`.
public struct SystemHostResolver: HostResolver {
    public init() {}

    public func addresses(for host: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var head: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &head)
                guard status == 0, let first = head else {
                    let reason = String(cString: gai_strerror(status))
                    continuation.resume(throwing: HostResolutionFailure(host: host, reason: reason))
                    return
                }
                defer { freeaddrinfo(first) }

                var addresses: [String] = []
                var node: UnsafeMutablePointer<addrinfo>? = first
                while let current = node {
                    if let socketAddress = current.pointee.ai_addr {
                        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let resolved = getnameinfo(
                            socketAddress,
                            current.pointee.ai_addrlen,
                            &buffer,
                            socklen_t(buffer.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        )
                        if resolved == 0 {
                            let text = decodeCString(buffer)
                            if !addresses.contains(text) { addresses.append(text) }
                        }
                    }
                    node = current.pointee.ai_next
                }
                continuation.resume(returning: addresses)
            }
        }
    }
}

// MARK: - Typed acquisition failures

/// Every way a safe acquisition can refuse or fail.
///
/// Each case is distinct because the product must explain a refusal (and later
/// a stop reason) without collapsing "the destination is private", "the body
/// is too large", and "the request timed out" into one opaque failure.
public enum AcquisitionError: Error, Equatable, LocalizedError, Sendable {
    case invalidPolicy(reason: String)
    case invalidURL(reason: String, url: String)
    case blockedScheme(scheme: String)
    case credentialsInURL(host: String)
    case blockedPort(port: Int, host: String)
    case reservedHostName(host: String)
    case loopbackAddress(host: String, address: String)
    case privateAddress(host: String, address: String)
    case linkLocalAddress(host: String, address: String)
    case multicastAddress(host: String, address: String)
    case metadataService(host: String, address: String)
    case reservedAddress(host: String, address: String)
    case hostResolutionFailed(host: String, reason: String)
    case unresolvableHost(host: String)
    case invalidResolvedAddress(host: String, value: String)
    case transportFailure(reason: String)
    case timeout(url: URL)
    case httpStatus(code: Int, url: URL)
    case redirectWithoutLocation(url: URL)
    case redirectLoop(url: URL)
    case tooManyRedirects(limit: Int, url: URL)
    case missingContentType(url: URL)
    case unsupportedContentType(contentType: String, url: URL)
    case responseTooLarge(limit: Int, observed: Int)

    /// Stable machine-readable label, used by the frozen scenario fixture and
    /// by any later protocol mapping.
    public var kind: String {
        switch self {
        case .invalidPolicy: "invalid_policy"
        case .invalidURL: "invalid_url"
        case .blockedScheme: "blocked_scheme"
        case .credentialsInURL: "credentials_in_url"
        case .blockedPort: "blocked_port"
        case .reservedHostName: "reserved_host_name"
        case .loopbackAddress: "loopback_address"
        case .privateAddress: "private_address"
        case .linkLocalAddress: "link_local_address"
        case .multicastAddress: "multicast_address"
        case .metadataService: "metadata_service"
        case .reservedAddress: "reserved_address"
        case .hostResolutionFailed: "host_resolution_failed"
        case .unresolvableHost: "unresolvable_host"
        case .invalidResolvedAddress: "invalid_resolved_address"
        case .transportFailure: "transport_failure"
        case .timeout: "timeout"
        case .httpStatus: "http_status"
        case .redirectWithoutLocation: "redirect_without_location"
        case .redirectLoop: "redirect_loop"
        case .tooManyRedirects: "too_many_redirects"
        case .missingContentType: "missing_content_type"
        case .unsupportedContentType: "unsupported_content_type"
        case .responseTooLarge: "response_too_large"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .invalidPolicy(reason):
            "Invalid acquisition policy: \(reason)."
        case let .invalidURL(reason, url):
            "Invalid acquisition URL (\(reason)): \(url)."
        case let .blockedScheme(scheme):
            "Refused to fetch the \(scheme) scheme; only http and https are allowed."
        case let .credentialsInURL(host):
            "Refused to send embedded credentials to \(host)."
        case let .blockedPort(port, host):
            "Refused to fetch \(host) on port \(port)."
        case let .reservedHostName(host):
            "Refused to fetch the reserved host name \(host)."
        case let .loopbackAddress(host, address):
            "Refused to fetch \(host); \(address) is a loopback address."
        case let .privateAddress(host, address):
            "Refused to fetch \(host); \(address) is a private address."
        case let .linkLocalAddress(host, address):
            "Refused to fetch \(host); \(address) is a link-local address."
        case let .multicastAddress(host, address):
            "Refused to fetch \(host); \(address) is a multicast address."
        case let .metadataService(host, address):
            "Refused to fetch \(host); \(address) is a cloud metadata service."
        case let .reservedAddress(host, address):
            "Refused to fetch \(host); \(address) is in a reserved address range."
        case let .hostResolutionFailed(host, reason):
            "Could not resolve \(host): \(reason)."
        case let .unresolvableHost(host):
            "\(host) resolved to no addresses."
        case let .invalidResolvedAddress(host, value):
            "\(host) resolved to an unparseable address: \(value)."
        case let .transportFailure(reason):
            "Acquisition transport failed: \(reason)."
        case let .timeout(url):
            "Acquisition timed out for \(url.absoluteString)."
        case let .httpStatus(code, url):
            "Acquisition received HTTP \(code) for \(url.absoluteString)."
        case let .redirectWithoutLocation(url):
            "Redirect from \(url.absoluteString) carried no usable Location."
        case let .redirectLoop(url):
            "Redirect loop revisited \(url.absoluteString)."
        case let .tooManyRedirects(limit, url):
            "More than \(limit) redirects from \(url.absoluteString)."
        case let .missingContentType(url):
            "Response from \(url.absoluteString) declared no content type."
        case let .unsupportedContentType(contentType, url):
            "Response from \(url.absoluteString) had unsupported content type \(contentType)."
        case let .responseTooLarge(limit, observed):
            "Response of \(observed) bytes exceeds the \(limit)-byte ceiling."
        }
    }
}

// MARK: - Policy

/// The outbound request policy. Nothing may be fetched, and no redirect hop may
/// be followed, until this has approved the exact URL that will be contacted.
public struct AcquisitionPolicy: Equatable, Sendable {
    public static let defaultAllowedSchemes: Set<String> = ["http", "https"]
    public static let defaultAllowedPorts: Set<Int> = [80, 443, 8080, 8443]
    public static let defaultAllowedContentTypes: Set<String> = [
        "text/html",
        "application/xhtml+xml",
        "text/plain",
        "application/pdf",
    ]
    /// Reserved and internal-only name spaces (RFC 2606, RFC 6761, RFC 6762,
    /// and ICANN internal-use names). A public research tool has no legitimate
    /// reason to resolve them.
    public static let defaultReservedHostSuffixes: [String] = [
        ".localhost",
        ".local",
        ".internal",
        ".invalid",
        ".test",
        ".example",
        ".home.arpa",
    ]

    public let allowedSchemes: Set<String>
    public let allowedPorts: Set<Int>
    public let allowedContentTypes: Set<String>
    public let reservedHostSuffixes: [String]
    public let maxRedirects: Int
    public let maxBytes: Int
    public let timeoutSeconds: Double

    /// The shipped policy. It is built through the unchecked initializer
    /// because a static constant cannot throw; the values are the same ones the
    /// checked initializer validates by default.
    public static let `default` = AcquisitionPolicy(
        uncheckedSchemes: defaultAllowedSchemes,
        ports: defaultAllowedPorts,
        contentTypes: defaultAllowedContentTypes,
        suffixes: defaultReservedHostSuffixes,
        maxRedirects: 5,
        maxBytes: 5_000_000,
        timeoutSeconds: 15
    )

    private init(
        uncheckedSchemes: Set<String>,
        ports: Set<Int>,
        contentTypes: Set<String>,
        suffixes: [String],
        maxRedirects: Int,
        maxBytes: Int,
        timeoutSeconds: Double
    ) {
        self.allowedSchemes = Set(uncheckedSchemes.map { $0.lowercased() })
        self.allowedPorts = ports
        self.allowedContentTypes = Set(contentTypes.map { $0.lowercased() })
        self.reservedHostSuffixes = suffixes.map { $0.lowercased() }
        self.maxRedirects = maxRedirects
        self.maxBytes = maxBytes
        self.timeoutSeconds = timeoutSeconds
    }

    public init(
        allowedSchemes: Set<String> = AcquisitionPolicy.defaultAllowedSchemes,
        allowedPorts: Set<Int> = AcquisitionPolicy.defaultAllowedPorts,
        allowedContentTypes: Set<String> = AcquisitionPolicy.defaultAllowedContentTypes,
        reservedHostSuffixes: [String] = AcquisitionPolicy.defaultReservedHostSuffixes,
        maxRedirects: Int = 5,
        maxBytes: Int = 5_000_000,
        timeoutSeconds: Double = 15
    ) throws {
        guard !allowedSchemes.isEmpty else {
            throw AcquisitionError.invalidPolicy(reason: "at least one scheme must be allowed")
        }
        guard !allowedPorts.isEmpty else {
            throw AcquisitionError.invalidPolicy(reason: "at least one port must be allowed")
        }
        guard !allowedContentTypes.isEmpty else {
            throw AcquisitionError.invalidPolicy(reason: "at least one content type must be allowed")
        }
        guard maxRedirects >= 0 else {
            throw AcquisitionError.invalidPolicy(reason: "maxRedirects must not be negative")
        }
        guard maxBytes >= 1 else {
            throw AcquisitionError.invalidPolicy(reason: "maxBytes must be at least 1")
        }
        guard timeoutSeconds > 0 else {
            throw AcquisitionError.invalidPolicy(reason: "timeoutSeconds must be positive")
        }

        self.init(
            uncheckedSchemes: allowedSchemes,
            ports: allowedPorts,
            contentTypes: allowedContentTypes,
            suffixes: reservedHostSuffixes,
            maxRedirects: maxRedirects,
            maxBytes: maxBytes,
            timeoutSeconds: timeoutSeconds
        )
    }

    /// Approves one exact URL, including its resolved addresses, or refuses it
    /// with a typed reason. Called for the original request and again for every
    /// redirect hop, so a permitted origin cannot redirect into a blocked one.
    public func validate(_ url: URL, resolver: any HostResolver) async throws {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            throw AcquisitionError.invalidURL(reason: "missing scheme", url: url.absoluteString)
        }
        guard allowedSchemes.contains(scheme) else {
            throw AcquisitionError.blockedScheme(scheme: scheme)
        }
        guard url.user == nil, url.password == nil else {
            let host = url.host ?? url.absoluteString
            throw AcquisitionError.credentialsInURL(host: host)
        }
        guard let rawHost = url.host, !rawHost.isEmpty else {
            throw AcquisitionError.invalidURL(reason: "missing host", url: url.absoluteString)
        }

        let host = Self.normalizedHost(rawHost)
        guard !host.isEmpty else {
            throw AcquisitionError.invalidURL(reason: "empty host", url: url.absoluteString)
        }
        guard host != "localhost", !reservedHostSuffixes.contains(where: { host.hasSuffix($0) }) else {
            throw AcquisitionError.reservedHostName(host: host)
        }

        let port = url.port ?? Self.defaultPort(for: scheme)
        guard let port, allowedPorts.contains(port) else {
            throw AcquisitionError.blockedPort(port: port ?? -1, host: host)
        }

        if let literal = IPAddress(parsing: host) {
            try requirePublic(literal, host: host)
            return
        }

        let resolved: [String]
        do {
            resolved = try await resolver.addresses(for: host)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as HostResolutionFailure {
            throw AcquisitionError.hostResolutionFailed(host: host, reason: failure.reason)
        } catch {
            throw AcquisitionError.hostResolutionFailed(host: host, reason: String(describing: error))
        }

        guard !resolved.isEmpty else {
            throw AcquisitionError.unresolvableHost(host: host)
        }
        // Every answer must be public: a name that resolves to one public and
        // one private address is still a private destination.
        for value in resolved {
            guard let address = IPAddress(parsing: value) else {
                throw AcquisitionError.invalidResolvedAddress(host: host, value: value)
            }
            try requirePublic(address, host: host)
        }
    }

    private func requirePublic(_ address: IPAddress, host: String) throws {
        switch address.classification {
        case .publicRoutable:
            return
        case .loopback:
            throw AcquisitionError.loopbackAddress(host: host, address: address.text)
        case .privateNetwork:
            throw AcquisitionError.privateAddress(host: host, address: address.text)
        case .linkLocal:
            throw AcquisitionError.linkLocalAddress(host: host, address: address.text)
        case .multicast:
            throw AcquisitionError.multicastAddress(host: host, address: address.text)
        case .metadataService:
            throw AcquisitionError.metadataService(host: host, address: address.text)
        case .reserved:
            throw AcquisitionError.reservedAddress(host: host, address: address.text)
        }
    }

    /// Normalizes a host the way a resolver would treat it: case-insensitive,
    /// with the optional trailing root dot removed.
    static func normalizedHost(_ raw: String) -> String {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }
        while host.hasSuffix(".") {
            host = String(host.dropLast())
        }
        return host
    }

    static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "http": 80
        case "https": 443
        default: nil
        }
    }
}
