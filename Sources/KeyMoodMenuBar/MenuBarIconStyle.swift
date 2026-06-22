import Foundation
import KeyMoodCore

struct MenuBarIconStyle {
  let propellerStep: Double
  let bobAmplitude: Double
  let bobFrequency: Double
  let shakeAmplitude: Double
  let leanDegrees: Double
  let smokeCount: Int
  let wakeCount: Int
  let eyeStyle: EyeStyle
  let alpha: Double
  let roamingPhaseStep: Double

  var characterMotionStep: Double {
    guard propellerStep > 0, alpha > 0.5 else {
      return 0
    }

    switch eyeStyle {
    case .round:
      return .pi / 20
    case .oval:
      return .pi / 12
    case .flame:
      return .pi / 8
    case .overdrive:
      return .pi / 5.5
    case .sleepy:
      return .pi / 16
    }
  }

  static func make(mood: RuntimeMood, paused: Bool, noSensor: Bool) -> MenuBarIconStyle {
    if paused {
      return MenuBarIconStyle(
        propellerStep: 0,
        bobAmplitude: 0,
        bobFrequency: 0.2,
        shakeAmplitude: 0,
        leanDegrees: 0,
        smokeCount: 0,
        wakeCount: 0,
        eyeStyle: .sleepy,
        alpha: 0.45,
        roamingPhaseStep: 0
      )
    }

    if noSensor {
      return MenuBarIconStyle(
        propellerStep: 0.12,
        bobAmplitude: 0,
        bobFrequency: 0.2,
        shakeAmplitude: 0,
        leanDegrees: 0,
        smokeCount: 0,
        wakeCount: 0,
        eyeStyle: .round,
        alpha: 0.42,
        roamingPhaseStep: 0
      )
    }

    switch mood {
    case .calm:
      return MenuBarIconStyle(
        propellerStep: .pi / 16,
        bobAmplitude: 0.25,
        bobFrequency: 0.16,
        shakeAmplitude: 0,
        leanDegrees: 0,
        smokeCount: 1,
        wakeCount: 0,
        eyeStyle: .round,
        alpha: 1.0,
        roamingPhaseStep: 0.055
      )
    case .focused:
      return MenuBarIconStyle(
        propellerStep: .pi / 7,
        bobAmplitude: 0.75,
        bobFrequency: 0.24,
        shakeAmplitude: 0,
        leanDegrees: 0,
        smokeCount: 2,
        wakeCount: 1,
        eyeStyle: .oval,
        alpha: 1.0,
        roamingPhaseStep: 0.09
      )
    case .charged:
      return MenuBarIconStyle(
        propellerStep: .pi / 5,
        bobAmplitude: 1.1,
        bobFrequency: 0.38,
        shakeAmplitude: 0.35,
        leanDegrees: -2.2,
        smokeCount: 3,
        wakeCount: 3,
        eyeStyle: .flame,
        alpha: 1.0,
        roamingPhaseStep: 0.14
      )
    case .intense:
      return MenuBarIconStyle(
        propellerStep: .pi / 3.2,
        bobAmplitude: 1.35,
        bobFrequency: 0.58,
        shakeAmplitude: 0.9,
        leanDegrees: -5.2,
        smokeCount: 7,
        wakeCount: 5,
        eyeStyle: .overdrive,
        alpha: 1.0,
        roamingPhaseStep: 0.20
      )
    case .relaxing:
      return MenuBarIconStyle(
        propellerStep: .pi / 13,
        bobAmplitude: 0.55,
        bobFrequency: 0.20,
        shakeAmplitude: 0,
        leanDegrees: 0,
        smokeCount: 2,
        wakeCount: 1,
        eyeStyle: .sleepy,
        alpha: 1.0,
        roamingPhaseStep: 0.07
      )
    }
  }

  enum EyeStyle {
    case round
    case oval
    case sleepy
    case flame
    case overdrive
  }
}
