import Foundation

enum BuildConfiguration: String {
  case debug, release
}

enum ViewKind {
  case gview
  case godotClass
}

struct CLIError: Error, CustomStringConvertible {
  let message: String
  init(_ message: String) { self.message = message }
  var description: String { message }
}

struct CLIConfig {
  let viewFile: URL
  let viewSource: String
  let viewType: String
  let viewKind: ViewKind
  let assetDirectories: [URL]
  let includeDirectories: [URL]
  let godotCommand: String
  let runGodot: Bool
  let cacheRoot: URL
  let builderDependency: BuilderDependency
  let swiftgodotRev: String
  let buildConfiguration: BuildConfiguration
  let verbose: Bool
  let quiet: Bool
  let workspaceDirectory: URL
  let codesign: Bool
  let customProjectGodot: URL?

  static func defaultCacheRoot() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".swiftgodotbuilder/playgrounds", isDirectory: true)
  }

  static func absoluteURL(for path: String, baseDirectory: URL) -> URL {
    URL(fileURLWithPath: path, relativeTo: baseDirectory).standardizedFileURL
  }

  static func directoryExists(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
  }

  static func detectViewType(in source: String) throws -> (name: String, kind: ViewKind) {
    // First try to find a GView
    let gviewPattern = "(?:(?:public|internal|fileprivate|open|final)\\s+)*(?:struct|class)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*[^\\{]*\\bG?View\\b"
    if let gviewRegex = try? NSRegularExpression(pattern: gviewPattern),
       let match = gviewRegex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
       let nameRange = Range(match.range(at: 1), in: source)
    {
      return (String(source[nameRange]), .gview)
    }

    // Fall back to @Godot class
    let godotPattern = "@Godot\\s*(?:\\([^)]*\\))?\\s*(?:(?:public|internal|fileprivate|open|final)\\s+)*class\\s+([A-Za-z_][A-Za-z0-9_]*)"
    if let godotRegex = try? NSRegularExpression(pattern: godotPattern),
       let match = godotRegex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
       let nameRange = Range(match.range(at: 1), in: source)
    {
      return (String(source[nameRange]), .godotClass)
    }

    throw CLIError("Unable to detect a GView or @Godot class. Pass --root <TypeName> explicitly.")
  }

  static func detectKind(for typeName: String, in source: String) -> ViewKind? {
    let escaped = NSRegularExpression.escapedPattern(for: typeName)
    let range = NSRange(source.startIndex..., in: source)

    // Check if it's a GView
    let gviewPattern = "(?:(?:public|internal|fileprivate|open|final)\\s+)*(?:struct|class)\\s+\(escaped)\\s*:\\s*[^\\{]*\\bG?View\\b"
    if let gviewRegex = try? NSRegularExpression(pattern: gviewPattern),
       gviewRegex.firstMatch(in: source, range: range) != nil
    {
      return .gview
    }

    // Check if it's a @Godot class
    let godotPattern = "@Godot\\s*(?:\\([^)]*\\))?\\s*(?:(?:public|internal|fileprivate|open|final)\\s+)*class\\s+\(escaped)\\b"
    if let godotRegex = try? NSRegularExpression(pattern: godotPattern),
       godotRegex.firstMatch(in: source, range: range) != nil
    {
      return .godotClass
    }

    return nil
  }

  static func makeWorkspaceName(viewFile: URL, viewType: String) -> String {
    let base = sanitize(viewFile.deletingPathExtension().lastPathComponent)
    let hash = stableHash(viewFile.path + ":" + viewType)
    return "\(base)-\(hash)"
  }

  private static func sanitize(_ component: String) -> String {
    let allowed = component
      .replacingOccurrences(of: " ", with: "_")
      .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    return allowed.isEmpty ? "Playground" : allowed
  }

  static func stableHash(_ value: String) -> String {
    var hash: UInt64 = 5381
    for byte in value.utf8 {
      hash = ((hash << 5) &+ hash) &+ UInt64(byte)
    }
    return String(format: "%016llx", hash)
  }

  static func resolveGodotCommand() -> String {
    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    which.arguments = ["godot"]
    which.standardOutput = Pipe()
    which.standardError = Pipe()
    do {
      try which.run()
      which.waitUntilExit()
      if which.terminationStatus == 0 {
        return "godot"
      }
    } catch {}

    #if os(macOS)
      let mdfind = Process()
      mdfind.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
      mdfind.arguments = ["kMDItemCFBundleIdentifier = \"org.godotengine.godot\""]
      let mdfindPipe = Pipe()
      mdfind.standardOutput = mdfindPipe
      mdfind.standardError = Pipe()
      do {
        try mdfind.run()
        mdfind.waitUntilExit()
        if mdfind.terminationStatus == 0 {
          let data = mdfindPipe.fileHandleForReading.readDataToEndOfFile()
          if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
             !output.isEmpty, let appPath = output.components(separatedBy: "\n").first
          {
            let execPath = "\(appPath)/Contents/MacOS/Godot"
            if FileManager.default.fileExists(atPath: execPath) {
              return execPath
            }
          }
        }
      } catch {}
    #endif

    return "godot"
  }
}
