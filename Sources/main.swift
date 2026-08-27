import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Runs as a lightweight menu bar / status item accessory without Dock icon clutter
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
