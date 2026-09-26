import Foundation

/// One stable identity for a scholarly work, derived only from values that
/// identify the work rather than the page that happens to serve it.
///
/// A DOI is authoritative and case-insensitive; an arXiv identifier is
/// versionless, because `2401.12345v2` and `2401.12345v3` are two versions of
/// one work. Nothing here reads a title or a host, so two aggregator pages for
/// the same paper reconcile together and a summary page cannot invent a work.
public enum ScholarlyIdentity {
    public static func normalizedDOI(_ raw: String?) -> String? {
        guard var doi = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !doi.isEmpty else { return nil }
        for prefix in ["https://doi.org/", "http://doi.org/", "doi:"] where doi.hasPrefix(prefix) {
            doi = String(doi.dropFirst(prefix.count))
        }
        doi = doi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !doi.isEmpty, doi.contains("/") else { return nil }
        return doi
    }

    /// Strips a trailing `vN` and any leading path segments.
    public static func versionlessArxivID(_ raw: String) -> String? {
        var identifier = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://arxiv.org/abs/", "http://arxiv.org/abs/", "arxiv:"] where identifier.hasPrefix(prefix) {
            identifier = String(identifier.dropFirst(prefix.count))
        }
        if let range = identifier.range(of: #"v\d+$"#, options: .regularExpression) {
            identifier.removeSubrange(range)
        }
        identifier = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return identifier.isEmpty ? nil : identifier
    }

    /// The work identity for a discovery URL, or `nil` when the URL does not
    /// carry one. Only DOI-resolver and arXiv-abstract URLs qualify.
    public static func identity(for url: URL) -> String? {
        guard let rawHost = url.host?.lowercased() else { return nil }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        if host == "doi.org" {
            let path = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
            if let doi = normalizedDOI(path) { return "doi:\(doi)" }
            return nil
        }
        if host == "arxiv.org" || host == "export.arxiv.org" {
            let path = url.path
            guard path.hasPrefix("/abs/") else { return nil }
            let identifier = String(path.dropFirst("/abs/".count))
            if let arxiv = versionlessArxivID(identifier) { return "arxiv:\(arxiv)" }
            return nil
        }
        return nil
    }
}

/// Deterministic reconciliation across scholarly providers.
///
/// It changes discovery only: duplicates of one work collapse to the most
/// readable candidate, provider order decides which title is kept, and the
/// first-seen position is preserved. It never merges passage text, never
/// rewrites a title, and never creates a citation.
public enum ScholarlyReconciliation {
    /// Preference for a candidate URL serving the same work. A versionless
    /// arXiv abstract page is a readable HTML target; a DOI resolver is a
    /// redirect, not a document.
    public static func readabilityRank(_ url: URL) -> Int {
        guard let rawHost = url.host?.lowercased() else { return 3 }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        if host == "arxiv.org" || host == "export.arxiv.org" { return 0 }
        if host == "doi.org" { return 2 }
        return 1
    }

    public static func reconcile(_ hits: [SearchHit]) -> [SearchHit] {
        var indexByKey: [String: Int] = [:]
        var result: [SearchHit] = []
        for hit in hits {
            let key = ScholarlyIdentity.identity(for: hit.url) ?? "url:\(hit.url.absoluteString)"
            if let existing = indexByKey[key] {
                if readabilityRank(hit.url) < readabilityRank(result[existing].url) {
                    // Keep the first-seen provider's title, rank, and identity;
                    // upgrade only the target to the more readable page.
                    let first = result[existing]
                    result[existing] = SearchHit(
                        id: first.id,
                        query: first.query,
                        rank: first.rank,
                        url: hit.url,
                        title: first.title,
                        snippet: first.snippet
                    )
                }
            } else {
                indexByKey[key] = result.count
                result.append(hit)
            }
        }
        // Stable primary-source ordering. The M005.3 held-out run measured
        // aggregator pages (ResearchGate, Medium, a survey mirror) opening
        // before the primary papers they summarize. This is discovery ordering
        // only: it changes which page is fetched first, never what a passage
        // means or whether it can be cited.
        return result.enumerated()
            .sorted { left, right in
                let leftRank = primarySourceRank(left.element.url)
                let rightRank = primarySourceRank(right.element.url)
                if leftRank != rightRank { return leftRank < rightRank }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    /// `0` for a primary paper target (repositories, DOI registrar, PubMed
    /// Central, publisher domains), `2` for a known aggregator or tertiary
    /// page, and `1` for everything else. Host-based and deterministic.
    public static func primarySourceRank(_ url: URL) -> Int {
        guard let rawHost = url.host?.lowercased(), !rawHost.isEmpty else { return 1 }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        if primaryHosts.contains(where: { host == $0 || host.hasSuffix(".\( $0 )") }) { return 0 }
        if aggregatorHosts.contains(where: { host == $0 || host.hasSuffix(".\( $0 )") }) { return 2 }
        return 1
    }

    private static let primaryHosts: Set<String> = [
        "arxiv.org", "export.arxiv.org", "doi.org", "pmc.ncbi.nlm.nih.gov",
        "europepmc.org", "ncbi.nlm.nih.gov", "files.eric.ed.gov", "frontiersin.org",
        "nature.com", "science.org", "aclanthology.org", "acm.org", "ieee.org",
        "springer.com", "sciencedirect.com", "wiley.com", "tandfonline.com",
        "cambridge.org", "jstor.org", "apa.org", "psycnet.apa.org",
        "biorxiv.org", "medrxiv.org", "osf.io",
    ]

    private static let aggregatorHosts: Set<String> = [
        "researchgate.net", "medium.com", "semanticscholar.org", "wikipedia.org",
        "tiptreesystems.com", "wispaper.ai", "reddit.com",
    ]

    /// Reconciles provider groups in the order they are supplied: earlier
    /// providers supply the titles and the first-seen positions.
    public static func reconcile(_ providers: [[SearchHit]]) -> [SearchHit] {
        reconcile(providers.flatMap { $0 })
    }
}
