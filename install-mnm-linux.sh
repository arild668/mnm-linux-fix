#!/usr/bin/env bash
# Monsters & Memories - Linux AppImage workaround installer (unofficial)
#
# Fixes:
#   1. Blank white launcher window (EGL_BAD_PARAMETER) caused by bundled libwayland
#   2. Play button failing because the launcher leaks its environment into umu-run
#   3. Game files having nowhere to install (read-only AppImage mount)
#
# Usage:
#   bash install-mnm-linux.sh [path/to/MonstersAndMemories_amd64.appimage]
#
# Install location defaults to ~/Games/MnM. Override with:
#   MNM_DIR=/some/other/path bash install-mnm-linux.sh
#
# Running it again with a newer AppImage updates the launcher and keeps your game files.

set -euo pipefail

INSTALL_DIR="${MNM_DIR:-$HOME/Games/MnM}"
WRAPPER_DIR="$HOME/.local/bin"
WRAPPER="$WRAPPER_DIR/umu-run"
START_SCRIPT="$INSTALL_DIR/start-mnm.sh"
DESKTOP_FILE="$HOME/.local/share/applications/monsters-and-memories.desktop"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWARNING:\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Find the AppImage -----------------------------------------------------
APPIMAGE="${1:-}"
if [[ -z "$APPIMAGE" ]]; then
    for dir in "$PWD" "$HOME/Downloads" "$HOME/Hämtningar" "$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"; do
        [[ -d "$dir" ]] || continue
        found="$(find "$dir" -maxdepth 1 -iname '*monsters*memories*.appimage' -print 2>/dev/null | head -n1)"
        if [[ -n "$found" ]]; then APPIMAGE="$found"; break; fi
    done
fi
[[ -n "$APPIMAGE" ]] || die "Could not find the AppImage. Run: bash $0 /path/to/MonstersAndMemories_amd64.appimage"
[[ -f "$APPIMAGE" ]] || die "File not found: $APPIMAGE"
APPIMAGE="$(realpath "$APPIMAGE")"
info "Using AppImage: $APPIMAGE"

# --- 2. Find the system umu-run (not our own wrapper) ------------------------
REAL_UMU=""
while IFS= read -r candidate; do
    [[ "$candidate" == "$WRAPPER" ]] && continue
    REAL_UMU="$candidate"; break
done < <(type -ap umu-run 2>/dev/null || true)

if [[ -z "$REAL_UMU" ]]; then
    warn "umu-run was not found on this system."
    warn "The launcher needs it to start the game. Install 'umu-launcher' with your package manager"
    warn "(Bazzite/SteamOS-like distros usually have it already), then run this script again."
    REAL_UMU="/usr/bin/umu-run"
else
    info "Found system umu-run: $REAL_UMU"
fi

# --- 3. Extract the AppImage into a temporary folder -------------------------
mkdir -p "$INSTALL_DIR"
TMP="$(mktemp -d "$INSTALL_DIR/.extract.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

chmod +x "$APPIMAGE"
info "Extracting AppImage (this can take a moment)..."
( cd "$TMP" && "$APPIMAGE" --appimage-extract >/dev/null )
[[ -x "$TMP/squashfs-root/AppRun" ]] || die "Extraction failed: AppRun not found."

# --- 4. Remove bundled libwayland (fixes the white window) -------------------
info "Removing bundled libwayland libraries..."
find "$TMP/squashfs-root" -name 'libwayland-*' -print -delete

# --- 5. Keep existing game files when updating -------------------------------
OLD_ROOT="$INSTALL_DIR/squashfs-root"
GAME_SUBDIR="usr/bin/mnm"
if [[ -d "$OLD_ROOT/$GAME_SUBDIR" ]]; then
    info "Existing installation found - keeping your game files..."
    rm -rf "$TMP/squashfs-root/$GAME_SUBDIR"
    mkdir -p "$(dirname "$TMP/squashfs-root/$GAME_SUBDIR")"
    mv "$OLD_ROOT/$GAME_SUBDIR" "$TMP/squashfs-root/$GAME_SUBDIR"
fi
if [[ -d "$OLD_ROOT" ]]; then
    rm -rf "$OLD_ROOT"
fi
mv "$TMP/squashfs-root" "$OLD_ROOT"

# --- 6. Create the umu-run wrapper (fixes Play / Python / SSL errors) --------
info "Creating umu-run wrapper in $WRAPPER_DIR..."
mkdir -p "$WRAPPER_DIR"
cat > "$WRAPPER" <<EOF
#!/bin/bash
# Gives umu-run a clean environment instead of the launcher's AppImage environment.
unset PYTHONHOME PYTHONPATH LD_LIBRARY_PATH LD_PRELOAD GIO_MODULE_DIR
exec "$REAL_UMU" "\$@"
EOF
chmod +x "$WRAPPER"

# --- 7. Create start script ---------------------------------------------------
info "Creating start script..."
cat > "$START_SCRIPT" <<EOF
#!/bin/bash
export PATH="$WRAPPER_DIR:\$PATH"
cd "$OLD_ROOT"
exec ./AppRun "\$@"
EOF
chmod +x "$START_SCRIPT"

# --- 8. Desktop menu entry ----------------------------------------------------
ICON="applications-games"
for candidate in "$OLD_ROOT/.DirIcon" "$OLD_ROOT"/*.png; do
    if [[ -f "$candidate" ]]; then ICON="$candidate"; break; fi
done
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Monsters & Memories
Comment=Monsters & Memories launcher (Linux workaround)
Exec="$START_SCRIPT"
Path=$OLD_ROOT
Icon=$ICON
Terminal=false
Categories=Game;
EOF
update-desktop-database "$(dirname "$DESKTOP_FILE")" >/dev/null 2>&1 || true

# --- Done ---------------------------------------------------------------------
cat <<EOF
$(printf '\033[1;32m')All done!$(printf '\033[0m')
Start the launcher:
  - From your app menu: "Monsters & Memories"
  - Or from a terminal:  $START_SCRIPT
Add to Steam (optional):
  1. Steam > Add a Game > Add a Non-Steam Game > Browse
  2. Pick: $START_SCRIPT
     (switch the file type to "All files" if it isn't listed)
  3. Properties > Compatibility: make sure Proton is OFF (the launcher is a native Linux app)
The first time you press Play, umu downloads GE-Proton - that can take a few minutes.
To update the launcher later, download the new AppImage and run this script again.
EOF
