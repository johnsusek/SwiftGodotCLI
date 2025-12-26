import Foundation

struct Logger {
  let verbose: Bool
  let quiet: Bool

  func info(_ message: String) {
    guard !quiet else { return }
    print(message)
  }

  func debug(_ message: String) {
    guard verbose, !quiet else { return }
    print(message)
  }

  func warn(_ message: String) {
    FileHandle.standardError.write(Data("warning: \(message)\n".utf8))
  }
}
