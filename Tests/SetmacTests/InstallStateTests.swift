import Testing
@testable import Setmac

// MARK: - ConfigKey

@Suite("ConfigKey")
struct ConfigKeyTests {
    @Test("Different toolId + target produces different keys")
    func differentToolAndTarget() {
        let a = ConfigKey(toolId: "nvim", target: "nvim")
        let b = ConfigKey(toolId: "tmux", target: "tmux")
        #expect(a != b)
    }

    @Test("Same toolId + target produces equal keys")
    func sameKey() {
        let a = ConfigKey(toolId: "nvim", target: "nvim")
        let b = ConfigKey(toolId: "nvim", target: "nvim")
        #expect(a == b)
    }

    @Test("Can be used as dictionary key")
    func dictionaryKey() {
        var dict: [ConfigKey: String] = [:]
        let key = ConfigKey(toolId: "nvim", target: "nvim")
        dict[key] = "bundled"
        #expect(dict[key] == "bundled")
    }

    @Test("toolId containing colon does not clash with target-only key")
    func noColonAmbiguity() {
        // The old string key "tool:a:target" would be ambiguous —
        // struct keys are unambiguous by construction.
        let k1 = ConfigKey(toolId: "tool:a", target: "b")
        let k2 = ConfigKey(toolId: "tool", target: "a:b")
        #expect(k1 != k2)
    }
}

// MARK: - InstallState.applyMessage

@Suite("InstallState.applyMessage")
@MainActor
struct InstallStateApplyMessageTests {

    func makeMsg(
        type: String,
        tool: String? = "git",
        message: String? = nil,
        status: String? = nil,
        version: String? = nil,
        source: String? = nil,
        target: String? = nil
    ) -> CLIMessage {
        CLIMessage(
            type: type,
            tool: tool,
            message: message,
            status: status,
            version: version,
            source: source,
            target: target
        )
    }

    @Test("status installed sets .installed with version")
    func statusInstalled() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "status", status: "installed", version: "2.42.0"))
        if case let .installed(v) = state.statuses["git"] {
            #expect(v == "2.42.0")
        } else {
            Issue.record("Expected .installed")
        }
    }

    @Test("status not_installed sets .notInstalled")
    func statusNotInstalled() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "status", status: "not_installed"))
        #expect(state.statuses["git"] == .notInstalled)
    }

    @Test("progress sets .installing")
    func progress() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "progress", message: "Installing..."))
        #expect(state.statuses["git"] == .installing)
    }

    @Test("complete sets .installed and logs message")
    func complete() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "complete", message: "done", status: "installed", version: "2.42.0"))
        if case let .installed(v) = state.statuses["git"] {
            #expect(v == "2.42.0")
        } else {
            Issue.record("Expected .installed")
        }
        #expect(state.logLines.last?.message == "done")
    }

    @Test("uninstalled sets .notInstalled")
    func uninstalled() {
        let state = InstallState()
        state.statuses["git"] = .installed(version: "2.42.0")
        state.applyMessage(makeMsg(type: "uninstalled"))
        #expect(state.statuses["git"] == .notInstalled)
    }

    @Test("error sets .error with message")
    func error() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "error", message: "brew failed"))
        if case let .error(msg) = state.statuses["git"] {
            #expect(msg == "brew failed")
        } else {
            Issue.record("Expected .error")
        }
    }

    @Test("config_status populates configStatuses via ConfigKey")
    func configStatus() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "config_status", status: "bundled+system", target: "nvim"))
        let key = ConfigKey(toolId: "git", target: "nvim")
        #expect(state.configStatuses[key] == .bundledAndSystem)
    }

    @Test("log message appended to logLines")
    func log() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "log", message: "brew is downloading"))
        #expect(state.logLines.count == 1)
        #expect(state.logLines[0].message == "brew is downloading")
    }

    @Test("log ring buffer caps at 500 lines")
    func logRingBuffer() {
        let state = InstallState()
        for i in 0..<600 {
            state.applyMessage(makeMsg(type: "log", message: "line \(i)"))
        }
        #expect(state.logLines.count == 500)
        #expect(state.logLines.last?.message == "line 599")
    }

    @Test("unknown message type does not crash")
    func unknownType() {
        let state = InstallState()
        state.applyMessage(makeMsg(type: "future_unknown_type", message: "ignored"))
        // Should not crash; status is unchanged
        #expect(state.statuses["git"] == nil)
    }
}

// MARK: - ManifestLoader

@Suite("ManifestLoadError description")
struct ManifestLoadErrorTests {
    @Test("notFound has non-empty description")
    func notFoundDescription() {
        let err = ManifestLoadError.notFound
        #expect(!err.description.isEmpty)
    }

    @Test("schemaVersionMismatch includes version numbers")
    func mismatchDescription() {
        let err = ManifestLoadError.schemaVersionMismatch(found: 2, required: 1)
        #expect(err.description.contains("2"))
        #expect(err.description.contains("1"))
    }

    @Test("decodingFailed includes detail")
    func decodingFailedDescription() {
        let err = ManifestLoadError.decodingFailed("unexpected null")
        #expect(err.description.contains("unexpected null"))
    }
}
