# Morse Code Converter/Player in D

A D programming language command-line application that converts text ↔ Morse code with optional 700 Hz audio playback.

---

## Opening in VS Code

```bash
code morse-d-vscode/
```

VS Code will prompt: **"Do you want to install the recommended extensions?"**  
Click **Install All**. The key extension is **code-d** (`webfreak.code-d`), which
provides D language support, DUB integration, auto-completion, linting, and formatting.

After the extensions install, code-d will automatically detect `dub.json` and
index the project. This takes a few seconds on first open.

---

## Requirements

| Tool | Version | Install |
|------|---------|---------|
| D compiler | latest | https://dlang.org/download.html |
| DUB (build tool) | latest | Bundled with DMD / LDC / GDC |
| VS Code | any | https://code.visualstudio.com |

Any of the three major D compilers works:

| Compiler | Notes |
|----------|-------|
| **LDC** | LLVM backend — best runtime performance, recommended |
| **DMD** | Reference compiler — fastest compile times |
| **GDC** | GCC backend — `sudo apt install gdc` on Debian/Ubuntu |

The `settings.json` defaults to `ldc2` for the language server; change
`"d.dubCompiler"` to `"dmd"` or `"gdc"` if needed.

---

## VS Code keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| Build (debug) | `Ctrl+Shift+B` / `Cmd+Shift+B` |
| Run test task | `Ctrl+Shift+P` → *Tasks: Run Test Task* |
| Open terminal | `` Ctrl+` `` |
| Start debugging | `F5` |
| Step over | `F10` |
| Step into | `F11` |

The default build task (`Ctrl+Shift+B`) runs **dub: build (debug)**.

---

## Build & Run

From the integrated terminal (`` Ctrl+` ``):

```bash
# Build debug (default)
dub build

# Build optimised release binary
dub build --build=release

# Run via dub (rebuilds if sources changed)
dub run -- encode "Hello World"
dub run -- encode --play SOS
dub run -- decode "... --- ..."
dub run -- decode --play ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."

# Run the compiled binary directly
./morse encode "Hello World"
./morse --help
```

Windows:
```bat
dub run -- encode "Hello World"
morse.exe encode "Hello World"
```

---

## Tests

```bash
dub test
```

D's `unittest` blocks in `morse.d` and `audio.d` are compiled and run automatically.

From VS Code: `Ctrl+Shift+P` → *Tasks: Run Test Task* → **dub: test**

---

## Usage reference

```
morse encode [--play] <text ...>
morse decode [--play] <morse ...>
morse --help

Options:
  -p  --play    Play 700 Hz audio tones while printing output
  -h  --help    Show this help message
```

### Output format

```
┌────────────────────────────────────────────────────────────┐
│ Input  (Text):                                             │
│ Hello World                                                │
├────────────────────────────────────────────────────────────┤
│ Output (Morse):                                            │
│ .... . .-.. .-.. --- / .-- --- .-. .-.. -..                │
└────────────────────────────────────────────────────────────┘
```

---

## Morse format

| Symbol | Meaning |
|--------|---------|
| `.` | Dot |
| `-` | Dash |
| ` ` | Letter separator (single space) |
| ` / ` | Word separator (space-slash-space) |

---

## Supported characters

| Category | Characters |
|----------|-----------|
| Letters | A–Z (case-insensitive) |
| Digits | 0–9 |
| Punctuation | `. , ? ! - / @ ( )` |

---

## Audio playback (`--play`)

WAV audio is generated entirely in D — no external audio library needed.
Bytes are piped to a system player via `std.process.pipeProcess`.

| Platform | Player tried (in order) |
|----------|------------------------|
| Linux | `ffplay` → `aplay` → `paplay` → `sox` |
| macOS | `ffplay` → `afplay` |
| Windows | PowerShell `Media.SoundPlayer` (built-in) |

```bash
sudo apt install ffmpeg   # Linux
brew install ffmpeg       # macOS
```

---

## Project structure

```
morse-d-vscode/
├── dub.json                  DUB package manifest
├── .gitignore
├── README.md
├── .vscode/
│   ├── extensions.json       Recommended extensions
│   ├── settings.json         Editor, dfmt, and code-d settings
│   ├── tasks.json            Build / test / run / clean tasks
│   └── launch.json           Debug configurations (Linux, macOS, Windows)
└── source/
    ├── app.d                 CLI entry point
    ├── morse.d               Encode / decode + unittest blocks
    ├── audio.d               WAV generation + player + unittest blocks
    └── test_runner.d         Entry point for `dub test`
```
