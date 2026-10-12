# 🛡️ RustWall

> A lightweight, **SimpleWall-inspired** terminal firewall manager for Windows — written in **Rust**.

RustWall is a fast, dependency-free CLI tool for managing Windows Firewall rules. It focuses on the core use case of tools like [SimpleWall](https://github.com/henrypp/simplewall) and [TinyWall](https://tinywall.pados.hu/) — **blocking unwanted applications from reaching the internet** — but with zero GUI overhead and a tiny binary size.

---

## ✨ Features

- 🔒 **Lockdown mode** — default-deny outbound traffic, whitelist only what you trust
- 🚫 **Block / Allow** any application by path (inbound, outbound, or both)
- 📋 **List & manage** RustWall-managed rules without touching Windows Firewall UI
- 🧹 **Cleanup** — remove all RustWall rules in one command
- ⚡ **Fast & tiny** — release binary is **< 1 MB**, no runtime dependencies
- 🎨 **Colorized output** with clear status indicators
- 🔐 **Idempotent operations** — safe to run the same command multiple times
- 🏷️ **Prefixed rules** (`RustWall:`) — never conflicts with user-created rules
- 🪟 **Windows 7 → 11** supported (uses `netsh advfirewall` under the hood)

---

## 📸 Demo

```powershell
> rustwall block "C:\Program Files\Filmora\Filmora.exe"
✓ Blocked [in]  Filmora.exe
✓ Blocked [out] Filmora.exe

> rustwall list
● enabled  RustWall: Block Filmora.exe (in)   [in → block]   C:\Program Files\Filmora\Filmora.exe
● enabled  RustWall: Block Filmora.exe (out)  [out → block]  C:\Program Files\Filmora\Filmora.exe

ℹ 2 rule(s) shown.

> rustwall lockdown
🔒 Lockdown ON — all outbound traffic blocked.
   Use `rustwall allow <path>` to whitelist applications.
```

---

## 📦 Installation

### Prerequisites

- [Rust toolchain](https://rustup.rs/) (stable)
- Windows 7 or later
- **Administrator privileges** (required for firewall operations)

### Build from source

```powershell
git clone https://github.com/<your-username>/rustwall.git
cd rustwall
cargo build --release
```

The binary will be at:

```
target\release\rustwall.exe
```

Optionally, add it to your `PATH`:

```powershell
setx PATH "%PATH%;%CD%\target\release"
```

---

## 🚀 Usage

> ⚠️ **Always run from an elevated (Administrator) command prompt or PowerShell.**

```
rustwall <COMMAND> [OPTIONS]
```

### Commands

| Command | Description |
|---|---|
| `status` | Show Windows Firewall status for all profiles |
| `list [--all]` | List RustWall rules (or all rules with `--all`) |
| `block <PATH> [-d <dir>]` | Block an application (default: `both`) |
| `allow <PATH> [-d <dir>]` | Allow an application (default: `both`) |
| `delete <NAME>` | Delete a rule by name |
| `enable` | Enable Windows Firewall on all profiles |
| `disable` | Disable Windows Firewall (⚠️ dangerous) |
| `lockdown` | Block **all** outbound traffic (whitelist mode) |
| `unlock` | Restore default outbound policy (allow) |
| `cleanup` | Remove every RustWall-managed rule |

### Examples

```powershell
# Block an app both ways
rustwall block "C:\Games\game.exe"

# Block only outbound (silent telemetry killer)
rustwall block "C:\Program Files\App\app.exe" --direction out

# Whitelist an app inside lockdown mode
rustwall allow "C:\Program Files\MyBrowser\browser.exe"

# See only your RustWall rules
rustwall list

# Inspect every firewall rule on the system
rustwall list --all

# Enter paranoid mode: nothing talks to the internet unless allowed
rustwall lockdown

# Come back to normal
rustwall unlock

# Nuclear cleanup — remove every RustWall rule
rustwall cleanup
```

---

## 🧠 How It Works

RustWall wraps the built-in Windows command:

```
netsh advfirewall firewall ...
```

Every rule RustWall creates is **prefixed** with `RustWall:` so it can:

- 🔍 Be listed separately from user rules
- 🧹 Be cleaned up in bulk
- 🛡️ Never overwrite a rule you made manually

For **Lockdown mode**, RustWall changes the outbound policy on all firewall profiles to `blockoutbound`, then relies on per-application `allow` rules to whitelist trusted software.

> **Note:** RustWall uses the Windows Firewall API (`netsh`). For kernel-level filtering like [SimpleWall](https://github.com/henrypp/simplewall) itself, a future version will use [WFP (Windows Filtering Platform)](https://learn.microsoft.com/en-us/windows/win32/fwp/windows-filtering-platform-start-page) via the [`windows`](https://crates.io/crates/windows) crate.

---

## 🆚 Comparison

| Feature | **RustWall** | SimpleWall | TinyWall |
|---|---|---|---|
| **Interface** | CLI | GUI | GUI |
| **Written in** | Rust 🦀 | C | C# |
| **Open source** | ✅ | ✅ | ❌ |
| **Binary size** | ~800 KB | ~1 MB | ~2 MB |
| **Backend** | Windows Firewall (`netsh`) | WFP (kernel) | Windows Firewall COM |
| **Lockdown mode** | ✅ | ✅ | ✅ |
| **Dependencies** | None | None | .NET |

RustWall is intentionally **minimal** — it's a CLI-first tool for users who want a scripting-friendly firewall manager without a GUI.

---

## 🛠️ Project Structure

```
rustwall/
├── Cargo.toml
├── README.md
└── src/
    └── main.rs
```

---

## 🗺️ Roadmap

- [x] Block / Allow applications
- [x] Lockdown mode (default-deny outbound)
- [x] Rule listing & cleanup
- [ ] `monitor` — real-time connection viewer (like `netstat` + process mapping)
- [ ] `watch` — notify on new outbound connections
- [ ] Config file (`rustwall.toml`) for persistent whitelists
- [ ] Windows Service for background auto-enforcement
- [ ] Native WFP backend (kernel-level filtering, SimpleWall parity)

---

## ⚠️ Disclaimer

RustWall modifies **Windows Firewall settings**. It requires Administrator privileges and **will change system-wide firewall policy** when used with `lockdown`, `disable`, or `enable`.

- Always test rules in a safe environment first.
- `lockdown` mode blocks **all** outbound traffic — including Windows Update, DNS, and telemetry. Whitelist what you need.
- The author is **not responsible** for network outages caused by misconfiguration.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the repository
2. Create a branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- Inspired by [SimpleWall](https://github.com/henrypp/simplewall) by Henry++ and [TinyWall](https://tinywall.pados.hu/)
- Built with [Rust](https://www.rust-lang.org/) 🦀
- Uses [clap](https://crates.io/crates/clap), [anyhow](https://crates.io/crates/anyhow), and [colored](https://crates.io/crates/colored)

---

<p align="center">
  Made with ❤️ and 🦀 on Windows
</p>
