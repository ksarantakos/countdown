import AppKit

enum ResourceLocator {
    /// App resources are copied into `Contents/Resources` by the Xcode build.
    static func image(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            Log.app.error("Missing bundled resource \(name, privacy: .public).png")
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
