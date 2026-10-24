#!/usr/bin/env bash
# Monsters & Memories - Linux launcher installer (unofficial)
#
# Fixes common problems with the official Linux AppImage launcher:
#   1. Blank white launcher window (EGL_BAD_PARAMETER)
#   2. Play button doing nothing / umu-run crashing
#   3. Game files having nowhere to install (read-only AppImage mount)
#
# Two install modes, picked automatically:
#   native - only the launcher binary is extracted and runs with your system's
#            libraries. Avoids all AppImage bugs, no wrapper needed.
#            Requires WebKitGTK 4.1, GTK3 and libsoup3 on the system.
#            (Idea from the M&M community - thanks!)
#   full   - fallback when those libraries are missing: the whole AppImage is
#            extracted, the bundled libwayland is removed, and a small umu-run
#            wrapper clears the leaked AppImage environment.
#
# Usage:
#   bash install-mnm-linux.sh [path/to/MonstersAndMemories_amd64.appimage]
#
# Options (environment variables):
#   MNM_DIR=/some/path   install location (default: ~/Games/MnM)
#   MNM_MODE=full        force the full-extract mode
#
# Running it again with a newer AppImage updates the launcher and keeps your
# game files. Switching between modes also keeps them.

set -euo pipefail

INSTALL_DIR="${MNM_DIR:-$HOME/Games/MnM}"
MODE="${MNM_MODE:-auto}"
WRAPPER_DIR="$HOME/.local/bin"
WRAPPER="$WRAPPER_DIR/umu-run"
WRAPPER_MARK="# mnm-linux-fix wrapper"
START_SCRIPT="$INSTALL_DIR/start-mnm.sh"
DESKTOP_FILE="$HOME/.local/share/applications/monsters-and-memories.desktop"

NATIVE_BIN="$INSTALL_DIR/mnm_launcher"
NATIVE_GAME="$INSTALL_DIR/mnm"
FULL_ROOT="$INSTALL_DIR/squashfs-root"
FULL_GAME="$FULL_ROOT/usr/bin/mnm"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWARNING:\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Find the AppImage -----------------------------------------------------
APPIMAGE="${1:-}"
if [[ -z "$APPIMAGE" ]]; then
    for dir in "$PWD" "$HOME/Downloads" "$HOME/Hämtningar" "$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"; do
        [[ -n "$dir" && -d "$dir" ]] || continue
        found="$(find "$dir" -maxdepth 1 -iname '*monsters*memories*.appimage' -print 2>/dev/null | head -n1)"
        if [[ -n "$found" ]]; then APPIMAGE="$found"; break; fi
    done
fi
[[ -n "$APPIMAGE" ]] || die "Could not find the AppImage. Run: bash $0 /path/to/MonstersAndMemories_amd64.appimage"
[[ -f "$APPIMAGE" ]] || die "File not found: $APPIMAGE"
APPIMAGE="$(realpath "$APPIMAGE")"
info "Using AppImage: $APPIMAGE"

# --- 2. Check for umu-run -----------------------------------------------------
REAL_UMU=""
while IFS= read -r candidate; do
    [[ "$candidate" == "$WRAPPER" ]] && continue
    REAL_UMU="$candidate"; break
done < <(type -ap umu-run 2>/dev/null || true)

if [[ -z "$REAL_UMU" ]]; then
    warn "umu-run was not found on this system."
    warn "The launcher needs it to start the game. Install 'umu-launcher' with your package manager"
    warn "(gaming distros like Bazzite, Nobara and CachyOS usually have it), then run this script again."
    REAL_UMU="/usr/bin/umu-run"
else
    info "Found umu-run: $REAL_UMU"
fi

# --- 3. Extract the AppImage into a temporary folder -------------------------
mkdir -p "$INSTALL_DIR"
TMP="$(mktemp -d "$INSTALL_DIR/.extract.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

chmod +x "$APPIMAGE"
info "Extracting AppImage (this can take a moment)..."
( cd "$TMP" && "$APPIMAGE" --appimage-extract >/dev/null )
NEW_ROOT="$TMP/squashfs-root"
[[ -x "$NEW_ROOT/AppRun" ]] || die "Extraction failed: AppRun not found."

NEW_BIN="$(find "$NEW_ROOT" -type f -name 'mnm_launcher' -path '*/usr/bin/*' -print -quit)"
[[ -n "$NEW_BIN" ]] || die "Could not find mnm_launcher inside the AppImage."

# Save the icon before anything is deleted
ICON="applications-games"
for candidate in "$NEW_ROOT/.DirIcon" "$NEW_ROOT"/*.png; do
    if [[ -e "$candidate" ]]; then
        cp -L "$candidate" "$INSTALL_DIR/icon.png" 2>/dev/null && ICON="$INSTALL_DIR/icon.png"
        break
    fi
done

# --- 4. Pick the install mode -------------------------------------------------
if [[ "$MODE" == "auto" ]]; then
    missing="$(ldd "$NEW_BIN" 2>/dev/null | grep 'not found' || true)"
    if [[ -z "$missing" ]]; then
        MODE="native"
        info "All required system libraries found - using native mode."
    else
        MODE="full"
        warn "Some system libraries are missing, using full-extract mode instead:"
        printf '%s\n' "$missing" | sed 's/^/    /'
    fi
fi
[[ "$MODE" == "native" || "$MODE" == "full" ]] || die "Unknown MNM_MODE: $MODE (use native or full)"

# --- 5. Find existing game files (from either mode) --------------------------
EXISTING_GAME=""
for g in "$NATIVE_GAME" "$FULL_GAME"; do
    if [[ -d "$g" && ! -L "$g" ]]; then EXISTING_GAME="$g"; break; fi
done
SAVED_GAME="$INSTALL_DIR/.mnm-game-keep"
if [[ -n "$EXISTING_GAME" ]]; then
    info "Existing game files found - keeping them..."
    rm -rf "$SAVED_GAME"
    mv "$EXISTING_GAME" "$SAVED_GAME"
fi

# Remove the old launcher files of both modes (game files are already safe)
rm -rf "$FULL_ROOT" "$NATIVE_BIN"
[[ -L "$NATIVE_GAME" ]] && rm -f "$NATIVE_GAME"

# --- 6. Install ---------------------------------------------------------------
if [[ "$MODE" == "native" ]]; then
    info "Installing launcher binary..."
    mv "$NEW_BIN" "$NATIVE_BIN"
    chmod +x "$NATIVE_BIN"
    GAME_DEST="$NATIVE_GAME"
    WORK_DIR="$INSTALL_DIR"
    LAUNCH_CMD="./mnm_launcher"

    # The wrapper is not needed in native mode - remove ours if present
    if [[ -f "$WRAPPER" ]] && grep -qE "$WRAPPER_MARK|Gives umu-run a clean environment" "$WRAPPER"; then
        info "Removing umu-run wrapper (not needed in native mode)..."
        rm -f "$WRAPPER"
    fi
else
    info "Removing bundled libwayland libraries..."
    find "$NEW_ROOT" -name 'libwayland-*' -print -delete
    mv "$NEW_ROOT" "$FULL_ROOT"
    GAME_DEST="$FULL_GAME"
    WORK_DIR="$FULL_ROOT"
    LAUNCH_CMD="./AppRun"

    info "Creating umu-run wrapper in $WRAPPER_DIR..."
    mkdir -p "$WRAPPER_DIR"
    cat > "$WRAPPER" <<EOF
#!/bin/bash
$WRAPPER_MARK
# Gives umu-run a clean environment instead of the launcher's AppImage environment.
unset PYTHONHOME PYTHONPATH LD_LIBRARY_PATH LD_PRELOAD GIO_MODULE_DIR GIO_EXTRA_MODULES
exec "$REAL_UMU" "\$@"
EOF
    chmod +x "$WRAPPER"
fi

if [[ -d "$SAVED_GAME" ]]; then
    mkdir -p "$(dirname "$GAME_DEST")"
    mv "$SAVED_GAME" "$GAME_DEST"
fi

# --- 7. Start script ----------------------------------------------------------
info "Creating start script..."
if [[ "$MODE" == "native" ]]; then
    cat > "$START_SCRIPT" <<EOF
#!/bin/bash
cd "$WORK_DIR"
exec $LAUNCH_CMD "\$@"
EOF
else
    cat > "$START_SCRIPT" <<EOF
#!/bin/bash
export PATH="$WRAPPER_DIR:\$PATH"
cd "$WORK_DIR"
exec $LAUNCH_CMD "\$@"
EOF
fi
chmod +x "$START_SCRIPT"

# --- 8. App menu entry --------------------------------------------------------
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Monsters & Memories
Comment=Monsters & Memories launcher
Exec="$START_SCRIPT"
Path=$WORK_DIR
Icon=$ICON
Terminal=false
Categories=Game;
EOF
update-desktop-database "$(dirname "$DESKTOP_FILE")" >/dev/null 2>&1 || true

# --- Done ---------------------------------------------------------------------
cat <<EOF

$(printf '\033[1;32m')All done!$(printf '\033[0m') (mode: $MODE)

Start the launcher:
  - From your app menu: "Monsters & Memories"
  - Or from a terminal:  $START_SCRIPT

Add to Steam (optional):
  1. Steam > Add a Game > Add a Non-Steam Game > Browse
  2. Pick: $START_SCRIPT
     (switch the file type to "All files" if it isn't listed)
  3. Properties > Compatibility: leave it on Default - don't pick a Proton version

The first time you press Play, umu downloads GE-Proton - that can take a few minutes.
To update the launcher later, download the new AppImage and run this script again.
EOF
