import KeyMoodCore

struct MenuBarPresentation {
  let menuTitle: String
  let currentLabel: String
  let statusTitle: String

  static func make(mood: RuntimeMood, character: MenuBarCharacter, paused: Bool, noSensor: Bool) -> MenuBarPresentation {
    if paused {
      return MenuBarPresentation(menuTitle: "KeyMood: Paused", currentLabel: "Paused", statusTitle: "Paused")
    }

    if noSensor {
      return MenuBarPresentation(menuTitle: "KeyMood: No Sensor", currentLabel: "No Sensor", statusTitle: "No Sensor")
    }

    let label = character.displayLabel(for: mood)
    return MenuBarPresentation(menuTitle: "KeyMood: \(label)", currentLabel: label, statusTitle: character.shortLabel(for: mood))
  }
}
