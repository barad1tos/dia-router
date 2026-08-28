import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard ApplicationInstallation.isRunningFromCanonicalBundle else {
            NSLog(
                "Dia Router is running outside %@; skipping system registration.",
                ApplicationInstallation.canonicalBundleURL.path
            )
            return
        }

        registerToOpenAtLogin()

        if ProcessInfo.processInfo.arguments.contains("--migrate-legacy-default-and-quit") {
            Task {
                do {
                    if try await DefaultBrowserController.migrateLegacyDefaultBrowserIfNeeded() {
                        NSLog("Migrated the default web handler from legacy Router to Dia Router.")
                    }
                } catch {
                    NSLog("Could not migrate the legacy Router default: %@", error.localizedDescription)
                }

                await MainActor.run {
                    NSApp.terminate(nil)
                }
            }
            return
        }

        Task {
            try? await DefaultBrowserController.claimCustomScheme()
        }
    }

    private func registerToOpenAtLogin() {
        let service = SMAppService.loginItem(
            identifier: "com.diarouter.DiaRouter.LoginItem"
        )

        // Re-register once after moving the canonical app from ~/Applications
        // to /Applications so Service Management cannot retain the old path.
        let migrationKey = "canonicalApplicationsLoginItem.v2"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            do {
                try service.unregister()
            } catch {
                NSLog("Could not unregister the previous Dia Router login item: %@", error.localizedDescription)
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        guard service.status != .enabled,
              service.status != .requiresApproval else {
            return
        }

        do {
            try service.register()
        } catch {
            NSLog("Could not register Dia Router to open at login: %@", error.localizedDescription)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                RouterCoordinator.shared.route(url)
            }
        }
    }
}
