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
    
    public convenience init(executable: String, environment: [String: String]? = nil, currentDirectoryURL: URL? = nil) throws {
        let executableURL = try TerminalRunner.which(executable: executable, environment: environment, currentDirectoryURL: currentDirectoryURL)
        self.init(executableURL: executableURL, environment: environment, currentDirectoryURL: currentDirectoryURL)
    }
    
    public func makeRunnerFuture(_ arguments: String...) throws -> Future {
        return try .init(runner: self).launch(arguments)
    }
    
    public func makeRunnerFuture(_ arguments: [String]) throws -> Future {
        return try .init(runner: self).launch(arguments)
    }
}

extension TerminalRunner {
    
    private static var caches: [String: URL] = [:]
    
    private static var semaphore: DispatchSemaphore = .init(value: 1)
    
    private static func which(executable: String, environment: [String: String]? = nil, currentDirectoryURL: URL? = nil) throws -> URL {
        semaphore.wait()
        defer { semaphore.signal() }
        if let url = caches[executable] {
            return url
        } else {
            let runner = TerminalRunner(executableURL: .init(fileURLWithPath: "/usr/bin/which"), environment: environment, currentDirectoryURL: currentDirectoryURL)
            if let message = try runner.makeRunnerFuture(executable).wait().readlines?.first {
                return .init(fileURLWithPath: message)
            } else {
                throw Error.notfound(executable)
            }
        }
    }
}

extension TerminalRunner {
    
    public class Future {
        
        public let runner: TerminalRunner
        
        private let process: Process
        
        private let standardInput: Pipe

        private let standardOutput: Pipe

        private let standardError: Pipe
        
        private let terminationQueue: OperationQueue
        
        private var readReadabilityHandler: ((Message) -> Void)?
        
        internal init(runner: TerminalRunner) {
            self.runner = runner
            self.process = .init()
            self.standardInput = .init()
            self.standardOutput = .init()
            self.standardError = .init()
            self.terminationQueue = .init()
            self.terminationQueue.isSuspended = true
        }
        
        public func wait() throws -> Message {
            var result: Message = .output(.init())
            read { result += $0 }
            let semaphore = DispatchSemaphore(value: 0)
            terminationQueue.addOperation {
                semaphore.signal()
            }
            semaphore.wait()
            return result
        }
        
        public func read(_ body: @escaping (Message) -> Void) {
            readReadabilityHandler = body
        }
        
        public func write(_ data: Data) throws {
            standardInput.fileHandleForWriting.write(data)
        }
    }
    
    public enum Message {
        
        case output(Data)
        
        case error(Data)
        
        public var string: String? {
            switch self {
            case .output(let data): return String(data: data, encoding: .utf8)
            case .error(let data): return String(data: data, encoding: .utf8)
            }
        }
        
        public var readlines: [String]? {
            guard let string = string else {
                return nil
            }
            return string.split(separator: "\n").map(String.init)
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
    
    public enum Error: Swift.Error {
        
        case notfound(String)
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
        
        OperationQueue().addOperation { [self] in
            let group = DispatchGroup()
            group.enter()
            process.terminationHandler = { _ in
                group.leave()
            }
            group.wait()
            standardOutput.fileHandleForReading.readabilityHandler = nil
            standardError.fileHandleForReading.readabilityHandler =  nil
            readReadabilityHandler = nil
            terminationQueue.isSuspended = false
        }
        
        return self
    }
}
