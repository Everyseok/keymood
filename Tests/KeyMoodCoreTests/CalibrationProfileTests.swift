import XCTest
@testable import KeyMoodCore

final class CalibrationProfileTests: XCTestCase {
  func testCalibrationProfileRoundTripsThroughJSON() throws {
    let createdAt = Date(timeIntervalSinceReferenceDate: 100)
    let updatedAt = Date(timeIntervalSinceReferenceDate: 200)
    let profile = CalibrationProfile(
      createdAt: createdAt,
      updatedAt: updatedAt,
      deviceModelHint: "MacBookAir-test",
      softBaseline: CalibrationBaseline(averageImpact: 0.01, peakImpact: 0.03, smoothedEnergy: 0.08),
      normalBaseline: CalibrationBaseline(averageImpact: 0.03, peakImpact: 0.08, smoothedEnergy: 0.18),
      firmBaseline: CalibrationBaseline(averageImpact: 0.07, peakImpact: 0.18, smoothedEnergy: 0.36),
      focusedThreshold: 0.06,
      chargedThreshold: 0.14,
      intenseThreshold: 0.26,
      dwellSeconds: 0.65,
      relaxSpeed: 1.0
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(profile)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    XCTAssertEqual(try decoder.decode(CalibrationProfile.self, from: data), profile)
  }
}
