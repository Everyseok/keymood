import Foundation

struct MenuBarSensitivity {
  static let minimum = 0.0
  static let maximum = 100.0
  static let defaultValue = 30.0

  let value: Double

  init(_ value: Double = MenuBarSensitivity.defaultValue) {
    self.value = min(max(value, MenuBarSensitivity.minimum), MenuBarSensitivity.maximum)
  }

  var integerValue: Int {
    Int(value.rounded())
  }

  var multiplier: Double {
    let remappedValue = 60.0 + (value / MenuBarSensitivity.maximum) * 40.0
    let boosted = (remappedValue - 30.0) / 70.0
    return 1.0 + pow(boosted, 2.0) * 19.0
  }
}
