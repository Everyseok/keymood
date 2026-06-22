import Foundation

public enum RuntimeMood: Int {
  case calm
  case focused
  case charged
  case intense
  case relaxing

  public var label: String {
    switch self {
    case .calm:
      return "Dead Slow"
    case .focused:
      return "Slow Ahead"
    case .charged:
      return "Half Ahead"
    case .intense:
      return "Full Ahead"
    case .relaxing:
      return "Standby"
    }
  }
}

public struct MoodThresholds: Equatable, Sendable {
  public let focusedEnergy: Double
  public let focusedImpact: Double
  public let chargedEnergy: Double
  public let chargedImpact: Double
  public let intenseEnergy: Double
  public let intenseImpact: Double

  public init(
    focusedEnergy: Double,
    focusedImpact: Double,
    chargedEnergy: Double,
    chargedImpact: Double,
    intenseEnergy: Double,
    intenseImpact: Double
  ) {
    self.focusedEnergy = focusedEnergy
    self.focusedImpact = focusedImpact
    self.chargedEnergy = chargedEnergy
    self.chargedImpact = chargedImpact
    self.intenseEnergy = intenseEnergy
    self.intenseImpact = intenseImpact
  }

  public static let standard = MoodThresholds(
    focusedEnergy: 0.08,
    focusedImpact: 0.006,
    chargedEnergy: 0.18,
    chargedImpact: 0.018,
    intenseEnergy: 0.45,
    intenseImpact: 0.04
  )

  public static let responsiveMenuBar = MoodThresholds(
    focusedEnergy: 0.06,
    focusedImpact: 0.0045,
    chargedEnergy: 0.14,
    chargedImpact: 0.012,
    intenseEnergy: 0.26,
    intenseImpact: 0.022
  )
}

public final class MoodStateMachine {
  public let startedAt = Date()
  public let intenseDwell: TimeInterval
  public let thresholds: MoodThresholds
  public let minimumStateDuration: TimeInterval
  public let relaxDurationBonus: TimeInterval
  public private(set) var current: RuntimeMood = .calm
  public private(set) var target: RuntimeMood = .calm
  public private(set) var poseEnergy = 0.0
  private var currentSince = Date()
  private var intenseCandidateSince: Date?
  private var relaxingSince: Date?

  public init(
    intenseDwell: TimeInterval,
    thresholds: MoodThresholds = .standard,
    minimumStateDuration: TimeInterval = 0,
    relaxDurationBonus: TimeInterval = 0
  ) {
    self.intenseDwell = max(0.2, intenseDwell)
    self.thresholds = thresholds
    self.minimumStateDuration = max(0, minimumStateDuration)
    self.relaxDurationBonus = max(0, relaxDurationBonus)
  }

  public func update(energy: Double, impact: Double, now: Date) -> RuntimeMood {
    target = classifyTarget(energy: energy, impact: impact)
    updatePoseEnergy(signalEnergy: energy)

    switch current {
    case .intense:
      if target == .intense {
        relaxingSince = nil
        return current
      }
      relaxingSince = now
      intenseCandidateSince = nil
      return transition(to: .relaxing, now: now)

    case .relaxing:
      if target == .intense {
        return updateIntenseCandidate(now: now, fallback: .charged)
      }
      if now.timeIntervalSince(relaxingSince ?? now) < relaxDuration(for: poseEnergy) {
        return current
      }
      relaxingSince = nil
      return transition(to: target == .charged ? .focused : target, now: now)

    case .calm, .focused, .charged:
      if target == .intense {
        return updateIntenseCandidate(now: now, fallback: .charged)
      }
      intenseCandidateSince = nil
      return transition(to: target, now: now)
    }
  }

  private func transition(to next: RuntimeMood, now: Date) -> RuntimeMood {
    guard next != current else {
      return current
    }

    if minimumStateDuration > 0, now.timeIntervalSince(currentSince) < minimumStateDuration {
      return current
    }

    current = next
    currentSince = now
    return current
  }

  private func updateIntenseCandidate(now: Date, fallback: RuntimeMood) -> RuntimeMood {
    if intenseCandidateSince == nil {
      intenseCandidateSince = now
    }

    if now.timeIntervalSince(intenseCandidateSince ?? now) >= intenseDwell {
      relaxingSince = nil
      return transition(to: .intense, now: now)
    }

    return transition(to: fallback, now: now)
  }

  private func classifyTarget(energy: Double, impact: Double) -> RuntimeMood {
    if energy >= thresholds.intenseEnergy || impact >= thresholds.intenseImpact {
      return .intense
    }
    if energy >= thresholds.chargedEnergy || impact >= thresholds.chargedImpact {
      return .charged
    }
    if energy >= thresholds.focusedEnergy || impact >= thresholds.focusedImpact {
      return .focused
    }
    return .calm
  }

  private func updatePoseEnergy(signalEnergy: Double) {
    if signalEnergy > poseEnergy {
      poseEnergy = poseEnergy * 0.35 + signalEnergy * 0.65
    } else {
      poseEnergy *= 0.92
    }

    if poseEnergy < 0.01 {
      poseEnergy = 0
    }
  }

  private func relaxDuration(for energy: Double) -> TimeInterval {
    let base: TimeInterval
    if energy >= thresholds.intenseEnergy {
      base = 2.2
    } else if energy >= thresholds.chargedEnergy {
      base = 1.6
    } else {
      base = 1.0
    }
    return base + relaxDurationBonus
  }
}
