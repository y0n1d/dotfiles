# Agent instructions

## Project overview

This repository contains personal Arch Linux + Wayland dotfiles managed with
GNU Stow. The primary compositor is niri; sway and river are fallback
configurations. Each top-level package mirrors the path it installs below
`$HOME`.

Keep this file as the canonical repository guidance. Tool-specific files such
as `CLAUDE.md` should point here instead of duplicating these rules.

## Package map

| Package | Purpose |
| --- | --- |
| `niri` | Main compositor, startup, outputs, input, layout, rules and keybindings |
| `waybar` | Status bar, JSONC configuration, CSS and custom scripts |
| `zsh` | `.zshrc`, modular shell configuration and Starship prompt |
| `foot` | Terminal emulator |
| `mako` | Notifications |
| `rofi`, `wofi` | Application launchers |
| `fcitx5` | Fcitx5 and Rime input method configuration |
| `sway`, `river` | Fallback compositor configurations |
| `tmux` | tmux configuration and Catppuccin theme |
| `nvim`, `yazi`, `gtk` | Editor, file manager and GTK settings |

## Configuration conventions

- Read the entry point and include/source order before editing a module.
- `niri/.config/niri/config.kdl` includes the niri KDL modules.
- `zsh/.zshrc` sources modules from `zsh/.config/zsh/`.
- `sway/.config/sway/config` includes the sway modules.
- The current desktop session uses Waybar; do not add or start DMS unless the
  user explicitly requests it.
- niri `spawn-at-startup` does not run an interactive Zsh. Use
  `spawn-sh`/`spawn-sh-at-startup` when shell expansion, `~`, variables,
  pipelines or boolean operators are required.
- Waybar custom modules that emit JSON must use `"return-type": "json"` and
  must produce valid JSON even when metadata contains quotes or newlines.
- Runtime state and caches should use `$XDG_RUNTIME_DIR` with a safe fallback,
  not fixed shared filenames in `/tmp`.
- PipeWire default audio targets use `@DEFAULT_AUDIO_SINK@` and
  `@DEFAULT_AUDIO_SOURCE@`.

## Generated and machine-specific files

Do not manually maintain generated or machine-specific data unless the user
explicitly asks for it:

- `fcitx5/.config/fcitx5/conf/cached_layouts`
- `niri/.config/niri/dms/`
- `waybar/.config/waybar/.bak/`
- monitor/output names and modes that only apply to one machine

Never add passwords, API tokens, private keys, `.env` contents or other
secrets. Keep personal overrides in ignored local files where possible.

## Safe editing rules

- Preserve unrelated user changes and inspect `git status` before editing.
- Modify repository files only; do not overwrite the deployed files in `$HOME`.
- Do not use destructive commands such as `git reset --hard` or broad recursive
  deletion without explicit user authorization.
- Prefer `apply_patch` for edits.
- Keep changes focused and update `README.md` when user-facing behavior or
  dependencies change.

## Validation

Run checks appropriate to the files changed. The standard checks are:

```bash
niri validate --config niri/.config/niri/config.kdl

for f in niri/.config/niri/scripts/*.sh \
         waybar/.config/waybar/scripts/*.sh \
         sway/.config/sway/*.sh; do
    bash -n "$f"
done

for f in zsh/.zshrc zsh/.config/zsh/*.zsh; do
    zsh -n "$f"
done

git diff --check
stow -nv niri waybar zsh foot mako rofi
```

For JSONC, use a JSONC-aware parser when available; do not treat comments and
trailing commas as ordinary JSON. For shell changes, also check executable
permissions and quote paths containing variables.

## Deployment

Preview before changing the home directory:

```bash
stow -nv <package>
```

Deploy one package with `stow <package>`, deploy all packages with `stow */`,
and remove a package with `stow -D <package>`. Existing non-symlink targets may
need manual review; do not use `--adopt` automatically.

## Handoff requirements

When finishing a change, report:

1. Files changed and the functional effect.
2. Validation commands run and their results.
3. Any generated, machine-specific or user-manual step left untouched.
