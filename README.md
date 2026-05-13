# UITesting

A Playwright-flavored wrapper over Apple's XCUITest. Swift-native, all-sync, Swift 6 ready.

```swift
import UITesting

final class CreateDeckFlowTests: UITestingTestCase {
    func test_createDeck_appearsInLibrary() throws {
        app.launch()

        let library = LibraryScreen(driver: driver)
        try library.addButton.tap()
        try library.nameField.typeText("FlowTest Deck")
        try library.saveButton.tap()

        try expect(library.deckCell(named: "FlowTest Deck")).toBeVisible()
    }
}
```

## What you get over raw XCUITest

- **Lazy locators** — `Locator<Button>` is a description, not a snapshot. Re-resolves on every action.
- **Auto-waiting actions and assertions** — no more `assertExists().tap()` everywhere.
- **Compile-time type safety** — `screen.text("Saved").tap()` is a compile error.
- **Structured failure messages** with optional diagnostic mode that suggests likely test ID typos.

## Status

v0.1 in development. iOS only. See [the design spec](./docs/design.md) for the full architecture.

## License

MIT
