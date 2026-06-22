import Foundation

public struct RawMotionSnapshot {
  public let totalReports: Int
  public let lastImpact: Double
  public let averageImpact: Double
  public let peakImpact: Double
  public let smoothedEnergy: Double
  public let deviceCount: Int

  public init(
    totalReports: Int,
    lastImpact: Double,
    averageImpact: Double,
    peakImpact: Double,
    smoothedEnergy: Double,
    deviceCount: Int
  ) {
    self.totalReports = totalReports
    self.lastImpact = lastImpact
    self.averageImpact = averageImpact
    self.peakImpact = peakImpact
    self.smoothedEnergy = smoothedEnergy
    self.deviceCount = deviceCount
  }
}

public struct RawMotionVector: Equatable {
  public let x: Double
  public let y: Double
  public let z: Double

  public init(x: Double, y: Double, z: Double) {
    self.x = x
    self.y = y
    self.z = z
  }
}
