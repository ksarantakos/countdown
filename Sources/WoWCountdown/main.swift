import AppKit
import CountdownCore

let mode: RuntimeMode
do {
    mode = try RuntimeMode.parse(CommandLine.arguments)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(2)
}

let app = NSApplication.shared
let delegate = AppDelegate(mode: mode)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
