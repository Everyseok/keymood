import XCTest
@testable import KeyMoodCore

final class SignalProcessorTests: XCTestCase {
  func testRawAccelerometerVectorDecodesLittleEndianAxes() throws {
    var report = Array(repeating: UInt8(0), count: SignalProcessor.rawReportMinimumLength)
    writeInt32(65_536, to: &report, offset: 6)
    writeInt32(-131_072, to: &report, offset: 10)
    writeInt32(32_768, to: &report, offset: 14)

    let vector = report.withUnsafeMutableBufferPointer { buffer -> RawMotionVector? in
      guard let base = buffer.baseAddress else {
        return nil
      }
      return SignalProcessor.rawAccelerometerVector(from: base, length: buffer.count)
    }

    let unwrappedVector = try XCTUnwrap(vector)
    XCTAssertEqual(unwrappedVector.x, 1.0, accuracy: 0.0001)
    XCTAssertEqual(unwrappedVector.y, -2.0, accuracy: 0.0001)
    XCTAssertEqual(unwrappedVector.z, 0.5, accuracy: 0.0001)
  }

  func testRawAccelerometerVectorRejectsShortReports() {
    var report = Array(repeating: UInt8(0), count: SignalProcessor.rawReportMinimumLength - 1)

    let vector = report.withUnsafeMutableBufferPointer { buffer -> RawMotionVector? in
      guard let base = buffer.baseAddress else {
        return nil
      }
      return SignalProcessor.rawAccelerometerVector(from: base, length: buffer.count)
    }

    XCTAssertNil(vector)
  }

  func testImpactUsesThreeAxisMagnitudeWithoutAxisBias() {
    let previous = RawMotionVector(x: 1.0, y: -2.0, z: 0.5)
    let current = RawMotionVector(x: 1.0, y: 1.0, z: 4.5)

    XCTAssertEqual(SignalProcessor.impact(from: previous, to: current), 5.0, accuracy: 0.0001)
  }

  private func writeInt32(_ value: Int32, to report: inout [UInt8], offset: Int) {
    let raw = UInt32(bitPattern: value)
    report[offset] = UInt8(raw & 0xff)
    report[offset + 1] = UInt8((raw >> 8) & 0xff)
    report[offset + 2] = UInt8((raw >> 16) & 0xff)
    report[offset + 3] = UInt8((raw >> 24) & 0xff)
  }
}
