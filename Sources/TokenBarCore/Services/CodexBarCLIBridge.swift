import Foundation

public enum CLIBridgeError: Error, LocalizedError {
    case binaryNotFound
    case executionFailed(String)
    case parsingFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "CodexBar CLI binary not found in standard paths."
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        case .parsingFailed(let msg):
            return "JSON parsing failed: \(msg)"
        case .timedOut:
            return "Command timed out."
        }
    }
}

public actor CodexBarCLIBridge {
    public static let shared = CodexBarCLIBridge()

    private static let binaryCandidates: [String] = [
        "/opt/homebrew/bin/codexbar",
        "/usr/local/bin/codexbar",
        "/Applications/CodexBar.app/Contents/MacOS/CodexBarCLI"
    ]

    public nonisolated var resolvedPath: String? {
        Self.binaryCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public init() {}

    /// Runs codexbar --version and returns the detected CLI version string.
    public func fetchVersion(timeoutSeconds: TimeInterval = 3.0) async -> String? {
        guard let path = resolvedPath else { return nil }
        do {
            let data = try await runProcess(executablePath: path, arguments: ["--version"], timeout: timeoutSeconds)
            guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            if let last = raw.split(separator: " ").last {
                return String(last)
            }
            return raw
        } catch {
            return nil
        }
    }

    /// Runs codexbar CLI and returns decoded responses for all or specific provider.
    public func fetchUsage(provider: String? = nil, timeoutSeconds: TimeInterval = 15.0) async throws -> [CodexBarResponse] {
        guard let path = resolvedPath else {
            throw CLIBridgeError.binaryNotFound
        }

        var arguments = ["usage", "--format", "json"]
        if let provider {
            arguments.append(contentsOf: ["--provider", provider])
        }

        let data = try await runProcess(executablePath: path, arguments: arguments, timeout: timeoutSeconds)

        do {
            let responses = try JSONDecoder().decode([CodexBarResponse].self, from: data)
            return responses
        } catch {
            if let single = try? JSONDecoder().decode(CodexBarResponse.self, from: data) {
                return [single]
            }
            let outputStr = String(data: data, encoding: .utf8) ?? "<binary data>"
            throw CLIBridgeError.parsingFailed("\(error.localizedDescription). Output: \(outputStr)")
        }
    }

    /// Converts a CodexBarResponse to a presentation-ready ProviderUsage.
    public static func mapResponseToUsage(_ response: CodexBarResponse, config: ProviderConfig) -> ProviderUsage {
        var usage = ProviderUsage(id: config.id, displayName: config.displayName)
        usage.source = response.source

        if let error = response.error {
            usage.error = error.message
            return usage
        }

        guard let data = response.usage else {
            usage.error = "No quota data returned"
            return usage
        }

        func window(for field: ProviderConfig.RateWindowField) -> RateWindow? {
            switch field {
            case .primary: return data.primary
            case .secondary: return data.secondary
            case .tertiary: return data.tertiary
            }
        }

        if let extras = data.extraRateWindows {
            usage.extraWindows = extras.map { extra in
                ExtraWindowUsage(
                    id: extra.id,
                    title: extra.title,
                    usedPercent: extra.window.usedPercent,
                    resetsAt: extra.window.resetsAt,
                    windowMinutes: extra.window.windowMinutes
                )
            }
        }

        let org = data.accountOrganization ?? data.identity?.accountOrganization
        usage.accountOrganization = org
        usage.accountEmail = data.accountEmail ?? data.identity?.accountEmail
        usage.loginMethod = data.loginMethod ?? data.identity?.loginMethod
        usage.lastUpdated = data.updatedAt ?? Date()

        if config.displayType == .balance {
            let win = window(for: config.balanceField ?? .primary)
            if let desc = win?.resetDescription {
                usage.balance = extractBalance(from: desc)
            } else if let percent = win?.usedPercent {
                usage.balance = "\(Int(percent))%"
            }
        } else {
            let sessionWin = window(for: config.sessionField)
            let weeklyWin = config.weeklyField.flatMap { window(for: $0) }
            usage.sessionPercent = sessionWin?.usedPercent
            usage.sessionWindowMinutes = sessionWin?.windowMinutes
            usage.sessionResetsAt = sessionWin?.resetsAt

            usage.weeklyPercent = weeklyWin?.usedPercent
            usage.weeklyWindowMinutes = weeklyWin?.windowMinutes
            usage.weeklyResetsAt = weeklyWin?.resetsAt

            if config.sessionField != .tertiary && config.weeklyField != .tertiary, let tert = data.tertiary {
                usage.tertiaryPercent = tert.usedPercent
                usage.tertiaryWindowMinutes = tert.windowMinutes
                usage.tertiaryResetsAt = tert.resetsAt
            }
        }

        return usage
    }

    public static func extractBalance(from description: String) -> String {
        if let range = description.range(of: #"[¥$€£]\d+\.?\d*"#, options: .regularExpression) {
            return String(description[range])
        }
        if let range = description.range(of: #"\d+\.?\d*\s*(credits?|pts?|points?)"#, options: [.regularExpression, .caseInsensitive]) {
            return String(description[range])
        }
        return description
    }

    private func runProcess(executablePath: String, arguments: [String], timeout: TimeInterval) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            process.terminationHandler = { proc in
                timeoutItem.cancel()
                let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

                if proc.terminationStatus != 0 && stdoutData.isEmpty {
                    let errStr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Process exited with code \(proc.terminationStatus)"
                    continuation.resume(throwing: CLIBridgeError.executionFailed(errStr))
                } else {
                    continuation.resume(returning: stdoutData)
                }
            }

            do {
                try process.run()
            } catch {
                timeoutItem.cancel()
                continuation.resume(throwing: CLIBridgeError.executionFailed(error.localizedDescription))
            }
        }
    }
}
