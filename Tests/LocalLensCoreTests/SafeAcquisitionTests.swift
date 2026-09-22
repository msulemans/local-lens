import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The scenario table lives in `Fixtures/acquisition/safe-fetch-scenarios.json`
/// so that the blocked-destination matrix is reviewable as data rather than as
/// scattered assertions. It is hand-authored, synthetic, and contains no live
/// host, DNS answer, or captured response.
private struct ScenarioFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let note: String
    }

    struct PolicySpec: Decodable, Sendable {
        let allowed_schemes: [String]
        let allowed_ports: [Int]
        let allowed_content_types: [String]
        let reserved_host_suffixes: [String]
        let max_redirects: Int
        let max_bytes: Int
        let timeout_seconds: Double
    }

    struct BlockedDestination: Decodable, Sendable {
        let id: String
        let url: String
        let expected_outcome: String
        let why: String
    }

    struct ResolutionCase: Decodable, Sendable {
        let id: String
        let url: String
        let resolved_addresses: [String: [String]]?
        let resolution_failure: String?
        let expected_outcome: String
        let why: String
    }

    struct Response: Decodable, Sendable {
        let status: Int
        let headers: [String: String]
        let body: String?
    }

    struct Expected: Decodable, Sendable {
        let status_code: Int
        let content_type: String
        let final_url: String
        let redirect_count: Int
    }

    struct PolicyOverride: Decodable, Sendable {
        let max_redirects: Int?
        let max_bytes: Int?
    }

    struct FetchScenario: Decodable, Sendable {
        let id: String
        let requested_url: String
        let resolved_addresses: [String: [String]]?
        let policy_override: PolicyOverride?
        let responses: [Response]?
        let transport_error: String?
        let expected_outcome: String
        let expected: Expected?
        let why: String
    }

    let _fixture: Meta
    let policy: PolicySpec
    let blocked_destinations: [BlockedDestination]
    let resolution_cases: [ResolutionCase]
    let fetch_scenarios: [FetchScenario]
}

// MARK: - Stubs

/// The only resolver a test may use. An unlisted host throws instead of
/// answering, so a test that unexpectedly resolves something fails loudly
/// rather than silently reaching a name server.
private actor StubHostResolver: HostResolver {
    private let answers: [String: [String]]
    private let failure: String?
    private(set) var asked: [String] = []

    init(answers: [String: [String]] = [:], failure: String? = nil) {
        self.answers = answers
        self.failure = failure
    }

    func addresses(for host: String) async throws -> [String] {
        asked.append(host)
        if let failure {
            throw HostResolutionFailure(host: host, reason: failure)
        }
        guard let answer = answers[host] else {
            throw HostResolutionFailure(host: host, reason: "stub resolver has no answer for \(host)")
        }
        return answer
    }
}

/// The only HTTP implementation a test may use: a scripted list of responses.
private actor ScriptedSearchTransport: SearchTransport {
    private var pending: [ScenarioFixture.Response]
    private let transportError: String?
    private(set) var requests: [SearchRequest] = []

    init(responses: [ScenarioFixture.Response], transportError: String? = nil) {
        self.pending = responses
        self.transportError = transportError
    }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        requests.append(request)
        if let transportError {
            switch transportError {
            case "timeout_urlerror":
                throw URLError(.timedOut)
            case "timeout_wrapped":
                throw TransportFailure("URLError timedOut (-1001)")
            case "cancellation":
                throw CancellationError()
            default:
                throw TransportFailure(transportError)
            }
        }
        guard !pending.isEmpty else {
            throw TransportFailure("scripted transport exhausted before the test expected a response")
        }
        let response = pending.removeFirst()
        return SearchResponse(
            statusCode: response.status,
            body: Data((response.body ?? "").utf8),
            headers: response.headers
        )
    }
}

// MARK: - Tests

final class SafeAcquisitionTests: XCTestCase {

    private static let fixture: ScenarioFixture = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/acquisition/safe-fetch-scenarios.json")
        do {
            return try JSONDecoder().decode(ScenarioFixture.self, from: Data(contentsOf: url))
        } catch {
            fatalError("the frozen acquisition scenario fixture must decode: \(error)")
        }
    }()

    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func policy(_ override: ScenarioFixture.PolicyOverride? = nil) throws -> AcquisitionPolicy {
        let spec = Self.fixture.policy
        return try AcquisitionPolicy(
            allowedSchemes: Set(spec.allowed_schemes),
            allowedPorts: Set(spec.allowed_ports),
            allowedContentTypes: Set(spec.allowed_content_types),
            reservedHostSuffixes: spec.reserved_host_suffixes,
            maxRedirects: override?.max_redirects ?? spec.max_redirects,
            maxBytes: override?.max_bytes ?? spec.max_bytes,
            timeoutSeconds: spec.timeout_seconds
        )
    }

    private func url(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(URL(string: text), "scenario URL must parse: \(text)", file: file, line: line)
    }

    // MARK: Fixture integrity

    func testFrozenFixtureIsSyntheticAndCannotReachTheInternet() {
        let meta = Self.fixture._fixture
        XCTAssertTrue(meta.synthetic)
        XCTAssertEqual(meta.license, "redistributable")
        XCTAssertFalse(meta.note.isEmpty)

        var hosts: [String] = []
        var addresses: [String] = []
        for destination in Self.fixture.blocked_destinations {
            if let host = URL(string: destination.url)?.host { hosts.append(host) }
        }
        for scenario in Self.fixture.fetch_scenarios {
            if let host = URL(string: scenario.requested_url)?.host { hosts.append(host) }
            for (host, answers) in scenario.resolved_addresses ?? [:] {
                hosts.append(host)
                addresses.append(contentsOf: answers)
            }
            for response in scenario.responses ?? [] {
                for (field, value) in response.headers where field.lowercased() == "location" {
                    if let host = URL(string: value, relativeTo: URL(string: scenario.requested_url))?.host {
                        hosts.append(host)
                    }
                }
            }
        }
        for scenario in Self.fixture.resolution_cases {
            for (host, answers) in scenario.resolved_addresses ?? [:] {
                hosts.append(host)
                addresses.append(contentsOf: answers)
            }
        }

        XCTAssertFalse(hosts.isEmpty)
        // Reserved documentation names (RFC 2606/6761), internal-use names
        // (RFC 6762/8375), and the literal `localhost` are the only names a
        // fixture may use, because none of them can reach a real service.
        let reservedSuffixes = [".example.com", ".invalid", ".local", ".internal", ".home.arpa", ".test"]
        for host in hosts {
            if IPAddress(parsing: host) != nil { continue }
            XCTAssertTrue(
                host == "example.com" || host == "localhost"
                    || reservedSuffixes.contains(where: { host.hasSuffix($0) }),
                "fixture host \(host) is not a reserved documentation or internal-use name"
            )
        }

        // Answers the stub invents must be addresses; exactly one fixture case
        // deliberately returns an unparseable value, to prove the policy
        // refuses it instead of assuming it is public.
        XCTAssertFalse(addresses.isEmpty)
        let unparseable = addresses.filter { IPAddress(parsing: $0) == nil }
        XCTAssertEqual(unparseable, ["not-an-address"], "only the frozen unparseable-answer case may be unparseable")
    }

    func testFrozenPolicyMatchesTheShippedDefault() throws {
        let spec = Self.fixture.policy
        let shipped = AcquisitionPolicy.default
        XCTAssertEqual(Set(spec.allowed_schemes), shipped.allowedSchemes)
        XCTAssertEqual(Set(spec.allowed_ports), shipped.allowedPorts)
        XCTAssertEqual(Set(spec.allowed_content_types), shipped.allowedContentTypes)
        XCTAssertEqual(spec.reserved_host_suffixes, shipped.reservedHostSuffixes)
        XCTAssertEqual(spec.max_redirects, shipped.maxRedirects)
        XCTAssertEqual(spec.max_bytes, shipped.maxBytes)
        XCTAssertEqual(spec.timeout_seconds, shipped.timeoutSeconds)
    }

    // MARK: Blocked destinations

    func testBlockedDestinationsAreRefusedWithTheFrozenKindAndNoResolution() async throws {
        for destination in Self.fixture.blocked_destinations {
            let resolver = StubHostResolver()
            do {
                try await policy().validate(try url(destination.url), resolver: resolver)
                XCTFail("\(destination.id): expected a refusal (\(destination.expected_outcome))")
            } catch let error as AcquisitionError {
                XCTAssertEqual(error.kind, destination.expected_outcome, "\(destination.id): \(error)")
            } catch {
                XCTFail("\(destination.id): expected an AcquisitionError, got \(error)")
            }
            let asked = await resolver.asked
            XCTAssertTrue(
                asked.isEmpty,
                "\(destination.id): a refused literal or reserved name must not be resolved, asked \(asked)"
            )
        }
    }

    func testResolutionCasesMatchTheFrozenKind() async throws {
        for scenario in Self.fixture.resolution_cases {
            let resolver = StubHostResolver(
                answers: scenario.resolved_addresses ?? [:],
                failure: scenario.resolution_failure
            )
            let url = try url(scenario.url)
            if scenario.expected_outcome == "accepted" {
                do {
                    try await policy().validate(url, resolver: resolver)
                } catch {
                    XCTFail("\(scenario.id): expected acceptance, got \(error)")
                }
                continue
            }
            do {
                try await policy().validate(url, resolver: resolver)
                XCTFail("\(scenario.id): expected \(scenario.expected_outcome)")
            } catch let error as AcquisitionError {
                XCTAssertEqual(error.kind, scenario.expected_outcome, "\(scenario.id): \(error)")
            }
        }
    }

    // MARK: Fetch scenarios

    func testFetchScenariosMatchTheFrozenOutcome() async throws {
        for scenario in Self.fixture.fetch_scenarios {
            let transport = ScriptedSearchTransport(
                responses: scenario.responses ?? [],
                transportError: scenario.transport_error
            )
            let resolver = StubHostResolver(answers: scenario.resolved_addresses ?? [:])
            let requested = try url(scenario.requested_url)

            if scenario.expected_outcome == "cancelled" {
                do {
                    _ = try await SafeAcquisition.fetch(
                        requested,
                        transport: transport,
                        resolver: resolver,
                        policy: try policy(scenario.policy_override)
                    )
                    XCTFail("\(scenario.id): expected CancellationError")
                } catch is CancellationError {
                    // expected
                }
                continue
            }

            if scenario.expected_outcome == "accepted" {
                let result = try await SafeAcquisition.fetch(
                    requested,
                    transport: transport,
                    resolver: resolver,
                    policy: try policy(scenario.policy_override)
                )
                let expected = try XCTUnwrap(scenario.expected, "\(scenario.id): accepted scenarios must declare `expected`")
                XCTAssertEqual(result.statusCode, expected.status_code, scenario.id)
                XCTAssertEqual(result.contentType, expected.content_type, scenario.id)
                XCTAssertEqual(result.finalURL.absoluteString, expected.final_url, scenario.id)
                XCTAssertEqual(result.redirects.count, expected.redirect_count, scenario.id)
                XCTAssertEqual(result.requestedURL, requested, scenario.id)
                XCTAssertFalse(result.body.isEmpty, "\(scenario.id): a kept body must carry its bytes")
                XCTAssertEqual(result.byteCount, result.body.count, scenario.id)
                continue
            }

            do {
                _ = try await SafeAcquisition.fetch(
                    requested,
                    transport: transport,
                    resolver: resolver,
                    policy: try policy(scenario.policy_override)
                )
                XCTFail("\(scenario.id): expected \(scenario.expected_outcome)")
            } catch let error as AcquisitionError {
                XCTAssertEqual(error.kind, scenario.expected_outcome, "\(scenario.id): \(error)")
            }
        }
    }

    func testRefusedRequestIsNeverSent() async throws {
        let scenario = try XCTUnwrap(
            Self.fixture.fetch_scenarios.first { $0.id == "policy-refusal-before-transport" }
        )
        let transport = ScriptedSearchTransport(responses: scenario.responses ?? [])
        _ = try? await SafeAcquisition.fetch(
            try url(scenario.requested_url),
            transport: transport,
            resolver: StubHostResolver(answers: scenario.resolved_addresses ?? [:]),
            policy: try policy(scenario.policy_override)
        )
        let sent = await transport.requests
        XCTAssertTrue(sent.isEmpty, "a refused URL must produce zero requests, not a rejected one")
    }

    func testRedirectHopIsValidatedBeforeItIsRequested() async throws {
        let ids = [
            "redirect-into-private-address",
            "redirect-into-metadata-service",
            "redirect-into-reserved-name",
        ]
        for id in ids {
            let scenario = try XCTUnwrap(Self.fixture.fetch_scenarios.first { $0.id == id })
            let transport = ScriptedSearchTransport(responses: scenario.responses ?? [])
            _ = try? await SafeAcquisition.fetch(
                try url(scenario.requested_url),
                transport: transport,
                resolver: StubHostResolver(answers: scenario.resolved_addresses ?? [:]),
                policy: try policy(scenario.policy_override)
            )
            let sent = await transport.requests
            XCTAssertEqual(
                sent.count,
                1,
                "\(id): only the origin may be contacted before the next hop is refused"
            )
        }
    }

    func testRedirectLoopIsDetectedAcrossEquivalentURLForms() async throws {
        // A hop that only differs by the default port and a trailing root dot is
        // the same destination, so it must count as a loop rather than a new hop.
        let origin = try url("https://example.com/a")
        let loop = try url("https://example.com:443/a")
        let transport = ScriptedSearchTransport(responses: [
            .init(status: 302, headers: ["Location": loop.absoluteString], body: nil),
        ])
        do {
            _ = try await SafeAcquisition.fetch(
                origin,
                transport: transport,
                resolver: StubHostResolver(answers: ["example.com": ["93.184.216.34"]]),
                policy: try policy()
            )
            XCTFail("expected a redirect loop")
        } catch let error as AcquisitionError {
            XCTAssertEqual(error.kind, "redirect_loop")
        }
        XCTAssertEqual(SafeAcquisition.canonicalKey(origin), SafeAcquisition.canonicalKey(loop))
    }

    // MARK: Address classification

    func testEquivalentLoopbackEncodingsNormalizeToTheSameAddress() {
        let embedded = [
            "127.0.0.1", "127.1", "2130706433", "0x7f.0.0.1", "0177.0.0.1",
            "::ffff:127.0.0.1", "64:ff9b::127.0.0.1", "2002:7f00:1::",
        ]
        for encoding in embedded {
            let address = IPAddress(parsing: encoding)
            XCTAssertNotNil(address, "\(encoding) must parse")
            XCTAssertEqual(address?.text, "127.0.0.1", encoding)
            XCTAssertEqual(address?.classification, .loopback, encoding)
        }

        let native = IPAddress(parsing: "::1")
        XCTAssertEqual(native?.text, "::1")
        XCTAssertEqual(native?.classification, .loopback)
    }

    func testPublicAddressesAreNotMistakenForReservedOnes() throws {
        XCTAssertEqual(IPAddress(parsing: "93.184.216.34")?.classification, .publicRoutable)
        XCTAssertEqual(IPAddress(parsing: "172.32.0.1")?.classification, .publicRoutable)
        XCTAssertEqual(IPAddress(parsing: "2606:4700:4700::1111")?.classification, .publicRoutable)
        XCTAssertEqual(IPAddress(parsing: "8.8.4.4")?.classification, .publicRoutable)
    }

    func testNonAddressesAreNotTreatedAsAddresses() {
        for value in ["", "   ", "not-an-address", "1.2.3.4.5", "example.com", "999.1.1.1", "1.2.3.4.example"] {
            XCTAssertNil(IPAddress(parsing: value), "\(value) must not parse as an address")
        }
    }

    func testReservedNameCheckRequiresALabelBoundary() async throws {
        // `notexample.com` merely contains the reserved label as a substring and
        // must still be fetchable when it resolves publicly.
        let resolver = StubHostResolver(answers: ["notexample.com": ["93.184.216.34"]])
        try await policy().validate(try url("https://notexample.com/paper"), resolver: resolver)

        for blocked in ["example.invalid", "paper.example", "host.local"] {
            do {
                try await policy().validate(try url("https://\(blocked)/"), resolver: StubHostResolver())
                XCTFail("\(blocked) must be refused")
            } catch let error as AcquisitionError {
                XCTAssertEqual(error.kind, "reserved_host_name", blocked)
            }
        }
    }

    // MARK: Typed error surface

    func testEveryAcquisitionErrorKindIsDistinctAndExplained() {
        let url = URL(string: "https://example.com/a")!
        let samples: [AcquisitionError] = [
            .invalidPolicy(reason: "x"),
            .invalidURL(reason: "x", url: "y"),
            .blockedScheme(scheme: "ftp"),
            .credentialsInURL(host: "example.com"),
            .blockedPort(port: 22, host: "example.com"),
            .reservedHostName(host: "printer.local"),
            .loopbackAddress(host: "h", address: "127.0.0.1"),
            .privateAddress(host: "h", address: "10.0.0.1"),
            .linkLocalAddress(host: "h", address: "169.254.1.1"),
            .multicastAddress(host: "h", address: "224.0.0.1"),
            .metadataService(host: "h", address: "169.254.169.254"),
            .reservedAddress(host: "h", address: "240.0.0.1"),
            .hostResolutionFailed(host: "h", reason: "x"),
            .unresolvableHost(host: "h"),
            .invalidResolvedAddress(host: "h", value: "y"),
            .transportFailure(reason: "x"),
            .timeout(url: url),
            .httpStatus(code: 500, url: url),
            .redirectWithoutLocation(url: url),
            .redirectLoop(url: url),
            .tooManyRedirects(limit: 5, url: url),
            .missingContentType(url: url),
            .unsupportedContentType(contentType: "application/octet-stream", url: url),
            .responseTooLarge(limit: 10, observed: 11),
        ]
        let kinds = samples.map(\.kind)
        XCTAssertEqual(Set(kinds).count, kinds.count, "every case must have a unique kind label")
        for error in samples {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "\(error.kind) needs a human description")
            XCTAssertFalse(error.kind.isEmpty)
        }
    }

    func testPolicyInitializerRejectsImpossibleSettings() {
        let invalid: [() throws -> AcquisitionPolicy] = [
            { try AcquisitionPolicy(allowedSchemes: []) },
            { try AcquisitionPolicy(allowedPorts: []) },
            { try AcquisitionPolicy(allowedContentTypes: []) },
            { try AcquisitionPolicy(maxRedirects: -1) },
            { try AcquisitionPolicy(maxBytes: 0) },
            { try AcquisitionPolicy(timeoutSeconds: 0) },
        ]
        for make in invalid {
            do {
                _ = try make()
                XCTFail("expected invalidPolicy")
            } catch let error as AcquisitionError {
                XCTAssertEqual(error.kind, "invalid_policy")
            } catch {
                XCTFail("expected an AcquisitionError, got \(error)")
            }
        }
    }

    // MARK: Offline guards

    func testNoTestOrAppSourceCanReachTheNetworkOrTheSystemResolver() throws {
        // Built by concatenation so this guard does not match its own source.
        let forbidden = ["URL" + "Session", "System" + "HostResolver", "getaddr" + "info"]
        let roots = ["Tests", "Sources/LocalLensApp"].map { Self.repositoryRoot.appendingPathComponent($0) }

        var scanned = 0
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                scanned += 1
                let source = try String(contentsOf: file, encoding: .utf8)
                for needle in forbidden {
                    XCTAssertFalse(
                        source.contains(needle),
                        "\(file.path) must not reference \(needle); tests use stubs only"
                    )
                }
            }
        }
        XCTAssertGreaterThan(scanned, 0, "the offline guard must actually scan test sources")
    }
}
