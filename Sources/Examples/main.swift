import Foundation
import TerminalRunner

try TerminalRunner(executable: "xcodebuild").makeRunnerFuture("-h") { message in
    guard let string = message.string else {
        return
    }
    print(string)
}

print(try TerminalRunner(executable: "ls", currentDirectoryURL: .init(fileURLWithPath: NSHomeDirectory())).wait("-ah").messages.message!)

RunLoop.main.run()
