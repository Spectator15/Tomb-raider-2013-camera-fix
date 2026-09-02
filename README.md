<h1 align="center">Tomb Raider 2013 Camera Fix</h1>

<p align="center">Self-contained Windows and Linux/Proton utilities that remove normal gameplay camera wobble and forced auto-centering in Tomb Raider (2013) PC.</p>

---

## What it fixes

This utility removes:

- The normal gameplay camera wobble or head-bob while controlling Lara
- Horizontal and vertical camera auto-centering, including the automatic rotation back toward the direction Lara is facing

The result is freer mouse camera control with substantially less unwanted camera movement.

> [!WARNING]
> This utility is made and tested for **Steam build `743.0`**. Steam build `743.0` is the currently supported build.

## Windows installation

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

## Linux / Proton beta

> [!IMPORTANT]
> Linux support requires the Windows version of Tomb Raider running through Steam Proton. The separate Feral native Linux port is not supported.

Linux support is currently a beta. It has passed synthetic tests on an actual Linux runner, but real Tomb Raider gameplay through Proton has not yet been confirmed.

1. In Steam, set Tomb Raider (2013) to build `743.0`.
2. Open **Properties > Compatibility** and force a Proton version. Steam should download the Windows game files.
3. Use **Verify integrity of game files**, wait for Steam to finish, and make sure the game is closed.
4. Download [`TombRaider-Camera-Fix-Linux.sh`](https://github.com/Spectator15/Tomb-raider-2013-camera-fix/releases/download/v1.1.0-beta.1/TombRaider-Camera-Fix-Linux.sh).
5. In a terminal, make the file executable and run it:

   ```bash
   chmod +x TombRaider-Camera-Fix-Linux.sh
   ./TombRaider-Camera-Fix-Linux.sh
   ```

6. Choose **Apply complete camera fix**, then start the game normally through Steam with Proton enabled.

Python 3.8 or newer is required. Protontricks is not required, and the utility does not modify Proton prefixes, install packages, add Wine DLL overrides, change Steam compatibility settings, or convert save files.

The Linux utility detects native Steam, Flatpak Steam, secondary and external Steam libraries, and Steam Deck installations in Desktop Mode. If automatic discovery cannot identify the correct installation, use its manual-path option. Manual selection still requires a valid App ID `203160` Steam manifest and every normal executable safety check.

> [!CAUTION]
> Native Linux and Windows/Proton save files are not compatible. Back up your saves before switching from the Feral native version to Proton.

Snap Steam, ChromeOS, ARM Linux, GOG, Epic, Heroic, Lutris, standalone Wine, and the Feral native executable are outside this beta's scope.

## How it works

The utility **does not distribute a modified game executable**. It works locally with the user's own `TombRaider.exe`:

1. It verifies that the executable matches the expected build and byte patterns.
2. It patches three camera-related instruction regions.
3. It verifies the prepared and final files, refusing to write if the executable or patterns are unsupported or ambiguous.

Before the first patch, it creates a verified original backup and a small verification manifest beside the game executable. Existing valid backup files are preserved, and untrusted or incomplete backups are never overwritten.

All required PowerShell is embedded inside the Windows batch file. The Linux release embeds its Python 3 standard-library engine inside one Bash file.

Both platforms use the same exact build, version, patch names, original bytes, patched bytes, and unique-match requirements. Automated parity tests fail if those definitions diverge. The Linux implementation parses `libraryfolders.vdf` and `appmanifest_203160.acf`, then treats the executable's PE identity, version, and byte signatures as the final authority. It does not treat an existing `compatdata` directory as proof that Proton is active.

## Restore

### Windows

1. Run `TombRaider-Camera-Fix.bat` again.
2. Select the same `TombRaider.exe`.
3. Choose **Restore original TombRaider.exe**.

The utility restores only from its verified `TombRaider.exe.trcamera-original.bak` and `TombRaider.exe.trcamera-original.json` sidecars, then checks that the restored executable matches the recorded original byte for byte. If the backup cannot be trusted, restoration is refused.

### Linux / Proton

1. Run `TombRaider-Camera-Fix-Linux.sh` again.
2. Select the same Steam installation.
3. Choose **Restore original executable**.

Linux uses the same verified backup filenames and schema as Windows. A valid original backup created by either platform can be checked and used by the other. The utility never creates an original backup from an already patched executable and never overwrites incomplete or untrusted sidecars.

Steam verification or a game update may restore the original executable. If status reports the supported original state afterward, run the utility and apply the complete fix again.

## Limitations

The fix removes normal gameplay camera wobble and auto-centering, but it cannot remove every camera movement in the game.

- Scripted cutscene and cinematic camera movement is unaffected.
- Certain scripted gameplay camera sequences may still take control.
- When Lara is extremely close to a wall or other geometry, the game can still reposition or constrain the camera to prevent clipping.

These are separate game systems and are not part of the normal auto-centering and wobble behavior being patched. The camera is not completely unrestricted in every situation.

---

## Development and rebuilding

The editable launchers, patching engines, interface sources, and patch catalogue live under `src/`. Contributors should change those source files rather than editing either generated root release directly.

To rebuild the ready-to-run utility from the repository root and run the disposable-fixture validation suite, use:

```powershell
.\build\Build-Release.ps1
.\build\Test-Release.ps1
```

On Linux, use:

```bash
./build/Build-LinuxRelease.sh
./build/Test-LinuxRelease.sh
```

The generated `TombRaider-Camera-Fix.bat` and `TombRaider-Camera-Fix-Linux.sh` files remain committed so normal users can download and run them directly. The Linux test command requires Python 3 and ShellCheck. Both release builders are deterministic.

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
