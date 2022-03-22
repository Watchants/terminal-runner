# terminal-runner

```
let runner = TerminalRunner(executableURL: .init(fileURLWithPath: "/usr/bin/which"), environment: environment, currentDirectoryURL: currentDirectoryURL)
if let message = try runner.makeRunnerFuture(executable).wait().readlines?.first {
    return .init(fileURLWithPath: message)
}
```

```
let future = try TerminalRunner(executable: "ls", currentDirectoryURL: .init(fileURLWithPath: NSHomeDirectory())).makeRunnerFuture("-ah")
try future.wait()
```
