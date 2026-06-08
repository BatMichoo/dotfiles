# 🌌 BatMichoo's Dotfiles

Personal configurations automated for Arch Linux (CachyOS) and KDE Plasma.

## 🚀 Quick Bootstrap (Fresh Install)

On a clean CachyOS installation, you can configure your entire environment with a single command. This handles bare repository cloning, resolves default file collisions, installs aliases, sets up KDE defaults, and pulls Neovim configurations.

The script will automatically detect if you have an SSH key set up. If not, it will run `github-ssh-setup.sh` to generate one, print the public key, and pause so you can register it under your GitHub profile before continuing with the repository checkout.

Run the bootstrap command:

```bash
curl -fsSL https://raw.githubusercontent.com/BatMichoo/dotfiles/main/.local/bin/dotfiles-setup.sh -o /tmp/dotfiles-setup.sh && chmod +x /tmp/dotfiles-setup.sh && /tmp/dotfiles-setup.sh
```

---

## 🛠️ Included Integrations

### 1. Bare Repository Management
The repository tracks configuration changes across your `$HOME` directory without flooding your system with untracked files. 
- Administrative directory: `~/.dotfiles`
- Interacting with the repository is wrapped in a native Fish shell alias:
  ```bash
  dotfiles status
  dotfiles add .config/some-app/config
  dotfiles commit -m "feat: update config"
  dotfiles push origin main
  ```

### 2. Default Editor & Terminal Configuration
- **Terminal**: Ghostty is configured as the default emulator (`TERMINAL=ghostty`) in shell and KDE settings.
- **Default Editor**: Neovim (`nvim`) is set as the default text editor (`EDITOR=nvim` and `VISUAL=nvim`) for both Fish and Bash shells, as well as the default handler for plain text (`text/plain`) files in the GUI.

### 3. Keyboard Layout & Tiling
- **Keyboard**: US and Bulgarian Traditional Phonetic keyboard layouts are configured, with `Alt+Shift` set as the toggle shortcut.
- **KWin Tiling**: Custom window management script mapping `Meta` + `Up Arrow` to:
  - **Maximize** the active window if it is restored.
  - **Quick-tile to the top-half** of the screen if it is already maximized.

### 4. Power & Energy Management
PowerDevil settings are automated for AC and Battery profiles:
- **Screen Off**: 30 minutes idle timeout.
- **System Sleep (Suspend)**: 1 hour 30 minutes idle timeout.
- **Display Dimming**: Automatically disabled ("Never") when running on AC power.

---

## 📁 Repository Structure & Scripts

The environment configuration is split into modular scripts located in `.local/bin/`:

- **`dotfiles-setup.sh`** — Core orchestrator script that initializes the bare repository, pulls configurations, and executes the helper setup scripts.
- **`kde-setup.sh`** — Centralized configuration script for KDE Plasma desktop environment settings (tiling, keyboard layouts, power profiles, terminal defaults, and live service reloads).
- **`sys-setup.sh`** — Developer environment package installer (Build essentials, Ghostty, Node.js/fnm, Go, Rust, .NET SDK, Neovim, Lazygit, Tree-sitter).
- **`apps-setup.sh`** — Installer script for general applications (Discord, Steam, Google Chrome).
- **`github-ssh-setup.sh`** — Helper script to generate and print SSH keys for GitHub integration.
