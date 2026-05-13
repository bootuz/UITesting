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
