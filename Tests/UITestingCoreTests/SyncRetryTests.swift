import Testing
import Foundation
@testable import UITestingCore

@Suite("syncRetry primitive")
struct SyncRetryTests {

    @Test("returns immediately when predicate succeeds first call")
    func returnsImmediatelyWhenPredicateSucceedsFirstCall() throws {
        let clock = VirtualClock()
        var callCount = 0

        let result = try syncRetry(
            until: { () -> Int? in
                callCount += 1
                return 42
            },
            timeout: .seconds(5),
            pollInterval: .milliseconds(50),
            clock: clock,
            onTimeout: { throw TestError.shouldNotTimeout }
        )

        #expect(result == 42)
        #expect(callCount == 1)
    }

    @Test("retries until predicate succeeds")
    func retriesUntilPredicateSucceeds() throws {
        let clock = VirtualClock()
        var callCount = 0

        let result = try syncRetry(
            until: { () -> String? in
                callCount += 1
                return callCount >= 3 ? "found" : nil
            },
            timeout: .seconds(5),
            pollInterval: .milliseconds(50),
            clock: clock,
            onTimeout: { throw TestError.shouldNotTimeout }
        )

        #expect(result == "found")
        #expect(callCount == 3)
    }

    @Test("calls onTimeout when predicate never succeeds")
    func callsOnTimeoutWhenPredicateNeverSucceeds() {
        let clock = VirtualClock()
        var callCount = 0

        #expect(throws: TestError.timedOut) {
            try syncRetry(
                until: { () -> Bool? in
                    callCount += 1
                    return nil
                },
                timeout: .milliseconds(200),
                pollInterval: .milliseconds(50),
                clock: clock,
                onTimeout: { throw TestError.timedOut }
            )
        }
        #expect(callCount >= 4)
    }

    @Test("runs one last predicate attempt after deadline")
    func oneLastPredicateAttemptAfterDeadline() throws {
        let clock = VirtualClock()
        var callCount = 0

        // Loop runs at t=0, 50, 100 (3 attempts) then sleeps to t=150,
        // exits the while, and runs ONE final attempt. Total = 4 attempts.
        // Make the predicate succeed exactly on attempt 4 to verify the
        // post-deadline retry runs.
        let result = try syncRetry(
            until: { () -> Bool? in
                callCount += 1
                if callCount < 4 { return nil }
                return true
            },
            timeout: .milliseconds(150),
            pollInterval: .milliseconds(50),
            clock: clock,
            onTimeout: { throw TestError.timedOut }
        )

        #expect(result == true)
        #expect(callCount == 4)
    }

    enum TestError: Error, Equatable {
        case shouldNotTimeout
        case timedOut
    }
}
