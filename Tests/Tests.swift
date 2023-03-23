import XCTest

@testable import TerminalRunner

final class Tests: XCTestCase {
    
    func testList() throws {
        try TerminalRunner(executable: "ls", currentDirectoryURL: .init(fileURLWithPath: NSHomeDirectory())).wait("-ah")
    }
    
    func testWhich() throws {
        let runner = TerminalRunner(executableURL: .init(fileURLWithPath: "/usr/bin/which"))
        XCTAssertNil(runner)
    }
}
