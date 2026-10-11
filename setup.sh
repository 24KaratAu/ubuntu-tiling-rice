#!/usr/bin/env bash
# Ubuntu GNOME + Forge tiling setup.
#
#   curl -sSL https://raw.githubusercontent.com/24KaratAu/ubuntu-tiling-rice/main/setup.sh | bash
#
# Safe to re-run. Existing kitty/zsh configs are backed up before being replaced.

set -euo pipefail

REPO="24KaratAu/ubuntu-tiling-rice"
BRANCH="main"
FORGE_UUID="forge@jmmaranan.com"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Everything runs inside main() so that, when piped from curl, bash has read
# the whole script before any command (apt, sudo) can swallow stdin.
main() {
    # ---------------------------------------------------------------- preflight

    [ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (it will sudo when needed)"
    command -v apt-get >/dev/null || die "this script needs apt (Ubuntu/Debian)"
    command -v gnome-shell >/dev/null || die "GNOME Shell not found"

    # ----------------------------------------------------------------- packages

    info "Installing packages"
    sudo apt-get update
    sudo apt-get install -y \
        kitty zsh zsh-autosuggestions zsh-syntax-highlighting \
        gnome-screenshot wl-clipboard dconf-cli curl

    # ------------------------------------------------------------- repo sources

    # When piped from curl there is no checkout next to the script, so fetch one.
    SRC=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        [ -f "$here/config/kitty/kitty.conf" ] && SRC="$here"
    fi
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    if [ -z "$SRC" ]; then
        info "Downloading $REPO"
        curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" \
            | tar -xz -C "$TMP" --strip-components=1
        SRC="$TMP"
    fi

    # ------------------------------------------------------------------ helpers

    # Install a file, keeping a timestamped backup of whatever it replaces.
    install_file() {
        local src=$1 dest=$2 mode=${3:-644}
        if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
            cp -a "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"
            warn "existing $dest backed up"
        fi
        install -D -m "$mode" "$src" "$dest"
    }

    # Append an item to a gsettings string array unless it is already there.
    gs_list_add() {
        local schema=$1 key=$2 item=$3 cur
        cur="$(gsettings get "$schema" "$key")"
        case "$cur" in
            *"'$item'"*) ;;
            "@as []"|"[]") gsettings set "$schema" "$key" "['$item']" ;;
            *) gsettings set "$schema" "$key" "${cur%]}, '$item']" ;;
        esac
    }

    has_schema() { gsettings list-schemas | grep -qx "$1"; }

    MEDIA_KEYS="org.gnome.settings-daemon.plugins.media-keys"
    CUSTOM_BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

    # custom_key <id> <name> <binding> <command>
    custom_key() {
        local path="$CUSTOM_BASE/$1/"
        gs_list_add "$MEDIA_KEYS" custom-keybindings "$path"
        gsettings set "$MEDIA_KEYS.custom-keybinding:$path" name "$2"
        gsettings set "$MEDIA_KEYS.custom-keybinding:$path" binding "$3"
        gsettings set "$MEDIA_KEYS.custom-keybinding:$path" command "$4"
    }

    # -------------------------------------------------------------------- files

    info "Installing kitty config, zshrc and screenshot script"
    install_file "$SRC/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    install_file "$SRC/config/zsh/zshrc"        "$HOME/.zshrc"
    install_file "$SRC/bin/region-screenshot"   "$HOME/.local/bin/region-screenshot" 755

    zsh_path="$(command -v zsh)"
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]; then
        info "Setting zsh as the login shell"
        sudo chsh -s "$zsh_path" "$USER"
    fi

    # -------------------------------------------------------------------- forge

    shell_major="$(gnome-shell --version | grep -oE '[0-9]+' | head -n1)"
    forge_dir="$HOME/.local/share/gnome-shell/extensions/$FORGE_UUID"

    if [ -d "$forge_dir" ] || [ -d "/usr/share/gnome-shell/extensions/$FORGE_UUID" ]; then
        info "Forge already installed"
    else
        info "Installing Forge for GNOME Shell $shell_major"
        dl="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$FORGE_UUID&shell_version=$shell_major" \
            | grep -oE '"download_url": *"[^"]+"' | cut -d'"' -f4 || true)"
        if [ -n "$dl" ]; then
            curl -fsSL "https://extensions.gnome.org$dl" -o "$TMP/forge.zip"
            gnome-extensions install --force "$TMP/forge.zip"
        else
            warn "no Forge release for GNOME Shell $shell_major on extensions.gnome.org;"
            warn "install it manually from https://github.com/forge-ext/forge"
        fi
    fi

    # A freshly installed extension is unknown to the running shell, so enable it
    # through the setting; it loads on the next login.
    gs_list_add org.gnome.shell enabled-extensions "$FORGE_UUID"

    # Ubuntu's own tiling extension fights with Forge.
    for uuid in tiling-assistant@ubuntu.com tiling-assistant@leleat-on-github; do
        gnome-extensions disable "$uuid" 2>/dev/null || true
    done

    # Forge's schema lives inside the extension, so write its keys through dconf.
    # Its defaults for these collide with Super+Shift+S and Super+Return below.
    FORGE_KEYS="/org/gnome/shell/extensions/forge/keybindings"
    dconf write "$FORGE_KEYS/con-stacked-layout-toggle" "@as []"
    dconf write "$FORGE_KEYS/window-swap-last-active" "@as []"
    dconf write "$FORGE_KEYS/window-toggle-float" "['<Super>space']"

    # -------------------------------------------------------------- keybindings

    info "Applying GNOME settings"

    WM="org.gnome.desktop.wm.keybindings"
    gsettings set "$WM" close "['<Super>q', '<Alt>F4']"
    gsettings set "$WM" toggle-fullscreen "['<Super><Shift>f']"

    # Ten fixed workspaces on Super+1..0, move windows with Super+Shift+1..0.
    gsettings set org.gnome.mutter dynamic-workspaces false
    gsettings set org.gnome.desktop.wm.preferences num-workspaces 10
    for i in 1 2 3 4 5 6 7 8 9 10; do
        key=$((i % 10))
        gsettings set "$WM" "switch-to-workspace-$i" "['<Super>$key']"
        gsettings set "$WM" "move-to-workspace-$i" "['<Super><Shift>$key']"
    done

    # Super+N otherwise launches the Nth dock app.
    for i in 1 2 3 4 5 6 7 8 9; do
        gsettings set org.gnome.shell.keybindings "switch-to-application-$i" "[]"
    done
    if has_schema org.gnome.shell.extensions.dash-to-dock; then
        for i in 1 2 3 4 5 6 7 8 9 10; do
            gsettings set org.gnome.shell.extensions.dash-to-dock "app-hotkey-$i" "[]"
            gsettings set org.gnome.shell.extensions.dash-to-dock "app-shift-hotkey-$i" "[]"
        done
    fi

    # Free Super+Shift+S from the built-in screenshot UI.
    gsettings set org.gnome.shell.keybindings show-screenshot-ui "[]"

    custom_key kitty      "Kitty"             "<Super>Return"   "kitty"
    custom_key firefox    "Firefox"           "<Super>b"        "firefox"
    custom_key files      "Files"             "<Super>e"        "nautilus --new-window"
    custom_key screenshot "Region Screenshot" "<Super><Shift>s" "$HOME/.local/bin/region-screenshot"

    # --------------------------------------------------------------- appearance

    IFACE="org.gnome.desktop.interface"
    gsettings set "$IFACE" enable-hot-corners false
    gsettings set "$IFACE" color-scheme prefer-dark
    if [ -d /usr/share/themes/Yaru-prussiangreen-dark ]; then
        gsettings set "$IFACE" gtk-theme Yaru-prussiangreen-dark
        gsettings set "$IFACE" icon-theme Yaru-prussiangreen
    fi

    info "Done. Log out and back in to load Forge and the new shell."
}

main "$@"
