import Testing
@testable import AudioFallback

struct AudioFallbackPlannerTests {
    @Test func choosesFirstAvailableInputFromPriorityList() {
        let unavailableUID = "studio-mic"
        let fallback = ManagedAudioDevice(
            id: 1,
            uid: "macbook-mic",
            name: "MacBook Microphone",
            supportsInput: true,
            supportsOutput: false
        )
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [unavailableUID, fallback.uid],
            outputPriorityUIDs: []
        )

        let selected = AudioFallbackPlanner.preferredDevice(
            for: .input,
            preferences: preferences,
            availableDevices: [fallback]
        )

        #expect(selected == fallback)
    }

    @Test func inputAndOutputPriorityListsAreIndependent() {
        let headset = ManagedAudioDevice(
            id: 1,
            uid: "headset",
            name: "Bluetooth Headset",
            supportsInput: true,
            supportsOutput: true
        )
        let microphone = ManagedAudioDevice(
            id: 2,
            uid: "usb-mic",
            name: "USB Microphone",
            supportsInput: true,
            supportsOutput: false
        )
        let speakers = ManagedAudioDevice(
            id: 3,
            uid: "desk-speakers",
            name: "Desk Speakers",
            supportsInput: false,
            supportsOutput: true
        )
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [microphone.uid, headset.uid],
            outputPriorityUIDs: [speakers.uid, headset.uid]
        )

        #expect(AudioFallbackPlanner.preferredDevice(
            for: .input,
            preferences: preferences,
            availableDevices: [headset, microphone, speakers]
        ) == microphone)

        #expect(AudioFallbackPlanner.preferredDevice(
            for: .output,
            preferences: preferences,
            availableDevices: [headset, microphone, speakers]
        ) == speakers)
    }

    @Test func mergesDiscoveredDevicesAtTheEnd() {
        let known = ManagedAudioDevice(
            id: 1,
            uid: "known",
            name: "Known",
            supportsInput: false,
            supportsOutput: true
        )
        let discovered = ManagedAudioDevice(
            id: 2,
            uid: "discovered",
            name: "Discovered",
            supportsInput: false,
            supportsOutput: true
        )
        let inputOnly = ManagedAudioDevice(
            id: 3,
            uid: "input-only",
            name: "Input Only",
            supportsInput: true,
            supportsOutput: false
        )
        let preferences = AudioFallbackPreferences(outputPriorityUIDs: [known.uid])

        let merged = AudioFallbackPlanner.mergedPriorityUIDs(
            for: .output,
            preferences: preferences,
            availableDevices: [known, discovered, inputOnly]
        )

        #expect(merged == [known.uid, discovered.uid])
    }

    @Test func seedsEmptyPriorityListWithCurrentDevice() {
        let current = ManagedAudioDevice(
            id: 1,
            uid: "current-speakers",
            name: "Current Speakers",
            supportsInput: false,
            supportsOutput: true
        )
        let other = ManagedAudioDevice(
            id: 2,
            uid: "other-speakers",
            name: "Other Speakers",
            supportsInput: false,
            supportsOutput: true
        )

        let merged = AudioFallbackPlanner.mergedPriorityUIDs(
            for: .output,
            preferences: AudioFallbackPreferences(),
            availableDevices: [other, current],
            preferredFirstUID: current.uid
        )

        #expect(merged == [current.uid, other.uid])
    }

    @Test func keepsExistingPriorityAheadOfCurrentSystemDevice() {
        let preferred = ManagedAudioDevice(
            id: 1,
            uid: "preferred-mic",
            name: "Preferred Microphone",
            supportsInput: true,
            supportsOutput: false
        )
        let systemSelected = ManagedAudioDevice(
            id: 2,
            uid: "bluetooth-headset",
            name: "Bluetooth Headset",
            supportsInput: true,
            supportsOutput: true
        )
        let preferences = AudioFallbackPreferences(inputPriorityUIDs: [preferred.uid, systemSelected.uid])

        let merged = AudioFallbackPlanner.mergedPriorityUIDs(
            for: .input,
            preferences: preferences,
            availableDevices: [systemSelected, preferred],
            preferredFirstUID: systemSelected.uid
        )

        #expect(merged == [preferred.uid, systemSelected.uid])
    }
}
