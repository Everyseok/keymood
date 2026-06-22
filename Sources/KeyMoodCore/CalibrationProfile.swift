import Foundation

public struct CalibrationProfile: Codable, Equatable {
  public var schemaVersion: Int
  public var createdAt: Date
  public var updatedAt: Date
  public var deviceModelHint: String?
  public var softBaseline: CalibrationBaseline
  public var normalBaseline: CalibrationBaseline
  public var firmBaseline: CalibrationBaseline
  public var focusedThreshold: Double
  public var chargedThreshold: Double
  public var intenseThreshold: Double
  public var dwellSeconds: Double
  public var relaxSpeed: Double

  public init(
    schemaVersion: Int = 1,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    deviceModelHint: String? = nil,
    softBaseline: CalibrationBaseline,
    normalBaseline: CalibrationBaseline,
    firmBaseline: CalibrationBaseline,
    focusedThreshold: Double,
    chargedThreshold: Double,
    intenseThreshold: Double,
    dwellSeconds: Double,
    relaxSpeed: Double
  ) {
    self.schemaVersion = schemaVersion
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deviceModelHint = deviceModelHint
    self.softBaseline = softBaseline
    self.normalBaseline = normalBaseline
    self.firmBaseline = firmBaseline
    self.focusedThreshold = focusedThreshold
    self.chargedThreshold = chargedThreshold
    self.intenseThreshold = intenseThreshold
    self.dwellSeconds = dwellSeconds
    self.relaxSpeed = relaxSpeed
  }
}

public struct CalibrationBaseline: Codable, Equatable {
  public var averageImpact: Double
  public var peakImpact: Double
  public var smoothedEnergy: Double

  public init(averageImpact: Double, peakImpact: Double, smoothedEnergy: Double) {
    self.averageImpact = averageImpact
    self.peakImpact = peakImpact
    self.smoothedEnergy = smoothedEnergy
  }
}
