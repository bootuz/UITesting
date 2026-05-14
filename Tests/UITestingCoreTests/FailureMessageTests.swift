import Testing
@testable import UITestingCore

@Suite("Failure message rendering")
struct FailureMessageTests {

    @Test func structured_rendering_includesLocatorPathAndObservation() {
        let error = LocatorError(
            kind: .notVisible,
            locator: LocatorDescription(path: "button(accID: \"library.addButton\")"),
            observed: .missing,
            elapsed: .milliseconds(5012),
            file: #filePath,
            line: #line,
            diagnostics: nil
        )

        let rendered = error.description

        #expect(rendered.contains("✗ Expected button(accID: \"library.addButton\") to be visible"))
        #expect(rendered.contains("Locator: button(accID: \"library.addButton\")"))
        #expect(rendered.contains("Last observed: missing (not in hierarchy)"))
        #expect(rendered.contains("Elapsed: 5.012s"))
    }

    @Test func verbose_rendering_includesCandidatesAndHint() {
        let candidates = [
            ElementAttributes(accID: "library.searchButton", label: "Search", elementType: .button),
            ElementAttributes(accID: "library.sortButton",   label: "Sort",   elementType: .button)
        ]
        let diagnostics = LocatorError.DiagnosticInfo(
            candidates: candidates,
            closestMatch: candidates[0]
        )
        let error = LocatorError(
            kind: .notVisible,
            locator: LocatorDescription(path: "button(accID: \"library.addButton\")"),
            observed: .missing,
            elapsed: .milliseconds(5012),
            file: #filePath,
            line: #line,
            diagnostics: diagnostics
        )

        let rendered = error.description

        #expect(rendered.contains("Nearby elements in current hierarchy:"))
        #expect(rendered.contains("library.searchButton"))
        #expect(rendered.contains("library.sortButton"))
        #expect(rendered.contains("Hint: closest accID match is \"library.searchButton\"."))
    }

    @Test func negated_headline_reads_naturally() {
        let error = LocatorError(
            kind: .notVisible,
            locator: LocatorDescription(path: "anyElement(accID: \"library.deckCell.FlowTest Deck\")"),
            observed: .present(.init(accID: "library.deckCell.FlowTest Deck", isVisible: true)),
            elapsed: .seconds(5),
            file: #filePath,
            line: #line,
            isNegated: true
        )
        let rendered = error.description
        #expect(rendered.contains("not to be visible"))
        #expect(!rendered.contains("Expected anyElement(accID: \"library.deckCell.FlowTest Deck\") to be visible\n"))
    }

    @Test func valueMismatch_includesExpectedAndObserved() {
        let error = LocatorError(
            kind: .valueMismatch(expected: "42", observed: "17"),
            locator: LocatorDescription(path: "textField(accID: \"age\")"),
            observed: .present(.init(accID: "age", value: "17")),
            elapsed: .milliseconds(200),
            file: #filePath,
            line: #line
        )

        let rendered = error.description
        #expect(rendered.contains("\"42\""))
        #expect(rendered.contains("\"17\""))
    }
}
