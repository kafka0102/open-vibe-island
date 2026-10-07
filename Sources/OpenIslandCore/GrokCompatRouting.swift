import Foundation

/// Decides when a Claude-family hook invocation is actually Grok.
///
/// Grok CLI loads `~/.claude/settings.json` for Claude Code compatibility and
/// runs those commands unchanged, including `--source claude`. The process
/// environment and the camelCase envelope are the reliable identity signals:
/// Claude itself only emits snake_case `hook_event_name` / `session_id` /
/// `last_assistant_message`.
public enum GrokCompatRouting {
    public static func shouldRouteToGrok(payload: Data, environment: [String: String]) -> Bool {
        if isGrokHookProcess(environment: environment) {
            return true
        }
        return payloadLooksLikeGrokEnvelope(payload)
    }

    /// Grok's hook runner sets these on every hook process. Claude Code does not.
    public static func isGrokHookProcess(environment: [String: String]) -> Bool {
        for key in ["GROK_SESSION_ID", "GROK_HOOK_EVENT"] {
            let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty {
                return true
            }
        }
        return false
    }

    /// True when stdin is Grok's compat envelope rather than a Claude payload.
    ///
    /// Grok sends both shapes at once: camelCase `hookEventName` / `sessionId`,
    /// plus Claude's `hook_event_name` / `session_id`. The assistant reply is
    /// only on camelCase `lastAssistantMessage`.
    public static func payloadLooksLikeGrokEnvelope(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        let hasCamelIdentity = object["hookEventName"] != nil && object["sessionId"] != nil
        let hasCamelAssistantReply = object["lastAssistantMessage"] != nil && object["hook_event_name"] != nil
        return hasCamelIdentity || hasCamelAssistantReply
    }
}
