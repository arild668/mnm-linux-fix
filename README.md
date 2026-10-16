# Monsters & Memories – Linux launcher fix

Unofficial script that fixes common problems with the Monsters & Memories Linux AppImage launcher.

| Problem | Cause |
|---|---|
| Blank white launcher window (`EGL_BAD_PARAMETER`) | Bundled `libwayland` libraries conflict with newer systems |
| Play does nothing / umu-run crashes | The launcher leaks its AppImage environment into umu-run |
| Game download or install fails | The game installs inside the read-only AppImage |

## Install

First, download the **Linux AppImage** (`MonstersAndMemories_amd64.appimage`) from the official Monsters & Memories website. You don't need to make it executable – the script does that for you.

Open a terminal and run:

```bash
curl -LO https://raw.githubusercontent.com/arild668/mnm-linux-fix/main/install-mnm-linux.sh
bash install-mnm-linux.sh ~/Downloads/MonstersAndMemories_amd64.appimage
```

Change `~/Downloads/...` if your AppImage is somewhere else.

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
3. In **Properties → Compatibility**, make sure Proton is **off**. The launcher is a native Linux app.

## Requirements

`umu-launcher` must be installed.

- **Bazzite, Nobara, CachyOS:** usually already installed
- **Fedora, Arch, Manjaro:** install `umu-launcher` from your package manager
- **Ubuntu, Mint, Debian:** you may need to install it from the [umu-launcher GitHub page](https://github.com/Open-Wine-Components/umu-launcher)

## Tested on

- Bazzite (Fedora 43), AMD Radeon

Tried it on another distro? Open an issue and tell me whether it worked!

---

*Not affiliated with the Monsters & Memories developers.*
