import ArgumentParser
import Foundation

@main
struct SwiftGodotBuilderCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swiftgodotbuilder",
    abstract: "Build and run SwiftGodotBuilder GView files"
  )

  @Argument(help: "Path to a Swift file containing a GView or @Godot class", completion: .file())
  var viewFile: String?

  @Option(name: .long, help: "Override the root type (GView or @Godot class)")
  var root: String?

  @Option(name: .long, help: "Symlink asset directories into the Godot project (repeatable)", completion: .directory)
  var assets: [String] = []

  @Option(name: .long, help: "Copy .swift files from directory into sources (repeatable)", completion: .directory)
  var include: [String] = []

  @Option(name: .long, help: "Path to Godot executable", completion: .file())
  var godot: String?

  @Option(name: .long, help: "Workspace cache directory", completion: .directory)
  var cache: String?

  @Option(name: .long, help: "Override the SwiftGodotBuilder dependency path", completion: .directory)
  var builderPath: String?

  @Option(name: .long, help: "SwiftGodotBuilder branch/tag/commit (default: main)")
  var builderRev: String?

  @Option(name: .long, help: "SwiftGodot branch/tag/commit (default: main)")
  var swiftgodotRev: String?

  @Option(name: .long, help: "Use a custom project.godot file", completion: .file())
  var project: String?

  @Flag(name: .long, help: "Build in release mode")
  var release = false

  @Flag(name: .long, help: "Do not launch Godot after building")
  var noRun = false

  @Flag(name: .long, help: "Codesign dylibs")
  var codesign = false

  @Flag(name: .long, help: "Delete cached playgrounds and exit")
  var clean = false

  @Flag(name: .long, help: "Print extra logs and commands")
  var verbose = false

  @Flag(name: .long, help: "Suppress informational logs")
  var quiet = false

  func validate() throws {
    if quiet && verbose {
      throw ValidationError("Cannot enable both --quiet and --verbose")
    }
    if !clean && viewFile == nil {
      throw ValidationError("Missing expected argument '<view-file>'")
    }
  }

  private func clean(cacheRoot: URL, logger: Logger) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: cacheRoot.path) {
      logger.info("Removing cached playgrounds at \(cacheRoot.path)...")
      try fm.removeItem(at: cacheRoot)
    } else {
      logger.info("No cache directory found at \(cacheRoot.path)")
    }
  }

  func run() throws {
    let baseDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let cacheRoot = cache.map { CLIConfig.absoluteURL(for: $0, baseDirectory: baseDirectory) }
      ?? CLIConfig.defaultCacheRoot()

    let logger = Logger(verbose: verbose, quiet: quiet)

    if clean {
      try clean(cacheRoot: cacheRoot, logger: logger)
      return
    }

    // Check for Swift/Xcode
    try validateSwiftAvailable()

    guard let viewFile = viewFile else {
      throw CLIError("View file is required")
    }

    let viewFileURL = CLIConfig.absoluteURL(for: viewFile, baseDirectory: baseDirectory)
    guard FileManager.default.fileExists(atPath: viewFileURL.path) else {
      throw CLIError("View file not found at \(viewFileURL.path)")
    }

    let assetDirectories = try assets.map { dir -> URL in
      let dirURL = CLIConfig.absoluteURL(for: dir, baseDirectory: baseDirectory)
      guard CLIConfig.directoryExists(at: dirURL) else {
        throw CLIError("Assets directory not found at \(dirURL.path)")
      }
      return dirURL
    }

    let includeDirectories = try include.map { dir -> URL in
      let dirURL = CLIConfig.absoluteURL(for: dir, baseDirectory: baseDirectory)
      guard CLIConfig.directoryExists(at: dirURL) else {
        throw CLIError("Include directory not found at \(dirURL.path)")
      }
      return dirURL
    }

    var customProjectGodot: URL?
    if let projectPath = project {
      let projectURL = CLIConfig.absoluteURL(for: projectPath, baseDirectory: baseDirectory)
      guard FileManager.default.fileExists(atPath: projectURL.path) else {
        throw CLIError("Project file not found at \(projectURL.path)")
      }
      customProjectGodot = projectURL
    }

    let viewSource = try String(contentsOf: viewFileURL, encoding: .utf8)
    let detected = try CLIConfig.detectViewType(in: viewSource)
    let viewType = root ?? detected.name
    let viewKind: ViewKind
    if let root = root {
      viewKind = CLIConfig.detectKind(for: root, in: viewSource) ?? detected.kind
    } else {
      viewKind = detected.kind
    }
    let workspaceName = CLIConfig.makeWorkspaceName(viewFile: viewFileURL, viewType: viewType)
    let workspaceDirectory = cacheRoot.appendingPathComponent(workspaceName, isDirectory: true)
    let builderDependency = BuilderDependency.resolve(
      overridePath: builderPath.map { CLIConfig.absoluteURL(for: $0, baseDirectory: baseDirectory) },
      rev: builderRev,
      baseDirectory: baseDirectory
    )
    let resolvedGodotCommand = godot ?? CLIConfig.resolveGodotCommand()
    if !noRun {
      try validateGodotAvailable(resolvedGodotCommand)
    }
    let buildConfiguration: BuildConfiguration = release ? .release : .debug

    let config = CLIConfig(
      viewFile: viewFileURL,
      viewSource: viewSource,
      viewType: viewType,
      viewKind: viewKind,
      assetDirectories: assetDirectories,
      includeDirectories: includeDirectories,
      godotCommand: resolvedGodotCommand,
      runGodot: !noRun,
      cacheRoot: cacheRoot,
      builderDependency: builderDependency,
      swiftgodotRev: swiftgodotRev ?? "main",
      buildConfiguration: buildConfiguration,
      verbose: verbose,
      quiet: quiet,
      workspaceDirectory: workspaceDirectory,
      codesign: codesign,
      customProjectGodot: customProjectGodot
    )

    let scaffold = PlaygroundScaffold(config: config, logger: logger)

    try scaffold.prepare()
    try scaffold.build()

    if config.runGodot {
      try scaffold.launchGodot()
    } else {
      logger.info("Godot project ready at \(scaffold.godotProjectPath.path)")
    }
  }

  private func validateSwiftAvailable() throws {
    guard (try? runCommand(["swift", "--version"])) == 0 else {
      throw CLIError("""
        Swift toolchain not found.
        Install Xcode from the App Store or run: xcode-select --install
        """)
    }
  }

  private func validateGodotAvailable(_ command: String) throws {
    guard (try? runCommand([command, "--version"])) == 0 else {
      throw CLIError("""
        Godot not found at '\(command)'.
        Install Godot 4.x from https://godotengine.org or specify path with --godot
        """)
    }
  }
}
