# SwiftGodotCLI

CLI tool for building and running [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder) GView files and SwiftGodot classes.

By default, pulls from the `main` branch of both [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder) and [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot). Use `--builder-rev` and `--swiftgodot-rev` to pin specific branches, tags, or commits.

## Installation

```bash
# Build from source
git clone https://github.com/johnsusek/SwiftGodotCLI
cd SwiftGodotCLI
swift build -c release
cp .build/release/swiftgodotbuilder /usr/local/bin/
```

## Usage

```
OVERVIEW: Build and run SwiftGodotBuilder GView files

USAGE: swiftgodotbuilder [<options>] [<view-file>]

ARGUMENTS:
  <view-file>             Path to a Swift file containing a GView or @Godot class

OPTIONS:
  --root <root>           Override the root type (GView or @Godot class)
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
# Run a GView file
swiftgodotbuilder MyView.swift

# Run a @Godot class
swiftgodotbuilder MyGame.swift

# Specify which type to use as root
swiftgodotbuilder MyFile.swift --root MyCustomView

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

## Options

| Option | Description |
|--------|-------------|
| `--root <type>` | Override the root type (GView or @Godot class) |
| `--assets <dir>` | Symlink asset directories into Godot project (repeatable) |
| `--include <dir>` | Copy .swift files from directory into sources (repeatable) |
| `--godot <path>` | Path to Godot executable |
| `--cache <dir>` | Workspace cache directory |
| `--builder-path <path>` | Override the SwiftGodotBuilder dependency path |
| `--builder-rev <rev>` | SwiftGodotBuilder branch/tag/commit (default: main) |
| `--swiftgodot-rev <rev>` | SwiftGodot branch/tag/commit (default: main) |
| `--project <path>` | Use a custom project.godot file |
| `--release` | Build in release mode |
| `--no-run` | Do not launch Godot after building |
| `--codesign` | Codesign dylibs |
| `--clean` | Delete cached playgrounds and exit |
| `--verbose` | Print extra logs |
| `--quiet` | Suppress informational logs |

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
