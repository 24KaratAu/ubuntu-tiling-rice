# Ubuntu GNOME Forge Tiling Setup

One command to turn a stock Ubuntu GNOME desktop into a keyboard-driven tiling
setup: [Forge](https://github.com/forge-ext/forge) for tiling, Kitty as the
terminal, Zsh with autosuggestions, and Hyprland-style `Super` keybindings.

## Install

```bash
curl -sSL https://raw.githubusercontent.com/24KaratAu/ubuntu-tiling-rice/main/setup.sh | bash
```

Then log out and back in so GNOME loads Forge and your login shell switches to Zsh.

Or from a clone:

```bash
git clone https://github.com/24KaratAu/ubuntu-tiling-rice.git
cd ubuntu-tiling-rice && ./setup.sh
```

The script asks for your sudo password (apt and `chsh`), is safe to re-run, and
backs up an existing `~/.zshrc` or `kitty.conf` to `<file>.bak.<timestamp>`
before replacing it.

Built and used on **Ubuntu 22.04 (GNOME 42, Wayland)**. On other releases the
script fetches whichever Forge build extensions.gnome.org lists for your GNOME
version; that path is untested.

## Keybindings

| Keys | Action |
| --- | --- |
| `Super + Return` | Kitty |
| `Super + B` | Firefox |
| `Super + E` | Files (Nautilus) |
| `Super + Shift + S` | Select a region, copy it to the clipboard |
| `Super + Q` / `Alt + F4` | Close window |
| `Super + Shift + F` | Toggle fullscreen |
| `Super + Space` | Toggle floating for the focused window (Forge) |
| `Super + 1` … `0` | Switch to workspace 1–10 |
| `Super + Shift + 1` … `0` | Move window to workspace 1–10 |

Everything else is Forge's defaults (`Super + H/J/K/L` to focus,
`Super + Shift + H/J/K/L` to move, `Super + W` to toggle tiling).

## What it does

**Packages** — `kitty`, `zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting`,
`gnome-screenshot`, `wl-clipboard`.

**Forge** — installed from extensions.gnome.org if missing and enabled. Ubuntu's
own Tiling Assistant is disabled so the two don't fight. Two Forge defaults that
collide with the bindings above are cleared (`Super + Shift + S` stacked layout,
`Super + Return` swap with last window), and float toggle moves to `Super + Space`.

**Workspaces** — ten fixed workspaces instead of dynamic ones. The dock's
`Super + N` app launchers are unbound so the number keys are free for
workspace switching.

**Region screenshot** — GNOME's screenshot UI is unbound from its shortcut and
`Super + Shift + S` runs [`bin/region-screenshot`](bin/region-screenshot)
instead, which grabs a region with `gnome-screenshot` and pipes it to the
Wayland clipboard with `wl-copy`. Nothing is saved to disk.

**Kitty** ([`config/kitty/kitty.conf`](config/kitty/kitty.conf)) — Catppuccin
Mocha colours, slight transparency, and the tiling fixes: client-side
decorations off, XWayland instead of native Wayland
(`linux_display_server x11`), and no remembered window size. Together these
stop the flicker/resize loop Kitty gets into when Forge snaps it into a tile.

**Zsh** ([`config/zsh/zshrc`](config/zsh/zshrc)) — set as the login shell, with
shared history, syntax highlighting and autosuggestions. Up-arrow accepts the
current suggestion if there is one and otherwise walks history. The binding
calls the plugin's internal `_zsh_autosuggest_widget_accept` directly, since
`autosuggest-accept` did not work from inside a custom widget with Ubuntu's
packaged `zsh-autosuggestions`.

**Appearance** — dark mode, hot corners off, and the Yaru Prussian Green theme
and icons where available.

## Undo

Restore the `.bak.*` files, `chsh -s /bin/bash`, disable Forge in the
Extensions app, and reset the shortcuts under Settings → Keyboard → View and
Customize Shortcuts.

## License

[MIT](LICENSE)
