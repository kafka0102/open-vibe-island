import Foundation
import Testing
@testable import OpenIslandCore

struct KimiHooksTests {
    @Test
    func installIntoEmptyConfigEmitsAllManagedBlocks() {
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: nil,
            hookCommand: command
        )

        #expect(mutation.changed)
        #expect(mutation.managedHooksPresent)
        let contents = try! #require(mutation.contents)

        for event in ["SessionStart", "UserPromptSubmit", "Stop", "Notification", "PreToolUse", "PostToolUse"] {
            #expect(contents.contains("event = \"\(event)\""))
        }

        #expect(contents.contains(KimiHookInstaller.markerComment))
        #expect(contents.contains("--source kimi"))
        #expect(contents.contains("timeout = \(KimiHookInstaller.managedTimeout)"))
    }

    @Test
    func installPreservesUnrelatedUserHooks() {
        let userToml = """
        default_model = "kimi-for-coding"

        [[hooks]]
        event = "PostToolUse"
        matcher = "WriteFile"
        command = "prettier --write"

        """
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("prettier --write"))
        #expect(contents.contains("default_model = \"kimi-for-coding\""))
        #expect(contents.contains(KimiHookInstaller.markerComment))
    }

    @Test
    func installRemovesEmptyTopLevelHooksArrayPlaceholder() {
        let userToml = """
        default_model = "kimi-code/kimi-for-coding"
        default_thinking = true
        hooks = [] # Kimi may seed this placeholder

        [models."kimi-code/kimi-for-coding"]
        provider = "managed:kimi-code"

        [[hooks]]
        event = "PostToolUse"
        command = "user-hook"

        """
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("hooks = []") == false)
        #expect(contents.contains("[models.\"kimi-code/kimi-for-coding\"]"))
        #expect(contents.contains("command = \"user-hook\""))
        #expect(contents.contains("event = \"SessionStart\""))
    }

    @Test
    func installKeepsNonTopLevelHooksArrayAssignments() {
        let userToml = """
        [harness]
        hooks = []
        embedded = true

        """
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("[harness]\nhooks = []\nembedded = true"))
        #expect(contents.contains("event = \"SessionStart\""))
    }

    @Test
    func installRemovesSpacedEmptyTopLevelHooksArrayPlaceholder() {
        let userToml = """
        default_model = "kimi-code/kimi-for-coding"
        hooks = [ ] # Kimi may seed this placeholder

        """
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("hooks = [ ] # Kimi may seed this placeholder") == false)
        #expect(contents.contains("event = \"SessionStart\""))
    }

    @Test
    func installKeepsHooksArrayAfterCommentedTableHeader() {
        let userToml = """
        [harness] # user-owned table
        hooks = [ ]
        embedded = true

        """
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("[harness] # user-owned table\nhooks = [ ]\nembedded = true"))
        #expect(contents.contains("event = \"SessionStart\""))
    }

    @Test
    func installKeepsHooksTextInsideMultilineStrings() {
        let userToml = #"""
        basic_message = """
        hooks = []
        """
        literal_message = '''
        hooks = [ ]
        '''
        hooks = [ ] # actual placeholder

        """#
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("hooks = [ ] # actual placeholder") == false)
        #expect(contents.contains(#"""
        basic_message = """
        hooks = []
        """
        """#))
        #expect(contents.contains("literal_message = '''\nhooks = [ ]\n'''"))
    }

    @Test
    func installKeepsNonEmptyTopLevelHooksArrayWithStrings() {
        let userToml = #"""
        default_model = "kimi-code/kimi-for-coding"
        hooks = ["user-hook"]

        """#
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains(#"hooks = ["user-hook"]"#))
        #expect(contents.contains("event = \"SessionStart\""))
    }

    @Test
    func installRemovesEmptyTopLevelHooksArrayFromCRLFConfig() {
        let userToml = "default_model = \"kimi-code/kimi-for-coding\"\r\nhooks = []\r\n"
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let mutation = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let contents = try! #require(mutation.contents)
        #expect(contents.contains("hooks = []") == false)
        #expect(contents.contains("event = \"SessionStart\""))
    }

    @Test
    func reinstallIsIdempotent() {
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let firstInstall = KimiHookInstaller.installConfigTOML(
            existingContents: nil,
            hookCommand: command
        )
        let secondInstall = KimiHookInstaller.installConfigTOML(
            existingContents: firstInstall.contents,
            hookCommand: command
        )

        #expect(secondInstall.contents == firstInstall.contents)
        #expect(secondInstall.changed == false)
    }

    @Test
    func uninstallRemovesManagedBlocksAndKeepsUserHooks() {
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let userToml = """
        default_model = "kimi-for-coding"

        [[hooks]]
        event = "PostToolUse"
        matcher = "WriteFile"
        command = "prettier --write"

        """
        let installed = KimiHookInstaller.installConfigTOML(
            existingContents: userToml,
            hookCommand: command
        )

        let uninstall = KimiHookInstaller.uninstallConfigTOML(
            existingContents: installed.contents,
            managedCommand: command
        )

        #expect(uninstall.changed)
        let remaining = try! #require(uninstall.contents)
        #expect(remaining.contains("prettier --write"))
        #expect(remaining.contains("default_model"))
        #expect(remaining.contains(KimiHookInstaller.markerComment) == false)
        #expect(remaining.contains("--source kimi") == false)
    }

    @Test
    func uninstallHandlesEmptyInputGracefully() {
        let emptyMutation = KimiHookInstaller.uninstallConfigTOML(
            existingContents: nil,
            managedCommand: nil
        )
        #expect(emptyMutation.contents == nil)
        #expect(emptyMutation.changed == false)

        let blankMutation = KimiHookInstaller.uninstallConfigTOML(
            existingContents: "",
            managedCommand: "anything"
        )
        #expect(blankMutation.contents == nil)
        #expect(blankMutation.changed == false)
    }

    @Test
    func uninstallFallsBackToCommandMatchForMarkerlessEntries() {
        // Older installs (or third-party tooling mimicking our command) may lack the marker.
        // Uninstall should still clean them up when given the exact managed command.
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let legacyToml = """
        [[hooks]]
        event = "UserPromptSubmit"
        command = \(tomlQuoted(command))
        timeout = 45

        [[hooks]]
        event = "PostToolUse"
        command = "other-tool"

        """

        let mutation = KimiHookInstaller.uninstallConfigTOML(
            existingContents: legacyToml,
            managedCommand: command
        )

        #expect(mutation.changed)
        let remaining = try! #require(mutation.contents)
        #expect(remaining.contains("other-tool"))
        #expect(remaining.contains("--source kimi") == false)
    }

    @Test
    func uninstallReducesToNilWhenFileOnlyHadManagedContent() {
        let command = KimiHookInstaller.hookCommand(for: "/opt/open-island/OpenIslandHooks")
        let installed = KimiHookInstaller.installConfigTOML(
            existingContents: nil,
            hookCommand: command
        )

        let mutation = KimiHookInstaller.uninstallConfigTOML(
            existingContents: installed.contents,
            managedCommand: command
        )

        #expect(mutation.changed)
        #expect(mutation.contents == nil)
    }

    @Test
    func staleLegacyKimiCommandIsDetectedThenRefreshedByInstall() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-island-kimi-stale-\(UUID().uuidString)", isDirectory: true)
        let kimiDirectory = rootURL.appendingPathComponent(".kimi", isDirectory: true)
        let currentBinaryURL = rootURL.appendingPathComponent("OpenIsland2/bin/OpenIslandHooks")
        let legacyBinaryURL = rootURL.appendingPathComponent("OpenIsland/bin/OpenIslandHooks")
        let sourceBinaryURL = rootURL.appendingPathComponent("build/OpenIslandHooks")
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try FileManager.default.createDirectory(at: kimiDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceBinaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("current-kimi".utf8).write(to: sourceBinaryURL)

        let legacyCommand = KimiHookInstaller.hookCommand(for: legacyBinaryURL.path)
        let config = """
        default_model = "kimi-for-coding"

        [[hooks]]
        event = "Stop"
        command = "echo keep-me"

        \(KimiHookInstaller.markerComment)
        [[hooks]]
        event = "SessionStart"
        matcher = "startup|resume"
        command = \(tomlQuoted(legacyCommand))
        timeout = 45

        """
        try config.write(to: kimiDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let manifest = """
        {"hookCommand":\(String(data: try JSONEncoder().encode(legacyCommand), encoding: .utf8)!),"installedAt":"2026-07-08T00:00:00Z"}
        """
        try manifest.write(
            to: kimiDirectory.appendingPathComponent(KimiHookInstallerManifest.fileName),
            atomically: true,
            encoding: .utf8
        )

        let manager = KimiHookInstallationManager(
            kimiDirectory: kimiDirectory,
            managedHooksBinaryURL: currentBinaryURL
        )
        let stale = try manager.status()
        #expect(stale.managedHooksPresent)
        #expect(stale.managedCommandIsStale)

        let refreshed = try manager.install(hooksBinaryURL: sourceBinaryURL)
        #expect(refreshed.managedHooksPresent)
        #expect(!refreshed.managedCommandIsStale)
        #expect(refreshed.manifest?.hookCommand == KimiHookInstaller.hookCommand(for: currentBinaryURL.path))

        let rewritten = try String(contentsOf: refreshed.configURL, encoding: .utf8)
        #expect(rewritten.contains(currentBinaryURL.path))
        #expect(!rewritten.contains(legacyBinaryURL.path))
        #expect(rewritten.contains("echo keep-me"))
        #expect(rewritten.contains("default_model"))

        let uninstalled = try manager.uninstall()
        #expect(!uninstalled.managedHooksPresent)
        let remaining = try String(contentsOf: refreshed.configURL, encoding: .utf8)
        #expect(remaining.contains("echo keep-me"))
        #expect(remaining.contains("default_model"))
        #expect(!remaining.contains("OpenIslandHooks"))
    }

    @Test
    func resolvedAgentToolMapsKimiSource() {
        var payload = ClaudeHookPayload(
            cwd: "/tmp",
            hookEventName: .sessionStart,
            sessionID: "kimi-session-1"
        )
        payload.hookSource = "kimi"

        #expect(payload.resolvedAgentTool == .kimiCLI)
    }

    // Matches the quoting KimiHookInstaller writes into config.toml so the test's
    // synthetic "legacy" entry decodes through the same path the installer uses.
    private func tomlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
