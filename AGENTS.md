# AGENTS.md

Instructions for AI coding agents working in this repository.

## What this is

This is a **bare git repository** used to manage dotfiles directly in `$HOME`, without symlinks. The actual git directory lives at `~/.dotfiles` (not `~/.git`), and the work tree is `$HOME` itself. Only files explicitly added to the repo are tracked; everything else in `$HOME` is ignored by design.

## The `dotfiles` command

All git operations against this repo go through the `dotfiles` command, **not** plain `git`. It's a Fish shell function (`~/.config/fish/functions/dotfiles.fish`) equivalent to:

```bash
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME "$@"
```

If the `dotfiles` function isn't available in the current shell (e.g. non-interactive/non-fish contexts), use the full form directly:

```bash
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" <command>
```

Running plain `git status`/`git add`/etc. from `$HOME` will **not** work — there is no `.git` directory there.

### Common commands

```bash
dotfiles status
dotfiles diff -- <path>
dotfiles add <path>
dotfiles commit -m "type(scope): message"
dotfiles log --oneline
dotfiles push origin main
```

### Important config quirks

- `status.showUntrackedFiles = no` is set on this repo. This means `dotfiles status` will **not** list new/untracked files in `$HOME` — it only shows changes to files already tracked. To check whether a specific new file is tracked, use `dotfiles ls-files -- <path>` (empty output means untracked). Don't assume a clean `dotfiles status` means there's nothing new to add.
- `.config/nvim` is a submodule pointing at a separate `nvim-config` repo. A "modified: .config/nvim (new commits)" status is normal and usually left alone unless the nvim config itself is being changed.

## Commit conventions

Commits follow Conventional Commits style: `type(scope): short summary`, e.g. `feat(ghostty): set default window size to 1200x720`, `fix(fish): drop deprecated keychain --agents flag`. Keep unrelated changes in separate commits.

## Repository layout

- `.local/bin/*.sh` — modular setup scripts (KDE, sys packages, apps, SSH bootstrap, service reloads). See `README.md` for what each one does.
- Config files are tracked at their real `$HOME`-relative paths (e.g. `.config/fish/config.fish`, `.config/ghostty/config`, `.config/kxkbrc`).
- `README.md` documents the bootstrap flow and script responsibilities — keep it in sync when adding or changing a script.

## Remote

`origin` is `git@github.com:BatMichoo/dotfiles.git`. Never force-push, and don't push without being explicitly asked to.
