import XCTest

@testable import TerminalRunner

final class Tests: XCTestCase {
    
    func testList() async throws {
        _ = try await TerminalRunner(
            executable: "ls",
            currentDirectoryURL: .init(fileURLWithPath: NSHomeDirectory())
        ).make("-ah")
    }
    
    func testWhich() throws {
        let runner = TerminalRunner(executableURL: .init(fileURLWithPath: "/usr/bin/which"))
        XCTAssertNotNil(runner)
    }
}
