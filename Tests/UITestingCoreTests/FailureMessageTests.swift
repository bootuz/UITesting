import Testing
@testable import UITestingCore

@Suite("Failure message rendering")
struct FailureMessageTests {

    @Test func structured_rendering_includesLocatorPathAndObservation() {
        let error = LocatorError(
            kind: .notVisible,
            locator: LocatorDescription(path: "button(testID: \"library.addButton\")"),
            observed: .missing,
            elapsed: .milliseconds(5012),
            file: #filePath,
            line: #line,
            diagnostics: nil
        )

        let rendered = error.description

        #expect(rendered.contains("✗ Expected button(testID: \"library.addButton\") to be visible"))
        #expect(rendered.contains("Locator: button(testID: \"library.addButton\")"))
        #expect(rendered.contains("Last observed: missing (not in hierarchy)"))
        #expect(rendered.contains("Elapsed: 5.012s"))
    }

    @Test func verbose_rendering_includesCandidatesAndHint() {
        let candidates = [
            ElementAttributes(testID: "library.searchButton", label: "Search", elementType: .button),
            ElementAttributes(testID: "library.sortButton",   label: "Sort",   elementType: .button)
        ]
        let diagnostics = LocatorError.DiagnosticInfo(
            candidates: candidates,
            closestMatch: candidates[0]
        )
        let error = LocatorError(
            kind: .notVisible,
            locator: LocatorDescription(path: "button(testID: \"library.addButton\")"),
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
        #expect(rendered.contains("Hint: closest testID match is \"library.searchButton\"."))
    }

    @Test func negated_headline_reads_naturally() {
        let error = LocatorError(
            kind: .notVisible,
            locator: LocatorDescription(path: "anyElement(testID: \"library.deckCell.FlowTest Deck\")"),
            observed: .present(.init(testID: "library.deckCell.FlowTest Deck", isVisible: true)),
            elapsed: .seconds(5),
            file: #filePath,
            line: #line,
            isNegated: true
        )
        let rendered = error.description
        #expect(rendered.contains("not to be visible"))
        #expect(!rendered.contains("Expected anyElement(testID: \"library.deckCell.FlowTest Deck\") to be visible\n"))
    }

    @Test func valueMismatch_includesExpectedAndObserved() {
        let error = LocatorError(
            kind: .valueMismatch(expected: "42", observed: "17"),
            locator: LocatorDescription(path: "textField(testID: \"age\")"),
            observed: .present(.init(testID: "age", value: "17")),
            elapsed: .milliseconds(200),
            file: #filePath,
            line: #line
        )

        let rendered = error.description
        #expect(rendered.contains("\"42\""))
        #expect(rendered.contains("\"17\""))
    }
}
