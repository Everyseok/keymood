import Foundation
import IOKit
import IOKit.hid
import KeyMoodCore
import KeyMoodSensor

enum Command: String {
  case sensors
  case stream
  case rawStream = "raw-stream"
  case moodStream = "mood-stream"
  case calibrate
  case help
}

let arguments = Array(CommandLine.arguments.dropFirst())
let command = Command(rawValue: arguments.first ?? "help") ?? .help

switch command {
case .sensors:
  listSensors()
case .stream:
  streamSensors(arguments: Array(arguments.dropFirst()))
case .rawStream:
  rawStreamSensors(arguments: Array(arguments.dropFirst()))
case .moodStream:
  moodStream(arguments: Array(arguments.dropFirst()))
case .calibrate:
  runCalibration(arguments: Array(arguments.dropFirst()))
case .help:
  printHelp()
}

func printHelp() {
  print("""
  KeyMood Probe

  Commands:
    keymood-probe sensors
      List local HID/SPU sensor candidates.

    keymood-probe stream [--seconds 15]
      Stream model-free typing vibration energy from candidate sensor devices.

    keymood-probe raw-stream [--seconds 15]
      Stream AppleSPU accelerometer raw reports and print impact energy.

    keymood-probe mood-stream [--seconds 30] [--dwell 1.0]
      Convert typing impact into stable engine regimes:
      Dead Slow, Slow Ahead, Half Ahead, Full Ahead, and Standby.

    keymood-probe calibrate [--rounds 2] [--repeats 3]
      Guide light/strong typing rounds and print a comparison graph.

  The probe does not read typed text or key codes.
  """)
}

func rawStreamSensors(arguments: [String]) {
  let seconds = readDoubleFlag("--seconds", from: arguments) ?? 15.0
  let state = RawMotionCaptureState()
  let reader = AppleSPUSensorReader(state: state)
  let wake = reader.start()
  defer {
    reader.stop()
  }

  print("Streaming AppleSPU raw accelerometer reports for \(fixed(seconds, 1))s.")
  print("Type on the built-in keyboard, then try one firmer tap. Ctrl+C stops it.")
  if wake.drivers > 0 {
    print("SPU wake: drivers=\(wake.drivers) propertyWrites=\(wake.successes) failedWrites=\(wake.failures)")
  }
  print("")

  guard reader.hasDevices else {
    printOpenFailures(state.diagnostics().openFailures)
    print("No raw accelerometer device opened. If macOS denied access, build once and try:")
    print("  swift build")
    print("  sudo .build/debug/keymood-probe raw-stream --seconds \(Int(seconds))")
    return
  }

  print("device(s): \(state.deviceNames().joined(separator: ", "))")
  print("")
  print("time    reports/s  impact-g  energy  mood-proxy")

  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    reader.poll(interval: 0.05)
    printRawSamples(state.consumeSamples())
    if let tick = state.consumeTickIfNeeded() {
      printRawTick(tick)
    }
  }

  print("")
  printRawSummary(state.summary())
}

func moodStream(arguments: [String]) {
  let seconds = readDoubleFlag("--seconds", from: arguments) ?? 30.0
  let dwell = readDoubleFlag("--dwell", from: arguments) ?? 1.0
  let state = RawMotionCaptureState()
  let machine = MoodStateMachine(intenseDwell: dwell)
  let reader = AppleSPUSensorReader(state: state)
  let wake = reader.start()
  defer {
    reader.stop()
  }

  print("Streaming KeyMood state for \(fixed(seconds, 1))s.")
  print("Use another text field for clean output; typing in this terminal will echo characters.")
  if wake.drivers > 0 {
    print("SPU wake: drivers=\(wake.drivers) propertyWrites=\(wake.successes) failedWrites=\(wake.failures)")
  }
  print("")

  guard reader.hasDevices else {
    printOpenFailures(state.diagnostics().openFailures)
    print("No raw accelerometer device opened. Try:")
    print("  swift build")
    print("  sudo .build/debug/keymood-probe mood-stream --seconds \(Int(seconds))")
    return
  }

  print("device(s): \(state.deviceNames().joined(separator: ", "))")
  print("")
  print("time    impact-g  signal               pose                 target       state")

  var lastPrint = Date()
  var lastMood: RuntimeMood?
  let deadline = Date().addingTimeInterval(seconds)

  while Date() < deadline {
    reader.poll(interval: 0.05)
    printRawSamples(state.consumeSamples())
    let now = Date()
    let snapshot = state.snapshot()
    let mood = machine.update(energy: snapshot.smoothedEnergy, impact: snapshot.lastImpact, now: now)

    if now.timeIntervalSince(lastPrint) >= 0.5 || mood != lastMood {
      let elapsed = now.timeIntervalSince(machine.startedAt)
      let signalBar = energyBar(snapshot.smoothedEnergy)
      let poseBar = energyBar(machine.poseEnergy)
      let target = machine.target.label.padding(toLength: 12, withPad: " ", startingAt: 0)
      print("\(fixed(elapsed, 1))s  \(fixed(snapshot.lastImpact, 4))    \(signalBar) \(poseBar) \(target) \(mood.label)")
      lastPrint = now
      lastMood = mood
    }
  }

  print("")
  printRawSummary(state.summary())
  print("final mood: \(machine.current.label)")
}

func listSensors() {
  let manager = SensorService.makeManager(candidateOnly: false)

  let devices = SensorService.copyDevices(from: manager).sorted { lhs, rhs in
    SensorService.deviceSortKey(lhs) < SensorService.deviceSortKey(rhs)
  }

  print("HID devices: \(devices.count)")
  print("")

  for device in devices {
    let marker = SensorService.isCandidateSensor(device) ? "*" : " "
    let product = SensorService.stringProperty(device, kIOHIDProductKey) ?? "-"
    let transport = SensorService.stringProperty(device, kIOHIDTransportKey) ?? "-"
    let vendor = SensorService.intProperty(device, kIOHIDVendorIDKey).map(String.init) ?? "-"
    let usagePage = SensorService.intProperty(device, kIOHIDPrimaryUsagePageKey).map(String.init) ?? "-"
    let usage = SensorService.intProperty(device, kIOHIDPrimaryUsageKey).map(String.init) ?? "-"
    let rates = SensorService.stringProperty(device, "sensor_rates") ?? "-"
    let restricted = SensorService.boolishProperty(device, "motionRestrictedService") ?? "-"

    print("\(marker) product=\(product) transport=\(transport) vendor=\(vendor) usagePage=\(usagePage) usage=\(usage) rates=\(rates) motionRestricted=\(restricted)")
  }

  print("")
  print("* = default stream candidate")
}

func streamSensors(arguments: [String]) {
  let seconds = readDoubleFlag("--seconds", from: arguments) ?? 15.0
  let manager = SensorService.makeManager(candidateOnly: true)
  let state = StreamState(seconds: seconds)
  let context = Unmanaged.passUnretained(state).toOpaque()

  IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
    guard let context else { return }
    let state = Unmanaged<StreamState>.fromOpaque(context).takeUnretainedValue()
    state.handle(value)
  }, context)

  IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
  let openResult = SensorService.openManager(manager)
  if openResult != kIOReturnSuccess {
    print("warning: IOHIDManagerOpen returned \(openResult)")
  }

  print("Streaming candidate SPU/HID sensor deltas for \(fixed(seconds, 1))s.")
  print("Type on the built-in keyboard while this runs. Ctrl+C stops it.")
  print("")
  print("time    events/s  active  energy  mood-proxy")

  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    CFRunLoopRunInMode(.defaultMode, 0.05, false)
    printStreamSamples(state.consumeSamples())
    if let tick = state.consumeTickIfNeeded() {
      printStreamTick(tick)
    }
  }

  printStreamSummary(state.summary())
  IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
  IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
}

func printStreamSamples(_ samples: [StreamSample]) {
  for sample in samples {
    print("# sample device=\(sample.deviceName) usagePage=\(sample.usagePage) usage=\(sample.usage) raw=\(sample.rawValue)")
  }
}

func printStreamTick(_ tick: StreamTick) {
  let proxy = moodProxy(energy: tick.energy, eventsPerSecond: tick.eventsPerSecond)
  let bar = energyBar(tick.energy)
  print("\(fixed(tick.elapsed, 1))s  \(fixed(tick.eventsPerSecond, 1))     \(tick.activeElementCount)      \(fixed(tick.energy, 3))  \(bar) \(proxy)")
}

func printStreamSummary(_ summary: StreamSummary) {
  print("")
  print("Summary")
  print("- events: \(summary.totalEvents)")
  print("- candidate devices: \(summary.candidateDevices.joined(separator: ", "))")
  print("- active elements: \(summary.activeElementCount)")
  print("- max energy: \(fixed(summary.maxEnergy, 3))")

  if summary.totalEvents == 0 {
    print("")
    print("No candidate sensor events arrived. This Mac may require a lower-level SPU reader or an alternate keyboard-rhythm fallback.")
  }
}

func printRawSamples(_ samples: [RawMotionSample]) {
  for sample in samples {
    let vector = sample.vector
    print("# raw sample id=\(sample.reportID) len=\(sample.reportLength) x=\(fixed(vector.x, 4))g y=\(fixed(vector.y, 4))g z=\(fixed(vector.z, 4))g")
  }
}

func printRawTick(_ tick: RawMotionTick) {
  let proxy = rawMoodProxy(impact: tick.impact, energy: tick.energy, reportsPerSecond: tick.reportsPerSecond)
  let bar = energyBar(tick.energy)
  print("\(fixed(tick.elapsed, 1))s  \(fixed(tick.reportsPerSecond, 1))      \(fixed(tick.impact, 4))    \(fixed(tick.energy, 3))  \(bar) \(proxy)")
}

func printRawSummary(_ summary: RawMotionSummary) {
  let snapshot = summary.snapshot
  let diagnostics = summary.diagnostics

  print("Summary")
  print("- reports: \(snapshot.totalReports)")
  print("- opened devices: \(diagnostics.deviceNames.joined(separator: ", "))")
  print("- report lengths: \(reportLengthsDescription(diagnostics.reportLengths))")
  print("- bad reports: \(diagnostics.badReports)")
  print("- average impact: \(fixed(snapshot.averageImpact, 5))g")
  print("- peak impact: \(fixed(snapshot.peakImpact, 5))g")
  print("- final energy: \(fixed(snapshot.smoothedEnergy, 3))")

  if !diagnostics.openFailures.isEmpty {
    print("")
    printOpenFailures(diagnostics.openFailures)
  }

  if snapshot.totalReports == 0 {
    print("")
    print("No raw reports arrived. On some macOS builds this path needs root:")
    print("  swift build")
    print("  sudo .build/debug/keymood-probe raw-stream --seconds 5")
  }
}

func printOpenFailures(_ failures: [String]) {
  guard !failures.isEmpty else {
    return
  }

  print("Open failures:")
  for failure in failures {
    print("- \(failure)")
  }
  print("")
}

func runCalibration(arguments: [String]) {
  let rounds = max(1, Int(readDoubleFlag("--rounds", from: arguments) ?? 2.0))
  let repeats = max(1, Int(readDoubleFlag("--repeats", from: arguments) ?? 3.0))
  let phrase = "mood mood mood calm calm calm focus focus focus"
  var results: [RoundResult] = []

  print("KeyMood typing-force calibration")
  print("")
  print("Phrase:")
  print("  \(phrase)")
  print("")
  print("For each round, type the phrase \(repeats) time(s). Press Enter after each line.")
  print("Typed content is discarded; only count + sensor energy are measured.")
  print("")

  for index in 1...rounds {
    results.append(runCalibrationRound(
      label: "light \(index)",
      instruction: "Type softly, like you are barely touching the keys.",
      repeats: repeats,
      phrase: phrase
    ))
    results.append(runCalibrationRound(
      label: "strong \(index)",
      instruction: "Type firmly, with intentionally heavier key presses.",
      repeats: repeats,
      phrase: phrase
    ))
  }

  printCalibrationGraph(results)
}

struct RoundResult {
  let label: String
  let seconds: TimeInterval
  let keyBytes: Int
  let events: Int
  let activeElements: Int
  let averageEnergy: Double
  let peakEnergy: Double

  var charsPerSecond: Double {
    seconds > 0 ? Double(keyBytes) / seconds : 0
  }
}

func runCalibrationRound(label: String, instruction: String, repeats: Int, phrase: String) -> RoundResult {
  print("Round: \(label)")
  print(instruction)
  print("Phrase: \(phrase)")
  print("Press Enter to start.")
  _ = readLine()

  let session = SensorCaptureSession()
  session.start()

  var keyBytes = 0
  let startedAt = Date()

  for index in 1...repeats {
    print("[\(index)/\(repeats)] \(phrase)")
    keyBytes += (readLine() ?? "").utf8.count
  }

  let elapsed = Date().timeIntervalSince(startedAt)
  session.stop()
  let capture = session.state.snapshot()

  let result = RoundResult(
    label: label,
    seconds: elapsed,
    keyBytes: keyBytes,
    events: capture.totalReports,
    activeElements: capture.deviceCount,
    averageEnergy: capture.averageImpact,
    peakEnergy: capture.peakImpact
  )

  print("Result: keys=\(result.keyBytes) events=\(result.events) active=\(result.activeElements) avg=\(fixed(result.averageEnergy, 4)) peak=\(fixed(result.peakEnergy, 4))")
  print("Rhythm: duration=\(fixed(result.seconds, 2))s chars/s=\(fixed(result.charsPerSecond, 2))")
  print("")
  return result
}

func printCalibrationGraph(_ results: [RoundResult]) {
  print("")
  print("Sensor graph")
  print("Each bar shows peak sensor energy. Avg is better for sustained force; peak is better for impact.")
  print("")

  let maxPeak = max(results.map(\.peakEnergy).max() ?? 0, 0.001)
  for result in results {
    let width = Int((result.peakEnergy / maxPeak * 32.0).rounded())
    let bar = String(repeating: "#", count: max(0, width))
    let paddedLabel = result.label.padding(toLength: 10, withPad: " ", startingAt: 0)
    print("\(paddedLabel) \(bar) peak=\(fixed(result.peakEnergy, 4)) avg=\(fixed(result.averageEnergy, 4)) keys=\(result.keyBytes) events=\(result.events)")
  }

  let light = results.filter { $0.label.hasPrefix("light") }.map(\.peakEnergy)
  let strong = results.filter { $0.label.hasPrefix("strong") }.map(\.peakEnergy)
  if let lightAvg = average(light), let strongAvg = average(strong) {
    print("")
    print("light peak avg:  \(fixed(lightAvg, 4))")
    print("strong peak avg: \(fixed(strongAvg, 4))")
    if strongAvg > lightAvg * 1.25 {
      print("Signal verdict: usable separation between soft and firm typing.")
    } else if strongAvg > lightAvg {
      print("Signal verdict: weak separation; calibration or lower-level sensor access may be needed.")
    } else {
      print("Signal verdict: no separation yet. Try longer rounds or check sensor event access.")
    }
  }

  if results.allSatisfy({ $0.events == 0 }) {
    print("")
    print("Sensor verdict: no SPU/HID motion events reached this process.")
    print("Falling back to keyboard rhythm, which measures how intensely you type without reading key contents.")
  }

  print("")
  print("Keyboard rhythm graph")
  print("Each bar shows characters per second for the line-entry rounds.")
  print("")

  let maxRate = max(results.map(\.charsPerSecond).max() ?? 0, 0.001)
  for result in results {
    let width = Int((result.charsPerSecond / maxRate * 32.0).rounded())
    let bar = String(repeating: "#", count: max(0, width))
    let paddedLabel = result.label.padding(toLength: 10, withPad: " ", startingAt: 0)
    print("\(paddedLabel) \(bar) chars/s=\(fixed(result.charsPerSecond, 2)) duration=\(fixed(result.seconds, 2))s keys=\(result.keyBytes)")
  }

  let lightRate = results.filter { $0.label.hasPrefix("light") }.map(\.charsPerSecond)
  let strongRate = results.filter { $0.label.hasPrefix("strong") }.map(\.charsPerSecond)
  if let lightAvg = average(lightRate), let strongAvg = average(strongRate) {
    print("")
    print("light rhythm avg:  \(fixed(lightAvg, 2)) chars/s")
    print("strong rhythm avg: \(fixed(strongAvg, 2)) chars/s")
    if strongAvg > lightAvg * 1.15 {
      print("Rhythm verdict: strong rounds were measurably more intense.")
    } else if lightAvg > strongAvg * 1.15 {
      print("Rhythm verdict: light rounds were faster; force and rhythm are not aligned in this run.")
    } else {
      print("Rhythm verdict: soft and firm rounds were similar by timing. Use a longer phrase or more repeats.")
    }
  }
}
