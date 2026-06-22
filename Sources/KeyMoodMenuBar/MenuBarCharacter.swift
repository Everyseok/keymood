import AppKit
import KeyMoodCore

enum MenuBarCharacter {
  case submarine
  case cheerFrog

  var displayName: String {
    switch self {
    case .submarine:
      return "Submarine"
    case .cheerFrog:
      return "Cheer Frog"
    }
  }

  func displayLabel(for mood: RuntimeMood) -> String {
    switch self {
    case .submarine:
      return mood.label
    case .cheerFrog:
      switch mood {
      case .calm:
        return "Ready"
      case .focused:
        return "Cheer"
      case .charged:
        return "Hype"
      case .intense:
        return "Frenzy"
      case .relaxing:
        return "Cooldown"
      }
    }
  }

  func shortLabel(for mood: RuntimeMood) -> String {
    switch self {
    case .submarine:
      switch mood {
      case .calm:
        return "Dead"
      case .focused:
        return "Slow"
      case .charged:
        return "Half"
      case .intense:
        return "Full"
      case .relaxing:
        return "Standby"
      }
    case .cheerFrog:
      switch mood {
      case .calm:
        return "Ready"
      case .focused:
        return "Cheer"
      case .charged:
        return "Hype"
      case .intense:
        return "Frenzy"
      case .relaxing:
        return "Cool"
      }
    }
  }
}

@MainActor
enum MenuBarCharacterRenderer {
  static func image(
    for character: MenuBarCharacter,
    mood: RuntimeMood,
    paused: Bool,
    noSensor: Bool,
    tick: Int,
    animationPhase: CGFloat,
    roaming: Bool,
    roamingLength: CGFloat,
    roamingProgress: CGFloat,
    roamingDirection: CGFloat
  ) -> NSImage {
    switch character {
    case .submarine:
      return MenuBarIconRenderer.image(
        mood: mood,
        paused: paused,
        noSensor: noSensor,
        tick: tick,
        roaming: roaming,
        roamingLength: roamingLength,
        roamingProgress: roamingProgress,
        roamingDirection: roamingDirection
      )
    case .cheerFrog:
      return MenuBarCheerFrogRenderer.image(
        mood: mood,
        paused: paused,
        noSensor: noSensor,
        tick: tick,
        animationPhase: animationPhase,
        roaming: roaming,
        roamingLength: roamingLength,
        roamingProgress: roamingProgress,
        roamingDirection: roamingDirection
      )
    }
  }
}
