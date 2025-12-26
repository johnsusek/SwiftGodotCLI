import Foundation

#if os(Windows)
let envExecutable = "cmd.exe"
let envPrefix = ["/c"]
let libraryExtension = "dll"
#elseif os(Linux)
let envExecutable = "/usr/bin/env"
let envPrefix: [String] = []
let libraryExtension = "so"
#else
let envExecutable = "/usr/bin/env"
let envPrefix: [String] = []
let libraryExtension = "dylib"
#endif

func runCommand(_ arguments: [String]) throws -> Int32 {
  let process = Process()
  process.executableURL = URL(filePath: envExecutable)
  process.arguments = envPrefix + arguments
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  try process.run()
  process.waitUntilExit()
  return process.terminationStatus
}
