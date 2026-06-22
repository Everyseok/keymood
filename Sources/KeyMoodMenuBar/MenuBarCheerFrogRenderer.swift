import AppKit
import KeyMoodCore

enum MenuBarCheerFrogRenderer {
  private static let compactStatusLength: CGFloat = 62
  private static let compactImageSize = NSSize(width: compactStatusLength, height: 22)
  private static let sourceBounds = CGRect(x: -10, y: 0, width: 116, height: 50)

  static func image(
    mood: RuntimeMood,
    paused: Bool,
    noSensor: Bool,
    tick: Int,
    animationPhase: CGFloat? = nil,
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
    let xOffset = xOffset(imageWidth: imageSize.width, drawWidth: drawWidth, roaming: roaming, progress: roamingProgress)
    let yOffset = (imageSize.height - drawHeight) / 2
    let facingLeft = roaming && roamingDirection < 0

    context.translateBy(x: xOffset + (facingLeft ? drawWidth : 0), y: imageSize.height - yOffset)
    context.scaleBy(x: facingLeft ? -scale : scale, y: -scale)
    context.translateBy(x: -sourceBounds.minX, y: -sourceBounds.minY)
    let phase = animationPhase ?? CGFloat(Double(tick)) * CGFloat(max(style.characterMotionStep, .pi / 24))
    drawCheerFrog(context: context, style: style, tick: tick, phase: phase)
    context.restoreGState()

    return image
  }

  private static func xOffset(imageWidth: CGFloat, drawWidth: CGFloat, roaming: Bool, progress: CGFloat) -> CGFloat {
    let travel = max(imageWidth - drawWidth, 0)
    guard roaming, travel > 0 else {
      return travel / 2
    }

    return travel * min(max(progress, 0), 1)
  }

  private static func drawCheerFrog(context: CGContext, style: MenuBarIconStyle, tick: Int, phase: CGFloat) {
    let pose = CheerFrogPose(style: style, tick: tick, phase: phase)
    let alpha = style.alpha
    let fill = NSColor.white.withAlphaComponent(alpha)
    let ink = NSColor.black.withAlphaComponent(0.92 * alpha)
    let faintInk = NSColor.black.withAlphaComponent(0.42 * alpha)
    let faintFill = NSColor.white.withAlphaComponent(0.72 * alpha)

    drawSteam(context: context, pose: pose, ink: ink, fill: fill)
    drawMotionMarks(context: context, pose: pose, ink: ink, fill: fill)

    context.saveGState()
    context.translateBy(x: pose.shakeX, y: pose.bobY)
    context.rotate(by: pose.lean)

    drawArms(context: context, pose: pose, fill: fill, ink: ink)
    drawBody(context: context, fill: fill, faintFill: faintFill, ink: ink)
    drawHead(context: context, fill: fill, ink: ink)
    drawFace(context: context, pose: pose, fill: fill, ink: ink, faintInk: faintInk)

    context.restoreGState()
  }

  private static func drawBody(context: CGContext, fill: NSColor, faintFill: NSColor, ink: NSColor) {
    fillEllipse(context: context, cx: 46.0, cy: 39.0, rx: 13.8, ry: 8.8, color: fill, stroke: ink, width: 1.25)
    fillEllipse(context: context, cx: 46.2, cy: 40.3, rx: 7.2, ry: 4.5, color: faintFill, stroke: ink.withAlphaComponent(0.16), width: 0.5)
  }

  private static func drawHead(context: CGContext, fill: NSColor, ink: NSColor) {
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 24.0, y: 23.0))
    head.curve(to: NSPoint(x: 31.5, y: 12.0), controlPoint1: NSPoint(x: 23.6, y: 17.0), controlPoint2: NSPoint(x: 26.2, y: 12.4))
    head.curve(to: NSPoint(x: 45.7, y: 8.4), controlPoint1: NSPoint(x: 35.0, y: 7.5), controlPoint2: NSPoint(x: 41.0, y: 6.9))
    head.curve(to: NSPoint(x: 60.8, y: 12.5), controlPoint1: NSPoint(x: 51.2, y: 6.8), controlPoint2: NSPoint(x: 57.2, y: 7.8))
    head.curve(to: NSPoint(x: 68.0, y: 24.5), controlPoint1: NSPoint(x: 66.4, y: 13.1), controlPoint2: NSPoint(x: 69.0, y: 17.5))
    head.curve(to: NSPoint(x: 62.2, y: 36.8), controlPoint1: NSPoint(x: 69.6, y: 29.7), controlPoint2: NSPoint(x: 66.8, y: 34.7))
    head.curve(to: NSPoint(x: 46.0, y: 41.0), controlPoint1: NSPoint(x: 57.6, y: 40.2), controlPoint2: NSPoint(x: 51.8, y: 41.5))
    head.curve(to: NSPoint(x: 29.6, y: 36.6), controlPoint1: NSPoint(x: 39.0, y: 41.8), controlPoint2: NSPoint(x: 32.5, y: 40.4))
    head.curve(to: NSPoint(x: 24.0, y: 23.0), controlPoint1: NSPoint(x: 25.7, y: 32.0), controlPoint2: NSPoint(x: 23.0, y: 28.3))
    head.close()
    fillPath(head, color: fill, stroke: ink, width: 1.45)

    fillEllipse(context: context, cx: 34.0, cy: 11.8, rx: 8.6, ry: 7.8, color: fill, stroke: ink, width: 1.2)
    fillEllipse(context: context, cx: 57.3, cy: 11.8, rx: 8.6, ry: 7.8, color: fill, stroke: ink, width: 1.2)
  }

  private static func drawFace(context: CGContext, pose: CheerFrogPose, fill: NSColor, ink: NSColor, faintInk: NSColor) {
    let focus = pose.eyeFocus
    fillEllipse(context: context, cx: 34.5, cy: 12.4, rx: 5.0 + pose.eyeWide, ry: 4.5 + pose.eyeWide * 0.45, color: fill, stroke: faintInk, width: 0.7)
    fillEllipse(context: context, cx: 57.7, cy: 12.4, rx: 5.0 + pose.eyeWide, ry: 4.5 + pose.eyeWide * 0.45, color: fill, stroke: faintInk, width: 0.7)
    fillEllipse(context: context, cx: 35.8 + focus, cy: 13.2, rx: 1.75 + pose.eyeWide * 0.12, ry: 2.05 + pose.eyeWide * 0.10, color: ink)
    fillEllipse(context: context, cx: 58.9 + focus, cy: 13.2, rx: 1.75 + pose.eyeWide * 0.12, ry: 2.05 + pose.eyeWide * 0.10, color: ink)
    fillEllipse(context: context, cx: 35.1 + focus, cy: 12.2, rx: 0.42, ry: 0.42, color: fill)
    fillEllipse(context: context, cx: 58.2 + focus, cy: 12.2, rx: 0.42, ry: 0.42, color: fill)

    strokeLine(context: context, fromX: 29.4, fromY: 17.0, toX: 40.4, toY: 17.9 - pose.eyeWide * 0.15, width: 1.0, color: ink)
    strokeLine(context: context, fromX: 51.5, fromY: 17.9 - pose.eyeWide * 0.15, toX: 63.0, toY: 17.0, width: 1.0, color: ink)

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: 35.0, y: 28.2))
    mouth.curve(
      to: NSPoint(x: 58.4, y: 28.0),
      controlPoint1: NSPoint(x: 40.8, y: 34.0 + pose.smileOpen),
      controlPoint2: NSPoint(x: 52.0, y: 34.0 + pose.smileOpen)
    )
    strokePath(mouth, color: ink, width: 1.55)

    if pose.openMouth {
      fillEllipse(context: context, cx: 47.0, cy: 30.2 + Double(pose.smileOpen) * 0.15, rx: 4.4, ry: 2.5 + Double(pose.smileOpen) * 0.08, color: ink)
      fillEllipse(context: context, cx: 46.5, cy: 29.0, rx: 1.4, ry: 0.7, color: fill.withAlphaComponent(fill.alphaComponent * 0.85))
    }
  }

  private static func drawArms(context: CGContext, pose: CheerFrogPose, fill: NSColor, ink: NSColor) {
    drawArm(context: context, shoulder: CGPoint(x: 34.2, y: 35.0), length: pose.armLength, angle: pose.leftArmAngle, handRadius: pose.handRadius, fill: fill, ink: ink)
    drawArm(context: context, shoulder: CGPoint(x: 57.8, y: 35.0), length: pose.armLength, angle: pose.rightArmAngle, handRadius: pose.handRadius, fill: fill, ink: ink)
  }

  private static func drawArm(context: CGContext, shoulder: CGPoint, length: CGFloat, angle: CGFloat, handRadius: CGFloat, fill: NSColor, ink: NSColor) {
    let elbow = CGPoint(
      x: shoulder.x + cos(angle) * length * 0.54,
      y: shoulder.y + sin(angle) * length * 0.54
    )
    let hand = CGPoint(
      x: shoulder.x + cos(angle) * length,
      y: shoulder.y + sin(angle) * length
    )
    let path = NSBezierPath()
    path.move(to: NSPoint(x: shoulder.x, y: shoulder.y))
    path.curve(
      to: NSPoint(x: hand.x, y: hand.y),
      controlPoint1: NSPoint(x: elbow.x - sin(angle) * 4.1, y: elbow.y + cos(angle) * 4.1),
      controlPoint2: NSPoint(x: elbow.x + sin(angle) * 2.8, y: elbow.y - cos(angle) * 2.8)
    )
    strokePath(path, color: ink, width: 5.4)
    strokePath(path, color: fill, width: 3.25)
    fillEllipse(context: context, cx: Double(hand.x), cy: Double(hand.y), rx: Double(handRadius * 1.10), ry: Double(handRadius), color: fill, stroke: ink, width: 1.25)
    fillEllipse(context: context, cx: Double(hand.x + cos(angle) * handRadius * 0.25), cy: Double(hand.y + sin(angle) * handRadius * 0.25), rx: Double(handRadius * 0.32), ry: Double(handRadius * 0.28), color: ink.withAlphaComponent(ink.alphaComponent * 0.88))
  }

  private static func drawMotionMarks(context: CGContext, pose: CheerFrogPose, ink: NSColor, fill: NSColor) {
    guard pose.motionMarkCount > 0 else {
      return
    }

    for index in 0..<pose.motionMarkCount {
      let spread = CGFloat(index) * 4.4
      let lift = CGFloat(index % 2) * 2.3
      let alpha = max(0.32, 0.82 - CGFloat(index) * 0.12)
      strokeLine(context: context, fromX: 16.5 - spread, fromY: 16.0 - lift, toX: 22.0 - spread, toY: 9.0 - lift, width: 1.15, color: ink.withAlphaComponent(ink.alphaComponent * alpha))
      strokeLine(context: context, fromX: 76.0 + spread, fromY: 9.0 - lift, toX: 82.0 + spread, toY: 16.0 - lift, width: 1.15, color: ink.withAlphaComponent(ink.alphaComponent * alpha))
      if pose.motionMarkCount >= 4 && index.isMultiple(of: 2) {
        fillEllipse(context: context, cx: Double(20.5 - spread), cy: Double(5.6 - lift), rx: 1.15, ry: 1.15, color: fill.withAlphaComponent(fill.alphaComponent * alpha), stroke: ink.withAlphaComponent(ink.alphaComponent * alpha), width: 0.6)
        fillEllipse(context: context, cx: Double(82.5 + spread), cy: Double(5.8 - lift), rx: 1.15, ry: 1.15, color: fill.withAlphaComponent(fill.alphaComponent * alpha), stroke: ink.withAlphaComponent(ink.alphaComponent * alpha), width: 0.6)
      }
    }
  }

  private static func drawSteam(context: CGContext, pose: CheerFrogPose, ink: NSColor, fill: NSColor) {
    guard pose.steamCount > 0 else {
      return
    }

    for index in 0..<pose.steamCount {
      let row = CGFloat(index % 2)
      let side = index.isMultiple(of: 2) ? -1.0 : 1.0
      let drift = sin(Double(pose.steamPhase + CGFloat(index) * 0.7)) * 1.6
      let x = 46.0 + side * (7.8 + CGFloat(index / 2) * 5.2) + CGFloat(drift)
      let y = 3.8 + row * 3.2
      let puff = 1.65 + CGFloat(index % 3) * 0.32
      let alpha = max(0.34, 0.80 - CGFloat(index) * 0.08)
      fillEllipse(
        context: context,
        cx: Double(x),
        cy: Double(y),
        rx: Double(puff),
        ry: Double(puff * 0.92),
        color: fill.withAlphaComponent(fill.alphaComponent * alpha),
        stroke: ink.withAlphaComponent(ink.alphaComponent * alpha),
        width: 0.72
      )
    }
  }

  private static func fillEllipse(
    context: CGContext,
    cx: Double,
    cy: Double,
    rx: Double,
    ry: Double,
    color: NSColor,
    stroke: NSColor? = nil,
    width: Double = 0.8
  ) {
    let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: rect)

    if let stroke {
      context.setStrokeColor(stroke.cgColor)
      context.setLineWidth(width)
      context.strokeEllipse(in: rect)
    }
  }

  private static func fillPath(_ path: NSBezierPath, color: NSColor, stroke: NSColor? = nil, width: Double = 0.8) {
    color.setFill()
    path.fill()

    if let stroke {
      stroke.setStroke()
      path.lineWidth = width
      path.stroke()
    }
  }

  private static func strokePath(_ path: NSBezierPath, color: NSColor, width: Double) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.stroke()
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
}

private struct CheerFrogPose {
  let leftArmAngle: CGFloat
  let rightArmAngle: CGFloat
  let armLength: CGFloat
  let handRadius: CGFloat
  let bobY: CGFloat
  let shakeX: CGFloat
  let lean: CGFloat
  let eyeFocus: CGFloat
  let eyeWide: CGFloat
  let smileOpen: CGFloat
  let openMouth: Bool
  let motionMarkCount: Int
  let steamCount: Int
  let steamPhase: CGFloat

  init(style: MenuBarIconStyle, tick _: Int, phase: CGFloat) {
    let wave = sin(phase)
    let openAmount = Self.openCloseAmount(phase: phase)
    let pulse = abs(sin(phase * 0.72))
    let smoothShake = sin(phase * 1.35)
    let bobWave = sin(phase * 0.78)
    steamPhase = phase

    switch style.eyeStyle {
    case .round:
      let arms = Self.armAngles(openAmount: openAmount, leftOpen: -.pi * 0.73, rightOpen: -.pi * 0.27)
      leftArmAngle = arms.left
      rightArmAngle = arms.right
      armLength = 33.0
      handRadius = 5.0
      bobY = bobWave * max(CGFloat(style.bobAmplitude), 1.05)
      shakeX = smoothShake * 0.28
      lean = wave * 0.026
      eyeFocus = 0.0
      eyeWide = 0.0
      smileOpen = 0.0
      openMouth = false
      motionMarkCount = 2
      steamCount = 3
    case .oval:
      let arms = Self.armAngles(openAmount: openAmount, leftOpen: -.pi * 0.78, rightOpen: -.pi * 0.22)
      leftArmAngle = arms.left
      rightArmAngle = arms.right
      armLength = 32.0
      handRadius = 4.9
      bobY = bobWave * CGFloat(style.bobAmplitude)
      shakeX = smoothShake * 0.14
      lean = wave * 0.018
      eyeFocus = 0.35
      eyeWide = 0.12
      smileOpen = 0.6
      openMouth = false
      motionMarkCount = 2
      steamCount = 2
    case .flame:
      let arms = Self.armAngles(openAmount: openAmount, leftOpen: -.pi * 0.84, rightOpen: -.pi * 0.16)
      leftArmAngle = arms.left
      rightArmAngle = arms.right
      armLength = 34.0
      handRadius = 5.25
      bobY = bobWave * CGFloat(style.bobAmplitude)
      shakeX = smoothShake * max(CGFloat(style.shakeAmplitude), 0.46)
      lean = wave * 0.035
      eyeFocus = 0.72
      eyeWide = 0.35
      smileOpen = 1.8
      openMouth = true
      motionMarkCount = 4
      steamCount = 4
    case .overdrive:
      let arms = Self.armAngles(openAmount: openAmount, leftOpen: -.pi * 0.91, rightOpen: -.pi * 0.09)
      leftArmAngle = arms.left
      rightArmAngle = arms.right
      armLength = 36.0
      handRadius = 5.6
      bobY = bobWave * CGFloat(style.bobAmplitude)
      shakeX = smoothShake * max(CGFloat(style.shakeAmplitude), 0.95)
      lean = wave * 0.060
      eyeFocus = 0.95 + pulse * 0.20
      eyeWide = 0.70
      smileOpen = 3.2
      openMouth = true
      motionMarkCount = 7
      steamCount = 7
    case .sleepy:
      let arms = Self.armAngles(openAmount: openAmount, leftOpen: -.pi * 0.69, rightOpen: -.pi * 0.31)
      leftArmAngle = arms.left
      rightArmAngle = arms.right
      armLength = 30.0
      handRadius = 4.35
      bobY = bobWave * CGFloat(style.bobAmplitude)
      shakeX = smoothShake * 0.12
      lean = wave * 0.015
      eyeFocus = -0.18
      eyeWide = 0.0
      smileOpen = -0.2
      openMouth = false
      motionMarkCount = 1
      steamCount = 2
    }
  }

  private static func openCloseAmount(phase: CGFloat) -> CGFloat {
    let fullCycle = CGFloat.pi * 2
    let cycle = (phase.truncatingRemainder(dividingBy: fullCycle) + fullCycle).truncatingRemainder(dividingBy: fullCycle) / fullCycle
    return cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2
  }

  private static func armAngles(openAmount: CGFloat, leftOpen: CGFloat, rightOpen: CGFloat) -> (left: CGFloat, right: CGFloat) {
    let leftClosed = -CGFloat.pi * 0.51
    let rightClosed = -CGFloat.pi * 0.49
    let clampedOpen = min(max(openAmount, 0), 1)
    return (
      left: leftClosed + (leftOpen - leftClosed) * clampedOpen,
      right: rightClosed + (rightOpen - rightClosed) * clampedOpen
    )
  }
}
