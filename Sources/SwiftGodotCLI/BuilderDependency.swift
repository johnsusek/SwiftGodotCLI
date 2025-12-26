import Foundation

enum BuilderDependency {
  case local(URL)
  case remote(rev: String)

  static func resolve(overridePath: URL?, rev: String?, baseDirectory: URL) -> BuilderDependency {
    if let override = overridePath {
      return .local(override)
    }
    if let env = ProcessInfo.processInfo.environment["SWIFTGODOTCLI_BUILDER_PATH"] {
      let url = URL(fileURLWithPath: env, relativeTo: baseDirectory).standardizedFileURL
      if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        return .local(url)
      }
    }
    return .remote(rev: rev ?? "main")
  }

  var manifestEntry: String {
    switch self {
    case let .local(url):
      let escapedPath = url.path
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      return ".package(name: \"SwiftGodotBuilder\", path: \"\(escapedPath)\")"
    case let .remote(rev):
      return ".package(url: \"https://github.com/johnsusek/SwiftGodotBuilder\", branch: \"\(rev)\")"
    }
  }
}
