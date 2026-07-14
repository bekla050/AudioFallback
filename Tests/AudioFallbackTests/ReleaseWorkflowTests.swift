import Foundation
import Testing

struct ReleaseWorkflowTests {
    @Test func hasTagTriggerSecurityGatesAndDraftPublication() throws {
        let workflow = try String(contentsOf: repositoryRoot.appendingPathComponent(".github/workflows/release.yml"))
        for required in [
            "v*.*.*", "contents: write", "scripts/validate-release.sh", "swift test",
            "scripts/build-app.sh", "codesign --verify --strict", "notarytool submit",
            "stapler staple", "generate_appcast", "--ed-key-file -", "gh release create",
            "--draft", "gh release edit", "--draft=false", "MACOS_CERT_P12",
            "MACOS_CERT_PASSWORD", "MACOS_SIGN_IDENTITY", "NOTARY_APPLE_ID",
            "NOTARY_TEAM_ID", "NOTARY_PASSWORD", "SPARKLE_PRIVATE_KEY",
            "Erforderliches Secret fehlt"
        ] {
            #expect(workflow.contains(required))
        }
    }

    @Test func keepsSecretsOutOfScriptsAndOrdersReleaseGates() throws {
        let workflow = try String(contentsOf: repositoryRoot.appendingPathComponent(".github/workflows/release.yml"))
        #expect(workflow.contains("on:\n  push:\n    tags:\n      - \"v*.*.*\""))
        for disallowedTrigger in ["pull_request:", "workflow_dispatch:", "schedule:"] {
            #expect(!workflow.contains(disallowedTrigger))
        }

        let notarizationStart = try #require(workflow.range(of: "- name: Notarisieren und stapeln")?.lowerBound)
        let appcastStart = try #require(workflow.range(
            of: "- name: Signierten Appcast erzeugen",
            range: notarizationStart..<workflow.endIndex
        )?.lowerBound)
        let notarizationStep = String(workflow[notarizationStart..<appcastStart])
        let runStart = try #require(notarizationStep.range(of: "run: |")?.lowerBound)
        let notarizationRun = String(notarizationStep[runStart...])

        for secret in ["NOTARY_APPLE_ID", "NOTARY_TEAM_ID", "NOTARY_PASSWORD"] {
            #expect(notarizationStep.contains("\(secret): ${{ secrets.\(secret) }}"))
            #expect(!notarizationRun.contains("${{ secrets.\(secret) }}"))
        }
        #expect(notarizationRun.contains("--apple-id \"$NOTARY_APPLE_ID\""))
        #expect(notarizationRun.contains("--team-id \"$NOTARY_TEAM_ID\""))
        #expect(notarizationRun.contains("--password \"$NOTARY_PASSWORD\""))
        #expect(workflow.contains("codesign --verify --strict --deep --verbose=2"))

        let validation = try #require(workflow.range(of: "scripts/validate-release.sh")?.lowerBound)
        let tests = try #require(workflow.range(of: "run: swift test")?.lowerBound)
        let build = try #require(workflow.range(of: "run: scripts/build-app.sh")?.lowerBound)
        let draft = try #require(workflow.range(of: "gh release create")?.lowerBound)
        let publication = try #require(workflow.range(of: "gh release edit")?.lowerBound)
        #expect(validation < tests)
        #expect(tests < build)
        #expect(build < draft)
        #expect(draft < publication)
    }
}

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
