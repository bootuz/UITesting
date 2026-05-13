import Foundation

/// Base protocol for Page Object types.
///
/// Conform a struct to `Screen`, expose a `driver` reference, and use the
/// locator factory methods provided by the default implementation to
/// declare `Locator<Kind>` properties. The protocol intentionally does
/// **not** require any specific initializer — bring your own dependencies
/// alongside `driver` if needed.
///
/// ```swift
/// struct LibraryScreen: Screen {
///     let driver: any Driver
///     var addButton: Locator<Button> { button("library.addButton") }
///     var nameField: Locator<TextField> { textField("library.nameField") }
/// }
/// ```
public protocol Screen: Sendable {
    var driver: any Driver { get }
    var timeoutPolicy: TimeoutPolicy { get }
}

extension Screen {
    public var timeoutPolicy: TimeoutPolicy { .default }
}

// MARK: - Locator factories (by accessibility identifier)

extension Screen {
    public func button(_ testID: String) -> Locator<Button> {
        makeLocator(testID: testID, kind: Button.self, label: "button")
    }

    public func textField(_ testID: String) -> Locator<TextField> {
        makeLocator(testID: testID, kind: TextField.self, label: "textField")
    }

    public func cell(testID: String) -> Locator<Cell> {
        makeLocator(testID: testID, kind: Cell.self, label: "cell")
    }

    public func image(_ testID: String) -> Locator<Image> {
        makeLocator(testID: testID, kind: Image.self, label: "image")
    }

    public func switch_(_ testID: String) -> Locator<Switch> {
        makeLocator(testID: testID, kind: Switch.self, label: "switch")
    }

    public func slider(_ testID: String) -> Locator<Slider> {
        makeLocator(testID: testID, kind: Slider.self, label: "slider")
    }
}

// MARK: - Locator factories (by visible label)

extension Screen {
    public func button(label: String) -> Locator<Button> {
        makeLocatorByLabel(label: label, kind: Button.self, kindLabel: "button")
    }

    public func textField(label: String) -> Locator<TextField> {
        makeLocatorByLabel(label: label, kind: TextField.self, kindLabel: "textField")
    }
}

// MARK: - Static text by content

extension Screen {
    public func text(_ content: String) -> Locator<StaticText> {
        let query = ElementQuery(steps: [
            .byKind(.staticText),
            .byText(content)
        ])
        return Locator<StaticText>(
            driver: driver,
            query: query,
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "staticText(\"\(content)\")")
        )
    }
}

// MARK: - Generic factories

extension Screen {
    /// Generic locator factory for custom `ElementKind` types. Conform your
    /// custom kind to `ElementKind` plus the capability protocols matching
    /// the actions you want to expose, then call this factory.
    public func locator<K: ElementKind>(
        testID: String,
        of kind: K.Type = K.self
    ) -> Locator<K> {
        let query = ElementQuery(steps: [
            .byKind(K.tag),
            .byTestID(testID)
        ])
        return Locator<K>(
            driver: driver,
            query: query,
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(K.tag)(testID: \"\(testID)\")")
        )
    }

    /// Predicate-based escape hatch. `descriptor` is a human-readable string
    /// used in failure messages.
    public func anyElement(
        matching predicate: NSPredicate,
        descriptor: String
    ) -> Locator<AnyElement> {
        let locatorPredicate = LocatorPredicate(predicate, descriptor: descriptor)
        let query = ElementQuery(steps: [
            .byKind(.anyElement),
            .filter(locatorPredicate)
        ])
        return Locator<AnyElement>(
            driver: driver,
            query: query,
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "any(\(descriptor))")
        )
    }
}

// MARK: - Internal helpers

extension Screen {
    fileprivate func makeLocator<K: ElementKind>(
        testID: String,
        kind: K.Type,
        label: String
    ) -> Locator<K> {
        let query = ElementQuery(steps: [
            .byKind(K.tag),
            .byTestID(testID)
        ])
        return Locator<K>(
            driver: driver,
            query: query,
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(label)(testID: \"\(testID)\")")
        )
    }

    fileprivate func makeLocatorByLabel<K: ElementKind>(
        label: String,
        kind: K.Type,
        kindLabel: String
    ) -> Locator<K> {
        let query = ElementQuery(steps: [
            .byKind(K.tag),
            .byLabel(label)
        ])
        return Locator<K>(
            driver: driver,
            query: query,
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(kindLabel)(label: \"\(label)\")")
        )
    }
}
