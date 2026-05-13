import Foundation

/// Human-readable rendering of an `ElementQuery`.
///
/// Built by the locator factory chain so failure messages can show the full
/// path that was searched. Hashable so the dedup logic can use it as a key.
public struct LocatorDescription: Sendable, Hashable, CustomStringConvertible {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    public var description: String { path }
}

/// A structured failure thrown by Locator actions and Expectation matchers.
///
/// The `id` UUID lets `UITestingTestCase.record(_:)` filter the runtime-rethrown
/// duplicate so Xcode shows a single failure marker at the user's call site.
public struct LocatorError: Error, Sendable, CustomStringConvertible {
    public let id: UUID
    public let kind: Kind
    public let locator: LocatorDescription
    public let observed: ElementSnapshot
    public let elapsed: Duration
    public let file: StaticString
    public let line: UInt
    public let diagnostics: DiagnosticInfo?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        locator: LocatorDescription,
        observed: ElementSnapshot,
        elapsed: Duration,
        file: StaticString,
        line: UInt,
        diagnostics: DiagnosticInfo? = nil
    ) {
        self.id = id
        self.kind = kind
        self.locator = locator
        self.observed = observed
        self.elapsed = elapsed
        self.file = file
        self.line = line
        self.diagnostics = diagnostics
    }

    public enum Kind: Sendable, Equatable {
        case notVisible
        case notHittable
        case notExist
        case valueMismatch(expected: String, observed: String?)
        case labelMismatch(expected: String, observed: String?)
        case textMismatch(expected: String, observed: String?)
        case toggleMismatch(expectedOn: Bool, observedOn: Bool?)
        case focusMismatch(expectedFocused: Bool)
        case adjustableMismatch(expected: Double, observed: Double?, tolerance: Double)
        case timeout
        case actionFailed(String)
    }

    public struct DiagnosticInfo: Sendable, Equatable {
        public let candidates: [ElementAttributes]
        public let closestMatch: ElementAttributes?

        public init(candidates: [ElementAttributes], closestMatch: ElementAttributes?) {
            self.candidates = candidates
            self.closestMatch = closestMatch
        }
    }

    public var description: String {
        FailureMessageRenderer.render(self)
    }
}

/// Renders LocatorError in the Structured + Diagnostic formats from the spec.
enum FailureMessageRenderer {
    static func render(_ error: LocatorError) -> String {
        var lines: [String] = []
        lines.append("✗ \(headline(error))")
        lines.append("")
        lines.append("  Locator: \(error.locator.path)")
        lines.append("  Last observed: \(observedDescription(error.observed))")
        lines.append("  Elapsed: \(formatDuration(error.elapsed))")

        if let diagnostics = error.diagnostics, !diagnostics.candidates.isEmpty {
            lines.append("")
            lines.append("  Nearby elements in current hierarchy:")
            for candidate in diagnostics.candidates.prefix(8) {
                lines.append("    • \(formatCandidate(candidate))")
            }
            if let closest = diagnostics.closestMatch, let id = closest.testID {
                lines.append("")
                lines.append("  Hint: closest testID match is \"\(id)\".")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func headline(_ error: LocatorError) -> String {
        switch error.kind {
        case .notVisible:
            return "Expected \(error.locator) to be visible"
        case .notHittable:
            return "Expected \(error.locator) to be hittable"
        case .notExist:
            return "Expected \(error.locator) to exist"
        case let .valueMismatch(expected, observed):
            return "Expected \(error.locator) to have value \"\(expected)\", got \(formatOptional(observed))"
        case let .labelMismatch(expected, observed):
            return "Expected \(error.locator) to have label \"\(expected)\", got \(formatOptional(observed))"
        case let .textMismatch(expected, observed):
            return "Expected \(error.locator) to contain text \"\(expected)\", got \(formatOptional(observed))"
        case let .toggleMismatch(expectedOn, observedOn):
            let observedLabel = observedOn.map { $0 ? "on" : "off" } ?? "missing"
            return "Expected \(error.locator) to be \(expectedOn ? "on" : "off"), got \(observedLabel)"
        case let .focusMismatch(expectedFocused):
            return "Expected \(error.locator) to be \(expectedFocused ? "focused" : "unfocused")"
        case let .adjustableMismatch(expected, observed, tolerance):
            let observedLabel = observed.map { String(format: "%.4f", $0) } ?? "missing"
            return "Expected \(error.locator) value ≈ \(String(format: "%.4f", expected)) (±\(tolerance)), got \(observedLabel)"
        case .timeout:
            return "Timed out waiting for \(error.locator)"
        case let .actionFailed(message):
            return "Action failed on \(error.locator): \(message)"
        }
    }

    private static func observedDescription(_ snapshot: ElementSnapshot) -> String {
        switch snapshot {
        case .missing:
            return "missing (not in hierarchy)"
        case let .present(attrs):
            var pieces: [String] = ["present"]
            if let id = attrs.testID { pieces.append("testID=\"\(id)\"") }
            if let label = attrs.label { pieces.append("label=\"\(label)\"") }
            if let value = attrs.value { pieces.append("value=\"\(value)\"") }
            pieces.append("visible=\(attrs.isVisible)")
            pieces.append("hittable=\(attrs.isHittable)")
            return pieces.joined(separator: " ")
        }
    }

    private static func formatCandidate(_ attrs: ElementAttributes) -> String {
        var pieces: [String] = ["\(attrs.elementType)"]
        if let id = attrs.testID { pieces.append("[testID=\"\(id)\"]") }
        if let label = attrs.label { pieces.append("label=\"\(label)\"") }
        return pieces.joined(separator: " ")
    }

    private static func formatOptional(_ value: String?) -> String {
        value.map { "\"\($0)\"" } ?? "<missing>"
    }

    private static func formatDuration(_ duration: Duration) -> String {
        let seconds = Double(duration.components.seconds) +
            Double(duration.components.attoseconds) / 1e18
        return String(format: "%.3fs", seconds)
    }
}
