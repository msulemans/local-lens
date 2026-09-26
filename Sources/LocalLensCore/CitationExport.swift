import Foundation

/// Deterministic BibTeX and RIS export of the cited works in one answer.
///
/// Only works that actually appear as an accepted citation are exported; a
/// discovered-but-unread page is not a reference. The metadata available at
/// this boundary is a title, a fetched URL, and a snapshot identity, so the
/// entry is emitted as a generic electronic source and the exact-passage
/// identity is recorded in the note field. No author or year is invented.
public enum CitationExport {
    public static func bibTeX(_ artifact: LiveAnswerArtifact) -> String {
        let works = citedWorks(artifact)
        var lines: [String] = []
        for work in works {
            lines.append("@misc{\(work.key),")
            lines.append("  title = {\(escapeBibTeX(work.title))},")
            if let url = work.url {
                lines.append("  url = {\(url.absoluteString)},")
            }
            lines.append("  note = {Local Lens exact passage \(work.passageID)}")
            lines.append("}")
        }
        return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    }

    public static func ris(_ artifact: LiveAnswerArtifact) -> String {
        let works = citedWorks(artifact)
        var lines: [String] = []
        for work in works {
            lines.append("TY  - ELEC")
            lines.append("TI  - \(work.title)")
            if let url = work.url {
                lines.append("UR  - \(url.absoluteString)")
            }
            lines.append("N1  - Local Lens exact passage \(work.passageID)")
            lines.append("ER  - ")
        }
        return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    }

    /// A plain-text rendering of the brief and its citations, for a paste or a
    /// `.md` file. It carries the hosted/local label verbatim.
    public static func markdown(_ artifact: LiveAnswerArtifact) -> String {
        var lines: [String] = []
        lines.append("# \(artifact.question)")
        lines.append("")
        lines.append(artifact.answer)
        lines.append("")
        lines.append("_\(artifact.label) · \(artifact.citations.count) exact passages · \(String(format: "%.1f", artifact.elapsedSeconds))s_")
        lines.append("")
        for citation in artifact.citations {
            lines.append("## [\(citation.marker)] \(citation.heading)")
            lines.append("")
            lines.append("> \(citation.quote)")
            lines.append("")
            if let url = citation.sourceURL {
                lines.append("Source: \(url.absoluteString)")
            }
            lines.append("Passage: `\(citation.passageID)` · Snapshot: `\(citation.snapshotID)`")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    struct CitedWork: Equatable {
        let key: String
        let title: String
        let url: URL?
        let passageID: String
    }

    /// One entry per distinct source URL, in citation-marker order. A work cited
    /// twice contributes one reference; a citation with no URL still exports,
    /// because the snapshot identity is the evidence.
    static func citedWorks(_ artifact: LiveAnswerArtifact) -> [CitedWork] {
        var seen: Set<String> = []
        var works: [CitedWork] = []
        for citation in artifact.citations.sorted(by: { $0.marker < $1.marker }) {
            let dedupeKey = citation.sourceURL?.absoluteString ?? "passage:\(citation.passageID)"
            guard seen.insert(dedupeKey).inserted else { continue }
            works.append(CitedWork(
                key: key(for: citation),
                title: citation.heading.isEmpty ? (citation.sourceURL?.host ?? "Untitled source") : citation.heading,
                url: citation.sourceURL,
                passageID: citation.passageID
            ))
        }
        return works
    }

    /// A stable, ASCII citation key: `locallens` plus a short content hash, so
    /// the same answer always exports the same key and two answers do not
    /// collide by accident.
    static func key(for citation: LiveAnswerArtifact.Citation) -> String {
        let digest = StableIdentity.make("bibtex", citation.sourceURL?.absoluteString ?? "", citation.heading)
        return "locallens\(digest)"
    }

    /// BibTeX is brace-delimited; a stray brace in a title would truncate the
    /// entry, so braces are escaped and the rest of the text is untouched.
    static func escapeBibTeX(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\textbackslash{}")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
    }
}
