import AppKit
import Foundation

enum DefaultBrowserController {
    private static let legacyBundleIdentifiers = [
        "com.example.SafariProfileRouter",
        "com.jdsimcoe.SafariProfileRouter",
    ]

    static var isDefaultRouter: Bool {
        guard ApplicationInstallation.isRunningFromCanonicalBundle,
              let probeURL = URL(string: "https://example.com"),
              let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL) else {
            return false
        }

        return ApplicationInstallation.refersToRunningBundle(applicationURL)
    }

    static func makeDefaultRouter() async throws {
        guard ApplicationInstallation.isRunningFromCanonicalBundle else {
            throw DefaultBrowserError.noncanonicalInstallation
        }

        let applicationURL = Bundle.main.bundleURL
        try await setDefault(applicationURL: applicationURL, scheme: "http")
        try await setDefault(applicationURL: applicationURL, scheme: "https")
    }

    static func claimCustomScheme() async throws {
        try await setDefault(
            applicationURL: Bundle.main.bundleURL,
            scheme: "dia-router"
        )
    }

    static func migrateLegacyDefaultBrowserIfNeeded() async throws -> Bool {
        guard let probeURL = URL(string: "https://example.com"),
              let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL),
              let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier,
              isLegacyBundleIdentifier(bundleIdentifier) else {
            return false
        }

        try await makeDefaultRouter()
        return true
    }

    static func isLegacyBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return legacyBundleIdentifiers.contains(bundleIdentifier)
    }

    private static func setDefault(applicationURL: URL, scheme: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.setDefaultApplication(
                at: applicationURL,
                toOpenURLsWithScheme: scheme
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

private enum DefaultBrowserError: LocalizedError {
    case noncanonicalInstallation

    var errorDescription: String? {
        "Install and launch Dia Router from /Applications/Dia Router.app before making it the default web router."
    }
}
