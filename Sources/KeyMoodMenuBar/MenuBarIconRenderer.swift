import AppKit
import KeyMoodCore

enum MenuBarIconRenderer {
  static let compactStatusLength: CGFloat = 40
  static let minimumRoamingStatusLength: CGFloat = 260
  static let maximumRoamingStatusLength: CGFloat = 520

  private static let compactImageSize = NSSize(width: compactStatusLength, height: 22)
  private static let sourceBounds = CGRect(x: 1, y: 4, width: 91, height: 50)

  static func roamingStatusLength(for screen: NSScreen?) -> CGFloat {
    let screenWidth = screen?.frame.width ?? 1440
    return min(max(screenWidth * 0.28, minimumRoamingStatusLength), maximumRoamingStatusLength)
  }

  static func image(
    mood: RuntimeMood,
    paused: Bool,
    noSensor: Bool,
    tick: Int,
    roaming: Bool,
    roamingLength: CGFloat,
    roamingProgress: CGFloat,
    roamingDirection: CGFloat
  ) -> NSImage {
    let style = MenuBarIconStyle.make(mood: mood, paused: paused, noSensor: noSensor)
    let imageSize = roaming ? NSSize(width: max(roamingLength, compactStatusLength), height: compactImageSize.height) : compactImageSize
    let image = NSImage(size: imageSize)
    image.lockFocus()
    defer {
      image.unlockFocus()
      image.isTemplate = false
    }

    guard let context = NSGraphicsContext.current?.cgContext else {
      return image
    }

    context.clear(CGRect(origin: .zero, size: imageSize))
    context.saveGState()
    let scale = min(imageSize.width / sourceBounds.width, imageSize.height / sourceBounds.height)
    let drawWidth = sourceBounds.width * scale
    let drawHeight = sourceBounds.height * scale
    let xOffset = roamingXOffset(imageWidth: imageSize.width, drawWidth: drawWidth, roaming: roaming, progress: roamingProgress)
    let yOffset = (imageSize.height - drawHeight) / 2
    let facingLeft = roaming && roamingDirection < 0

    context.translateBy(x: xOffset + (facingLeft ? drawWidth : 0), y: imageSize.height - yOffset)
    context.scaleBy(x: facingLeft ? -scale : scale, y: -scale)
    context.translateBy(x: -sourceBounds.minX, y: -sourceBounds.minY)
    drawSubmarine(context: context, style: style, tick: tick)
    context.restoreGState()

    return image
  }

  private static func roamingXOffset(
    imageWidth: CGFloat,
    drawWidth: CGFloat,
    roaming: Bool,
    progress: CGFloat
  ) -> CGFloat {
    let travel = max(imageWidth - drawWidth, 0)
    guard roaming, travel > 0 else {
      return travel / 2
    }

    return travel * min(max(progress, 0), 1)
  }

  private static func drawSubmarine(context: CGContext, style: MenuBarIconStyle, tick: Int) {
    let bodyColor = NSColor.white.withAlphaComponent(style.alpha)
    let detailColor = NSColor.black.withAlphaComponent(0.82 * style.alpha)
    let outlineColor = NSColor.black.withAlphaComponent(0.40 * style.alpha)
    let flameColor = NSColor(red: 1.0, green: 0.12, blue: 0.04, alpha: style.alpha)
    let smokeColor = NSColor.white.withAlphaComponent(0.86 * style.alpha)

    drawWake(context: context, count: style.wakeCount, alpha: style.alpha, tick: tick)
    drawSmoke(context: context, count: style.smokeCount, color: smokeColor, tick: tick)

    context.saveGState()
    let bob = sin(Double(tick) * style.bobFrequency) * style.bobAmplitude
    let shake = style.shakeAmplitude == 0 ? 0 : (tick.isMultiple(of: 2) ? style.shakeAmplitude : -style.shakeAmplitude)
    let lean = style.leanDegrees * .pi / 180
    context.translateBy(x: 54 + shake, y: 35 + bob)
    context.rotate(by: lean)
    context.translateBy(x: -54, y: -35)

    drawPropeller(context: context, color: bodyColor, outline: outlineColor, angle: Double(tick) * style.propellerStep)
    fillRoundedRect(context: context, x: 22, y: 32, width: 9, height: 8, radius: 1.5, color: bodyColor, stroke: outlineColor)
    drawBody(context: context, fill: bodyColor, stroke: outlineColor)
    drawFin(context: context, fill: bodyColor, stroke: outlineColor)
    fillRoundedRect(context: context, x: 50, y: 13, width: 8, height: 11, radius: 2, color: bodyColor, stroke: outlineColor)
    fillRoundedRect(context: context, x: 47, y: 11, width: 17, height: 5, radius: 2.5, color: bodyColor, stroke: outlineColor)
    drawEyes(context: context, style: style, detail: detailColor, flame: flameColor, highlight: bodyColor, tick: tick)

    context.restoreGState()
  }

  private static func drawPropeller(context: CGContext, color: NSColor, outline: NSColor, angle: Double) {
    context.saveGState()
    context.translateBy(x: 17, y: 36)
    context.rotate(by: angle)
    context.translateBy(x: -17, y: -36)
    fillEllipse(context: context, cx: 17, cy: 28.5, rx: 4.2, ry: 8.6, color: color, stroke: outline)
    fillEllipse(context: context, cx: 17, cy: 43.5, rx: 4.2, ry: 8.6, color: color, stroke: outline)
    context.restoreGState()
  }

  private static func drawBody(context: CGContext, fill: NSColor, stroke: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 30, y: 36))
    path.curve(
      to: NSPoint(x: 54, y: 21.4),
      controlPoint1: NSPoint(x: 31.7, y: 25.7),
      controlPoint2: NSPoint(x: 40, y: 21.4)
    )
    path.line(to: NSPoint(x: 69.5, y: 21.4))
    path.curve(
      to: NSPoint(x: 89, y: 36.2),
      controlPoint1: NSPoint(x: 81, y: 21.4),
      controlPoint2: NSPoint(x: 89, y: 28)
    )
    path.curve(
      to: NSPoint(x: 69.5, y: 50),
      controlPoint1: NSPoint(x: 89, y: 44),
      controlPoint2: NSPoint(x: 81.2, y: 50)
    )
    path.line(to: NSPoint(x: 43.8, y: 50))
    path.curve(
      to: NSPoint(x: 30, y: 36),
      controlPoint1: NSPoint(x: 35.5, y: 50),
      controlPoint2: NSPoint(x: 29.4, y: 44)
    )
    path.close()
    fillPath(path, color: fill, stroke: stroke)
  }

  private static func drawFin(context: CGContext, fill: NSColor, stroke: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 43, y: 47))
    path.curve(
      to: NSPoint(x: 32.6, y: 51.2),
      controlPoint1: NSPoint(x: 40.6, y: 51.2),
      controlPoint2: NSPoint(x: 35.9, y: 52.8)
    )
    path.curve(
      to: NSPoint(x: 34.4, y: 44.4),
      controlPoint1: NSPoint(x: 30.2, y: 50),
      controlPoint2: NSPoint(x: 31.1, y: 46.7)
    )
    path.line(to: NSPoint(x: 45.9, y: 39.9))
    path.curve(
      to: NSPoint(x: 43, y: 47),
      controlPoint1: NSPoint(x: 46.1, y: 43.1),
      controlPoint2: NSPoint(x: 45.2, y: 45.3)
    )
    path.close()
    fillPath(path, color: fill, stroke: stroke)
  }

  private static func drawEyes(
    context: CGContext,
    style: MenuBarIconStyle,
    detail: NSColor,
    flame: NSColor,
    highlight: NSColor,
    tick: Int
  ) {
    switch style.eyeStyle {
    case .round:
      fillEllipse(context: context, cx: 67.5, cy: 34, rx: 4.5, ry: 4.5, color: detail)
      fillEllipse(context: context, cx: 78.5, cy: 34, rx: 4.5, ry: 4.5, color: detail)
      fillEllipse(context: context, cx: 70.0, cy: 31.8, rx: 1.75, ry: 1.75, color: highlight)
      fillEllipse(context: context, cx: 81.0, cy: 31.8, rx: 1.75, ry: 1.75, color: highlight)
    case .oval:
      fillEllipse(context: context, cx: 67.5, cy: 34, rx: 4.5, ry: 4.8, color: detail)
      fillEllipse(context: context, cx: 78.5, cy: 34, rx: 4.5, ry: 4.8, color: detail)
      fillEllipse(context: context, cx: 70.0, cy: 31.7, rx: 1.75, ry: 1.75, color: highlight)
      fillEllipse(context: context, cx: 81.0, cy: 31.7, rx: 1.75, ry: 1.75, color: highlight)
    case .sleepy:
      fillEllipse(context: context, cx: 67.5, cy: 34.3, rx: 4.8, ry: 3.2, color: detail)
      fillEllipse(context: context, cx: 78.5, cy: 34.3, rx: 4.8, ry: 3.2, color: detail)
      fillEllipse(context: context, cx: 70.0, cy: 32.8, rx: 1.55, ry: 1.55, color: highlight)
      fillEllipse(context: context, cx: 81.0, cy: 32.8, rx: 1.55, ry: 1.55, color: highlight)
    case .flame:
      drawFlameGlow(context: context, color: flame, strength: 0.65)
      fillRoundedRect(context: context, x: 62.2, y: 31.7, width: 10.2, height: 5.2, radius: 2.6, color: detail)
      fillRoundedRect(context: context, x: 73.6, y: 31.7, width: 10.2, height: 5.2, radius: 2.6, color: detail)
      drawHalfFlames(context: context, color: flame, scale: 1.24 + (tick.isMultiple(of: 2) ? 0.12 : 0))
      fillEllipse(context: context, cx: 70.0, cy: 32.9, rx: 1.30, ry: 1.30, color: highlight)
      fillEllipse(context: context, cx: 81.0, cy: 32.9, rx: 1.30, ry: 1.30, color: highlight)
    case .overdrive:
      drawFlameGlow(context: context, color: flame, strength: 0.95)
      drawFullEyeCutouts(context: context, color: detail)
      drawFullFlames(context: context, color: flame, tick: tick)
      drawSparks(context: context, color: flame, tick: tick)
      fillEllipse(context: context, cx: 70.0, cy: 32.1, rx: 1.25, ry: 1.25, color: highlight)
      fillEllipse(context: context, cx: 79.0, cy: 32.1, rx: 1.25, ry: 1.25, color: highlight)
    }
  }

  private static func drawFlameGlow(context: CGContext, color: NSColor, strength: Double) {
    let glow = color.withAlphaComponent(color.alphaComponent * strength)
    fillEllipse(context: context, cx: 67.8, cy: 32.0, rx: 6.6, ry: 5.1, color: glow)
    fillEllipse(context: context, cx: 78.2, cy: 32.0, rx: 6.6, ry: 5.1, color: glow)
  }

  private static func drawHalfFlames(context: CGContext, color: NSColor, scale: Double) {
    context.saveGState()
    context.translateBy(x: 73, y: 33)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -73, y: -33)

    let left = NSBezierPath()
    left.move(to: NSPoint(x: 63.2, y: 34.6))
    left.curve(to: NSPoint(x: 69.9, y: 27.9), controlPoint1: NSPoint(x: 64.3, y: 30.8), controlPoint2: NSPoint(x: 66.9, y: 28.8))
    left.curve(to: NSPoint(x: 71.6, y: 33.4), controlPoint1: NSPoint(x: 69.1, y: 30.0), controlPoint2: NSPoint(x: 69.7, y: 31.7))
    left.curve(to: NSPoint(x: 63.2, y: 34.6), controlPoint1: NSPoint(x: 69.2, y: 32.8), controlPoint2: NSPoint(x: 66.8, y: 33.2))
    left.close()
    fillPath(left, color: color, stroke: NSColor.black.withAlphaComponent(0.24 * color.alphaComponent))

    let right = NSBezierPath()
    right.move(to: NSPoint(x: 74.3, y: 34.6))
    right.curve(to: NSPoint(x: 81.0, y: 27.9), controlPoint1: NSPoint(x: 75.4, y: 30.8), controlPoint2: NSPoint(x: 78.0, y: 28.8))
    right.curve(to: NSPoint(x: 82.7, y: 33.4), controlPoint1: NSPoint(x: 80.2, y: 30.0), controlPoint2: NSPoint(x: 80.8, y: 31.7))
    right.curve(to: NSPoint(x: 74.3, y: 34.6), controlPoint1: NSPoint(x: 80.3, y: 32.8), controlPoint2: NSPoint(x: 77.9, y: 33.2))
    right.close()
    fillPath(right, color: color, stroke: NSColor.black.withAlphaComponent(0.24 * color.alphaComponent))

    context.restoreGState()
  }

  private static func drawFullEyeCutouts(context: CGContext, color: NSColor) {
    let left = NSBezierPath()
    left.move(to: NSPoint(x: 62.7, y: 33.7))
    left.line(to: NSPoint(x: 72.8, y: 30.0))
    left.line(to: NSPoint(x: 72.8, y: 36.5))
    left.line(to: NSPoint(x: 62.7, y: 36.5))
    left.close()
    fillPath(left, color: color)

    let right = NSBezierPath()
    right.move(to: NSPoint(x: 83.3, y: 33.7))
    right.line(to: NSPoint(x: 73.2, y: 30.0))
    right.line(to: NSPoint(x: 73.2, y: 36.5))
    right.line(to: NSPoint(x: 83.3, y: 36.5))
    right.close()
    fillPath(right, color: color)
  }

  private static func drawFullFlames(context: CGContext, color: NSColor, tick: Int) {
    let scale = tick.isMultiple(of: 2) ? 1.36 : 1.20
    context.saveGState()
    context.translateBy(x: 73, y: 33)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -73, y: -33)

    let left = NSBezierPath()
    left.move(to: NSPoint(x: 62.1, y: 34.7))
    left.curve(to: NSPoint(x: 71.0, y: 24.9), controlPoint1: NSPoint(x: 63.3, y: 29.5), controlPoint2: NSPoint(x: 66.2, y: 26.6))
    left.curve(to: NSPoint(x: 73.2, y: 32.1), controlPoint1: NSPoint(x: 69.9, y: 27.6), controlPoint2: NSPoint(x: 70.7, y: 29.7))
    left.curve(to: NSPoint(x: 62.1, y: 34.7), controlPoint1: NSPoint(x: 70.1, y: 31.3), controlPoint2: NSPoint(x: 67.1, y: 32.0))
    left.close()
    fillPath(left, color: color, stroke: NSColor.black.withAlphaComponent(0.24 * color.alphaComponent))

    let right = NSBezierPath()
    right.move(to: NSPoint(x: 83.9, y: 34.7))
    right.curve(to: NSPoint(x: 75.0, y: 24.9), controlPoint1: NSPoint(x: 82.7, y: 29.5), controlPoint2: NSPoint(x: 79.8, y: 26.6))
    right.curve(to: NSPoint(x: 72.8, y: 32.1), controlPoint1: NSPoint(x: 76.1, y: 27.6), controlPoint2: NSPoint(x: 75.3, y: 29.7))
    right.curve(to: NSPoint(x: 83.9, y: 34.7), controlPoint1: NSPoint(x: 75.9, y: 31.3), controlPoint2: NSPoint(x: 78.9, y: 32.0))
    right.close()
    fillPath(right, color: color, stroke: NSColor.black.withAlphaComponent(0.24 * color.alphaComponent))

    context.restoreGState()
  }

  private static func drawSparks(context: CGContext, color: NSColor, tick: Int) {
    let pulse = tick.isMultiple(of: 2) ? 1.0 : 0.55
    let sparkColor = color.withAlphaComponent(color.alphaComponent * pulse)
    let stroke = NSColor.black.withAlphaComponent(0.22 * color.alphaComponent)
    fillEllipse(context: context, cx: 65.4, cy: 27.8, rx: 1.35, ry: 1.35, color: sparkColor, stroke: stroke)
    fillEllipse(context: context, cx: 80.6, cy: 27.8, rx: 1.35, ry: 1.35, color: sparkColor, stroke: stroke)
    fillEllipse(context: context, cx: 73.0, cy: 25.9, rx: 1.05, ry: 1.05, color: sparkColor, stroke: stroke)
    fillEllipse(context: context, cx: 84.2, cy: 31.0, rx: 0.9, ry: 0.9, color: sparkColor, stroke: stroke)
  }

  private static func drawSmoke(context: CGContext, count: Int, color: NSColor, tick: Int) {
    guard count > 0 else {
      return
    }

    let chimneyPuffs: [(Double, Double, Double)] = [
      (41.5, 8.7, 4.5),
      (48.2, 11.7, 4.0),
      (52.5, 7.7, 3.5),
      (57.0, 11.4, 3.1)
    ]
    let propellerPuffs: [(Double, Double, Double)] = [
      (13.0, 31.0, 2.7),
      (7.5, 36.5, 2.3),
      (3.2, 42.0, 1.9)
    ]
    let stroke = NSColor.black.withAlphaComponent(0.30 * color.alphaComponent)
    let sizeBoost = 1.0 + Double(count) * 0.13

    for index in 0..<min(count, chimneyPuffs.count) {
      let point = chimneyPuffs[index]
      let drift = sin(Double(tick + index) * 0.45) * 1.15
      let alpha = max(0.38, 0.72 + sin(Double(tick + index) * 0.55) * 0.20)
      fillEllipse(
        context: context,
        cx: point.0,
        cy: point.1 - drift,
        rx: point.2 * sizeBoost,
        ry: point.2 * sizeBoost,
        color: color.withAlphaComponent(color.alphaComponent * alpha),
        stroke: stroke
      )
    }

    guard count > 4 else {
      return
    }

    let propellerCount = min(count - 4, propellerPuffs.count)
    for index in 0..<propellerCount {
      let point = propellerPuffs[index]
      let drift = sin(Double(tick + index) * 0.75) * 0.9
      let alpha = max(0.46, 0.76 + sin(Double(tick + index) * 0.6) * 0.18)
      fillEllipse(
        context: context,
        cx: point.0 - Double((tick + index) % 3) * 0.75,
        cy: point.1 + drift,
        rx: point.2 * 1.32,
        ry: point.2 * 1.32,
        color: color.withAlphaComponent(color.alphaComponent * alpha),
        stroke: stroke
      )
    }
  }

  private static func drawWake(context: CGContext, count: Int, alpha: Double, tick: Int) {
    guard count > 0 else {
      return
    }

    let marks: [(Double, Double, Double, Double)] = [
      (3.8, 38.8, 5.4, 1.75),
      (8.5, 43.0, 5.0, 1.65),
      (13.5, 47.1, 4.2, 1.45),
      (19.0, 50.2, 3.4, 1.25),
      (25.0, 52.0, 2.7, 1.05)
    ]
    let fill = NSColor(red: 0.58, green: 0.90, blue: 1.0, alpha: 0.92 * alpha)
    let stroke = NSColor.black.withAlphaComponent(0.36 * alpha)

    for index in 0..<min(count, marks.count) {
      let mark = marks[index]
      let offset = Double((tick + index) % 4) * -1.05
      fillEllipse(
        context: context,
        cx: mark.0 + offset,
        cy: mark.1,
        rx: mark.2,
        ry: mark.3,
        color: fill,
        stroke: stroke
      )

      if count >= 3, index < 3 {
        fillEllipse(
          context: context,
          cx: mark.0 + offset + 2.0,
          cy: mark.1 - 3.0,
          rx: mark.2 * 0.45,
          ry: mark.3 * 0.85,
          color: fill.withAlphaComponent(fill.alphaComponent * 0.72),
          stroke: stroke
        )
      }
    }
  }

  private static func fillEllipse(context: CGContext, cx: Double, cy: Double, rx: Double, ry: Double, color: NSColor, stroke: NSColor? = nil) {
    let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: rect)

    if let stroke {
      context.setStrokeColor(stroke.cgColor)
      context.setLineWidth(0.8)
      context.strokeEllipse(in: rect)
    }
  }

  private static func fillRoundedRect(
    context: CGContext,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    radius: Double,
    color: NSColor,
    stroke: NSColor? = nil
  ) {
    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
    fillPath(path, color: color, stroke: stroke)
  }

  private static func strokeLine(
    context: CGContext,
    fromX: Double,
    fromY: Double,
    toX: Double,
    toY: Double,
    width: Double,
    color: NSColor
  ) {
    context.saveGState()
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: fromX, y: fromY))
    context.addLine(to: CGPoint(x: toX, y: toY))
    context.strokePath()
    context.restoreGState()
  }

  private static func fillPath(_ path: NSBezierPath, color: NSColor, stroke: NSColor? = nil) {
    color.setFill()
    path.fill()

    if let stroke {
      stroke.setStroke()
      path.lineWidth = 0.8
      path.stroke()
    }
  }
}
