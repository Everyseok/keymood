import Foundation
import IOKit
import IOKit.hid

public struct SPUWakeResult {
  public let drivers: Int
  public let successes: Int
  public let failures: Int

  public init(drivers: Int, successes: Int, failures: Int) {
    self.drivers = drivers
    self.successes = successes
    self.failures = failures
  }
}

public final class AppleSPUSensorReader: @unchecked Sendable {
  public let state: RawMotionCaptureState
  public private(set) var wakeResult = SPUWakeResult(drivers: 0, successes: 0, failures: 0)
  private var devices: [RawReportDevice] = []
  private var started = false

  public init(state: RawMotionCaptureState = RawMotionCaptureState()) {
    self.state = state
  }

  @discardableResult
  public func start() -> SPUWakeResult {
    guard !started else {
      return wakeResult
    }

    wakeResult = SensorService.wakeSPUDrivers()
    devices = SensorService.openRawAccelerometerDevices(state: state)
    started = true
    return wakeResult
  }

  public func poll(interval: TimeInterval) {
    CFRunLoopRunInMode(.defaultMode, interval, false)
  }

  public func stop() {
    guard started else {
      return
    }

    for device in devices {
      device.close()
    }
    devices.removeAll()
    started = false
  }

  public var hasDevices: Bool {
    !devices.isEmpty
  }

  deinit {
    stop()
  }
}

public enum SensorService {
  public static func makeManager(candidateOnly: Bool) -> IOHIDManager {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    if candidateOnly {
      let matches: [[String: Any]] = [
        [
          kIOHIDTransportKey: "SPU",
          kIOHIDPrimaryUsagePageKey: 0xff00
        ],
        [
          kIOHIDTransportKey: "SPU",
          kIOHIDPrimaryUsagePageKey: 0xff0c
        ],
        [
          kIOHIDTransportKey: "SPU",
          kIOHIDPrimaryUsagePageKey: 0x20
        ]
      ]
      IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
    } else {
      IOHIDManagerSetDeviceMatching(manager, nil)
    }

    return manager
  }

  @discardableResult
  public static func openManager(_ manager: IOHIDManager) -> IOReturn {
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  public static func wakeSPUDrivers() -> SPUWakeResult {
    var iterator: io_iterator_t = 0
    guard let matching = IOServiceMatching("AppleSPUHIDDriver") else {
      return SPUWakeResult(drivers: 0, successes: 0, failures: 0)
    }

    let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
    guard result == kIOReturnSuccess else {
      return SPUWakeResult(drivers: 0, successes: 0, failures: 1)
    }

    defer {
      IOObjectRelease(iterator)
    }

    var drivers = 0
    var successes = 0
    var failures = 0

    while true {
      let service = IOIteratorNext(iterator)
      if service == 0 {
        break
      }

      drivers += 1
      let writes = [
        setRegistryInt32(service, "SensorPropertyReportingState", 1),
        setRegistryInt32(service, "SensorPropertyPowerState", 1),
        setRegistryInt32(service, "ReportInterval", 1000)
      ]

      successes += writes.filter { $0 == kIOReturnSuccess }.count
      failures += writes.filter { $0 != kIOReturnSuccess }.count
      IOObjectRelease(service)
    }

    return SPUWakeResult(drivers: drivers, successes: successes, failures: failures)
  }

  static func openRawAccelerometerDevices(state: RawMotionCaptureState) -> [RawReportDevice] {
    var iterator: io_iterator_t = 0
    guard let matching = IOServiceMatching("AppleSPUHIDDevice") else {
      state.addOpenFailure("IOServiceMatching(AppleSPUHIDDevice) failed.")
      return []
    }

    let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
    guard result == kIOReturnSuccess else {
      state.addOpenFailure("IOServiceGetMatchingServices failed: \(kernReturnDescription(result))")
      return []
    }

    defer {
      IOObjectRelease(iterator)
    }

    var devices: [RawReportDevice] = []

    while true {
      let service = IOIteratorNext(iterator)
      if service == 0 {
        break
      }

      defer {
        IOObjectRelease(service)
      }

      let usagePage = registryIntProperty(service, "PrimaryUsagePage") ?? 0
      let usage = registryIntProperty(service, "PrimaryUsage") ?? 0

      guard usagePage == 0xff00, usage == 3 else {
        continue
      }

      guard let hidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
        state.addOpenFailure("IOHIDDeviceCreate failed for AppleSPU accelerometer.")
        continue
      }

      let name = rawRegistryDeviceName(service)
      let device = RawReportDevice(device: hidDevice, name: name, state: state)
      let openResult = device.openAndSchedule()

      if openResult == kIOReturnSuccess {
        state.addDevice(name)
        devices.append(device)
      } else {
        state.addOpenFailure("\(name) open failed: \(kernReturnDescription(openResult))")
      }
    }

    if devices.isEmpty {
      state.addOpenFailure("No AppleSPU accelerometer matched usagePage=0xFF00 usage=3.")
    }

    return devices
  }

  public static func copyDevices(from manager: IOHIDManager) -> [IOHIDDevice] {
    guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
      return []
    }
    return Array(deviceSet)
  }

  public static func isCandidateSensor(_ device: IOHIDDevice) -> Bool {
    let transport = stringProperty(device, kIOHIDTransportKey)
    let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey)
    let rates = stringProperty(device, "sensor_rates")

    guard transport == "SPU" else {
      return false
    }

    return usagePage == 0xff00
      || usagePage == 0xff0c
      || usagePage == 0x20
      || (rates?.isEmpty == false)
  }

  public static func deviceSortKey(_ device: IOHIDDevice) -> String {
    [
      isCandidateSensor(device) ? "0" : "1",
      stringProperty(device, kIOHIDTransportKey) ?? "",
      intProperty(device, kIOHIDPrimaryUsagePageKey).map(String.init) ?? "",
      intProperty(device, kIOHIDPrimaryUsageKey).map(String.init) ?? "",
      stringProperty(device, kIOHIDProductKey) ?? ""
    ].joined(separator: "|")
  }

  public static func deviceName(_ device: IOHIDDevice) -> String {
    let product = stringProperty(device, kIOHIDProductKey) ?? "SPU"
    let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey).map(String.init) ?? "?"
    let usage = intProperty(device, kIOHIDPrimaryUsageKey).map(String.init) ?? "?"
    return "\(product)[\(usagePage):\(usage)]"
  }

  public static func elementKey(_ element: IOHIDElement, device: IOHIDDevice) -> String {
    "\(deviceName(device)):\(IOHIDElementGetUsagePage(element)):\(IOHIDElementGetUsage(element))"
  }

  public static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
    guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
      return nil
    }
    return String(describing: value)
  }

  public static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
    guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
      return nil
    }
    if let number = value as? NSNumber {
      return number.intValue
    }
    return Int(String(describing: value))
  }

  public static func boolishProperty(_ device: IOHIDDevice, _ key: String) -> String? {
    guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
      return nil
    }
    if CFGetTypeID(value) == CFBooleanGetTypeID() {
      return CFBooleanGetValue((value as! CFBoolean)) ? "true" : "false"
    }
    return String(describing: value)
  }

  private static func registryProperty(_ entry: io_registry_entry_t, _ key: String) -> AnyObject? {
    guard let value = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0) else {
      return nil
    }
    return value.takeRetainedValue()
  }

  private static func registryIntProperty(_ entry: io_registry_entry_t, _ key: String) -> Int? {
    guard let value = registryProperty(entry, key) else {
      return nil
    }
    if let number = value as? NSNumber {
      return number.intValue
    }
    return Int(String(describing: value))
  }

  private static func registryStringProperty(_ entry: io_registry_entry_t, _ key: String) -> String? {
    guard let value = registryProperty(entry, key) else {
      return nil
    }
    return String(describing: value)
  }

  private static func setRegistryInt32(_ entry: io_registry_entry_t, _ key: String, _ value: Int32) -> IOReturn {
    var mutableValue = value
    guard let number = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &mutableValue) else {
      return kIOReturnError
    }
    return IORegistryEntrySetCFProperty(entry, key as CFString, number)
  }

  private static func rawRegistryDeviceName(_ entry: io_registry_entry_t) -> String {
    let product = registryStringProperty(entry, "Product") ?? "AppleSPU"
    let usagePage = registryIntProperty(entry, "PrimaryUsagePage").map { String($0, radix: 16) } ?? "?"
    let usage = registryIntProperty(entry, "PrimaryUsage").map { String($0, radix: 16) } ?? "?"
    return "\(product)[0x\(usagePage):0x\(usage)]"
  }

  private static func kernReturnDescription(_ result: IOReturn) -> String {
    "0x\(String(UInt32(bitPattern: result), radix: 16))"
  }
}

final class RawReportDevice {
  private let device: IOHIDDevice
  private let name: String
  private let state: RawMotionCaptureState
  private let bufferSize = 4096
  private let reportBuffer: UnsafeMutablePointer<UInt8>
  private var opened = false

  init(device: IOHIDDevice, name: String, state: RawMotionCaptureState) {
    self.device = device
    self.name = name
    self.state = state
    reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    reportBuffer.initialize(repeating: 0, count: bufferSize)
  }

  func openAndSchedule() -> IOReturn {
    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openResult == kIOReturnSuccess else {
      return openResult
    }

    opened = true
    let context = Unmanaged.passUnretained(state).toOpaque()
    IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, bufferSize, { context, result, _, _, reportID, report, reportLength in
      guard let context else {
        return
      }

      let state = Unmanaged<RawMotionCaptureState>.fromOpaque(context).takeUnretainedValue()
      state.handleReport(result: result, reportID: reportID, report: report, length: reportLength)
    }, context)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    return openResult
  }

  func close() {
    guard opened else {
      return
    }

    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    opened = false
  }

  deinit {
    close()
    reportBuffer.deinitialize(count: bufferSize)
    reportBuffer.deallocate()
  }
}

public final class SensorCaptureSession: @unchecked Sendable {
  public let state = RawMotionCaptureState()
  private var shouldRun = true
  private var thread: Thread?

  public init() {}

  public func start() {
    let ready = DispatchSemaphore(value: 0)
    let state = self.state

    thread = Thread {
      let reader = AppleSPUSensorReader(state: state)
      reader.start()
      ready.signal()

      while self.shouldRun {
        reader.poll(interval: 0.02)
      }

      reader.stop()
    }

    thread?.start()
    _ = ready.wait(timeout: .now() + 2)
  }

  public func stop() {
    shouldRun = false
    Thread.sleep(forTimeInterval: 0.1)
  }
}
