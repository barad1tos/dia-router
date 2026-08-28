import Foundation

enum ApplicationInstallation {
    static let canonicalBundleURL = URL(
        fileURLWithPath: "/Applications/Dia Router.app",
        isDirectory: true
    )

    static var isRunningFromCanonicalBundle: Bool {
        isCanonicalBundle(Bundle.main.bundleURL)
    }

    static func isCanonicalBundle(_ bundleURL: URL) -> Bool {
        normalized(bundleURL) == normalized(canonicalBundleURL)
    }

    static func refersToRunningBundle(_ bundleURL: URL) -> Bool {
        normalized(bundleURL) == normalized(Bundle.main.bundleURL)
    }

    private static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
