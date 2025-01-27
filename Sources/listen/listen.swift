// The Swift Programming Language
// https://docs.swift.org/swift-book
import ArgumentParser
import libListen
import struct Foundation.Locale

@main
struct ListenApp: AsyncParsableCommand {
    //    // https://apple.github.io/swift-argument-parser/documentation/argumentparser/declaringarguments/
    //    // Arguments are the trailing list of zero or more values (*not* associated with any -key)
    //    @Argument(help: "Recipes to downloads")
    //    var recipeURLs: [String]
    //
    //    // An option is a key and a value, e.g. -destination foo
    //    @Option(name: .shortAndLong, help: "Folder to write PDF(s) to")
    //    var destination: String = "."
    //
    //    // A flag is just a key, e.g. -verbose
    //    @Flag(name: .shortAndLong, help: "Set to true if the URL(s) are collections")
    //    var isCollection: Bool = false

    // Override the default app name (derived from our type name)
    static let configuration = CommandConfiguration(commandName: "listen")

    @Flag(name: .shortAndLong, help: "Print list of supported languages (locales)")
    var supported: Bool = false

    @Flag(name: .shortAndLong, help: "Prints program name and version")
    var version: Bool = false

    @Flag(name: .shortAndLong, help: "Only use on-device speech recognition")
    var device: Bool = false

    @Flag(name: [.customShort("m"), .customLong("single")], help: "Single line mode (mic only)")
    var singleLineMode: Bool = false

    @Flag(name: .shortAndLong, help: "Add punctuation to speech recognition results (macOS 13+)")
    var punctuation: Bool = false

    @Option(name: [.customShort("x"), .customLong("exit")], help: "Set exit word that causes program to quit")
    var exitWord: String?

    @Option(name: .shortAndLong, help: "Specify audio file to process")
    var input: String?

    @Option(name: .shortAndLong, help: "Specify speech recognition language (locale)")
    var language: String = Locale.current.identifier
        .replacingOccurrences(of: "_", with: "-")

    mutating func run() async throws {
        if version {
            print("listen version 1.0 (adapted from hear by Sveinbjorn Thordarson)")
            return
        }

        if supported {
            Listen.printSupportedLanguages()
            return
        }

        let config = Listen.Config(language: language,
                                 input: input,
                                 onDevice: device,
                                 singleLineMode: singleLineMode,
                                 addPunctuation: punctuation,
                                 exitWord: exitWord)

        Listen.transcribe(config)
    }
}
