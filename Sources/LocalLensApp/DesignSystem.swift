import AppKit
import LocalLensCore
import SwiftUI

/// The visual system for the workspace.
///
/// It exists because the first four-mode run showed the surface was made of
/// tracked-out all-caps labels, `·`-joined counters, and monospaced micro-text
/// on every line, which reads as scaffolding rather than as a product. The
/// rules here are narrow on purpose:
///
/// - Surfaces are semantic system colours, so the window is correct in light
///   and dark appearance without a second palette to maintain.
/// - One accent (evidence), two semantic flags (caution, conflict). Nothing
///   else is tinted, so a tinted thing always means something.
/// - Sentence case throughout. No all-caps eyebrows, no middle-dot counters.
/// - Monospaced digits only where numbers must align in a column.
/// - Prose keeps a readable measure; the answer is the one large text on the
///   screen and everything else is smaller than it.
enum Lens {

    // MARK: - Colour

    enum Color {
        /// The window plane behind cards.
        static let canvas = SwiftUI.Color(nsColor: .windowBackgroundColor)
        /// A card, row, or panel that holds content.
        static let card = SwiftUI.Color(nsColor: .textBackgroundColor)
        /// A quiet inset: source rows, quote blocks, table headers.
        static let inset = SwiftUI.Color(nsColor: .underPageBackgroundColor)
        static let line = SwiftUI.Color(nsColor: .separatorColor)

        static let ink = SwiftUI.Color(nsColor: .labelColor)
        static let muted = SwiftUI.Color(nsColor: .secondaryLabelColor)
        static let faint = SwiftUI.Color(nsColor: .tertiaryLabelColor)

        /// The only accent: a claim is backed by an exact stored passage.
        static let evidence = dynamic(
            light: NSColor(srgbRed: 0.04, green: 0.42, blue: 0.38, alpha: 1),
            dark: NSColor(srgbRed: 0.35, green: 0.80, blue: 0.72, alpha: 1)
        )
        /// Something is single-source, undated, or thin. Not an error.
        static let caution = dynamic(
            light: NSColor(srgbRed: 0.60, green: 0.38, blue: 0.05, alpha: 1),
            dark: NSColor(srgbRed: 0.93, green: 0.72, blue: 0.33, alpha: 1)
        )
        /// Two stored pages disagree, or a run refused to answer.
        static let conflict = dynamic(
            light: NSColor(srgbRed: 0.64, green: 0.17, blue: 0.15, alpha: 1),
            dark: NSColor(srgbRed: 0.95, green: 0.51, blue: 0.47, alpha: 1)
        )

        private static func dynamic(light: NSColor, dark: NSColor) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
        }
    }

    // MARK: - Type

    enum Text {
        static let display = Font.system(size: 25, weight: .semibold)
        static let section = Font.system(size: 15, weight: .semibold)
        /// The answer. The largest body text on the screen.
        static let reading = Font.system(size: 15)
        static let body = Font.system(size: 13)
        static let label = Font.system(size: 12)
        static let caption = Font.system(size: 11)
        /// Aligned counts and durations only.
        static let data = Font.system(size: 11, weight: .medium).monospacedDigit()
    }

    enum Space {
        static let hairline: CGFloat = 1
        static let tight: CGFloat = 6
        static let row: CGFloat = 10
        static let group: CGFloat = 16
        static let section: CGFloat = 26
        static let page: CGFloat = 28
    }

    enum Radius {
        static let control: CGFloat = 9
        static let card: CGFloat = 13
    }
}

// MARK: - Building blocks

/// A surface that holds content. One radius for cards, a hairline border
/// instead of a shadow, and an inset variant for secondary material.
private struct LensCard: ViewModifier {
    var inset = false
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(inset ? Lens.Color.inset : Lens.Color.card, in: RoundedRectangle(cornerRadius: Lens.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Lens.Radius.card)
                    .stroke(highlighted ? Lens.Color.evidence.opacity(0.55) : Lens.Color.line)
            )
    }
}

extension View {
    func lensCard(inset: Bool = false, highlighted: Bool = false) -> some View {
        modifier(LensCard(inset: inset, highlighted: highlighted))
    }
}

/// A titled region. The detail line says what the section is for; the trailing
/// slot carries counts or a control, never both in the same visual weight.
struct LensSection<Content: View, Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.row) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    SwiftUI.Text(title)
                        .font(Lens.Text.section)
                        .foregroundStyle(Lens.Color.ink)
                    if let detail {
                        SwiftUI.Text(detail)
                            .font(Lens.Text.caption)
                            .foregroundStyle(Lens.Color.muted)
                    }
                }
                Spacer(minLength: Lens.Space.row)
                trailing()
            }
            content()
        }
    }
}

extension LensSection where Trailing == EmptyView {
    init(title: String, detail: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, detail: detail, content: content, trailing: { EmptyView() })
    }
}

/// How a source stands against a claim. Every case is something the run
/// measured; none of them is a quality judgement.
enum SupportVerdict {
    case supports(Int)
    case partly(Int)
    case singleSource
    case conflicts

    var label: String {
        switch self {
        case .supports: "2+ sources"
        case .partly: "Partly"
        case .singleSource: "Single source"
        case .conflicts: "Conflicts"
        }
    }

    var tint: SwiftUI.Color {
        switch self {
        case .supports: Lens.Color.evidence
        case .partly, .singleSource: Lens.Color.caution
        case .conflicts: Lens.Color.conflict
        }
    }
}

struct VerdictChip: View {
    let verdict: SupportVerdict
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(verdict.tint)
                .frame(width: 6, height: 6)
            SwiftUI.Text(verdict.label)
                .font(Lens.Text.caption)
                .foregroundStyle(verdict.tint)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(verdict.tint.opacity(0.10), in: Capsule())
        .fixedSize()
    }
}

/// A number with a quiet label, used where a count is the point.
struct LensMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            SwiftUI.Text(value)
                .font(Lens.Text.data)
                .foregroundStyle(Lens.Color.ink)
            SwiftUI.Text(label)
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.muted)
        }
    }
}

/// A quiet inline note. Used for the stop reason, the window line, and the
/// relevance line, which are all clauses about the run rather than findings.
struct LensNote: View {
    let systemImage: String
    var tint: SwiftUI.Color = Lens.Color.muted
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
                .foregroundStyle(tint)
            SwiftUI.Text(text)
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The question field.
///
/// It grows with the question instead of clipping it, keeps a visible boundary
/// when empty, and states its own shortcut. The first version was a
/// single-line field that lost its edges in a crowded row: a typed question
/// longer than the row appeared cut off at both ends with no sign the text was
/// still there.
struct QuestionField: View {
    @Binding var question: String
    var onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Lens.Space.row) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(focused ? Lens.Color.evidence : Lens.Color.faint)
                .padding(.top, 2)

            TextField("Ask a question and every claim will cite an exact passage…", text: $question, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Lens.Text.reading)
                .lineLimit(1...6)
                .focused($focused)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("researchQuestionField")

            if !question.isEmpty {
                Button {
                    question = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Lens.Color.faint)
                }
                .buttonStyle(.plain)
                .help("Clear the question")
                .accessibilityLabel("Clear the question")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Lens.Color.card, in: RoundedRectangle(cornerRadius: Lens.Radius.control + 2))
        .overlay(
            RoundedRectangle(cornerRadius: Lens.Radius.control + 2)
                .stroke(focused ? Lens.Color.evidence.opacity(0.65) : Lens.Color.line, lineWidth: focused ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

/// A small, quiet button used for row-level actions.
struct LensQuietButton: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 10)) }
            SwiftUI.Text(title).font(Lens.Text.caption)
        }
        .foregroundStyle(Lens.Color.muted)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Lens.Color.inset, in: Capsule())
        .fixedSize()
    }
}
