import Foundation
import Testing
@testable import DiaRouter

struct SettingsStoreTests {
    @Test @MainActor
    func addedRuleBecomesHighestPriority() throws {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let existingRule = RoutingRule(
            id: UUID(),
            isEnabled: true,
            matchType: .domain,
            pattern: "existing.example",
            profileID: RouterConfiguration.workProfileID
        )
        let store = SettingsStore(defaults: defaults, detectedProfiles: [])
        store.configuration = RouterConfiguration(
            profiles: [
                DiaProfile(
                    id: RouterConfiguration.workProfileID,
                    name: "Work",
                    shortcutNumber: 1
                ),
            ],
            rules: [existingRule],
            defaultProfileID: RouterConfiguration.workProfileID
        )

        let addedRuleID = try #require(store.addRule())

        #expect(store.configuration.rules.map(\.id) == [addedRuleID, existingRule.id])
    }
}
