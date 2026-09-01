from __future__ import annotations

import hashlib
import itertools
import json
import os
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = REPOSITORY_ROOT / "src"
sys.path.insert(0, os.fspath(SOURCE_ROOT))

import CameraFixEngineLinux as engine  # noqa: E402


def align(value: int, boundary: int) -> int:
    return (value + boundary - 1) & ~(boundary - 1)


def version_blob(version: tuple[int, int, int, int]) -> bytes:
    key = "VS_VERSION_INFO\x00".encode("utf-16le")
    prefix = struct.pack("<HHH", 0, 52, 0) + key
    prefix += b"\x00" * ((4 - len(prefix) % 4) % 4)
    major, minor, build, private = version
    fixed = struct.pack(
        "<13I",
        0xFEEF04BD,
        0x00010000,
        (major << 16) | minor,
        (build << 16) | private,
        (major << 16) | minor,
        (build << 16) | private,
        0x3F,
        0,
        0x00040004,
        1,
        0,
        0,
        0,
    )
    result = bytearray(prefix + fixed)
    struct.pack_into("<H", result, 0, len(result))
    return bytes(result)


def build_pe_fixture(
    *,
    version: tuple[int, int, int, int] = (1, 1, 743, 0),
    machine: int = 0x014C,
    optional_magic: int = 0x010B,
    subsystem: int = 2,
    states: dict[str, str] | None = None,
    omit: str | None = None,
    duplicate: str | None = None,
    conflict: str | None = None,
) -> bytes:
    states = states or {}
    blob = version_blob(version)
    resource = bytearray(88 + len(blob))
    struct.pack_into("<HH", resource, 12, 0, 1)
    struct.pack_into("<II", resource, 16, 16, 0x80000000 | 24)
    struct.pack_into("<HH", resource, 24 + 12, 0, 1)
    struct.pack_into("<II", resource, 40, 1, 0x80000000 | 48)
    struct.pack_into("<HH", resource, 48 + 12, 0, 1)
    struct.pack_into("<II", resource, 64, 1033, 72)
    struct.pack_into("<IIII", resource, 72, 0x1000 + 88, len(blob), 1200, 0)
    resource[88:] = blob
    resource.extend(b"\xCC" * 32)
    for patch in engine.CATALOGUE.patches:
        if patch.key == omit:
            resource.extend(b"\xC3" * len(patch.original))
        else:
            selected = patch.patched if states.get(patch.key) == "Patched" else patch.original
            resource.extend(selected)
            if patch.key == duplicate:
                resource.extend(b"\xCC" * 8 + selected)
            if patch.key == conflict:
                other = patch.original if selected == patch.patched else patch.patched
                resource.extend(b"\xCC" * 8 + other)
        resource.extend(b"\xCC" * 32)

    raw_size = align(len(resource), 0x200)
    headers = bytearray(0x200)
    headers[:2] = b"MZ"
    struct.pack_into("<I", headers, 0x3C, 0x80)
    headers[0x80:0x84] = b"PE\x00\x00"
    struct.pack_into("<HHIIIHH", headers, 0x84, machine, 1, 0, 0, 0, 0xE0, 0x0102)
    optional = 0x98
    struct.pack_into("<H", headers, optional, optional_magic)
    struct.pack_into("<I", headers, optional + 16, 0x1000)
    struct.pack_into("<I", headers, optional + 28, 0x00400000)
    struct.pack_into("<I", headers, optional + 32, 0x1000)
    struct.pack_into("<I", headers, optional + 36, 0x200)
    struct.pack_into("<I", headers, optional + 56, 0x2000)
    struct.pack_into("<I", headers, optional + 60, 0x200)
    struct.pack_into("<H", headers, optional + 68, subsystem)
    struct.pack_into("<I", headers, optional + 92, 16)
    struct.pack_into("<II", headers, optional + 112, 0x1000, len(resource))
    section = optional + 0xE0
    headers[section:section + 8] = b".rsrc\x00\x00\x00"
    struct.pack_into("<IIII", headers, section + 8, len(resource), 0x1000, raw_size, 0x200)
    struct.pack_into("<I", headers, section + 36, 0x40000040)
    return bytes(headers + resource + b"\x00" * (raw_size - len(resource)))


def vdf_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def write_manifest(library: Path, install_dir: str, state_flags: str = "4") -> Path:
    manifest = library / f"steamapps/appmanifest_{engine.CATALOGUE.steam_app_id}.acf"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        '"AppState"\n{\n'
        f'  "appid" "{engine.CATALOGUE.steam_app_id}"\n'
        f'  "StateFlags" "{state_flags}"\n'
        f'  "installdir" "{vdf_escape(install_dir)}"\n'
        '}\n',
        encoding="utf-8",
    )
    return manifest


def make_installation(library: Path, install_dir: str = "Tomb Raider", data: bytes | None = None, steam_type: str = "Native Steam") -> engine.Installation:
    game = library / "steamapps/common" / install_dir
    game.mkdir(parents=True, exist_ok=True)
    executable = game / engine.TARGET_FILENAME
    executable.write_bytes(data if data is not None else build_pe_fixture())
    executable.chmod(0o764)
    manifest = write_manifest(library, install_dir)
    return engine.Installation(executable.resolve(), game.resolve(), library.resolve(), manifest.resolve(), steam_type)


def write_current_library_vdf(root: Path, libraries: list[Path]) -> None:
    lines = ['"libraryfolders"', "{"]
    for index, library in enumerate(libraries):
        lines.extend([f'  "{index}"', "  {", f'    "path" "{vdf_escape(os.fspath(library))}"', "  }"])
    lines.append("}")
    (root / "steamapps").mkdir(parents=True, exist_ok=True)
    (root / "steamapps/libraryfolders.vdf").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_old_library_vdf(root: Path, libraries: list[Path]) -> None:
    lines = ['"LibraryFolders"', "{"]
    for index, library in enumerate(libraries):
        lines.append(f'  "{index}" "{vdf_escape(os.fspath(library))}"')
    lines.append("}")
    (root / "steamapps").mkdir(parents=True, exist_ok=True)
    (root / "steamapps/libraryfolders.vdf").write_text("\n".join(lines) + "\n", encoding="utf-8")


class LinuxCameraFixTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="TombRaiderCameraFixLinuxTests-")
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def native_root(self) -> Path:
        root = self.root / "home/.local/share/Steam"
        (root / "steamapps").mkdir(parents=True, exist_ok=True)
        return root

    def flatpak_root(self) -> Path:
        root = self.root / "home/.var/app/com.valvesoftware.Steam/data/Steam"
        (root / "steamapps").mkdir(parents=True, exist_ok=True)
        return root

    def test_01_patch_catalogue_matches_windows_definitions_exactly(self) -> None:
        source = (SOURCE_ROOT / "CameraFixEngine.ps1").read_text(encoding="utf-8")
        pattern = re.compile(
            r"Key = '([^']+)'\s+Name = '([^']+)'\s+Original = \[byte\[\]\]\(ConvertFrom-CameraFixHex '([^']+)'\)\s+Patched = \[byte\[\]\]\(ConvertFrom-CameraFixHex '([^']+)'\)",
            re.MULTILINE,
        )
        windows = pattern.findall(source)
        self.assertEqual(len(windows), len(engine.CATALOGUE.patches))
        for windows_item, linux in zip(windows, engine.CATALOGUE.patches):
            self.assertEqual(windows_item[0], linux.key)
            self.assertEqual(windows_item[1], linux.name)
            self.assertEqual(bytes.fromhex(windows_item[2]), linux.original)
            self.assertEqual(bytes.fromhex(windows_item[3]), linux.patched)
            self.assertEqual(linux.original, linux.verification_original)
            self.assertEqual(linux.patched, linux.verification_patched)
            self.assertEqual(linux.expected_count, 1)
        self.assertEqual(engine.CATALOGUE.file_version, "1.1.743.0")
        self.assertIn("$versionInfo.FileBuildPart -eq 743", source)
        self.assertIn("$originalOffsets.Count -eq 1", source)
        self.assertIn("$patchedOffsets.Count -eq 1", source)

    def test_02_native_steam_discovery_uses_appmanifest_install_dir(self) -> None:
        root = self.native_root()
        write_current_library_vdf(root, [root])
        expected = make_installation(root, "A Different Tomb Raider Folder")
        found, diagnostics = engine.discover_installations(self.root / "home")
        self.assertEqual(diagnostics, [])
        self.assertEqual([item.executable for item in found], [expected.executable])
        self.assertEqual(found[0].steam_type, "Native Steam")

    def test_03_flatpak_steam_discovery(self) -> None:
        root = self.flatpak_root()
        write_current_library_vdf(root, [root])
        expected = make_installation(root, steam_type="Flatpak Steam")
        found, _ = engine.discover_installations(self.root / "home")
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].executable, expected.executable)
        self.assertEqual(found[0].steam_type, "Flatpak Steam")

    def test_04_secondary_library_current_vdf_layout(self) -> None:
        root = self.native_root()
        secondary = self.root / "External Library"
        (secondary / "steamapps").mkdir(parents=True)
        write_current_library_vdf(root, [root, secondary])
        expected = make_installation(secondary)
        found, _ = engine.discover_installations(self.root / "home")
        self.assertEqual([item.executable for item in found], [expected.executable])

    def test_05_secondary_library_old_vdf_layout_and_escaped_path(self) -> None:
        root = self.native_root()
        secondary = self.root / "External Old Library"
        (secondary / "steamapps").mkdir(parents=True)
        write_old_library_vdf(root, [secondary])
        expected = make_installation(secondary)
        found, _ = engine.discover_installations(self.root / "home")
        self.assertEqual([item.executable for item in found], [expected.executable])
        parsed = engine.parse_vdf('"root" { "value" "quoted \\"path\\"" }')
        root_node = engine._pairs(parsed, "root")[0]
        self.assertEqual(engine._first_string(root_node, "value"), 'quoted "path"')

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks are unavailable")
    def test_06_symlinked_duplicate_roots_and_libraries_are_deduplicated(self) -> None:
        root = self.native_root()
        write_current_library_vdf(root, [root])
        expected = make_installation(root)
        steam_link = self.root / "home/.steam/steam"
        steam_link.parent.mkdir(parents=True)
        try:
            steam_link.symlink_to(root, target_is_directory=True)
        except OSError as exc:
            self.skipTest(f"symlink creation is unavailable: {exc}")
        found, _ = engine.discover_installations(self.root / "home")
        self.assertEqual([item.executable for item in found], [expected.executable])

    def test_07_multiple_real_installations_remain_separate(self) -> None:
        root = self.native_root()
        second = self.root / "SecondLibrary"
        (second / "steamapps").mkdir(parents=True)
        write_current_library_vdf(root, [root, second])
        first_install = make_installation(root)
        second_install = make_installation(second)
        found, _ = engine.discover_installations(self.root / "home")
        self.assertEqual({item.executable for item in found}, {first_install.executable, second_install.executable})

    def test_08_paths_with_spaces_and_non_ascii_characters(self) -> None:
        root = self.native_root()
        secondary = self.root / "Bibliothèque externe 日本語"
        (secondary / "steamapps").mkdir(parents=True)
        write_current_library_vdf(root, [secondary])
        expected = make_installation(secondary, "Tomb Raider Édition")
        found, _ = engine.discover_installations(self.root / "home")
        self.assertEqual([item.executable for item in found], [expected.executable])

    def test_09_malformed_vdf_is_rejected_without_guessing(self) -> None:
        root = self.native_root()
        (root / "steamapps/libraryfolders.vdf").write_text('"libraryfolders" { "0" { "path" "unterminated }', encoding="utf-8")
        found, diagnostics = engine.discover_installations(self.root / "home")
        self.assertEqual(found, [])
        self.assertTrue(any("malformed" in item for item in diagnostics))

    def test_10_vdf_path_traversal_is_rejected(self) -> None:
        root = self.native_root()
        unsafe = self.root / "Library/../Escape"
        write_current_library_vdf(root, [unsafe])
        found, diagnostics = engine.discover_installations(self.root / "home")
        self.assertEqual(found, [])
        self.assertTrue(any("traversal-free" in item for item in diagnostics))

    def test_11_manifest_traversal_is_rejected(self) -> None:
        root = self.native_root()
        write_current_library_vdf(root, [root])
        (root / "steamapps/common").mkdir(parents=True)
        write_manifest(root, "../Outside")
        found, diagnostics = engine.discover_installations(self.root / "home")
        self.assertEqual(found, [])
        self.assertTrue(any("invalid App ID" in item for item in diagnostics))

    def test_12_manual_selection_requires_matching_steam_manifest(self) -> None:
        root = self.native_root()
        installation = make_installation(root)
        resolved_file = engine.resolve_manual_installation(os.fspath(installation.executable))
        resolved_directory = engine.resolve_manual_installation(os.fspath(installation.game_directory))
        self.assertEqual(resolved_file.executable, installation.executable)
        self.assertEqual(resolved_directory.executable, installation.executable)
        outside = self.root / engine.TARGET_FILENAME
        outside.write_bytes(build_pe_fixture())
        with self.assertRaisesRegex(engine.CameraFixError, "Steam library"):
            engine.resolve_manual_installation(os.fspath(outside))

    def test_13_feral_native_installation_is_rejected_with_required_guidance(self) -> None:
        root = self.native_root()
        write_current_library_vdf(root, [root])
        game = root / "steamapps/common/Tomb Raider"
        game.mkdir(parents=True)
        (game / "TombRaider.sh").write_text("#!/bin/sh\n", encoding="utf-8")
        (game / "TombRaider").write_bytes(b"\x7fELF" + b"\x00" * 128)
        write_manifest(root, "Tomb Raider")
        found, diagnostics = engine.discover_installations(self.root / "home")
        self.assertEqual(found, [])
        self.assertIn(engine.FERAL_MESSAGE, diagnostics)
        with self.assertRaisesRegex(engine.CameraFixError, "Feral native Linux port"):
            engine.resolve_manual_installation(os.fspath(game))

    def test_14_incomplete_installation_is_distinguished(self) -> None:
        root = self.native_root()
        write_current_library_vdf(root, [root])
        game = root / "steamapps/common/Tomb Raider"
        game.mkdir(parents=True)
        write_manifest(root, "Tomb Raider")
        found, diagnostics = engine.discover_installations(self.root / "home")
        self.assertEqual(found, [])
        self.assertTrue(any("incomplete" in item for item in diagnostics))

    def test_15_native_elf_named_as_target_is_rejected(self) -> None:
        installation = make_installation(self.native_root(), data=b"\x7fELF" + b"\x00" * 300)
        with self.assertRaisesRegex(engine.CameraFixError, "native Linux ELF"):
            engine.inspect_executable(installation.executable)

    def test_16_supported_pe_identity_and_version(self) -> None:
        path = self.root / engine.TARGET_FILENAME
        path.write_bytes(build_pe_fixture())
        inspection = engine.inspect_executable(path)
        self.assertEqual(inspection.state, "Unpatched")
        self.assertEqual(inspection.pe.file_version, "1.1.743.0")
        self.assertTrue(inspection.pe.is_expected_architecture)
        self.assertTrue(inspection.pe.is_gui_executable)

    def test_17_wrong_version_architecture_subsystem_and_truncation(self) -> None:
        cases = (
            (build_pe_fixture(version=(1, 1, 742, 0)), "Unsupported"),
            (build_pe_fixture(machine=0x8664), "Unsupported"),
            (build_pe_fixture(subsystem=3), "Unsupported"),
        )
        for index, (data, expected) in enumerate(cases):
            path = self.root / f"case{index}" / engine.TARGET_FILENAME
            path.parent.mkdir()
            path.write_bytes(data)
            self.assertEqual(engine.inspect_executable(path).state, expected)
        truncated = self.root / "truncated" / engine.TARGET_FILENAME
        truncated.parent.mkdir()
        truncated.write_bytes(b"MZ" + b"\x00" * 10)
        with self.assertRaisesRegex(engine.CameraFixError, "too small"):
            engine.inspect_executable(truncated)

    def test_18_every_understood_patch_combination_is_classified(self) -> None:
        keys = [patch.key for patch in engine.CATALOGUE.patches]
        for mask in range(8):
            states = {key: "Patched" for index, key in enumerate(keys) if mask & (1 << index)}
            inspection = engine.inspect_bytes(build_pe_fixture(states=states), Path(engine.TARGET_FILENAME))
            expected = "Unpatched" if mask == 0 else "CompletelyPatched" if mask == 7 else "PartiallyPatched"
            self.assertEqual(inspection.state, expected, f"mask {mask}")

    def test_19_missing_duplicate_conflicting_and_unknown_patterns_are_rejected(self) -> None:
        for mode, kwargs, classification in (
            ("missing", {"omit": "Wobble"}, "Missing"),
            ("duplicate", {"duplicate": "Wobble"}, "Duplicated"),
            ("conflict", {"conflict": "Wobble"}, "Conflicting"),
        ):
            inspection = engine.inspect_bytes(build_pe_fixture(**kwargs), Path(engine.TARGET_FILENAME))
            self.assertEqual(inspection.state, "Unsupported", mode)
            wobble = next(item for item in inspection.patterns if item.key == "Wobble")
            self.assertEqual(wobble.classification, classification)
        unknown = bytearray(build_pe_fixture())
        offset = unknown.find(engine.CATALOGUE.patches[0].original)
        unknown[offset + 1] ^= 0xFF
        inspection = engine.inspect_bytes(bytes(unknown), Path(engine.TARGET_FILENAME))
        self.assertEqual(inspection.state, "Unsupported")

    def test_20_apply_changes_only_expected_regions_and_reruns_safely(self) -> None:
        installation = make_installation(self.native_root())
        original = installation.executable.read_bytes()
        original_mode = stat.S_IMODE(installation.executable.stat().st_mode)
        before = installation.executable.stat().st_mtime_ns
        result = engine.apply_fix(installation)
        self.assertTrue(result["changed"])
        patched = installation.executable.read_bytes()
        original_inspection = engine.inspect_bytes(original, installation.executable)
        regions = engine._regions_from_original(original_inspection)
        self.assertEqual(engine.outside_region_sha256(original, regions), engine.outside_region_sha256(patched, regions))
        self.assertEqual(len(original), len(patched))
        self.assertEqual(stat.S_IMODE(installation.executable.stat().st_mode), original_mode)
        patched_mtime = installation.executable.stat().st_mtime_ns
        self.assertNotEqual(before, patched_mtime)
        second = engine.apply_fix(installation)
        self.assertFalse(second["changed"])
        self.assertEqual(installation.executable.stat().st_mtime_ns, patched_mtime)

    def test_21_backup_manifest_is_windows_compatible_and_preserved(self) -> None:
        installation = make_installation(self.native_root())
        engine.apply_fix(installation)
        backup = engine.validate_backup(installation.executable)
        self.assertTrue(backup.valid, backup.reason)
        assert backup.manifest is not None
        for field in ("SchemaVersion", "Tool", "OriginalFilename", "FileVersion", "Size", "SHA256", "StoredPEChecksum", "CreatedUtc"):
            self.assertIn(field, backup.manifest)
        backup_hash = engine.sha256_file(backup.backup_path)
        manifest_text = backup.manifest_path.read_text(encoding="utf-8")
        engine.restore_original(installation)
        engine.apply_fix(installation)
        self.assertEqual(engine.sha256_file(backup.backup_path), backup_hash)
        self.assertEqual(backup.manifest_path.read_text(encoding="utf-8"), manifest_text)

    def test_22_restore_verifies_original_and_is_idempotent(self) -> None:
        installation = make_installation(self.native_root())
        original_hash = engine.sha256_file(installation.executable)
        engine.apply_fix(installation)
        restored = engine.restore_original(installation)
        self.assertTrue(restored["changed"])
        self.assertEqual(engine.sha256_file(installation.executable), original_hash)
        second = engine.restore_original(installation)
        self.assertFalse(second["changed"])

    def test_23_incomplete_invalid_and_verified_backups_are_never_overwritten(self) -> None:
        installation = make_installation(self.native_root())
        backup_path, manifest_path = engine.sidecar_paths(installation.executable)
        backup_path.write_bytes(b"do not overwrite")
        before = backup_path.read_bytes()
        with self.assertRaisesRegex(engine.CameraFixError, "not trustworthy"):
            engine.create_original_backup(installation.executable)
        self.assertEqual(backup_path.read_bytes(), before)
        self.assertFalse(manifest_path.exists())

    def test_24_partially_patched_requires_verified_original_backup(self) -> None:
        installation = make_installation(self.native_root(), data=build_pe_fixture(states={"Wobble": "Patched"}))
        with self.assertRaisesRegex(engine.CameraFixError, "partly patched"):
            engine.apply_fix(installation)
        self.assertEqual(engine.inspect_executable(installation.executable).state, "PartiallyPatched")

    def test_25_verified_backup_can_complete_every_partial_combination(self) -> None:
        keys = [patch.key for patch in engine.CATALOGUE.patches]
        for mask in range(1, 7):
            library = self.root / f"Library{mask}"
            installation = make_installation(library)
            engine.create_original_backup(installation.executable)
            states = {key: "Patched" for index, key in enumerate(keys) if mask & (1 << index)}
            installation.executable.write_bytes(build_pe_fixture(states=states))
            engine.apply_fix(installation)
            self.assertEqual(engine.inspect_executable(installation.executable).state, "CompletelyPatched")

    def test_26_windows_created_backup_and_windows_applied_patch_are_recognised(self) -> None:
        installation = make_installation(self.native_root())
        original = installation.executable.read_bytes()
        original_inspection = engine.inspect_executable(installation.executable)
        backup_path, manifest_path = engine.sidecar_paths(installation.executable)
        backup_path.write_bytes(original)
        windows_manifest = {
            "SchemaVersion": 1,
            "Tool": "Tomb Raider Complete Camera Fix",
            "OriginalFilename": "TombRaider.exe",
            "FileVersion": "1.1.743.0",
            "Size": len(original),
            "SHA256": original_inspection.sha256,
            "StoredPEChecksum": f"0x{original_inspection.pe.stored_checksum:08X}",
            "CreatedUtc": "2026-01-01T00:00:00.0000000Z",
        }
        manifest_path.write_text(json.dumps(windows_manifest), encoding="utf-8")
        prepared, _, _ = engine.prepare_complete_patch(original_inspection)
        installation.executable.write_bytes(prepared)
        self.assertTrue(engine.validate_backup(installation.executable).valid)
        self.assertEqual(engine.inspect_executable(installation.executable).state, "CompletelyPatched")
        restored = engine.restore_original(installation)
        self.assertTrue(restored["changed"])
        self.assertEqual(installation.executable.read_bytes(), original)

    def test_27_already_patched_without_backup_is_safe_but_cannot_restore(self) -> None:
        states = {patch.key: "Patched" for patch in engine.CATALOGUE.patches}
        installation = make_installation(self.native_root(), data=build_pe_fixture(states=states))
        before = engine.sha256_file(installation.executable)
        result = engine.apply_fix(installation)
        self.assertFalse(result["changed"])
        self.assertEqual(engine.sha256_file(installation.executable), before)
        with self.assertRaisesRegex(engine.CameraFixError, "cannot be trusted"):
            engine.restore_original(installation)

    def test_28_stale_backup_cannot_restore_over_an_unsupported_update(self) -> None:
        installation = make_installation(self.native_root())
        engine.apply_fix(installation)
        installation.executable.write_bytes(build_pe_fixture(version=(1, 1, 744, 0)))
        current_hash = engine.sha256_file(installation.executable)
        with self.assertRaisesRegex(engine.CameraFixError, "unsupported"):
            engine.restore_original(installation)
        self.assertEqual(engine.sha256_file(installation.executable), current_hash)

    def test_29_apply_rollback_after_replace_and_final_verification_failure(self) -> None:
        for failure_point in ("after_replace", "after_final_verification"):
            installation = make_installation(self.root / failure_point)
            original_hash = engine.sha256_file(installation.executable)
            with self.assertRaisesRegex(engine.CameraFixError, "Simulated failure"):
                engine.apply_fix(installation, failure_point)
            self.assertEqual(engine.sha256_file(installation.executable), original_hash)
            self.assertEqual(engine.inspect_executable(installation.executable).state, "Unpatched")

    def test_30_restore_rollback_after_replace_and_final_verification_failure(self) -> None:
        for failure_point in ("after_replace", "after_final_verification"):
            installation = make_installation(self.root / ("restore-" + failure_point))
            engine.apply_fix(installation)
            patched_hash = engine.sha256_file(installation.executable)
            with self.assertRaisesRegex(engine.CameraFixError, "Simulated failure"):
                engine.restore_original(installation, failure_point)
            self.assertEqual(engine.sha256_file(installation.executable), patched_hash)
            self.assertEqual(engine.inspect_executable(installation.executable).state, "CompletelyPatched")

    def test_31_failures_before_replacement_leave_no_tool_temporaries(self) -> None:
        for failure_point in ("after_backup", "after_temp_write", "before_replace"):
            installation = make_installation(self.root / failure_point)
            original_hash = engine.sha256_file(installation.executable)
            with self.assertRaisesRegex(engine.CameraFixError, "Simulated failure"):
                engine.apply_fix(installation, failure_point)
            self.assertEqual(engine.sha256_file(installation.executable), original_hash)
            leftovers = [path for path in installation.game_directory.iterdir() if path.name.startswith(".TombRaiderCameraFix-")]
            self.assertEqual(leftovers, [])

    def test_32_running_game_detection_is_app_specific(self) -> None:
        installation = make_installation(self.native_root())
        proc = self.root / "proc"
        matching = proc / "100"
        matching.mkdir(parents=True)
        (matching / "cmdline").write_bytes(b"wine64-preloader\x00Z:\\games\\TombRaider.exe\x00")
        (matching / "environ").write_bytes(b"STEAM_COMPAT_APP_ID=203160\x00")
        unrelated = proc / "101"
        unrelated.mkdir()
        (unrelated / "cmdline").write_bytes(b"wine\x00OtherGame.exe\x00")
        (unrelated / "environ").write_bytes(b"STEAM_COMPAT_APP_ID=999\x00")
        self.assertTrue(engine.game_running(installation.executable, proc))
        (matching / "environ").write_bytes(b"STEAM_COMPAT_APP_ID=999\x00")
        self.assertFalse(engine.game_running(installation.executable, proc))

    def test_33_steam_update_directories_block_changes(self) -> None:
        installation = make_installation(self.native_root())
        update = installation.library / f"steamapps/downloading/{engine.CATALOGUE.steam_app_id}"
        update.mkdir(parents=True)
        before = engine.sha256_file(installation.executable)
        with self.assertRaisesRegex(engine.CameraFixError, "downloading or updating"):
            engine.apply_fix(installation)
        self.assertEqual(engine.sha256_file(installation.executable), before)

    def test_34_live_executable_or_manifest_change_aborts(self) -> None:
        installation = make_installation(self.native_root())
        executable_snapshot, manifest_snapshot = engine.assert_operation_safe(installation)
        with installation.executable.open("ab") as stream:
            stream.write(b"changed")
        with self.assertRaisesRegex(engine.CameraFixError, "changed during preparation"):
            engine._recheck_operation_safe(installation, executable_snapshot, manifest_snapshot)

        installation = make_installation(self.root / "manifest-change")
        executable_snapshot, manifest_snapshot = engine.assert_operation_safe(installation)
        time.sleep(0.002)
        installation.manifest.write_text(installation.manifest.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        with self.assertRaisesRegex(engine.CameraFixError, "app manifest"):
            engine._recheck_operation_safe(installation, executable_snapshot, manifest_snapshot)

    @unittest.skipIf(sys.platform != "linux", "Linux permission behavior is tested on the Ubuntu runner")
    def test_35_read_only_game_directory_fails_without_sudo(self) -> None:
        installation = make_installation(self.native_root())
        installation.game_directory.chmod(0o555)
        try:
            with self.assertRaises((engine.CameraFixError, PermissionError, OSError)):
                engine.apply_fix(installation)
        finally:
            installation.game_directory.chmod(0o755)

    def test_36_root_and_non_x86_64_runtime_are_rejected(self) -> None:
        with mock.patch.object(engine.os, "geteuid", return_value=0, create=True), mock.patch.object(engine.sys, "platform", "linux"), mock.patch.object(engine.platform, "machine", return_value="x86_64"):
            with self.assertRaisesRegex(engine.CameraFixError, "root"):
                engine.ensure_linux_runtime()
        with mock.patch.object(engine.os, "geteuid", return_value=1000, create=True), mock.patch.object(engine.sys, "platform", "linux"), mock.patch.object(engine.platform, "machine", return_value="aarch64"):
            with self.assertRaisesRegex(engine.CameraFixError, "x86_64"):
                engine.ensure_linux_runtime()

    def test_37_status_does_not_claim_compatdata_proves_proton(self) -> None:
        installation = make_installation(self.native_root())
        (installation.library / f"steamapps/compatdata/{engine.CATALOGUE.steam_app_id}/pfx").mkdir(parents=True)
        output = engine.format_status(installation)
        self.assertIn("does not change or conclusively detect Steam's compatibility selection", output)
        self.assertIn("Launch the game through Steam with Proton enabled", output)

    def test_38_cli_noninteractive_status_and_safety_paths(self) -> None:
        installation = make_installation(self.native_root())
        with mock.patch.object(engine, "ensure_linux_runtime"):
            with mock.patch("builtins.print") as printer:
                self.assertEqual(engine.main(["status", "--path", os.fspath(installation.executable)]), 0)
                self.assertTrue(printer.called)
            update = installation.library / f"steamapps/temp/{engine.CATALOGUE.steam_app_id}"
            update.mkdir(parents=True)
            self.assertEqual(engine.main(["apply", "--path", os.fspath(installation.executable)]), 1)

    def test_39_null_byte_and_newline_path_tricks_are_rejected(self) -> None:
        for value in ("bad\x00path", "bad\npath"):
            with self.assertRaisesRegex(engine.CameraFixError, "control characters"):
                engine.resolve_manual_installation(value)

    def test_40_wrong_same_named_pe_is_rejected(self) -> None:
        installation = make_installation(self.native_root(), data=build_pe_fixture(version=(9, 9, 9, 9), omit="Vertical"))
        inspection = engine.inspect_executable(installation.executable)
        self.assertEqual(inspection.state, "Unsupported")
        with self.assertRaisesRegex(engine.CameraFixError, "unsupported"):
            engine.apply_fix(installation)

    def test_41_catalogue_never_uses_fixed_offsets(self) -> None:
        source = (SOURCE_ROOT / "CameraFixEngineLinux.py").read_text(encoding="utf-8")
        self.assertNotIn("PATCH_OFFSET", source)
        shifted = b"\xCC" * 257 + build_pe_fixture()
        # A prefixed blob is no longer a valid PE, but pattern discovery itself
        # must still find shifted signatures instead of relying on offsets.
        states = engine.analyse_patterns(shifted)
        self.assertTrue(all(item.classification == "Unpatched" for item in states))

    def test_42_backup_refuses_unrelated_changes_outside_regions(self) -> None:
        installation = make_installation(self.native_root())
        engine.apply_fix(installation)
        data = bytearray(installation.executable.read_bytes())
        data[-1] ^= 0x01
        installation.executable.write_bytes(data)
        with self.assertRaisesRegex(engine.CameraFixError, "outside"):
            engine.restore_original(installation)

    def test_43_patch_catalogue_json_is_machine_readable_and_complete(self) -> None:
        catalogue = json.loads((SOURCE_ROOT / "CameraFixPatches.json").read_text(encoding="utf-8"))
        self.assertEqual(catalogue["steam_app_id"], 203160)
        self.assertEqual(catalogue["steam_build"], "743.0")
        self.assertEqual(catalogue["file_version"], "1.1.743.0")
        self.assertEqual(catalogue["complete_state_requires"], [patch.key for patch in engine.CATALOGUE.patches])

    @unittest.skipUnless(sys.platform == "linux", "generated Linux release runs on the Ubuntu runner")
    def test_44_generated_release_noninteractive_status(self) -> None:
        release = REPOSITORY_ROOT / "TombRaider-Camera-Fix-Linux.sh"
        installation = make_installation(self.native_root())
        result = subprocess.run(
            [os.fspath(release), "--status", "--game-path", os.fspath(installation.executable)],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Current state:     Unpatched", result.stdout)


if __name__ == "__main__":
    unittest.main()
