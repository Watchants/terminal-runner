import Foundation
import TerminalRunner

let runner = try await TerminalRunner(executable: "xcodebuild")
let future = try runner.makeRunnerFuture("-h") { message in
    if let string = message.string {
        print(string)
    }
}
try await future.wait()

print(try await TerminalRunner(executable: "ls", currentDirectoryURL: .init(fileURLWithPath: NSHomeDirectory())).make().message!)

//RunLoop.main.run()
