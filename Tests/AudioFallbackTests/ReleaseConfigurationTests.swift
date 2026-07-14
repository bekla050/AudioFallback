import Foundation
import Testing

struct ReleaseConfigurationTests {
    @Test func releaseMetadataMatchesVersion030() throws {
        #expect(try run("scripts/build-app.sh", "--print-version").stdout == "0.3.0\n")
        #expect(try run("scripts/build-app.sh", "--print-build-version").stdout == "5\n")
        #expect(try run("scripts/build-app.sh", "--print-dmg-name").stdout == "AudioFallback-0.3.0.dmg\n")
        #expect(try run("scripts/validate-release.sh", "v0.3.0").status == 0)
    }

    @Test func rejectsMismatchedOrMalformedTags() throws {
        #expect(try run("scripts/validate-release.sh", "v0.2.1").status != 0)
        #expect(try run("scripts/validate-release.sh", "0.3.0").status != 0)
        #expect(try run("scripts/validate-release.sh", "v0.3").status != 0)
    }

    @Test func containsSparkleSecurityConfiguration() throws {
        let script = try String(contentsOf: repositoryRoot.appendingPathComponent("scripts/build-app.sh"))
        #expect(script.contains("https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml"))
        #expect(script.contains("iAIs1MYTW9kxpXK+DXdhWBFr6geSS14RG0CwZR3DFgs="))
        #expect(script.contains("SUScheduledCheckInterval"))
        #expect(script.contains("86400"))
    }
}

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

private func run(_ relativeExecutable: String, _ arguments: String...) throws -> CommandResult {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = repositoryRoot.appendingPathComponent(relativeExecutable)
    process.arguments = arguments
    process.currentDirectoryURL = repositoryRoot
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    return CommandResult(
        status: process.terminationStatus,
        stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
        stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}
