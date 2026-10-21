# Monsters & Memories – Linux launcher fix

Unofficial script that fixes common problems with the Monsters & Memories Linux AppImage launcher.

| Problem | Cause |
|---|---|
| Blank white launcher window (`EGL_BAD_PARAMETER`) | Bundled `libwayland` libraries conflict with newer systems |
| Play does nothing / umu-run crashes | The launcher leaks its AppImage environment into umu-run |
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

1. Extracts the AppImage to `~/Games/MnM`
2. Removes the bundled `libwayland-*` libraries
3. Creates a wrapper at `~/.local/bin/umu-run` that gives umu-run a clean environment
4. Creates a start script and an app menu entry

## Updating the launcher

Download the new AppImage and run the script again. Your game files are kept.

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
  mv ~/Games/MnM/squashfs-root/usr/bin/mnm ~/Games/MnM/mnm-old
  ```

  When everything works, you can delete `~/Games/MnM/mnm-old`.

To read the game's log:

```bash
find ~/.local/share/mnm -name "Player.log" -exec tail -n 40 {} \;
```

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

- Bazzite (Fedora 44), AMD Radeon

Tried it on another distro? Open an issue and tell me whether it worked!

---

*Not affiliated with the Monsters & Memories developers.*
