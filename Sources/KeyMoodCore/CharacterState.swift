import Foundation

public struct CharacterState: Equatable {
  public let mood: RuntimeMood
  public let poseEnergy: Double
  public let animationIntensity: Double

  public init(mood: RuntimeMood, poseEnergy: Double) {
    self.mood = mood
    self.poseEnergy = poseEnergy
    self.animationIntensity = min(max(poseEnergy, 0), 1)
  }
}
