import AppKit
import KeyMoodCore

final class RegimeRailView: NSView {
  private let moods: [RuntimeMood] = [.calm, .focused, .charged, .intense, .relaxing]
  private var mood: RuntimeMood = .calm
  private var character: MenuBarCharacter = .submarine
  private var paused = false
  private var noSensor = false

  override var isFlipped: Bool {
    true
  }

  init() {
    super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 54))
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    nil
  }

  func update(mood: RuntimeMood, character: MenuBarCharacter, paused: Bool, noSensor: Bool) {
    self.mood = mood
    self.character = character
    self.paused = paused
    self.noSensor = noSensor
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let labels = moods.map { character.shortLabel(for: $0) }
    let activeIndex = moods.firstIndex(of: mood) ?? 0
    let disabled = paused || noSensor
    let content = bounds.insetBy(dx: 12, dy: 7)
    let segmentWidth = content.width / CGFloat(labels.count)
    let capsuleY: CGFloat = 9
    let capsuleHeight: CGFloat = 23
    let indicatorY: CGFloat = 39

    for (index, label) in labels.enumerated() {
      let segment = NSRect(
        x: content.minX + CGFloat(index) * segmentWidth,
        y: content.minY,
        width: segmentWidth,
        height: content.height
      )
      let isActive = index == activeIndex
      let alpha: CGFloat = disabled ? 0.42 : 1.0

      if isActive {
        let capsule = NSRect(
          x: segment.minX + 3,
          y: capsuleY,
          width: max(segment.width - 6, 34),
          height: capsuleHeight
        )
        let capsuleColor = NSColor.controlAccentColor.withAlphaComponent(0.20 * alpha)
        capsuleColor.setFill()
        NSBezierPath(roundedRect: capsule, xRadius: 9, yRadius: 9).fill()
      }

      let font = fittingFont(for: label, width: max(segment.width - 8, 20), active: isActive)
      let textColor = textColor(active: isActive, disabled: disabled)
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byClipping
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraph
      ]
      let textRect = NSRect(
        x: segment.minX + 2,
        y: capsuleY + 5,
        width: max(segment.width - 4, 20),
        height: 15
      )
      label.draw(with: textRect, options: [.usesLineFragmentOrigin], attributes: attributes)

      if isActive {
        drawIndicator(centerX: segment.midX, y: indicatorY, alpha: alpha)
      }
    }
  }

  private func fittingFont(for label: String, width: CGFloat, active: Bool) -> NSFont {
    let weight: NSFont.Weight = active ? .semibold : .regular
    let preferredSize: CGFloat = active ? 11 : 10
    let minimumSize: CGFloat = 8.8

    var size = preferredSize
    while size > minimumSize {
      let font = NSFont.systemFont(ofSize: size, weight: weight)
      let measuredWidth = (label as NSString).size(withAttributes: [.font: font]).width
      if measuredWidth <= width {
        return font
      }
      size -= 0.4
    }

    return NSFont.systemFont(ofSize: minimumSize, weight: weight)
  }

  private func textColor(active: Bool, disabled: Bool) -> NSColor {
    if disabled {
      return NSColor.secondaryLabelColor.withAlphaComponent(active ? 0.70 : 0.45)
    }

    return active ? .labelColor : NSColor.secondaryLabelColor.withAlphaComponent(0.78)
  }

  private func drawIndicator(centerX: CGFloat, y: CGFloat, alpha: CGFloat) {
    let radius: CGFloat = 2.4
    let dot = NSRect(x: centerX - radius, y: y, width: radius * 2, height: radius * 2)
    NSColor.labelColor.withAlphaComponent(0.88 * alpha).setFill()
    NSBezierPath(ovalIn: dot).fill()
  }
}
