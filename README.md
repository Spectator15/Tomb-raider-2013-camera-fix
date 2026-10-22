<h1 align="center">Tomb Raider 2013 Camera Fix</h1>

<p align="center">A one-file patcher that removes camera wobble and forced auto-centering in Tomb Raider (2013) on PC.</p>

<p align="center">
  <a href="https://github.com/Spectator15/Tomb-raider-2013-camera-fix/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/Spectator15/Tomb-raider-2013-camera-fix?label=release"></a>
  <a href="https://github.com/Spectator15/Tomb-raider-2013-camera-fix/releases"><img alt="Linux beta" src="https://img.shields.io/github/v/release/Spectator15/Tomb-raider-2013-camera-fix?include_prereleases&label=linux%20beta&color=orange"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20(Proton)-blue">
  <img alt="Steam build" src="https://img.shields.io/badge/Steam%20build-743.0-lightgrey">
</p>

## Quick start

> [!WARNING]
> Only Steam build **`743.0`** is supported. Set it in Steam, then run **Verify integrity of game files** before patching. Close the game first.

**Windows**

1. Download [`TombRaider-Camera-Fix.bat`](https://github.com/Spectator15/Tomb-raider-2013-camera-fix/releases/latest/download/TombRaider-Camera-Fix.bat) and run it.
2. Choose **Apply complete camera fix** and type `APPLY`.
3. Launch the game through Steam as normal.

**Linux / Steam Deck (Proton, beta)**

Force a Proton version in **Properties → Compatibility** first, then verify files.

```bash
chmod +x TombRaider-Camera-Fix-Linux.sh
./TombRaider-Camera-Fix-Linux.sh
```

Get the script from the [latest beta release](https://github.com/Spectator15/Tomb-raider-2013-camera-fix/releases/download/v1.1.0-beta.2/TombRaider-Camera-Fix-Linux.sh). Needs Python 3.8+.

To undo, run the tool again and choose **Restore original**.

## Why this exists

The camera in Tomb Raider (2013) keeps bobbing and pulling itself back behind Lara, which gets tiring fast with a mouse. The [Disable Camera Wobble](https://www.nexusmods.com/tombraider2013/mods/87) mod fixed this, but it shipped an executable for a different build, and it didn't work for my setup.

So I made a tool that patches *your own* game file, checks it carefully first, and keeps a backup so you can always go back.

## Patches

| Patch | What it does | Credit |
| --- | --- | --- |
| **Wobble** | Removes the gameplay camera head-bob | This project, idea from [Disable Camera Wobble](https://www.nexusmods.com/tombraider2013/mods/87) |
| **Horizontal** | Stops the camera swinging back left/right toward Lara's facing | This project |
| **Vertical** | Stops the camera drifting back up/down to center | This project |

All three are applied together as the "complete camera fix".

## What it does

- Finds your Steam install automatically, or lets you pick `TombRaider.exe`
- Checks the exact build and bytes before changing anything
- Makes a verified backup before the first patch
- Is safe to run again, and skips a game that's already patched
- Restores the original exactly, byte for byte
- Ships no game files and no modified `.exe`

<details>
<summary><b>Safety checks and backups</b></summary>

- The patcher refuses to write if the executable, its version (`1.1.743.0`), or any byte pattern is unsupported, missing, or matches more than once.
- It checks both the prepared file and the final file after writing.
- Backups sit next to the game: `TombRaider.exe.trcamera-original.bak` and `TombRaider.exe.trcamera-original.json`.
- It never makes a backup from an already-patched file, and never overwrites a backup that is incomplete or untrusted. If the backup can't be trusted, restore is refused.
- Windows and Linux use the same backup format, so a backup made on one works on the other.
- Windows may ask for admin rights if the game folder is protected.
- A Steam update or file verification may undo the patch. Check status, then apply again.

</details>

<details>
<summary><b>Linux / Proton details</b></summary>

- This needs the **Windows** version running through Proton. The Feral native Linux port is not supported.
- It detects native Steam, Flatpak Steam, extra and external Steam libraries, and Steam Deck in Desktop Mode. There is also a manual-path option, which still needs a valid App ID `203160` manifest.
- It doesn't touch Proton prefixes, install packages, add Wine DLL overrides, change Steam settings, or convert saves. Protontricks is not needed.
- **Not supported:** Snap Steam, ChromeOS, ARM Linux, GOG, Epic, Heroic, Lutris, standalone Wine.
- **Testing status:** passes automated tests on Ubuntu CI and Ubuntu under WSL 2. Real gameplay through Proton is not confirmed yet.

> [!CAUTION]
> Native Linux saves and Windows/Proton saves are not compatible. Back up your saves before switching from the Feral version.

</details>

<details>
<summary><b>Limitations</b></summary>

The fix covers normal gameplay wobble and auto-centering. Other camera systems are separate and still work as usual:

- Cutscenes and cinematic cameras
- Some scripted gameplay camera sequences
- Collision correction when Lara is right up against a wall

</details>

## Development

Source lives in `src/` (launchers, patch engines, interfaces, and `CameraFixPatches.json`). Edit those, not the generated files in the root.

**Windows (PowerShell)**

```powershell
.\build\Build-Release.ps1
.\build\Test-Release.ps1
```

**Linux** (needs Python 3 and ShellCheck)

```bash
./build/Build-LinuxRelease.sh
./build/Test-LinuxRelease.sh
```

Builds are deterministic. The generated `.bat` and `.sh` are committed so users can download them directly. Tests fail if the Windows and Linux patch definitions ever drift apart.

## Disclaimer

This is an unofficial fan-made tool. It is not affiliated with Crystal Dynamics, Square Enix, Eidos, Valve, Nexus Mods, or the original mod's author. No files or code were copied from the Nexus mod. This repo does not distribute `TombRaider.exe`, `steam_api.dll`, modified game files, or game assets. Use at your own risk.
