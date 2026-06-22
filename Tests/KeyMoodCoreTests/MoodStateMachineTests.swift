import XCTest
@testable import KeyMoodCore

final class MoodStateMachineTests: XCTestCase {
  func testIntenseRequiresDwellBeforeFullAhead() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let machine = MoodStateMachine(intenseDwell: 1.0, thresholds: .responsiveMenuBar)

    XCTAssertEqual(machine.update(energy: 0.30, impact: 0, now: start), .charged)
    XCTAssertEqual(machine.update(energy: 0.30, impact: 0, now: start.addingTimeInterval(0.5)), .charged)
    XCTAssertEqual(machine.update(energy: 0.30, impact: 0, now: start.addingTimeInterval(1.0)), .intense)
  }

  func testFullAheadDropsIntoStandbyBeforeSettling() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let machine = MoodStateMachine(intenseDwell: 0.2, thresholds: .responsiveMenuBar)

    _ = machine.update(energy: 0.30, impact: 0, now: start)
    XCTAssertEqual(machine.update(energy: 0.30, impact: 0, now: start.addingTimeInterval(0.3)), .intense)

    XCTAssertEqual(machine.update(energy: 0, impact: 0, now: start.addingTimeInterval(0.4)), .relaxing)
    XCTAssertEqual(machine.update(energy: 0, impact: 0, now: start.addingTimeInterval(0.8)), .relaxing)
    XCTAssertEqual(machine.update(energy: 0, impact: 0, now: start.addingTimeInterval(2.2)), .calm)
  }
}
