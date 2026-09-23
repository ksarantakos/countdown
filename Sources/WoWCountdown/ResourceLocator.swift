import AppKit

/// Finds the SwiftPM resource bundle.
///
/// In the packaged app it must be in `Contents/Resources`; `Bundle.module` is only used when
/// running unpackaged (`swift run`), so build-directory paths can't mask a missing bundle.
enum ResourceLocator {
    static let bundleName = "WoWCountdown_WoWCountdown.bundle"

    static let bundle: Bundle? = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent(bundleName),
           let bundle = Bundle(url: url) {
            return bundle
        }
        if Bundle.main.bundleURL.pathExtension == "app" {
            Log.app.error("Resource bundle \(bundleName, privacy: .public) missing from the app")
            return nil
        }
        return Bundle.module
    }()

    static func image(named name: String) -> NSImage? {
        guard let url = bundle?.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
