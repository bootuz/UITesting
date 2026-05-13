import Foundation
@testable import UITestingCore

/// In-memory `Driver` implementation for host-side tests. Allows scripting:
///
/// - The snapshot returned for a given query at each tick (`script(query:)`).
/// - The behavior of `perform` (defaults to recording without side effects).
/// - The enumeration returned for diagnostic mode.
///
/// All methods are MainActor-free because UITestingCore is not actor-isolated.
final class FakeDriver: Driver, @unchecked Sendable {

    let reporter: any FailureReporter
    var diagnostics: FailureDiagnostics

    /// Programmable snapshots. Each `(query, [snapshots])` entry returns
    /// snapshots in FIFO order; once exhausted, returns the last entry's value.
    private var scriptedSnapshots: [ElementQuery: [ElementSnapshot]] = [:]
    private var defaultSnapshot: ElementSnapshot = .missing

    /// Recorded actions, in order. Each entry includes the query targeted.
    private(set) var performedActions: [(action: ElementAction, query: ElementQuery)] = []

    /// Hook to throw an error on `perform`. If non-nil, `perform` throws.
    var performError: Error?

    /// Programmable enumeration result, keyed by ElementKindTag.
    var enumerationResults: [ElementKindTag: [ElementAttributes]] = [:]

    init(
        reporter: any FailureReporter = RecordingFailureReporter(),
        diagnostics: FailureDiagnostics = .standard
    ) {
        self.reporter = reporter
        self.diagnostics = diagnostics
    }

    func resolve(_ query: ElementQuery) -> ElementSnapshot {
        if var snapshots = scriptedSnapshots[query] {
            if let first = snapshots.first {
                if snapshots.count > 1 {
                    snapshots.removeFirst()
                    scriptedSnapshots[query] = snapshots
                }
                return first
            }
        }
        return defaultSnapshot
    }

    func perform(_ action: ElementAction, on query: ElementQuery) throws {
        if let performError {
            throw performError
        }
        performedActions.append((action, query))
    }

    func enumerate(kind: ElementKindTag) -> [ElementAttributes] {
        enumerationResults[kind] ?? []
    }

    // MARK: - Scripting

    /// Set the snapshot(s) returned for a query. Subsequent calls pop the
    /// FIFO list until one remains (which is then returned indefinitely).
    func script(_ snapshots: [ElementSnapshot], for query: ElementQuery) {
        scriptedSnapshots[query] = snapshots
    }

    /// Set the snapshot returned by default for any un-scripted query.
    func setDefault(_ snapshot: ElementSnapshot) {
        defaultSnapshot = snapshot
    }
}
