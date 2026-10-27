# Monsters & Memories – Linux launcher fix

Unofficial script that fixes common problems with the Monsters & Memories Linux AppImage launcher.

| Problem | Cause |
|---|---|
| Blank white launcher window (`EGL_BAD_PARAMETER`) | Bundled `libwayland` libraries conflict with newer systems |
| Play does nothing / umu-run crashes | The AppImage leaks its environment into umu-run |
| Links in the launcher don't open the browser | Same leaked AppImage environment (fixed in native mode) |
| Game download or install fails | The game installs inside the read-only AppImage |

## Install

First, download the **Linux AppImage** (`MonstersAndMemories_amd64.appimage`) from the official Monsters & Memories website. You don't need to make it executable – the script does that for you.

Then open a terminal and run:

```bash
curl -LO https://raw.githubusercontent.com/arild668/mnm-linux-fix/main/install-mnm-linux.sh
bash install-mnm-linux.sh ~/Downloads/MonstersAndMemories_amd64.appimage
```

Change `~/Downloads/...` if your AppImage is somewhere else (e.g. `~/Hämtningar` on a Swedish system). You can also leave the path out – the script looks in your Downloads folder by itself.

Then start **Monsters & Memories** from your app menu.

## What the script does

The script picks one of two modes automatically:

**Native mode** (used when your system has the libraries the launcher needs):

1. Extracts only the launcher program (`mnm_launcher`) to `~/Games/MnM`
2. The launcher then runs with your system's own libraries instead of the bundled ones, which avoids all problems above – no wrapper needed
3. The game is installed in `~/Games/MnM/mnm`

Requires WebKitGTK 4.1, GTK3 and libsoup3 – most desktop distros, including Bazzite, already have them.

**Full mode** (fallback when those libraries are missing):

1. Extracts the whole AppImage to `~/Games/MnM/squashfs-root`
2. Removes the bundled `libwayland-*` libraries
3. Creates a wrapper at `~/.local/bin/umu-run` that gives umu-run a clean environment
4. The game is installed in `~/Games/MnM/squashfs-root/usr/bin/mnm`

Both modes create a start script (`~/Games/MnM/start-mnm.sh`) and an app menu entry. To force full mode, run the script with `MNM_MODE=full`.

## Updating

- **Game patches:** just press **Update** in the launcher.
- **New launcher version:** download the new AppImage and run the script again. Your game files are kept, also when switching between modes.

## Adding to Steam (optional)

1. In Steam: **Add a Game → Add a Non-Steam Game → Browse**
2. Pick `~/Games/MnM/start-mnm.sh` (switch the file type to "All files" if it isn't listed)
3. In **Properties → Compatibility**, leave it on **Default**. Don't select a Proton version – the launcher is a native Linux app. If the launcher doesn't start from Steam, check that no Proton version is selected.

Note: only the launcher runs natively. When you press Play, the launcher runs the game itself through GE-Proton (downloaded automatically by umu).

## Troubleshooting

### Black screen after pressing Play

The game starts in fullscreen, shows a white window, then a black window, and nothing happens. The game's log (`Player.log`) shows errors like `NullReferenceException ... TMP_Settings.get_defaultStyleSheet`.

This means the game files don't match the current version. Common causes:

- **More than one installation.** All installations share the same launcher settings and version database, so the launcher may think the game is up to date while starting old game files from another folder. Keep only one installation (e.g. `~/Games/MnM`), remove the others, and make sure your Steam shortcut points to the right `start-mnm.sh`.
- **An incomplete update.** Force a fresh game install by moving the game folder away and starting the launcher again – it will show **Install** and download the game:

  ```bash
  # native mode
  mv ~/Games/MnM/mnm ~/Games/MnM/mnm-old
  # full mode
  mv ~/Games/MnM/squashfs-root/usr/bin/mnm ~/Games/MnM/mnm-old
  ```

  When everything works, you can delete `~/Games/MnM/mnm-old`.

To read the game's log:

```bash
find ~/.local/share/mnm -name "Player.log" -exec tail -n 40 {} \;
```

### "Session expired or was revoked. Please sign in again."

If auto-login is enabled, the launcher keeps reusing an expired login, so you never get a chance to sign in again. Clear the saved login (a backup of the settings file is made first):

```bash
pkill -f mnm_launcher
cd ~/.local/share/com.monstersandmemories.launcher
cp launcher.db launcher.db.backup
python3 -c "
import sqlite3
c = sqlite3.connect('launcher.db')
c.execute(\"UPDATE settings SET value='' WHERE variable='token'\")
c.execute(\"UPDATE settings SET value='false' WHERE variable IN ('remember','autologin','auto_login')\")
c.commit()
print('Done')
"
```

Then start the launcher and sign in manually. This only clears the login – your game version info is kept, so the game won't reinstall.

If something goes wrong, restore the backup:

```bash
cd ~/.local/share/com.monstersandmemories.launcher
cp launcher.db.backup launcher.db
```

### Repair keeps failing with "Assembled file hash mismatch"

If Repair fails on the same file with the exact same wrong hash every time, check your system for disk or memory problems. This can be caused by data corruption on your PC, not the download:

```bash
sudo dmesg | grep -i -E "csum failed|i/o error|corrupt" | tail -n 20
```

Errors here (e.g. `BTRFS warning ... csum failed`) mean data on your drive is getting corrupted. Back up your files and check the drive (`sudo smartctl -a /dev/nvme0n1`) and RAM (memtest86+).


### Launcher crashes with "Error 71 (Protocol error) dispatching to Wayland display"

A known WebKitGTK issue on Wayland with some GPU/driver combinations. The start script already sets `WEBKIT_DISABLE_DMABUF_RENDERER=1`, which fixes it in most cases. If you start the launcher some other way, add it yourself:

```bash
WEBKIT_DISABLE_DMABUF_RENDERER=1 ./mnm_launcher
```

In Steam, put it in the launch options:

```
WEBKIT_DISABLE_DMABUF_RENDERER=1 %command%
```

If it still crashes, try `GDK_BACKEND=x11` instead, or with NVIDIA, add `__NV_DISABLE_EXPLICIT_SYNC=1`.


### Closing the game

Quit from inside the game rather than using Steam's **Stop** button. Stop kills everything immediately, which can leave files half-written. If the game hangs, you can close just the game with:

```bash
pkill -f mnm.exe
```

## Requirements

`umu-launcher` must be installed.

- **Bazzite, Nobara, CachyOS:** usually already installed
- **Fedora, Arch, Manjaro:** install `umu-launcher` from your package manager
- **Ubuntu, Mint, Debian:** you may need to install it from the [umu-launcher GitHub page](https://github.com/Open-Wine-Components/umu-launcher)

## Tested on

- Bazzite (Fedora 44), AMD Radeon – native mode

Tried it on another distro? Open an issue and tell me whether it worked!

## Credits

Native mode (running only the extracted launcher binary) was suggested by a player in the Monsters & Memories community – thanks!

## License

MIT – feel free to use, modify and share.

---

*Not affiliated with the Monsters & Memories developers.*

*Use at your own risk. In native mode, the script runs the official launcher unmodified.
It never asks for or stores your login.*
