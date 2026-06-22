import Foundation
import IOKit
import IOKit.hid
import KeyMoodCore
import KeyMoodSensor

struct StreamSample {
  let deviceName: String
  let usagePage: UInt32
  let usage: UInt32
  let rawValue: Int
}

struct StreamTick {
  let elapsed: TimeInterval
  let eventsPerSecond: Double
  let activeElementCount: Int
  let energy: Double
}

struct StreamSummary {
  let totalEvents: Int
  let candidateDevices: [String]
  let activeElementCount: Int
  let maxEnergy: Double
}

final class StreamState {
  private let start = Date()
  private var lastTick = Date()
  private var totalEvents = 0
  private var windowEvents = 0
  private var energy = 0.0
  private var maxEnergy = 0.0
  private var firstSamples: [StreamSample] = []
  private var firstSampleCount = 0
  private var candidateDevices = Set<String>()
  private var activeElements = Set<String>()
  private var lastValueByElement: [String: Double] = [:]

  let seconds: TimeInterval

  init(seconds: TimeInterval) {
    self.seconds = seconds
  }

  func handle(_ value: IOHIDValue) {
    let element = IOHIDValueGetElement(value)
    let device = IOHIDElementGetDevice(element)
    guard SensorService.isCandidateSensor(device) else {
      return
    }

    let elementID = SensorService.elementKey(element, device: device)
    let raw = Double(IOHIDValueGetIntegerValue(value))
    let previous = lastValueByElement[elementID]
    lastValueByElement[elementID] = raw
    activeElements.insert(elementID)
    candidateDevices.insert(SensorService.deviceName(device))

    totalEvents += 1
    windowEvents += 1

    if let previous {
      let delta = abs(raw - previous)
      energy = SignalProcessor.hidDeltaEnergy(previous: energy, rawDelta: delta)
      maxEnergy = max(maxEnergy, energy)
    }

    if firstSampleCount < 8 {
      firstSampleCount += 1
      firstSamples.append(StreamSample(
        deviceName: SensorService.deviceName(device),
        usagePage: IOHIDElementGetUsagePage(element),
        usage: IOHIDElementGetUsage(element),
        rawValue: Int(raw)
      ))
    }
  }

  func consumeSamples() -> [StreamSample] {
    let samples = firstSamples
    firstSamples.removeAll()
    return samples
  }

  func consumeTickIfNeeded() -> StreamTick? {
    let now = Date()
    let interval = now.timeIntervalSince(lastTick)
    guard interval >= 0.5 else {
      return nil
    }

    let tick = StreamTick(
      elapsed: now.timeIntervalSince(start),
      eventsPerSecond: Double(windowEvents) / interval,
      activeElementCount: activeElements.count,
      energy: energy
    )
    windowEvents = 0
    lastTick = now
    return tick
  }

  func summary() -> StreamSummary {
    StreamSummary(
      totalEvents: totalEvents,
      candidateDevices: candidateDevices.sorted(),
      activeElementCount: activeElements.count,
      maxEnergy: maxEnergy
    )
  }
}
