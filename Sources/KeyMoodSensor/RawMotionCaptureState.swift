import Foundation
import IOKit
import KeyMoodCore

public struct RawMotionSample {
  public let reportID: UInt32
  public let reportLength: Int
  public let vector: RawMotionVector
}

public struct RawMotionTick {
  public let elapsed: TimeInterval
  public let reportsPerSecond: Double
  public let impact: Double
  public let energy: Double
}

public struct RawMotionDiagnostics {
  public let deviceNames: [String]
  public let openFailures: [String]
  public let reportLengths: [Int: Int]
  public let badReports: Int
}

public struct RawMotionSummary {
  public let snapshot: RawMotionSnapshot
  public let diagnostics: RawMotionDiagnostics
}

public final class RawMotionCaptureState: @unchecked Sendable {
  private let lock = NSLock()
  private let start = Date()
  private var lastTick = Date()
  private var totalReports = 0
  private var windowReports = 0
  private var badReports = 0
  private var lengthCounts: [Int: Int] = [:]
  private var openedDevices = Set<String>()
  private var openFailures: [String] = []
  private var firstSamples: [RawMotionSample] = []
  private var firstSampleCount = 0
  private var lastVector: RawMotionVector?
  private var lastImpact = 0.0
  private var impactSum = 0.0
  private var impactSamples = 0
  private var peakImpact = 0.0
  private var smoothedEnergy = 0.0

  public init() {}

  func addDevice(_ name: String) {
    lock.lock()
    openedDevices.insert(name)
    lock.unlock()
  }

  func addOpenFailure(_ message: String) {
    lock.lock()
    openFailures.append(message)
    lock.unlock()
  }

  func handleReport(result: IOReturn, reportID: UInt32, report: UnsafeMutablePointer<UInt8>?, length: CFIndex) {
    guard result == kIOReturnSuccess, let report else {
      lock.lock()
      badReports += 1
      lock.unlock()
      return
    }

    let reportLength = Int(length)
    guard let vector = SignalProcessor.rawAccelerometerVector(from: report, length: reportLength) else {
      lock.lock()
      badReports += 1
      lengthCounts[reportLength, default: 0] += 1
      lock.unlock()
      return
    }

    lock.lock()

    let impact = lastVector.map { SignalProcessor.impact(from: $0, to: vector) } ?? 0

    lastVector = vector
    lastImpact = impact
    impactSum += impact
    impactSamples += 1
    peakImpact = max(peakImpact, impact)
    smoothedEnergy = SignalProcessor.rawImpactEnergy(previous: smoothedEnergy, impact: impact)
    totalReports += 1
    windowReports += 1
    lengthCounts[reportLength, default: 0] += 1

    if firstSampleCount < 4 {
      firstSampleCount += 1
      firstSamples.append(RawMotionSample(reportID: reportID, reportLength: reportLength, vector: vector))
    }

    lock.unlock()
  }

  public func consumeSamples() -> [RawMotionSample] {
    lock.lock()
    let samples = firstSamples
    firstSamples.removeAll()
    lock.unlock()
    return samples
  }

  public func consumeTickIfNeeded() -> RawMotionTick? {
    let now = Date()

    lock.lock()
    let interval = now.timeIntervalSince(lastTick)
    guard interval >= 0.5 else {
      lock.unlock()
      return nil
    }

    let tick = RawMotionTick(
      elapsed: now.timeIntervalSince(start),
      reportsPerSecond: Double(windowReports) / interval,
      impact: lastImpact,
      energy: smoothedEnergy
    )
    windowReports = 0
    lastTick = now
    lock.unlock()
    return tick
  }

  public func snapshot() -> RawMotionSnapshot {
    lock.lock()
    let snapshot = RawMotionSnapshot(
      totalReports: totalReports,
      lastImpact: lastImpact,
      averageImpact: impactSamples == 0 ? 0 : impactSum / Double(impactSamples),
      peakImpact: peakImpact,
      smoothedEnergy: smoothedEnergy,
      deviceCount: openedDevices.count
    )
    lock.unlock()
    return snapshot
  }

  public func deviceNames() -> [String] {
    diagnostics().deviceNames
  }

  public func diagnostics() -> RawMotionDiagnostics {
    lock.lock()
    let diagnostics = RawMotionDiagnostics(
      deviceNames: openedDevices.sorted(),
      openFailures: openFailures,
      reportLengths: lengthCounts,
      badReports: badReports
    )
    lock.unlock()
    return diagnostics
  }

  public func summary() -> RawMotionSummary {
    RawMotionSummary(snapshot: snapshot(), diagnostics: diagnostics())
  }
}
