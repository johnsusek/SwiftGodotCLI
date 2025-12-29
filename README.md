# SwiftGodotCLI

CLI tool for building and running [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) projects. Also supports [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder) GView files.

By default, pulls from the `main` branch of [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) (and [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder) when using GViews). Use `--swiftgodot-rev` and `--builder-rev` to pin specific branches, tags, or commits.

## Installation

Download the latest release from the [releases page](https://github.com/johnsusek/SwiftGodotCLI/releases), or build from source:

```bash
git clone https://github.com/johnsusek/SwiftGodotCLI
cd SwiftGodotCLI
swift build -c release
cp .build/release/swiftgodotbuilder /usr/local/bin/
```

## Usage

```
OVERVIEW: Build and run SwiftGodot files

USAGE: swiftgodotbuilder [<options>] [<swift-file>]

ARGUMENTS:
  <swift-file>            Path to a Swift file containing a @Godot class or GView

OPTIONS:
  --root <root>           Override the root type (@Godot class or GView)
  --assets <assets>       Symlink asset directories into the Godot project (repeatable)
  --include <include>     Copy .swift files from directory into sources (repeatable)
  --godot <godot>         Path to Godot executable
  --cache <cache>         Workspace cache directory
  --builder-path <builder-path>
                          Override the SwiftGodotBuilder dependency path
  --builder-rev <builder-rev>
                          SwiftGodotBuilder branch/tag/commit (default: main)
  --swiftgodot-rev <swiftgodot-rev>
                          SwiftGodot branch/tag/commit (default: main)
  --project <project>     Use a custom project.godot file
  --release               Build in release mode
  --no-run                Do not launch Godot after building
  --codesign              Codesign dylibs
  --clean                 Delete cached playgrounds and exit
  --verbose               Print extra logs and commands
  --quiet                 Suppress informational logs
  -h, --help              Show help information.
```

## Examples

```bash
# Run a @Godot class
swiftgodotbuilder MyGame.swift

# Run a GView file (SwiftGodotBuilder)
swiftgodotbuilder MyView.swift

# Specify which type to use as root
swiftgodotbuilder MyFile.swift --root MyCustomClass

# Include assets
swiftgodotbuilder MyGame.swift --assets ./sprites --assets ./sounds

# Include additional Swift files
swiftgodotbuilder MyGame.swift --include ./shared

# Build only (don't launch Godot)
swiftgodotbuilder MyGame.swift --no-run

# Use local SwiftGodotBuilder
swiftgodotbuilder MyGame.swift --builder-path ../SwiftGodotBuilder
# or
export SWIFTGODOTCLI_BUILDER_PATH=../SwiftGodotBuilder
swiftgodotbuilder MyGame.swift
```

## Shell Completions

Generate shell completions:

```bash
# zsh
swiftgodotbuilder --generate-completion-script zsh > ~/.zsh/completions/_swiftgodotbuilder

# bash
swiftgodotbuilder --generate-completion-script bash > ~/.bash_completion.d/swiftgodotbuilder

# fish
swiftgodotbuilder --generate-completion-script fish > ~/.config/fish/completions/swiftgodotbuilder.fish
```
