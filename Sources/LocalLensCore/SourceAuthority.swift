import Foundation

/// A deterministic source-type preference for search *discovery*.
///
/// A metasearch result list mixes official documentation with blogs and
/// aggregators in an order we do not control. The M003.7 card showed the
/// consequence: Q1 answered a Swift question from two personal blogs instead of
/// Apple/Swift documentation, and Q5 cited a single Medium post that repeats a
/// common misconception, so the pipeline endorsed a false premise with exact
/// quotes. Known official documentation and project forums are the pages that can
/// support a primary-source claim, so they are opened before general blogs when
/// both are present.
///
/// This is a discovery ordering only. It never changes the citation boundary:
/// a claim is still accepted only against an exact stored passage, the
/// snippet-never-evidence rule still holds, and a page that is not authoritative
/// is still opened when it is all that was found. It adds no model, no
/// embedding, and no network call, and it is a source-type feature, not a
/// learned reranker.
public enum SourceAuthority {
    /// Known project/vendor domains. A `docs.` or `developer.` prefix on an
    /// arbitrary host is not evidence of ownership and must not earn tier 0.
    private static let officialDomains: Set<String> = [
        "swift.org", "sqlite.org", "apple.com", "python.org", "mozilla.org",
        "rust-lang.org", "go.dev", "kernel.org", "oracle.com", "android.com",
        "microsoft.com", "gnu.org", "w3.org", "ietf.org",
    ]

    /// `0` for official/primary documentation or forums, `1` for everything
    /// else. A stable sort by this tier preserves the search engine's own order
    /// within each tier.
    public static func tier(for url: URL) -> Int {
        guard let rawHost = url.host?.lowercased(), !rawHost.isEmpty else { return 1 }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return 1 }
        // A known official registrable domain (the last two labels).
        let registrable = labels.suffix(2).joined(separator: ".")
        if officialDomains.contains(registrable) { return 0 }
        // Swift Evolution proposals live under github.com/swiftlang.
        if host == "github.com", url.path.lowercased().hasPrefix("/swiftlang/") { return 0 }
        return 1
    }

    /// Stable-sorts discovery hits so official sources are opened first while
    /// preserving the search engine's relative order inside each tier.
    public static func ordered(_ hits: [SearchHit]) -> [SearchHit] {
        hits.enumerated()
            .sorted { left, right in
                let leftTier = tier(for: left.element.url)
                let rightTier = tier(for: right.element.url)
                if leftTier != rightTier { return leftTier < rightTier }
                return left.offset < right.offset
            }
            .map(\.element)
    }
}
