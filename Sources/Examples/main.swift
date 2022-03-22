import Foundation
import TerminalRunner

try TerminalRunner(executable: "xcodebuild").makeRunnerFuture("-h").read { message in
    guard let string = message.string else {
        return
    }
    print(string)
}

print(try TerminalRunner(executable: "ls", currentDirectoryURL: .init(fileURLWithPath: NSHomeDirectory())).makeRunnerFuture("-ah").wait().string!)

RunLoop.main.run()
