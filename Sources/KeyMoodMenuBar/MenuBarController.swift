import AppKit
import Foundation
import KeyMoodCore
import KeyMoodSensor

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let moodItem = NSMenuItem()
  private let regimeRailItem = NSMenuItem()
  private let regimeRailView = RegimeRailView()
  private let characterItem = NSMenuItem()
  private let characterMenu = NSMenu()
  private let submarineItem = NSMenuItem(title: MenuBarCharacter.submarine.displayName, action: #selector(selectSubmarineCharacter), keyEquivalent: "")
  private let cheerFrogItem = NSMenuItem(title: MenuBarCharacter.cheerFrog.displayName, action: #selector(selectCheerFrogCharacter), keyEquivalent: "")
  private let sensitivityItem = NSMenuItem()
  private let currentStateLabel = NSTextField(labelWithString: "Current: Dead Slow")
  private let sensitivityLabel = NSTextField(labelWithString: "Sensitivity 30")
  private let sensitivitySlider = NSSlider(
    value: MenuBarSensitivity.defaultValue,
    minValue: MenuBarSensitivity.minimum,
    maxValue: MenuBarSensitivity.maximum,
    target: nil,
    action: nil
  )
  private let roamingItem = NSMenuItem()
  private let roamingLabel = NSTextField(labelWithString: "Roaming Mode")
  private let roamingSwitch = NSSwitch(frame: NSRect(x: 205, y: 6, width: 42, height: 24))
  private let pauseItem = NSMenuItem()
  private let quitItem = NSMenuItem()

  private var timer: Timer?
  private var state = RawMotionCaptureState()
  private var reader: AppleSPUSensorReader?
  private var machine = makeMenuBarMoodMachine()
  private var currentMood: RuntimeMood = .calm
  private var selectedCharacter: MenuBarCharacter = .submarine
  private var sensitivity = MenuBarSensitivity.defaultValue
  private var paused = false
  private var roamingEnabled = UserDefaults.standard.bool(forKey: "MenuBarRoamingEnabled")
  private var roamingProgress: CGFloat = 1.0
  private var roamingDirection: CGFloat = -1.0
  private var animationTick = 0
  private var cheerFrogPhase: CGFloat = 0
  private var didStart = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    start()
  }

  func start() {
    guard !didStart else {
      return
    }

    didStart = true
    NSApplication.shared.setActivationPolicy(.accessory)
    configureStatusItem()
    startSensor()

    timer = Timer.scheduledTimer(
      timeInterval: 0.06,
      target: self,
      selector: #selector(timerFired),
      userInfo: nil,
      repeats: true
    )
  }

  func applicationWillTerminate(_ notification: Notification) {
    timer?.invalidate()
    reader?.stop()
  }

  private func configureStatusItem() {
    if let button = statusItem.button {
      button.title = ""
      button.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
      button.imagePosition = .imageLeading
      button.imageScaling = .scaleProportionallyDown
    }

    statusItem.menu = menu
    menu.autoenablesItems = false

    moodItem.isEnabled = false

    menu.addItem(moodItem)
    configureRegimeRail()
    menu.addItem(regimeRailItem)
    menu.addItem(.separator())

    configureCharacterMenu()
    menu.addItem(characterItem)
    menu.addItem(.separator())
    configureSensitivityControl()
    menu.addItem(sensitivityItem)
    menu.addItem(.separator())

    configureRoamingControl()
    menu.addItem(roamingItem)
    menu.addItem(.separator())

    pauseItem.target = self
    pauseItem.action = #selector(togglePause)
    menu.addItem(pauseItem)

    quitItem.title = "Quit KeyMood"
    quitItem.target = self
    quitItem.action = #selector(quit)
    menu.addItem(quitItem)

    refreshMenu()
  }

  private func configureRegimeRail() {
    regimeRailItem.view = regimeRailView
  }

  private func configureCharacterMenu() {
    characterItem.title = "Character"
    characterItem.submenu = characterMenu

    submarineItem.target = self
    cheerFrogItem.target = self

    characterMenu.addItem(submarineItem)
    characterMenu.addItem(cheerFrogItem)
  }

  private func configureSensitivityControl() {
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 76))

    currentStateLabel.frame = NSRect(x: 14, y: 53, width: 232, height: 18)
    currentStateLabel.font = .menuFont(ofSize: 12)
    currentStateLabel.textColor = .labelColor
    container.addSubview(currentStateLabel)

    sensitivityLabel.frame = NSRect(x: 14, y: 31, width: 232, height: 18)
    sensitivityLabel.font = .menuFont(ofSize: 12)
    sensitivityLabel.textColor = .secondaryLabelColor
    container.addSubview(sensitivityLabel)

    sensitivitySlider.frame = NSRect(x: 10, y: 5, width: 238, height: 24)
    sensitivitySlider.integerValue = Int(sensitivity)
    sensitivitySlider.target = self
    sensitivitySlider.action = #selector(sensitivityChanged)
    sensitivitySlider.isContinuous = true
    container.addSubview(sensitivitySlider)

    sensitivityItem.view = container
  }

  private func configureRoamingControl() {
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 36))

    roamingLabel.frame = NSRect(x: 14, y: 9, width: 176, height: 18)
    roamingLabel.font = .menuFont(ofSize: 12)
    roamingLabel.textColor = .labelColor
    container.addSubview(roamingLabel)

    roamingSwitch.state = roamingEnabled ? .on : .off
    roamingSwitch.target = self
    roamingSwitch.action = #selector(roamingSwitchChanged)
    container.addSubview(roamingSwitch)

    roamingItem.view = container
  }

  private func startSensor() {
    state = RawMotionCaptureState()
    machine = makeMenuBarMoodMachine()

    let nextReader = AppleSPUSensorReader(state: state)
    _ = nextReader.start()
    reader = nextReader

    refreshMenu()
  }

  private func updateMood() {
    guard !paused else {
      currentMood = .calm
      refreshMenu()
      return
    }

    guard let reader, reader.hasDevices else {
      currentMood = .calm
      refreshMenu()
      return
    }

    let snapshot = state.snapshot()
    let multiplier = MenuBarSensitivity(sensitivity).multiplier
    let adjustedImpact = min(snapshot.lastImpact * multiplier, 1.0)
    let adjustedEnergy = min(snapshot.smoothedEnergy * multiplier, 1.0)
    currentMood = machine.update(energy: adjustedEnergy, impact: adjustedImpact, now: Date())

    refreshMenu()
  }

  @objc private func timerFired(_ timer: Timer) {
    animationTick += 1
    advanceCheerFrogPhase()
    advanceRoamingPosition()
    updateMood()
  }

  private func advanceCheerFrogPhase() {
    let noSensor = reader?.hasDevices != true && !paused
    let style = MenuBarIconStyle.make(mood: currentMood, paused: paused, noSensor: noSensor)
    let step = CGFloat(style.characterMotionStep)
    guard step > 0 else {
      return
    }

    let fullCycle = CGFloat.pi * 2
    cheerFrogPhase = (cheerFrogPhase + step).truncatingRemainder(dividingBy: fullCycle)
  }

  private func advanceRoamingPosition() {
    guard roamingEnabled else {
      return
    }

    let noSensor = reader?.hasDevices != true && !paused
    let style = MenuBarIconStyle.make(mood: currentMood, paused: paused, noSensor: noSensor)
    let step = CGFloat(style.roamingPhaseStep / Double.pi)
    guard step > 0 else {
      return
    }

    let nextProgress = roamingProgress + roamingDirection * step
    if nextProgress >= 1 {
      roamingProgress = 1
      roamingDirection = -1
    } else if nextProgress <= 0 {
      roamingProgress = 0
      roamingDirection = 1
    } else {
      roamingProgress = nextProgress
    }
  }

  private func refreshMenu() {
    let noSensor = reader?.hasDevices != true && !paused
    let presentation = MenuBarPresentation.make(mood: currentMood, character: selectedCharacter, paused: paused, noSensor: noSensor)
    let roamingLength = MenuBarIconRenderer.roamingStatusLength(for: statusItem.button?.window?.screen ?? NSScreen.main)
    statusItem.length = roamingEnabled ? roamingLength : NSStatusItem.variableLength

    if let button = statusItem.button {
      button.title = ""
      button.image = MenuBarCharacterRenderer.image(
        for: selectedCharacter,
        mood: currentMood,
        paused: paused,
        noSensor: noSensor,
        tick: animationTick,
        animationPhase: cheerFrogPhase,
        roaming: roamingEnabled,
        roamingLength: roamingLength,
        roamingProgress: roamingProgress,
        roamingDirection: roamingDirection
      )
    }

    moodItem.title = presentation.menuTitle
    regimeRailView.update(mood: currentMood, character: selectedCharacter, paused: paused, noSensor: noSensor)
    currentStateLabel.stringValue = "Current: \(presentation.currentLabel)"
    let currentSensitivity = MenuBarSensitivity(sensitivity)
    sensitivityLabel.stringValue = "Sensitivity \(currentSensitivity.integerValue)"
    sensitivitySlider.integerValue = currentSensitivity.integerValue
    roamingSwitch.state = roamingEnabled ? .on : .off
    updateCharacterSelectionState()
    pauseItem.title = paused ? "Resume" : "Pause"
  }

  private func updateCharacterSelectionState() {
    submarineItem.state = selectedCharacter == .submarine ? .on : .off
    cheerFrogItem.state = selectedCharacter == .cheerFrog ? .on : .off
  }

  @objc private func selectSubmarineCharacter() {
    selectedCharacter = .submarine
    refreshMenu()
  }

  @objc private func selectCheerFrogCharacter() {
    selectedCharacter = .cheerFrog
    refreshMenu()
  }

  @objc private func roamingSwitchChanged(_ sender: NSSwitch) {
    roamingEnabled = sender.state == .on
    if roamingEnabled {
      roamingProgress = 1
      roamingDirection = -1
    }
    UserDefaults.standard.set(roamingEnabled, forKey: "MenuBarRoamingEnabled")
    refreshMenu()
  }

  @objc private func togglePause() {
    if paused {
      paused = false
      startSensor()
    } else {
      paused = true
      reader?.stop()
      reader = nil
      currentMood = .calm
      refreshMenu()
    }
  }

  @objc private func sensitivityChanged(_ sender: NSSlider) {
    sensitivity = MenuBarSensitivity(Double(sender.integerValue)).value
    machine = makeMenuBarMoodMachine()
    refreshMenu()
  }

  @objc private func quit() {
    reader?.stop()
    NSApplication.shared.terminate(nil)
  }
}

private func makeMenuBarMoodMachine() -> MoodStateMachine {
  MoodStateMachine(
    intenseDwell: 0.65,
    thresholds: .responsiveMenuBar,
    minimumStateDuration: 1.0,
    relaxDurationBonus: 1.0
  )
}
