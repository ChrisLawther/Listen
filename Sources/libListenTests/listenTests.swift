import Testing
@testable import libListen

@Suite("Configuration Tests")
struct configurationTests {

    // Almost everything else is closely interacting with the system,
    // so not very amenable to unit testing. At least, not without
    // a *huge* injected dependencies + mocking effort.
    @Test
    func passingAFileNameResultsInAFileBasedTranscriptionConfiguration() throws {
        let config = Listen.Config(language: "",
                                   input: "somefile",
                                   onDevice: true,
                                   singleLineMode: true,
                                   addPunctuation: true,
                                   exitWord: nil)

        switch config.input {
        case .file(let fileName):
            #expect(fileName == "somefile")
        default:
            Issue.record("Input type should be .file")
        }
    }

    @Test
    func notPassingAFileNameResultsInADeviceBasedTranscriptionConfiguration() throws {
        let config = Listen.Config(language: "",
                                   input: nil,
                                   onDevice: true,
                                   singleLineMode: true,
                                   addPunctuation: true,
                                   exitWord: nil)

        switch config.input {
        case .device:
            break
        default:
            Issue.record("Input type should be .device")
        }
    }

}
