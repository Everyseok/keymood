import Foundation

func readDoubleFlag(_ name: String, from arguments: [String]) -> Double? {
  guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
    return nil
  }
  return Double(arguments[index + 1])
}

func fixed(_ value: Double, _ digits: Int) -> String {
  String(format: "%.\(digits)f", value)
}

func energyBar(_ energy: Double) -> String {
  let width = 18
  let filled = min(width, max(0, Int((energy * Double(width) * 2.0).rounded())))
  return String(repeating: "#", count: filled) + String(repeating: "-", count: width - filled)
}

func rawMoodProxy(impact: Double, energy: Double, reportsPerSecond: Double) -> String {
  if reportsPerSecond < 1.0 {
    return "no-signal"
  }
  if impact < 0.004 && energy < 0.08 {
    return "Dead Slow"
  }
  if impact < 0.012 && energy < 0.18 {
    return "Slow Ahead"
  }
  if impact < 0.035 && energy < 0.45 {
    return "Half Ahead"
  }
  return "Full Ahead"
}

func moodProxy(energy: Double, eventsPerSecond: Double) -> String {
  if eventsPerSecond < 1.0 {
    return "idle"
  }
  if energy < 0.015 {
    return "Dead Slow"
  }
  if energy < 0.05 {
    return "Slow Ahead"
  }
  if energy < 0.12 {
    return "Half Ahead"
  }
  return "Full Ahead"
}

func average(_ values: [Double]) -> Double? {
  guard !values.isEmpty else {
    return nil
  }
  return values.reduce(0, +) / Double(values.count)
}

func reportLengthsDescription(_ lengths: [Int: Int]) -> String {
  let description = lengths
    .sorted { $0.key < $1.key }
    .map { "\($0.key):\($0.value)" }
    .joined(separator: ", ")
  return description.isEmpty ? "-" : description
}
