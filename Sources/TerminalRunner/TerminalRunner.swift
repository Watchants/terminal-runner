//
//  TerminalRunner.swift
//  TerminalRunner
//
//  Created by Tiger on 3/20/22.
//

import Foundation

public final class TerminalRunner {
    
    public let executableURL: URL
    
    public let currentDirectoryURL: URL?
    
    public let environment: [String: String]?
    
    public init(executableURL: URL, environment: [String: String]? = nil, currentDirectoryURL: URL? = nil) {
        self.environment = environment
        self.executableURL = executableURL
        self.currentDirectoryURL = currentDirectoryURL
    }
    
    public convenience init(executable: String, environment: [String: String]? = nil, currentDirectoryURL: URL? = nil) async throws {
        let executableURL = try await TerminalRunner.which(
            executable: executable,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )
        self.init(
            executableURL: executableURL,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )
    }
    
    public func makeRunnerFuture(_ arguments: [String], body: @escaping (Message) -> Void) throws -> Future {
        try .init(runner: self, body: body).launch(arguments)
    }
    
    public func makeRunnerFuture(_ arguments: String..., body: @escaping (Message) -> Void) throws -> Future {
        try makeRunnerFuture(arguments, body: body)
    }
    
    public func make(_ arguments: String...) async throws -> [Message] {
        var messages = [Message]()
        let future = try makeRunnerFuture(arguments) { message in
            messages.append(message)
        }
        try await future.wait()
        return messages
    }
    
}

extension TerminalRunner.Future {
    
    public func wait() async throws {
        try await withUnsafeThrowingContinuation { continuation in
            do {
                try _wait().get()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func _wait() -> Result<Void, Error>  {
        let semaphore: DispatchSemaphore = .init(value: 0)
        var result = Result<Void, Error>.failure(Error("Something unexpected happened"))
        termination { status in
            switch status {
            case .running, .idle:
                result = .failure(Error("Something unexpected happened"))
            case .completed(let status):
                if status == 0 {
                    result = .success(())
                } else {
                    result = .failure(Error("TerminalRunner ended with exit code:\(status)"))
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    
}

extension TerminalRunner {
    
    private static func which(executable: String, environment: [String: String]? = nil, currentDirectoryURL: URL? = nil) async throws -> URL {
        let runner = TerminalRunner(
            executableURL: .init(fileURLWithPath: "/usr/bin/which"),
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )
        let messages = try await runner.make(executable)
        if let path = messages.message?.split(separator: "\n").first {
            return .init(fileURLWithPath: .init(path))
        } else {
            throw Error("command not found: \(executable)")
        }
    }
}

extension TerminalRunner {
    
    public class Future {
        
        public let runner: TerminalRunner
        
        public private(set) var status: Status
        
        private let process: Process
        
        private let standardInput: Pipe

        private let standardOutput: Pipe

        private let standardError: Pipe
        
        private let terminationQueue: OperationQueue
        
        private var readReadabilityHandler: ((Message) -> Void)?
        
        internal init(runner: TerminalRunner, body: @escaping (Message) -> Void) {
            self.status = .idle
            self.runner = runner
            self.process = .init()
            self.standardInput = .init()
            self.standardOutput = .init()
            self.standardError = .init()
            self.terminationQueue = .init()
            self.terminationQueue.isSuspended = true
            self.readReadabilityHandler = body
        }
        
        public func write(_ data: Data) throws {
            standardInput.fileHandleForWriting.write(data)
        }
        
        public func termination(block: @escaping (Status) -> Void) {
            terminationQueue.addOperation { [self] in
                block(status)
            }
        }
    }
    
    public enum Status {
        
        case idle
        
        case running
        
        case completed(Int32)
    }
    
    public enum Message {
        
        case output(Data)
        
        case error(Data)
        
        public var data: Data {
            switch self {
            case .output(let data):
                return data
            case .error(let data):
                return data
            }
        }
        
        public var string: String? {
            switch self {
            case .output(let data):
                return String(data: data, encoding: .utf8)
            case .error(let data):
                return String(data: data, encoding: .utf8)
            }
        }
        
        static func +=(lhs: inout Message, rhs: Message) {
            lhs = lhs + rhs
        }
        
        static func +(lhs: Message, rhs: Message) -> Message {
            switch (lhs, rhs) {
            case (.output(let data1), .output(let data2)):
                return .output(data1 + data2)
            case (.error(let data1), .error(let data2)):
                return .error(data1 + data2)
            case (.output(let data1), .error(let data2)):
                return .output(data1 + data2)
            case (.error(let data1), .output(let data2)):
                return .output(data1 + data2)
            }
        }
    }
    
}

extension TerminalRunner.Future {
    
    private func readability(_ message: TerminalRunner.Message) {
        readReadabilityHandler?(message)
    }
        
    private func standardOutputReadability(_ data: Data) {
        readability(.output(data))
    }
    
    private func standardErrorReadability(_ data: Data) {
        readability(.error(data))
    }
    
    private func standardOutputReadability(_ fileHandle: FileHandle) {
        readability(fileHandle, callback: standardOutputReadability(_:))
    }
    
    private func standardErrorReadability(_ fileHandle: FileHandle) {
        readability(fileHandle, callback: standardErrorReadability(_:))
    }
    
    private func readability(_ fileHandle: FileHandle, callback: (Data) -> Void) {
        var data = fileHandle.availableData
        while !data.isEmpty {
            defer { data = fileHandle.availableData }
            callback(data)
        }
    }
    
    internal func launch(_ arguments: [String]) throws -> Self {
        process.executableURL = runner.executableURL
        if let environment = runner.environment {
            process.environment = environment
        }
        if let currentDirectoryURL = runner.currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }
        process.arguments = arguments
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        
        standardOutput.fileHandleForReading.readabilityHandler = standardOutputReadability(_:)
        standardError.fileHandleForReading.readabilityHandler = standardErrorReadability(_:)
        
        try process.run()
        status = .running
        
        OperationQueue().addOperation { [self] in
            let group = DispatchGroup()
            group.enter()
            process.terminationHandler = { _ in
                group.leave()
            }
            group.wait()
            status = .completed(process.terminationStatus)
            standardOutput.fileHandleForReading.readabilityHandler = nil
            standardError.fileHandleForReading.readabilityHandler =  nil
            readReadabilityHandler = nil
            terminationQueue.isSuspended = false
        }
        
        return self
    }
}

extension Array where Element == TerminalRunner.Message {
    
    public var message: String? {
        let data = reduce(into: Data()) { data, message in
            data.append(contentsOf: message.data)
        }
        return .init(data: data, encoding: .utf8)
    }
    
}
