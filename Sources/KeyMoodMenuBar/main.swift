import AppKit

@MainActor
private enum KeyMoodMenuBarRuntime {
  static let controller = MenuBarController()
}

let app = NSApplication.shared
let controller = KeyMoodMenuBarRuntime.controller
app.delegate = controller
app.setActivationPolicy(.accessory)
controller.start()
app.run()
