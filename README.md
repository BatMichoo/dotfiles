# 🌌 BatMichoo's Dotfiles

Personal configurations automated for Arch Linux (CachyOS) and KDE Plasma.

## 🚀 Quick Bootstrap (Fresh Install)

On a clean CachyOS installation, you can configure your entire environment with a single command. This handles bare repository cloning, resolves default file collisions, installs aliases, sets up KDE defaults, and pulls Neovim configurations.

Ensure you have added your SSH keys to GitHub first (required to pull the repository and submodules), then run:

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

### 2. Ghostty Terminal
Ghostty is set as the default terminal emulator across the environment:
- Environment variable `TERMINAL=ghostty` configured.
- KDE Plasma system settings updated to launch Ghostty by default.

### 3. Neovim Configuration Submodule
Your decoupled Neovim configuration is tracked as a git submodule pointing to [nvim-config](https://github.com/BatMichoo/nvim-config) and cloned directly to `~/.config/nvim`.

### 4. Custom KWin Tiling Script
Installs a custom KWin window management script that maps `Meta` + `Up Arrow` to:
- **Maximize** the active window if it is restored.
- **Quick-tile to the top-half** of the screen if it is already maximized.

---

## 📁 Repository Structure
- `.local/bin/dotfiles-setup.sh` — Idempotent, robust setup bootstrap script
- `.config/fish/functions/dotfiles.fish` — Autoloaded Fish function alias
- `.local/share/kwin/scripts/toggle-maximize-tile/` — Custom window tiling script
