# chimera-hyprland
Automatic installer Chimera Linux + Btrfs + Limine + Snapper + Hyprland

# Chimera Linux + Btrfs + Limine + Snapper + Hyprland

A complete, "out-of-the-box" interactive installer for **Chimera Linux**, featuring Btrfs partitioning optimized for SSDs, RAM-efficient Snapper integration, UFW/sysctl security hardening, and a modular Hyprland desktop environment.

## Quick Installation (from Live ISO)

1. Boot the **Chimera Linux Live ISO** (`root` / `chimera`) and connect to the internet (use `nmtui` for Wi-Fi).
2. Run the following command:

```bash
curl -fsSL https://github.com/constantinadry26/chimera-hyprland.git -o install.sh && chmod +x install.sh && ./install.sh
```

## Hyprland Shortcuts

| Key Combination | Action |
| :--- | :--- |
| `Super + Q` | Terminal (`foot`) |
| `Super + B` | Browser (`firefox`) |
| `Super + E` | File Manager (`thunar`) |
| `Super + R` | Application Menu (`fuzzel`) |
| `Super + C` | Close window |
| `Super + F` | Fullscreen |
| `Super + V` | Floating mode |
| `Super + Shift + S` | Screenshot (to clipboard) |
| `Super + L` | Lock screen (`hyprlock`) |
| `Super + 1..5` | Switch Workspace |

## Useful Maintenance Commands

* **Safe Update (Pre/Post snapshots + Limine kernel update + cleanup):** `doas sysup`
* **List snapshots:** `doas snapper -c root list`
* **Restore system:** `doas snapper -c root rollback NUMBER`
