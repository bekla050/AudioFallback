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
}

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
