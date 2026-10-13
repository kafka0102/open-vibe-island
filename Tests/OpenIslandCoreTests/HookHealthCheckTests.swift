import Foundation
import Testing
@testable import OpenIslandCore

struct HookHealthCheckTests {
    @Test
    func existingButNonCurrentBinaryIsStaleAndRepairable() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-island-health-\(UUID().uuidString)", isDirectory: true)
        let claudeDirectory = rootURL.appendingPathComponent(".claude", isDirectory: true)
        let currentBinaryURL = rootURL.appendingPathComponent("OpenIsland2/bin/OpenIslandHooks")
        let legacyBinaryURL = rootURL.appendingPathComponent("OpenIsland/bin/OpenIslandHooks")
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyBinaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: legacyBinaryURL)
        try FileManager.default.createDirectory(at: currentBinaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("new".utf8).write(to: currentBinaryURL)

        let command = ClaudeHookInstaller.hookCommand(for: legacyBinaryURL.path)
        let settings: [String: Any] = [
            "hooks": [
                "SessionStart": [[
                    "hooks": [["type": "command", "command": command]],
                ]],
            ],
        ]
        try JSONSerialization.data(withJSONObject: settings).write(
            to: claudeDirectory.appendingPathComponent("settings.json")
        )

        let report = HookHealthCheck.checkClaude(
            claudeDirectory: claudeDirectory,
            managedHooksBinaryURL: currentBinaryURL
        )
        #expect(report.repairableIssues.contains {
            if case .staleCommandPath(let recorded, _) = $0 {
                return recorded == legacyBinaryURL.path
            }
            return false
        })

        let healthySettings: [String: Any] = [
            "hooks": [
                "SessionStart": [[
                    "hooks": [["type": "command", "command": ClaudeHookInstaller.hookCommand(for: currentBinaryURL.path)]],
                ]],
            ],
        ]
        try JSONSerialization.data(withJSONObject: healthySettings).write(
            to: claudeDirectory.appendingPathComponent("settings.json")
        )
        let healthy = HookHealthCheck.checkClaude(
            claudeDirectory: claudeDirectory,
            managedHooksBinaryURL: currentBinaryURL
        )
        #expect(!healthy.issues.contains {
            if case .staleCommandPath = $0 { return true }
            return false
        })
    }
}
