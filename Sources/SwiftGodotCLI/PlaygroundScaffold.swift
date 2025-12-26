import Foundation

struct PlaygroundScaffold {
  let config: CLIConfig
  let logger: Logger
  private let targetName = "SwiftGodotBuilderPlayground"
  private let fileManager = FileManager.default

  private var rootClassName: String {
    let cleaned = config.viewType.filter { $0.isLetter || $0.isNumber }
    return "\(cleaned.isEmpty ? "View" : cleaned)RootNode"
  }

  private var packageDirectory: URL {
    config.workspaceDirectory.appendingPathComponent("SwiftPackage", isDirectory: true)
  }

  private var sourcesDirectory: URL {
    packageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(targetName, isDirectory: true)
  }

  private var godotDirectory: URL {
    config.workspaceDirectory.appendingPathComponent("GodotProject", isDirectory: true)
  }

  private var godotBinDirectory: URL {
    godotDirectory.appendingPathComponent("bin", isDirectory: true)
  }

  private var godotHiddenDirectory: URL {
    godotDirectory.appendingPathComponent(".godot", isDirectory: true)
  }

  var godotProjectPath: URL { godotDirectory }

  func prepare() throws {
    try ensureDirectories()
    try writeSwiftSources()
    try writePackageManifest()
    try writeGodotFiles()
    try linkAssetDirectories()
  }

  func build() throws {
    logger.info("Building Swift package in \(packageDirectory.path)...")
    try runProcess(["swift", "build", "-c", config.buildConfiguration.rawValue], in: packageDirectory, suppressOutput: config.quiet)
    guard let binPathString = try runProcess(
      [
        "swift",
        "build",
        "-c",
        config.buildConfiguration.rawValue,
        "--show-bin-path",
      ],
      in: packageDirectory,
      captureOutput: true,
      suppressOutput: config.quiet
    )?.trimmingCharacters(in: .whitespacesAndNewlines), !binPathString.isEmpty else {
      throw CLIError("Unable to determine Swift build output path")
    }

    let binDirectory = URL(fileURLWithPath: binPathString, isDirectory: true)
    try syncLibraries(binDirectory: binDirectory)
    if !config.assetDirectories.isEmpty {
      try runHeadlessImport()
    }
  }

  func launchGodot() throws {
    logger.info("Launching Godot from \(godotDirectory.path)...")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [config.godotCommand, "--path", godotDirectory.path, "--disable-crash-handler"]
    process.currentDirectoryURL = config.workspaceDirectory
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signal(SIGINT, SIG_IGN)
    signalSource.setEventHandler {
      process.terminate()
    }
    signalSource.resume()

    try process.run()
    process.waitUntilExit()

    signalSource.cancel()
  }

  private func ensureDirectories() throws {
    try fileManager.createDirectory(at: config.cacheRoot, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: config.workspaceDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: packageDirectory, withIntermediateDirectories: true, attributes: nil)
    if fileManager.fileExists(atPath: sourcesDirectory.path) {
      let contents = try fileManager.contentsOfDirectory(at: sourcesDirectory, includingPropertiesForKeys: nil)
      for file in contents where file.pathExtension == "swift" {
        try fileManager.removeItem(at: file)
      }
    }
    try fileManager.createDirectory(at: sourcesDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: godotDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: godotBinDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: godotHiddenDirectory, withIntermediateDirectories: true, attributes: nil)
  }

  private func writeSwiftSources() throws {
    let destination = sourcesDirectory.appendingPathComponent( config.viewFile.lastPathComponent)
    try writeIfChanged(config.viewSource, to: destination)

    for includeDir in config.includeDirectories {
      try copySwiftFiles(from: includeDir)
    }

    let entryPoint: String
    switch config.viewKind {
    case .gview:
      entryPoint = """
      import SwiftGodot
      import SwiftGodotBuilder

      #initSwiftExtension(
        cdecl: "swift_entry_point",
        types: [\(rootClassName).self] + BuilderRegistry.types
      )

      @Godot
      final class \(rootClassName): Node2D {
        override func _ready() {
          let node = \(config.viewType)().toNode()
          addChild(node: node)
        }
      }
      """
    case .godotClass:
      entryPoint = """
      import SwiftGodot
      import SwiftGodotBuilder

      #initSwiftExtension(
        cdecl: "swift_entry_point",
        types: [\(config.viewType).self] + BuilderRegistry.types
      )
      """
    }

    let entryURL = sourcesDirectory.appendingPathComponent( "PlaygroundRoot.swift")
    try writeIfChanged(entryPoint, to: entryURL)
  }

  private func writeIfChanged(_ contents: String, to file: URL) throws {
    let data = Data(contents.utf8)
    if let existing = try? Data(contentsOf: file), existing == data {
      return
    }
    try data.write(to: file, options: [.atomic])
  }

  private func copySwiftFiles(from directory: URL) throws {
    let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    for file in contents where file.pathExtension == "swift" {
      let destination = sourcesDirectory.appendingPathComponent( file.lastPathComponent)
      guard !fileManager.fileExists(atPath: destination.path) else {
        logger.debug("Skipping \(file.lastPathComponent) (already exists)")
        continue
      }
      let source = try String(contentsOf: file, encoding: .utf8)
      try writeIfChanged(source, to: destination)
      logger.debug("Copied: \(file.lastPathComponent)")
    }
  }

  private func writePackageManifest() throws {
    let manifest = """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
      name: "\(targetName)",
      products: [
        .library(name: "\(targetName)", type: .dynamic, targets: ["\(targetName)"])
      ],
      dependencies: [
        \(config.builderDependency.manifestEntry),
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", branch: "\(config.swiftgodotRev)")
      ],
      targets: [
        .target(
          name: "\(targetName)",
          dependencies: [
            "SwiftGodotBuilder",
            .product(name: "SwiftGodot", package: "SwiftGodot")
          ],
          path: "Sources"
        )
      ]
    )
    """

    let packageURL = packageDirectory.appendingPathComponent( "Package.swift")
    try writeIfChanged(manifest, to: packageURL)
  }

  private func writeGodotFiles() throws {
    let projectGodotPath = godotDirectory.appendingPathComponent( "project.godot")

    if let customProject = config.customProjectGodot {
      if fileManager.fileExists(atPath: projectGodotPath.path) {
        try fileManager.removeItem(at: projectGodotPath)
      }
      try fileManager.copyItem(at: customProject, to: projectGodotPath)
      logger.debug("Using custom project.godot from \(customProject.path)")
    } else {
      let projectGodot = """
      config_version=5

      [application]
      config/name="SwiftGodotBuilderPlayground"
      run/main_scene="res://main.tscn"
      config/features=PackedStringArray("4.4")

      [display]
      window/size/viewport_width=320
      window/size/viewport_height=180
      window/size/window_width_override=640
      window/size/window_height_override=360
      window/stretch/mode="viewport"
      window/stretch/scale_mode="integer"
      """

      try projectGodot.write(to: projectGodotPath, atomically: true, encoding: .utf8)
    }

    let sceneRootType = config.viewKind == .godotClass ? config.viewType : rootClassName
    let scene = """
    [gd_scene format=3]

    [node name="Root" type="\(sceneRootType)"]
    """

    try scene.write(
      to: godotDirectory.appendingPathComponent( "main.tscn"),
      atomically: true,
      encoding: .utf8
    )

    let extensionFile = """
    [configuration]
    entry_symbol = "swift_entry_point"
    compatibility_minimum = 4.2

    [libraries]
    macos.debug = "res://bin/lib\(targetName).dylib"
    macos.release = "res://bin/lib\(targetName).dylib"
    windows.debug.x86_64 = "res://bin/\(targetName).dll"
    windows.release.x86_64 = "res://bin/\(targetName).dll"
    linux.debug.x86_64 = "res://bin/lib\(targetName).so"
    linux.release.x86_64 = "res://bin/lib\(targetName).so"

    [dependencies]
    macos.debug = { "res://bin/libSwiftGodot.dylib": "Contents/Frameworks" }
    macos.release = { "res://bin/libSwiftGodot.dylib": "Contents/Frameworks" }
    windows.debug.x86_64 = { "res://bin/SwiftGodot.dll": "" }
    windows.release.x86_64 = { "res://bin/SwiftGodot.dll": "" }
    linux.debug.x86_64 = { "res://bin/libSwiftGodot.so": "" }
    linux.release.x86_64 = { "res://bin/libSwiftGodot.so": "" }
    """

    try extensionFile.write(
      to: godotDirectory.appendingPathComponent( "\(targetName).gdextension"),
      atomically: true,
      encoding: .utf8
    )

    let extensionList = "res://\(targetName).gdextension\n"
    try extensionList.write(
      to: godotHiddenDirectory.appendingPathComponent( "extension_list.cfg"),
      atomically: true,
      encoding: .utf8
    )
  }

  private func linkAssetDirectories() throws {
    guard !config.assetDirectories.isEmpty else { return }
    for dir in config.assetDirectories {
      let destination = godotDirectory.appendingPathComponent( dir.lastPathComponent)
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.createSymbolicLink(atPath: destination.path, withDestinationPath: dir.path)
      logger.debug("Symlinked assets directory '\(dir.lastPathComponent)' -> \(dir.path)")
    }
  }

  private func syncLibraries(binDirectory: URL) throws {
    guard fileManager.fileExists(atPath: binDirectory.path) else {
      throw CLIError("Build artifacts not found at \(binDirectory.path)")
    }

    let contents = try fileManager.contentsOfDirectory(at: binDirectory, includingPropertiesForKeys: nil)
    let libs = contents.filter { $0.pathExtension == libraryExtension }

    guard !libs.isEmpty else {
      throw CLIError("No dynamic libraries produced by swift build")
    }

    let existing = try fileManager.contentsOfDirectory(at: godotBinDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    for url in existing where url.pathExtension == libraryExtension {
      try fileManager.removeItem(at: url)
    }

    var copied: [URL] = []

    for lib in libs {
      let destination = godotBinDirectory.appendingPathComponent( lib.lastPathComponent)
      try fileManager.copyItem(at: lib, to: destination)
      copied.append(destination)
    }

    #if os(macOS)
      if config.codesign {
        for lib in copied {
          do {
            try runProcess(
              ["codesign", "--force", "--deep", "--sign", "-", lib.path],
              in: config.workspaceDirectory,
              suppressOutput: config.quiet
            )
          } catch {
            logger.warn("Failed to codesign \(lib.lastPathComponent)")
          }
        }
      }
    #endif
  }

  private func runHeadlessImport() throws {
    let checksumFile = config.workspaceDirectory.appendingPathComponent( ".asset-checksum")
    let currentChecksum = computeAssetChecksum()

    if let cachedChecksum = try? String(contentsOf: checksumFile, encoding: .utf8),
       cachedChecksum == currentChecksum
    {
      logger.debug("Assets unchanged, skipping import")
      return
    }

    logger.info("Importing Godot resources (headless)...")
    try runProcess(
      [config.godotCommand, "--headless", "--path", godotDirectory.path, "--import"],
      in: config.workspaceDirectory,
      suppressOutput: config.quiet
    )

    try currentChecksum.write(to: checksumFile, atomically: true, encoding: .utf8)
  }

  private func computeAssetChecksum() -> String {
    var entries: [String] = []

    for dir in config.assetDirectories {
      if let enumerator = fileManager.enumerator(
        at: dir,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
      ) {
        while let url = enumerator.nextObject() as? URL {
          guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                resourceValues.isRegularFile == true,
                let modDate = resourceValues.contentModificationDate
          else {
            continue
          }
          let relativePath = url.path.replacingOccurrences(of: dir.path, with: "")
          let timestamp = Int(modDate.timeIntervalSince1970)
          entries.append("\(dir.lastPathComponent)\(relativePath):\(timestamp)")
        }
      }
    }

    entries.sort()
    let combined = entries.joined(separator: "\n")
    return CLIConfig.stableHash(combined)
  }

  @discardableResult
  private func runProcess(
    _ arguments: [String],
    in directory: URL,
    captureOutput: Bool = false,
    suppressOutput: Bool = false
  ) throws -> String? {
    logger.debug("Running: \(arguments.joined(separator: " ")) (cwd: \(directory.path))")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: envExecutable)
    process.arguments = envPrefix + arguments
    process.currentDirectoryURL = directory
    let outputPipe: Pipe? = captureOutput ? Pipe() : nil
    if let pipe = outputPipe {
      process.standardOutput = pipe
    } else if suppressOutput {
      process.standardOutput = FileHandle.nullDevice
    } else {
      process.standardOutput = FileHandle.standardOutput
    }
    process.standardError = FileHandle.standardError
    do {
      try process.run()
    } catch {
      throw CLIError("Unable to run command: \(arguments.first ?? "")")
    }
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw CLIError("Command failed: \(arguments.joined(separator: " "))")
    }

    if let pipe = outputPipe {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.closeFile()
      return String(data: data, encoding: .utf8)
    }

    return nil
  }
}
