Monsters & Memories – Linux launcher fix
Unofficial script that fixes common problems with the Linux AppImage launcher:

Blank white launcher window (EGL_BAD_PARAMETER) – caused by bundled libwayland libraries
Play does nothing / umu-run crashes – the launcher leaks its AppImage environment into umu-run
Game install/download fails – the game installs inside the read-only AppImage
Install
curl -LO https://raw.githubusercontent.com/arild668/mnm-linux-fix/main/install-mnm-linux.sh
bash install-mnm-linux.sh ~/Downloads/MonstersAndMemories_amd64.appimage
Change ~/Downloads/... if your AppImage is somewhere else.

Then start Monsters & Memories from your app menu.

What it does
Extracts the AppImage to ~/Games/MnM
Removes the bundled libwayland-* libraries
Creates a wrapper in ~/.local/bin/umu-run that gives umu-run a clean environment
Creates a start script and an app menu entry
Updating
Download the new AppImage and run the script again. Your game files are kept.

Steam (optional)
Add ~/Games/MnM/start-mnm.sh as a non-Steam game. Keep Proton off, since the launcher is a native Linux app.

Requirements
umu-launcher must be installed. Most gaming distros (Bazzite, Nobara, CachyOS) have it. On Fedora/Arch it's in the package manager. On Ubuntu/Mint/Debian you may need to install it first.
Tested on
Bazzite (Fedora 43), AMD Radeon
Comments with your distro and whether it worked are welcome!

Not affiliated with the Monsters & Memories developers.
