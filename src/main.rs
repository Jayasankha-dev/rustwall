use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::path::Path;
use std::process::Command;

/// All RustWall-managed rules start with this prefix
const APP_PREFIX: &str = "RustWall";

#[derive(Parser)]
#[command(name = "rustwall", version, about = "🛡️  RustWall — SimpleWall-style firewall CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Show firewall status for all profiles
    Status,

    /// List RustWall-managed rules
    List {
        /// Show ALL firewall rules, not just RustWall's
        #[arg(long, short)]
        all: bool,
    },

    /// Block an application
    Block {
        /// Path to .exe
        path: String,
        /// Direction: in | out | both
        #[arg(long, short, default_value = "both")]
        direction: String,
    },

    /// Allow an application
    Allow {
        path: String,
        #[arg(long, short, default_value = "both")]
        direction: String,
    },

    /// Delete a rule by name (RustWall prefix is added automatically)
    Delete {
        /// Rule name — either "Block foo.exe (out)" or just "foo.exe"
        name: String,
    },

    /// Enable Windows Firewall on all profiles
    Enable,

    /// Disable Windows Firewall (⚠️  dangerous)
    Disable,

    /// Lockdown mode — block ALL outbound traffic (whitelist only)
    Lockdown,

    /// Unlock — restore default outbound policy (allow outbound)
    Unlock,

    /// Delete every RustWall-managed rule
    Cleanup,
}

// ─────────────────────────────────────────────────────────────
//  Enable ANSI colors on classic Windows CMD
// ─────────────────────────────────────────────────────────────

#[cfg(windows)]
fn enable_ansi_colors() {
    use windows_sys::Win32::System::Console::{
        GetConsoleMode, GetStdHandle, SetConsoleMode, ENABLE_VIRTUAL_TERMINAL_PROCESSING,
        STD_OUTPUT_HANDLE,
    };
    unsafe {
        let handle = GetStdHandle(STD_OUTPUT_HANDLE);
        let mut mode: u32 = 0;
        if GetConsoleMode(handle, &mut mode) != 0 {
            let _ = SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        }
    }
}

fn main() {
    #[cfg(windows)]
    enable_ansi_colors();

    if let Err(e) = run() {
        eprintln!("{} {}", "✗".red().bold(), format!("{:#}", e).red());
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Status                    => cmd_status(),
        Commands::List { all }              => cmd_list(all),
        Commands::Block { path, direction } => cmd_block(&path, &direction),
        Commands::Allow { path, direction } => cmd_allow(&path, &direction),
        Commands::Delete { name }           => cmd_delete(&name),
        Commands::Enable                    => cmd_enable(),
        Commands::Disable                   => cmd_disable(),
        Commands::Lockdown                  => cmd_lockdown(),
        Commands::Unlock                    => cmd_unlock(),
        Commands::Cleanup                   => cmd_cleanup(),
    }
}

// ─────────────────────────────────────────────────────────────
//  Low-level netsh wrapper
// ─────────────────────────────────────────────────────────────

fn netsh(args: &[&str]) -> Result<String> {
    let output = Command::new("netsh")
        .args(args)
        .output()
        .context("Failed to launch netsh. Is Windows Defender Firewall installed?")?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let combined = format!("{}{}", stdout, stderr);

    if !output.status.success() {
        let low = combined.to_lowercase();
        if low.contains("access is denied") || low.contains("requires elevation") {
            bail!("Access denied — please run this command as Administrator.");
        }
        bail!("netsh failed:\n{}", combined.trim());
    }
    Ok(combined)
}

/// Ensure the path exists and return a cleaned absolute path (no \\?\ prefix).
fn resolve_path(p: &str) -> Result<String> {
    let path = Path::new(p);
    if !path.exists() {
        bail!("File not found: {}", p);
    }
    let canonical = path
        .canonicalize()
        .with_context(|| format!("Failed to resolve: {}", p))?;
    let s = canonical.to_string_lossy().to_string();
    let s = s.strip_prefix(r"\\?\").unwrap_or(&s).to_string();
    Ok(s)
}

fn file_name(p: &str) -> String {
    Path::new(p)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("unknown.exe")
        .to_string()
}

fn directions(d: &str) -> Result<Vec<&'static str>> {
    match d {
        "in"   => Ok(vec!["in"]),
        "out"  => Ok(vec!["out"]),
        "both" => Ok(vec!["in", "out"]),
        _ => bail!("Direction must be 'in', 'out', or 'both'"),
    }
}

// ─────────────────────────────────────────────────────────────
//  Commands
// ─────────────────────────────────────────────────────────────

fn cmd_status() -> Result<()> {
    let out = netsh(&["advfirewall", "show", "allprofiles", "state"])?;
    println!("{}", "── Firewall Status ──".cyan().bold());
    print!("{}", out);
    Ok(())
}

fn cmd_list(all: bool) -> Result<()> {
    let out = netsh(&["advfirewall", "firewall", "show", "rule", "name=all"])?;

    // Split into rule blocks (each starts with "Rule Name:")
    let mut blocks: Vec<String> = Vec::new();
    let mut current = String::new();
    for line in out.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("Rule Name:") && !current.is_empty() {
            blocks.push(std::mem::take(&mut current));
        }
        if trimmed.starts_with("Rule Name:") || !current.is_empty() {
            current.push_str(line);
            current.push('\n');
        }
    }
    if !current.is_empty() {
        blocks.push(current);
    }

    let mut shown = 0usize;
    for block in &blocks {
        let name = block
            .lines()
            .find_map(|l| l.trim().strip_prefix("Rule Name:").map(|s| s.trim().to_string()))
            .unwrap_or_default();

        if all || name.starts_with(APP_PREFIX) {
            let get = |key: &str| -> String {
                block
                    .lines()
                    .find_map(|l| {
                        l.trim()
                            .strip_prefix(key)
                            .map(|s| s.trim_start_matches(':').trim().to_string())
                    })
                    .unwrap_or_else(|| "-".into())
            };
            let enabled   = get("Enabled");
            let direction = get("Direction");
            let action    = get("Action");
            let program   = get("Program");

            let action_col = if action.eq_ignore_ascii_case("block") {
                action.red().bold()
            } else {
                action.green().bold()
            };
            let status_col = if enabled.eq_ignore_ascii_case("yes") {
                "● enabled".green()
            } else {
                "○ disabled".dimmed()
            };

            println!(
                "{}  {}  [{} → {}]  {}",
                status_col,
                name.yellow().bold(),
                direction.cyan(),
                action_col,
                program.dimmed(),
            );
            shown += 1;
        }
    }

    if shown == 0 {
        println!("{} No rules found.", "ℹ".blue().bold());
    } else {
        println!("\n{} {} rule(s) shown.", "ℹ".blue().bold(), shown);
    }
    Ok(())
}

fn cmd_block(path: &str, direction: &str) -> Result<()> {
    let path = resolve_path(path)?;
    let fname = file_name(&path);

    for dir in directions(direction)? {
        let rule = format!("{}: Block {} ({})", APP_PREFIX, fname, dir);

        // Idempotent: remove if exists
        let _ = netsh(&[
            "advfirewall", "firewall", "delete", "rule",
            &format!("name={}", rule),
        ]);

        netsh(&[
            "advfirewall", "firewall", "add", "rule",
            &format!("name={}", rule),
            &format!("dir={}", dir),
            "action=block",
            &format!("program={}", path),
            "enable=yes",
            "profile=any",
        ])?;

        println!("{} Blocked [{}] {}", "✓".green().bold(), dir.cyan(), fname.yellow());
    }
    Ok(())
}

fn cmd_allow(path: &str, direction: &str) -> Result<()> {
    let path = resolve_path(path)?;
    let fname = file_name(&path);

    for dir in directions(direction)? {
        let rule = format!("{}: Allow {} ({})", APP_PREFIX, fname, dir);

        let _ = netsh(&[
            "advfirewall", "firewall", "delete", "rule",
            &format!("name={}", rule),
        ]);

        netsh(&[
            "advfirewall", "firewall", "add", "rule",
            &format!("name={}", rule),
            &format!("dir={}", dir),
            "action=allow",
            &format!("program={}", path),
            "enable=yes",
            "profile=any",
        ])?;

        println!("{} Allowed [{}] {}", "✓".green().bold(), dir.cyan(), fname.yellow());
    }
    Ok(())
}

fn cmd_delete(name: &str) -> Result<()> {
    let candidates = vec![
        name.to_string(),
        format!("{}: {}", APP_PREFIX, name),
    ];

    for candidate in candidates {
        let res = netsh(&[
            "advfirewall", "firewall", "delete", "rule",
            &format!("name={}", candidate),
        ]);
        if res.is_ok() {
            println!("{} Deleted: {}", "✓".green().bold(), candidate.yellow());
            return Ok(());
        }
    }
    bail!("No rule found matching: {}", name);
}

fn cmd_enable() -> Result<()> {
    netsh(&["advfirewall", "set", "allprofiles", "state", "on"])?;
    println!("{} Windows Firewall enabled on all profiles.", "✓".green().bold());
    Ok(())
}

fn cmd_disable() -> Result<()> {
    println!("{} You are about to turn OFF Windows Firewall.", "⚠".yellow().bold());
    netsh(&["advfirewall", "set", "allprofiles", "state", "off"])?;
    println!("{} Windows Firewall disabled on all profiles.", "✓".green().bold());
    Ok(())
}

fn cmd_lockdown() -> Result<()> {
    netsh(&[
        "advfirewall", "set", "allprofiles",
        "firewallpolicy", "blockinbound,blockoutbound",
    ])?;
    println!("{} {} — all outbound traffic blocked.", "🔒".bold(), "Lockdown ON".red().bold());
    println!("   Use `rustwall allow <path>` to whitelist applications.");
    Ok(())
}

fn cmd_unlock() -> Result<()> {
    netsh(&[
        "advfirewall", "set", "allprofiles",
        "firewallpolicy", "blockinbound,allowoutbound",
    ])?;
    println!("{} {} — outbound traffic allowed again.", "🔓".bold(), "Lockdown OFF".green().bold());
    Ok(())
}

fn cmd_cleanup() -> Result<()> {
    let out = netsh(&["advfirewall", "firewall", "show", "rule", "name=all"])?;

    let names: Vec<String> = out
        .lines()
        .filter_map(|l| l.trim().strip_prefix("Rule Name:").map(|s| s.trim().to_string()))
        .filter(|n| n.starts_with(APP_PREFIX))
        .collect();

    if names.is_empty() {
        println!("{} No RustWall rules to remove.", "ℹ".blue().bold());
        return Ok(());
    }

    for name in &names {
        let _ = netsh(&[
            "advfirewall", "firewall", "delete", "rule",
            &format!("name={}", name),
        ]);
        println!("  {} {}", "·".dimmed(), name.dimmed());
    }
    println!("{} Removed {} rule(s).", "✓".green().bold(), names.len());
    Ok(())
}