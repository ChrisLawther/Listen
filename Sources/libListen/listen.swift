import Foundation
import Speech

public enum Listen {
    public struct Config {
        let language: String
        let input: Input
        let onDevice: Bool
        let singleLineMode: Bool
        let addPunctuation: Bool
        let exitWord: String?

        public init(language: String,
                    input: String?,
                    onDevice: Bool,
                    singleLineMode: Bool,
                    addPunctuation: Bool,
                    exitWord: String?) {
            self.language = language
            self.input = switch input {
            case .none:
                .device
            case .some(let filename):
                .file(filename)
            }

            self.onDevice = onDevice
            self.singleLineMode = singleLineMode
            self.addPunctuation = addPunctuation
            self.exitWord = exitWord
        }

        public enum Input {
            case device
            case file(String)
        }
    }

    /// Public entry point to begin transcription
    /// - Parameter config: Configuration describing the options to apply
    public static func transcribe(_ config: Config) {
        guard supportedLanguages().contains(config.language) else {
            die("Locale '\(config.language)' not supported. Run with -s flag to see list of supported locales")
        }

        requestSpeechAuthorization {
            transcribe(config: config)
        }

        // We need to keep the thread alive, without burning CPU
        while true {
            sleep(10)
        }
    }

    public static func printSupportedLanguages() {
        print(supportedLanguages().joined(separator: "\n"))
    }
}

extension Listen {
    // (There's probably a more correct way of mitigating strict concurrency errors)
    // These are only ever written to once, to retain the objects
    nonisolated(unsafe) static var avEngine: AVAudioEngine?
    nonisolated(unsafe) static var task: SFSpeechRecognitionTask?

    typealias OutputHandler = (String, Bool) -> Void
    
    /// Ask the system to prompt the user for permission to perform speech recognition
    /// - Parameter perform: A closure to execute if permission is given.
    static func requestSpeechAuthorization(then perform: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                perform()
            case .denied:
                Self.die("Speech recognition authorization denied")
            case .notDetermined:
                Self.die("Speech recognition authorization not determined")
            case .restricted:
                Self.die("Speech recognition authorization restricted on this device")
            @unknown default:
                Self.die("Unexpected authorization status (\(status)")
            }
        }
    }

    /// Perform a transcription
    /// - Parameters:
    ///   - config: The configuration
    static func transcribe(config: Config) {
        let request = makeRecognitionRequest(config: config)
        let recognizer = makeRecognizer(for: config.language, onDevice: config.onDevice)
        let outputHandler = outputHandler(for: config)

        task = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                Self.die(error.localizedDescription)
            }

            guard let result else { return }

            let transcript = result.bestTranscription.formattedString

            outputHandler(transcript, result.isFinal)
        }

        guard let bufferRecognitionRequest = request as? SFSpeechAudioBufferRecognitionRequest else {
            // Working from a file, nothing more to do here
            return
        }

        avEngine = AVAudioEngine()
        let inputNode = avEngine!.inputNode

        inputNode.installTap(onBus: 0,
                             bufferSize: 3200,
                             format: inputNode.outputFormat(forBus: 0)) { buffer, when in
            bufferRecognitionRequest.append(buffer)
        }

        do {
            try avEngine?.start()
        } catch {
            die("Failed to start audio capture: \(error)")
        }
    }
    
    /// Create and configure a `SFSpeechRecognitionRequest` suitable for the given configuration
    /// - Parameter config: The configuration
    /// - Returns: A `SFSpeechAudioBufferRecognitionRequest` or `SFSpeechURLRecognitionRequest`, as appropriate
    static func makeRecognitionRequest(config: Config) -> SFSpeechRecognitionRequest {
        let request:SFSpeechRecognitionRequest

        switch config.input {
        case .device:
            let bufferRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            request = bufferRecognitionRequest
            request.shouldReportPartialResults = true

        case .file(let filepath):
            guard FileManager.default.fileExists(atPath: filepath) else {
                die("No file at path '\(filepath)'")
            }
            let fileURL = URL(fileURLWithPath: filepath)
            request = SFSpeechURLRecognitionRequest(url: fileURL)
            request.shouldReportPartialResults = false
        }

        request.requiresOnDeviceRecognition = config.onDevice
        request.addsPunctuation = config.addPunctuation

        return request
    }

    /// Creates and confirms the featuers of a `SFSpeechRecognizer` for the given language
    /// - Parameter language: The desired language
    /// - Returns: A `SFSpeechRecognizer`
    static func makeRecognizer(for language: String, onDevice: Bool) -> SFSpeechRecognizer {
        let locale = Locale(identifier: language)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            die("Unable to initialize speech recognizer")
        }

        guard recognizer.isAvailable else {
            die("Speech recognizer not available. Try enabling Siri in System Preferences/Settings.")
        }

        if onDevice && !recognizer.supportsOnDeviceRecognition {
            die("On-device recognition is not supported for locale '\(language)'")
        }

        return recognizer
    }
    
    /// Creates an `OutputHandler` to suit the supplied configuration
    /// - Parameter config: The current configuration
    /// - Returns: An `OutputHandler`
    static func outputHandler(for config: Config) -> OutputHandler {
        switch config.input {
        case .device:
            onDeviceOutputHandler(for: config)
        case .file:
            fileInputOutputHandler()
        }
    }
    
    /// Creates a closure suitable for handling the output of a live audio transcription
    /// - Parameter config: The current configuration
    /// - Returns: An `OutputHandler`
    static func onDeviceOutputHandler(for config: Config) -> OutputHandler {
        { transcript, isFinal in
            if config.singleLineMode {
                // \u{001B} is unicode for the escape sequence(?)
                // 2k means clear line
                // \r means carriage return (no newline)
                print("\u{001B}[2K\r\(transcript)", terminator: "")
                fflush(stdout)
            } else {
                print(transcript)
            }

            if let exitWord = config.exitWord {
                let lowercased = transcript.lowercased()
                if lowercased.hasSuffix(" \(exitWord)") || lowercased == exitWord {
                    exit(EXIT_SUCCESS)
                }
            }

            if isFinal {
                exit(EXIT_SUCCESS)
            }
        }
    }

    /// Creates a closure suitable for handling the output of a file-based transcription
    /// - Returns: An `OutputHandler`
    static func fileInputOutputHandler() -> OutputHandler {
        { transcript, isFinal in
            let suffix = !transcript.hasSuffix(" ") && !isFinal ? " " : ""
            print(transcript + suffix, terminator: "")
            fflush(stdout)
            
            if isFinal {
                print("")
                exit(EXIT_SUCCESS)
            }
        }
    }

    /// List the supported langauges
    /// - Returns: A sorted list of the identifiers of all available locales
    static func supportedLanguages() -> [String] {
        return SFSpeechRecognizer
            .supportedLocales()
            .map(\.identifier)
            .sorted()
    }

    /// Print the supplied message and exit
    /// - Parameter message: The message to print
    static func die(_ message: String) -> Never {
        print(message)
        exit(EXIT_FAILURE)
    }
}
