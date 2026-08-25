<h1 align="center">Tomb Raider 2013 Camera Fix</h1>

<p align="center">A self-contained Windows utility that removes normal gameplay camera wobble and forced auto-centering in Tomb Raider (2013) PC.</p>

---

## What it fixes

This utility removes:

- The normal gameplay camera wobble or head-bob while controlling Lara
- Horizontal and vertical camera auto-centering, including the automatic rotation back toward the direction Lara is facing

The result is freer mouse camera control with substantially less unwanted camera movement.

> [!WARNING]
> This utility is made and tested for **Steam build `743.0`**. Steam build `743.0` is the currently supported build.

## Installation

1. In Steam, set Tomb Raider (2013) to build `743.0`.
2. After selecting build `743.0`, use Steam's **Verify integrity of game files** option so the installation is clean and matches that build.
3. Make sure Tomb Raider is closed.
4. Download and run [`TombRaider-Camera-Fix.bat`](https://github.com/Spectator15/Tomb-raider-2013-camera-fix/releases/latest/download/TombRaider-Camera-Fix.bat) from the latest release.
   - The utility searches normal Steam folders and Steam libraries for `TombRaider.exe`.
   - If it finds more than one installation, choose the correct one.
   - If it cannot find one automatically, select the executable in the file window or enter its full path.
5. Choose **Apply complete camera fix**, then type `APPLY` when prompted. Windows may request administrator permission if the game folder is protected.
6. Start the game normally through Steam.

Normal users do not need to build, combine, or edit anything. The root [`TombRaider-Camera-Fix.bat`](TombRaider-Camera-Fix.bat) is the complete ready-to-run utility.

> [!NOTE]
> Running the utility again is safe. It checks the current state and does not rewrite an executable that is already fully patched.

## How it works

The utility **does not distribute a modified game executable**. It works locally with the user's own `TombRaider.exe`:

1. It verifies that the executable matches the expected build and byte patterns.
2. It patches three camera-related instruction regions.
3. It verifies the prepared and final files, refusing to write if the executable or patterns are unsupported or ambiguous.

Before the first patch, it creates a verified original backup and a small verification manifest beside the game executable. Existing valid backup files are preserved, and untrusted or incomplete backups are never overwritten.

All required PowerShell is embedded inside the batch file.

## Restore

1. Run `TombRaider-Camera-Fix.bat` again.
2. Select the same `TombRaider.exe`.
3. Choose **Restore original TombRaider.exe**.

The utility restores only from its verified `TombRaider.exe.trcamera-original.bak` and `TombRaider.exe.trcamera-original.json` sidecars, then checks that the restored executable matches the recorded original byte for byte. If the backup cannot be trusted, restoration is refused.

## Limitations

The fix removes normal gameplay camera wobble and auto-centering, but it cannot remove every camera movement in the game.

- Scripted cutscene and cinematic camera movement is unaffected.
- Certain scripted gameplay camera sequences may still take control.
- When Lara is extremely close to a wall or other geometry, the game can still reposition or constrain the camera to prevent clipping.

These are separate game systems and are not part of the normal auto-centering and wobble behavior being patched. The camera is not completely unrestricted in every situation.

---

## Development and rebuilding

The editable launcher, patching engine, and interface sources live under `src\`. Contributors should change those source files rather than editing the generated root batch file directly.

To rebuild the ready-to-run utility from the repository root and run the disposable-fixture validation suite, use:

```powershell
.\build\Build-Release.ps1
.\build\Test-Release.ps1
```

The build combines the launcher template, `CameraFixEngine.ps1`, and `CameraFixInterface.ps1` in a deterministic order. The generated `TombRaider-Camera-Fix.bat` remains committed so normal users can download and run it directly.

---

## Attribution and disclaimer

This project was inspired by the [Disable Camera Wobble](https://www.nexusmods.com/tombraider2013/mods/87) mod on Nexus Mods. Its supplied executable was for a different game build and did not work properly for this setup, so this utility instead patches the user's own compatible executable. No files or source code were copied from that mod.

This repository does not distribute:

- `TombRaider.exe`
- `steam_api.dll`
- Modified game files
- Tomb Raider assets
- Files copied from the original Nexus archive

This is an unofficial fan-made utility. It is not affiliated with or endorsed by Crystal Dynamics, Square Enix, Eidos, Steam, Nexus Mods, or the author of the original mod. Use it at your own risk.
