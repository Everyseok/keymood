import Foundation

public enum SignalProcessor {
  public static let rawReportMinimumLength = 18

  public static func rawAccelerometerVector(from report: UnsafeMutablePointer<UInt8>, length: Int) -> RawMotionVector? {
    guard length >= rawReportMinimumLength else {
      return nil
    }

    return RawMotionVector(
      x: Double(readLittleEndianInt32(report, offset: 6)) / 65536.0,
      y: Double(readLittleEndianInt32(report, offset: 10)) / 65536.0,
      z: Double(readLittleEndianInt32(report, offset: 14)) / 65536.0
    )
  }

  public static func impact(from previous: RawMotionVector, to current: RawMotionVector) -> Double {
    let dx = current.x - previous.x
    let dy = current.y - previous.y
    let dz = current.z - previous.z
    return sqrt(dx * dx + dy * dy + dz * dz)
  }

  public static func rawImpactEnergy(previous: Double, impact: Double) -> Double {
    let normalized = min(impact / 0.08, 1.0)
    return previous * 0.82 + normalized * 0.18
  }

  public static func hidDeltaEnergy(previous: Double, rawDelta: Double) -> Double {
    let normalized = min(rawDelta / 1024.0, 1.0)
    return previous * 0.88 + normalized * 0.12
  }

  private static func readLittleEndianInt32(_ pointer: UnsafeMutablePointer<UInt8>, offset: Int) -> Int32 {
    let value = UInt32(pointer[offset])
      | (UInt32(pointer[offset + 1]) << 8)
      | (UInt32(pointer[offset + 2]) << 16)
      | (UInt32(pointer[offset + 3]) << 24)
    return Int32(bitPattern: value)
  }
}
