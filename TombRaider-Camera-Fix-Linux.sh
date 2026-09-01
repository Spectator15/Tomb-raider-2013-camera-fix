#!/usr/bin/env bash
# GENERATED FILE: contributors should edit the Linux sources under src/.
# Rebuild the ready-to-run script with build/Build-LinuxRelease.sh.
# Tomb Raider Complete Camera Fix - Linux/Proton launcher and interface
# Generated releases embed CameraFixEngineLinux.py below this launcher.

set -u

readonly TRCF_PYTHON_MARKER='#__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON__'
readonly TRCF_PYTHON_END='__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON_END__'
declare -a TRCF_TEMP_FILES=()
TRCF_ENGINE=''
TRCF_SELECTED_PATH=''
TRCF_SELECTED_TYPE=''
TRCF_ACTION='menu'
TRCF_GAME_PATH=''
TRCF_CONFIRMED=0

if [[ -t 1 && -z ${NO_COLOR+x} ]]; then
    readonly TRCF_CYAN=$'\033[36m'
    readonly TRCF_GREEN=$'\033[32m'
    readonly TRCF_YELLOW=$'\033[33m'
    readonly TRCF_RED=$'\033[31m'
    readonly TRCF_RESET=$'\033[0m'
else
    readonly TRCF_CYAN=''
    readonly TRCF_GREEN=''
    readonly TRCF_YELLOW=''
    readonly TRCF_RED=''
    readonly TRCF_RESET=''
fi

trcf_info() {
    printf '%s%s%s\n' "$TRCF_CYAN" "$*" "$TRCF_RESET"
}

trcf_success() {
    printf '%s%s%s\n' "$TRCF_GREEN" "$*" "$TRCF_RESET"
}

trcf_warning() {
    printf '%s%s%s\n' "$TRCF_YELLOW" "$*" "$TRCF_RESET" >&2
}

trcf_error() {
    printf '%s%s%s\n' "$TRCF_RED" "$*" "$TRCF_RESET" >&2
}

trcf_heading() {
    printf '\n%sTomb Raider Complete Camera Fix%s\n' "$TRCF_CYAN" "$TRCF_RESET"
    printf 'Linux/Proton beta, Steam build 743.0 only\n\n'
}

trcf_usage() {
    cat <<'EOF'
Usage:
  TombRaider-Camera-Fix-Linux.sh [--status | --apply | --restore]
                                  [--game-path PATH] [--yes]
  TombRaider-Camera-Fix-Linux.sh --help

Options:
  --status          Show executable, patch, and backup diagnostics.
  --apply           Apply the complete three-part camera fix.
  --restore         Restore the verified original executable.
  --game-path PATH  Select TombRaider.exe or its Steam game directory.
  --yes             Confirm --apply or --restore without an interactive prompt.
  --help            Show this help.

This beta supports only the Windows Steam version running through Proton.
The separate Feral native Linux port is not supported.
EOF
}

# Invoked indirectly by the EXIT trap below.
# shellcheck disable=SC2317,SC2329
trcf_cleanup() {
    local temporary
    for temporary in "${TRCF_TEMP_FILES[@]}"; do
        if [[ -n $temporary && -f $temporary ]]; then
            rm -f -- "$temporary"
        fi
    done
}

trcf_new_temp() {
    local temporary_root=${TMPDIR:-/tmp}
    if ! TRCF_TEMP_RESULT=$(mktemp "$temporary_root/TombRaiderCameraFix.XXXXXXXXXX"); then
        trcf_error 'Could not create a secure temporary file.'
        return 1
    fi
    chmod 600 -- "$TRCF_TEMP_RESULT"
    TRCF_TEMP_FILES+=("$TRCF_TEMP_RESULT")
}

trcf_prepare_engine() {
    local script_path=$0
    if [[ $script_path != */* ]]; then
        script_path=$(command -v -- "$script_path" 2>/dev/null || true)
    fi
    if [[ -z $script_path || ! -f $script_path ]]; then
        trcf_error 'Could not locate the running Linux release file.'
        return 1
    fi
    trcf_new_temp || return 1
    TRCF_ENGINE=$TRCF_TEMP_RESULT
    if ! awk -v marker="$TRCF_PYTHON_MARKER" -v ending="$TRCF_PYTHON_END" '
        $0 == ending { if (found) { ended = 1; exit } }
        found { print }
        $0 == marker { found = 1 }
        END { if (!found || !ended) exit 2 }
    ' "$script_path" > "$TRCF_ENGINE"; then
        trcf_error 'The embedded Python marker is missing or unreadable.'
        return 1
    fi
    if [[ ! -s $TRCF_ENGINE ]]; then
        trcf_error 'The embedded Python engine is empty.'
        return 1
    fi
}

trcf_load_records() {
    local record_file=$1
    TRCF_RECORDS=()
    mapfile -d '' -t TRCF_RECORDS < "$record_file"
    if (( ${#TRCF_RECORDS[@]} % 2 != 0 )); then
        trcf_error 'The embedded engine returned a malformed installation list.'
        return 1
    fi
}

trcf_select_manual() {
    local requested=${1:-}
    local record_file
    if [[ -z $requested ]]; then
        if [[ ! -t 0 ]]; then
            trcf_error 'No unambiguous Steam installation was found. Use --game-path PATH.'
            return 1
        fi
        read -r -p 'Enter TombRaider.exe or its Steam game-directory path, or press Enter to cancel: ' requested
        if [[ -z $requested ]]; then
            trcf_warning 'No executable was selected. Nothing was changed.'
            return 1
        fi
    fi
    trcf_new_temp || return 1
    record_file=$TRCF_TEMP_RESULT
    if ! python3 "$TRCF_ENGINE" resolve --path "$requested" --nul > "$record_file"; then
        return 1
    fi
    trcf_load_records "$record_file" || return 1
    if (( ${#TRCF_RECORDS[@]} != 2 )); then
        trcf_error 'Manual selection did not resolve to one Steam installation.'
        return 1
    fi
    TRCF_SELECTED_TYPE=${TRCF_RECORDS[0]}
    TRCF_SELECTED_PATH=${TRCF_RECORDS[1]}
}

trcf_choose_installation() {
    local force_choice=${1:-0}
    local record_file count index choice
    trcf_new_temp || return 1
    record_file=$TRCF_TEMP_RESULT
    trcf_info 'Looking for Steam App ID 203160 in native and Flatpak Steam libraries...'
    if ! python3 "$TRCF_ENGINE" discover --nul > "$record_file"; then
        return 1
    fi
    trcf_load_records "$record_file" || return 1
    count=$((${#TRCF_RECORDS[@]} / 2))
    if (( count == 1 && force_choice == 0 )); then
        TRCF_SELECTED_TYPE=${TRCF_RECORDS[0]}
        TRCF_SELECTED_PATH=${TRCF_RECORDS[1]}
        trcf_success "Found: $TRCF_SELECTED_PATH"
        return 0
    fi
    if (( count == 0 )); then
        trcf_warning 'No supported Windows Steam installation was found automatically.'
        trcf_select_manual ''
        return $?
    fi
    if [[ ! -t 0 ]]; then
        trcf_error 'More than one installation was found. Use --game-path PATH.'
        return 1
    fi
    printf '\nDetected Tomb Raider installations:\n'
    for ((index = 0; index < count; index++)); do
        printf '[%d] %s (%s)\n' "$((index + 1))" "${TRCF_RECORDS[index * 2 + 1]}" "${TRCF_RECORDS[index * 2]}"
    done
    printf '[M] Choose another executable manually\n'
    read -r -p 'Choose an installation number or M: ' choice
    if [[ $choice == [mM] ]]; then
        trcf_select_manual ''
        return $?
    fi
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
        index=$((choice - 1))
        TRCF_SELECTED_TYPE=${TRCF_RECORDS[index * 2]}
        TRCF_SELECTED_PATH=${TRCF_RECORDS[index * 2 + 1]}
        return 0
    fi
    trcf_error 'Invalid installation selection.'
    return 1
}

trcf_status() {
    python3 "$TRCF_ENGINE" status --path "$TRCF_SELECTED_PATH"
}

trcf_apply() {
    trcf_status || return 1
    printf '\nIntended changes: apply the complete wobble, horizontal auto-centering, and vertical auto-centering fix.\n'
    printf 'No Proton prefix, DLL, Steam setting, or other game file will be changed.\n'
    if (( TRCF_CONFIRMED == 0 )); then
        local confirmation
        if [[ ! -t 0 ]]; then
            trcf_error 'Noninteractive apply requires --yes.'
            return 1
        fi
        read -r -p 'Type APPLY to create or verify the backup and continue: ' confirmation
        if [[ $confirmation != 'APPLY' ]]; then
            trcf_warning 'Cancelled. Nothing was changed.'
            return 1
        fi
    fi
    python3 "$TRCF_ENGINE" apply --path "$TRCF_SELECTED_PATH"
}

trcf_restore() {
    trcf_status || return 1
    if (( TRCF_CONFIRMED == 0 )); then
        local confirmation
        if [[ ! -t 0 ]]; then
            trcf_error 'Noninteractive restore requires --yes.'
            return 1
        fi
        read -r -p 'Type RESTORE to restore the verified original executable: ' confirmation
        if [[ $confirmation != 'RESTORE' ]]; then
            trcf_warning 'Cancelled. Nothing was changed.'
            return 1
        fi
    fi
    python3 "$TRCF_ENGINE" restore --path "$TRCF_SELECTED_PATH"
}

trcf_parse_arguments() {
    local selected_action=0
    while (( $# > 0 )); do
        case $1 in
            --status|--apply|--restore)
                if (( selected_action != 0 )); then
                    trcf_error 'Choose only one of --status, --apply, or --restore.'
                    return 1
                fi
                TRCF_ACTION=${1#--}
                selected_action=1
                ;;
            --game-path)
                shift
                if (( $# == 0 )); then
                    trcf_error '--game-path requires a value.'
                    return 1
                fi
                TRCF_GAME_PATH=$1
                ;;
            --yes)
                TRCF_CONFIRMED=1
                ;;
            --help|-h)
                trcf_usage
                exit 0
                ;;
            *)
                trcf_error "Unknown argument: $1"
                trcf_usage >&2
                return 1
                ;;
        esac
        shift
    done
}

trcf_main() {
    trcf_parse_arguments "$@" || return 2
    if (( EUID == 0 )); then
        trcf_error 'Do not run this patcher as root or with sudo. Run it as your normal Steam user.'
        return 1
    fi
    if [[ $(uname -s) != 'Linux' ]]; then
        trcf_error 'This release supports desktop Linux only.'
        return 1
    fi
    case $(uname -m) in
        x86_64|amd64) ;;
        *)
            trcf_error "Only x86_64 desktop Linux is supported. Detected: $(uname -m)."
            return 1
            ;;
    esac
    if ! command -v python3 >/dev/null 2>&1; then
        trcf_error 'Python 3 is required. Install your distribution Python 3 package, then run this file again.'
        trcf_error 'This utility will not install packages automatically.'
        return 1
    fi
    trcf_prepare_engine || return 1
    trcf_heading
    if [[ -n $TRCF_GAME_PATH ]]; then
        trcf_select_manual "$TRCF_GAME_PATH" || return 1
    else
        trcf_choose_installation 0 || return 1
    fi

    case $TRCF_ACTION in
        status) trcf_status; return $? ;;
        apply) trcf_apply; return $? ;;
        restore) trcf_restore; return $? ;;
    esac

    if [[ ! -t 0 ]]; then
        trcf_error 'Noninteractive use requires --status, --apply, or --restore.'
        return 2
    fi

    local choice
    while true; do
        trcf_heading
        printf 'Selected: %s (%s)\n\n' "$TRCF_SELECTED_PATH" "$TRCF_SELECTED_TYPE"
        printf '[1] Apply complete camera fix\n'
        printf '[2] Restore original executable\n'
        printf '[3] Status and diagnostics\n'
        printf '[4] Choose another installation\n'
        printf '[5] Exit\n\n'
        read -r -p 'Choose 1, 2, 3, 4 or 5: ' choice
        case $choice in
            1) trcf_apply || true ;;
            2) trcf_restore || true ;;
            3) trcf_status || true ;;
            4) trcf_choose_installation 1 || true ;;
            5) trcf_info 'No game was launched.'; return 0 ;;
            *) trcf_warning 'Please enter 1, 2, 3, 4 or 5.' ;;
        esac
    done
}

trap trcf_cleanup EXIT
trap 'exit 130' HUP INT TERM
trcf_main "$@"
exit $?

# The generated file stores its embedded Python after this intentional exit.
# shellcheck disable=SC2317
: <<'__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON_END__'
#__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON__
# BEGIN GENERATED SOURCE: src/CameraFixEngineLinux.py
#!/usr/bin/env python3
"""Safe Tomb Raider (2013) Windows-executable patcher for Linux/Proton.

This module is embedded into TombRaider-Camera-Fix-Linux.sh for release. It
uses only the Python standard library and never modifies Proton prefixes.
"""

from __future__ import annotations

import argparse
import base64
import datetime as _datetime
import hashlib
import json
import os
import platform
import stat
import struct
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Callable, Iterable, Iterator, Optional, Sequence, Union


TOOL_NAME = "Tomb Raider Complete Camera Fix"
MANAGER_VERSION = "1.1.0-beta.1"
MANIFEST_SCHEMA = 1
TARGET_FILENAME = "TombRaider.exe"
BACKUP_SUFFIX = ".trcamera-original.bak"
MANIFEST_SUFFIX = ".trcamera-original.json"
MAX_METADATA_BYTES = 8 * 1024 * 1024
PATCH_CATALOGUE_BASE64 = "ewogICJjYXRhbG9ndWVfdmVyc2lvbiI6IDEsCiAgInN0ZWFtX2FwcF9pZCI6IDIwMzE2MCwKICAic3RlYW1fYnVpbGQiOiAiNzQzLjAiLAogICJmaWxlX3ZlcnNpb24iOiAiMS4xLjc0My4wIiwKICAicGUiOiB7CiAgICAibWFjaGluZSI6IDMzMiwKICAgICJvcHRpb25hbF9tYWdpYyI6IDI2NywKICAgICJzdWJzeXN0ZW0iOiAyCiAgfSwKICAiY29tcGxldGVfc3RhdGVfcmVxdWlyZXMiOiBbCiAgICAiV29iYmxlIiwKICAgICJIb3Jpem9udGFsIiwKICAgICJWZXJ0aWNhbCIKICBdLAogICJwYXRjaGVzIjogWwogICAgewogICAgICAiaWQiOiAiV29iYmxlIiwKICAgICAgIm5hbWUiOiAiR2FtZXBsYXkgY2FtZXJhIHdvYmJsZSAvIGhlYWQtYm9iIiwKICAgICAgImV4cGVjdGVkX2NvdW50IjogMSwKICAgICAgIm9yaWdpbmFsIjogIjhCIENGIEU4IERCIEZEIDQxIDAwIDg0IEMwIDc0IDE0IDU2IiwKICAgICAgInBhdGNoZWQiOiAiOEIgQ0YgRTggREIgRkQgNDEgMDAgODQgQzAgRUIgMTQgNTYiLAogICAgICAidmVyaWZpY2F0aW9uX29yaWdpbmFsIjogIjhCIENGIEU4IERCIEZEIDQxIDAwIDg0IEMwIDc0IDE0IDU2IiwKICAgICAgInZlcmlmaWNhdGlvbl9wYXRjaGVkIjogIjhCIENGIEU4IERCIEZEIDQxIDAwIDg0IEMwIEVCIDE0IDU2IgogICAgfSwKICAgIHsKICAgICAgImlkIjogIkhvcml6b250YWwiLAogICAgICAibmFtZSI6ICJIb3Jpem9udGFsIGF1dG8tY2VudGVyaW5nIiwKICAgICAgImV4cGVjdGVkX2NvdW50IjogMSwKICAgICAgIm9yaWdpbmFsIjogIjA4IEIwIDAxIEQ5IDlFIEEwIDBGIDAwIDAwIiwKICAgICAgInBhdGNoZWQiOiAiMDggQjAgMDEgOTAgOTAgOTAgOTAgOTAgOTAiLAogICAgICAidmVyaWZpY2F0aW9uX29yaWdpbmFsIjogIjA4IEIwIDAxIEQ5IDlFIEEwIDBGIDAwIDAwIiwKICAgICAgInZlcmlmaWNhdGlvbl9wYXRjaGVkIjogIjA4IEIwIDAxIDkwIDkwIDkwIDkwIDkwIDkwIgogICAgfSwKICAgIHsKICAgICAgImlkIjogIlZlcnRpY2FsIiwKICAgICAgIm5hbWUiOiAiVmVydGljYWwgYXV0by1jZW50ZXJpbmciLAogICAgICAiZXhwZWN0ZWRfY291bnQiOiAxLAogICAgICAib3JpZ2luYWwiOiAiRDkgNUUgMDQgRDkgNDQgMjQgMEMgRDkgNUUgMEMgRDkgNDQgMjQgMTggRDkgNUUgMTAgQzYgODcgQzQgMEYgMDAgMDAgMDEgRTkgQTIgRkUgRkYgRkYgREQgRDggNkEgMDAgRDkgODcgNDAgMDYgMDAgMDAgODMgRUMgMEMgRDkgNUMgMjQiLAogICAgICAicGF0Y2hlZCI6ICJEOSA1RSAyMCBEOSA0NCAyNCAwQyBEOSA1RSAwQyBEOSA0NCAyNCAxOCBEOSA1RSAxMCBDNiA4NyBDNCAwRiAwMCAwMCAwMSBFOSBBMiBGRSBGRiBGRiBERCBEOCA2QSAwMCBEOSA4NyA0MCAwNiAwMCAwMCA4MyBFQyAwQyBEOSA1QyAyNCIsCiAgICAgICJ2ZXJpZmljYXRpb25fb3JpZ2luYWwiOiAiRDkgNUUgMDQgRDkgNDQgMjQgMEMgRDkgNUUgMEMgRDkgNDQgMjQgMTggRDkgNUUgMTAgQzYgODcgQzQgMEYgMDAgMDAgMDEgRTkgQTIgRkUgRkYgRkYgREQgRDggNkEgMDAgRDkgODcgNDAgMDYgMDAgMDAgODMgRUMgMEMgRDkgNUMgMjQiLAogICAgICAidmVyaWZpY2F0aW9uX3BhdGNoZWQiOiAiRDkgNUUgMjAgRDkgNDQgMjQgMEMgRDkgNUUgMEMgRDkgNDQgMjQgMTggRDkgNUUgMTAgQzYgODcgQzQgMEYgMDAgMDAgMDEgRTkgQTIgRkUgRkYgRkYgREQgRDggNkEgMDAgRDkgODcgNDAgMDYgMDAgMDAgODMgRUMgMEMgRDkgNUMgMjQiCiAgICB9CiAgXQp9Cg=="

FERAL_MESSAGE = """This fix supports the Windows version of Tomb Raider running through Proton. The separate Feral native Linux port is not supported.

In Steam, open Tomb Raider → Properties → Compatibility and force a Proton version. Steam should then download the Windows game files.

Native Linux and Windows/Proton save files are not compatible. Back up your saves before switching."""


class CameraFixError(RuntimeError):
    """A safe, user-facing refusal or validation error."""


class VdfError(CameraFixError):
    """Malformed or unsafe Valve KeyValues data."""


VdfNode = list[tuple[str, Union[str, "VdfNode"]]]


@dataclass(frozen=True)
class PatchDefinition:
    key: str
    name: str
    expected_count: int
    original: bytes
    patched: bytes
    verification_original: bytes
    verification_patched: bytes


@dataclass(frozen=True)
class Catalogue:
    version: int
    steam_app_id: int
    steam_build: str
    file_version: str
    machine: int
    optional_magic: int
    subsystem: int
    complete_state_requires: tuple[str, ...]
    patches: tuple[PatchDefinition, ...]


@dataclass(frozen=True)
class PeMetadata:
    machine: int
    optional_magic: int
    subsystem: int
    stored_checksum: int
    checksum_offset: int
    file_version: str
    section_count: int
    is_expected_architecture: bool
    is_gui_executable: bool
    is_supported_version: bool


@dataclass(frozen=True)
class PatternState:
    key: str
    name: str
    classification: str
    explanation: Optional[str]
    original_offsets: tuple[int, ...]
    patched_offsets: tuple[int, ...]
    original: bytes
    patched: bytes

    @property
    def original_count(self) -> int:
        return len(self.original_offsets)

    @property
    def patched_count(self) -> int:
        return len(self.patched_offsets)


@dataclass(frozen=True)
class Inspection:
    path: Path
    data: bytes
    size: int
    sha256: str
    pe: PeMetadata
    patterns: tuple[PatternState, ...]
    state: str
    reason: Optional[str]

    @property
    def compatible(self) -> bool:
        return self.state != "Unsupported"


@dataclass
class SteamRoot:
    path: Path
    source_types: set[str] = field(default_factory=set)


@dataclass
class SteamLibrary:
    path: Path
    source_types: set[str] = field(default_factory=set)


@dataclass(frozen=True)
class Installation:
    executable: Path
    game_directory: Path
    library: Path
    manifest: Path
    steam_type: str


@dataclass(frozen=True)
class BackupValidation:
    valid: bool
    exists: bool
    reason: str
    backup_path: Path
    manifest_path: Path
    manifest: Optional[dict] = None
    inspection: Optional[Inspection] = None


@dataclass(frozen=True)
class FileSnapshot:
    device: int
    inode: int
    size: int
    mtime_ns: int
    sha256: str


def _hex_bytes(value: str) -> bytes:
    compact = "".join(value.split())
    if not compact or len(compact) % 2:
        raise CameraFixError("The patch catalogue contains invalid hexadecimal data.")
    try:
        return bytes.fromhex(compact)
    except ValueError as exc:
        raise CameraFixError("The patch catalogue contains invalid hexadecimal data.") from exc


def _catalogue_path() -> Path:
    return Path(__file__).resolve().with_name("CameraFixPatches.json")


def load_catalogue() -> Catalogue:
    if PATCH_CATALOGUE_BASE64.startswith("__"):
        raw = _catalogue_path().read_bytes()
    else:
        try:
            raw = base64.b64decode(PATCH_CATALOGUE_BASE64, validate=True)
        except (ValueError, TypeError) as exc:
            raise CameraFixError("The embedded patch catalogue is corrupt.") from exc
    try:
        source = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise CameraFixError("The patch catalogue is not valid UTF-8 JSON.") from exc

    try:
        patches = []
        for item in source["patches"]:
            patch = PatchDefinition(
                key=str(item["id"]),
                name=str(item["name"]),
                expected_count=int(item["expected_count"]),
                original=_hex_bytes(item["original"]),
                patched=_hex_bytes(item["patched"]),
                verification_original=_hex_bytes(item["verification_original"]),
                verification_patched=_hex_bytes(item["verification_patched"]),
            )
            if patch.expected_count != 1:
                raise CameraFixError("Every camera patch must require exactly one match.")
            if patch.original != patch.verification_original or patch.patched != patch.verification_patched:
                raise CameraFixError(f"Verification bytes diverge for {patch.name}.")
            if len(patch.original) != len(patch.patched):
                raise CameraFixError(f"Original and patched lengths diverge for {patch.name}.")
            patches.append(patch)
        catalogue = Catalogue(
            version=int(source["catalogue_version"]),
            steam_app_id=int(source["steam_app_id"]),
            steam_build=str(source["steam_build"]),
            file_version=str(source["file_version"]),
            machine=int(source["pe"]["machine"]),
            optional_magic=int(source["pe"]["optional_magic"]),
            subsystem=int(source["pe"]["subsystem"]),
            complete_state_requires=tuple(str(value) for value in source["complete_state_requires"]),
            patches=tuple(patches),
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise CameraFixError("The patch catalogue is missing required fields.") from exc

    keys = tuple(patch.key for patch in catalogue.patches)
    if len(keys) != len(set(keys)) or keys != catalogue.complete_state_requires:
        raise CameraFixError("The patch catalogue has inconsistent complete-state relationships.")
    return catalogue


CATALOGUE = load_catalogue()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def _has_unsafe_text(value: str) -> bool:
    return any(ord(character) < 32 or ord(character) == 127 for character in value)


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def _safe_resolve(path: Path, *, require_directory: bool = False, require_file: bool = False) -> Path:
    text = os.fspath(path)
    if not text or _has_unsafe_text(text):
        raise CameraFixError("A path is empty or contains control characters.")
    try:
        resolved = path.expanduser().resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise CameraFixError(f"The path does not resolve safely: {path}") from exc
    try:
        mode = resolved.stat().st_mode
    except OSError as exc:
        raise CameraFixError(f"The path cannot be inspected: {resolved}") from exc
    if require_directory and not stat.S_ISDIR(mode):
        raise CameraFixError(f"The selected path is not a directory: {resolved}")
    if require_file and not stat.S_ISREG(mode):
        raise CameraFixError(f"The selected path is not a regular file: {resolved}")
    return resolved


class VdfParser:
    """Small, bounded Valve KeyValues text parser for local Steam metadata."""

    def __init__(self, text: str):
        if "\x00" in text:
            raise VdfError("Valve metadata contains a null byte.")
        self.text = text
        self.position = 0
        self.length = len(text)

    def parse(self) -> VdfNode:
        result = self._parse_object(expect_close=False, depth=0)
        self._skip_space_and_comments()
        if self.position != self.length:
            raise VdfError("Unexpected trailing Valve metadata.")
        return result

    def _skip_space_and_comments(self) -> None:
        while self.position < self.length:
            character = self.text[self.position]
            if character.isspace():
                self.position += 1
                continue
            if self.text.startswith("//", self.position):
                newline = self.text.find("\n", self.position + 2)
                self.position = self.length if newline < 0 else newline + 1
                continue
            break

    def _parse_object(self, *, expect_close: bool, depth: int) -> VdfNode:
        if depth > 64:
            raise VdfError("Valve metadata nesting is too deep.")
        items: VdfNode = []
        while True:
            self._skip_space_and_comments()
            if self.position >= self.length:
                if expect_close:
                    raise VdfError("Valve metadata has an unclosed object.")
                return items
            if self.text[self.position] == "}":
                if not expect_close:
                    raise VdfError("Valve metadata has an unexpected closing brace.")
                self.position += 1
                return items
            key = self._parse_token()
            self._skip_space_and_comments()
            if self.position >= self.length:
                raise VdfError(f"Valve metadata key {key!r} has no value.")
            if self.text[self.position] == "{":
                self.position += 1
                value: Union[str, VdfNode] = self._parse_object(expect_close=True, depth=depth + 1)
            else:
                value = self._parse_token()
            items.append((key, value))

    def _parse_token(self) -> str:
        self._skip_space_and_comments()
        if self.position >= self.length or self.text[self.position] in "{}":
            raise VdfError("Valve metadata contains a missing key or value.")
        if self.text[self.position] == '"':
            self.position += 1
            value = []
            while self.position < self.length:
                character = self.text[self.position]
                self.position += 1
                if character == '"':
                    result = "".join(value)
                    if len(result) > 1024 * 1024:
                        raise VdfError("A Valve metadata token is unreasonably long.")
                    return result
                if character == "\\":
                    if self.position >= self.length:
                        raise VdfError("Valve metadata ends inside an escape sequence.")
                    escaped = self.text[self.position]
                    self.position += 1
                    value.append({"\\": "\\", '"': '"', "n": "\n", "t": "\t"}.get(escaped, "\\" + escaped))
                else:
                    value.append(character)
            raise VdfError("Valve metadata has an unterminated quoted string.")
        start = self.position
        while self.position < self.length and not self.text[self.position].isspace() and self.text[self.position] not in "{}":
            self.position += 1
        token = self.text[start:self.position]
        if not token:
            raise VdfError("Valve metadata contains an empty token.")
        return token


def parse_vdf(text: str) -> VdfNode:
    return VdfParser(text).parse()


def _pairs(node: VdfNode, key: str) -> list[Union[str, VdfNode]]:
    wanted = key.casefold()
    return [value for item_key, value in node if item_key.casefold() == wanted]


def _first_string(node: VdfNode, key: str) -> Optional[str]:
    for value in _pairs(node, key):
        if isinstance(value, str):
            return value
    return None


def _read_metadata(path: Path) -> str:
    try:
        file_size = path.stat().st_size
        if file_size < 0 or file_size > MAX_METADATA_BYTES:
            raise VdfError(f"Steam metadata is unreasonably large: {path}")
        return path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError as exc:
        raise VdfError(f"Steam metadata is not valid UTF-8: {path}") from exc
    except OSError as exc:
        raise VdfError(f"Steam metadata cannot be read: {path}") from exc


def _physical_key(path: Path) -> tuple[int, int]:
    details = path.stat()
    return details.st_dev, details.st_ino


def discover_steam_roots(home: Optional[Path] = None) -> list[SteamRoot]:
    home_path = (home or Path.home()).expanduser()
    override = os.environ.get("TRCF_LINUX_STEAM_ROOTS")
    candidates: list[tuple[Path, str]] = []
    if override:
        for value in override.split(os.pathsep):
            if value:
                candidates.append((Path(value), "Test Steam"))
    else:
        candidates.extend(
            [
                (home_path / ".local/share/Steam", "Native Steam"),
                (home_path / ".steam/steam", "Native Steam"),
                (home_path / ".steam/root", "Native Steam"),
                (home_path / ".var/app/com.valvesoftware.Steam/data/Steam", "Flatpak Steam"),
                (home_path / ".var/app/com.valvesoftware.Steam/.local/share/Steam", "Flatpak Steam"),
            ]
        )

    roots: dict[tuple[int, int], SteamRoot] = {}
    for candidate, source_type in candidates:
        try:
            resolved = _safe_resolve(candidate, require_directory=True)
            _safe_resolve(resolved / "steamapps", require_directory=True)
            key = _physical_key(resolved)
        except CameraFixError:
            continue
        if key not in roots:
            roots[key] = SteamRoot(path=resolved, source_types=set())
        roots[key].source_types.add(source_type)
    return list(roots.values())


def _library_values(tree: VdfNode) -> list[str]:
    containers = [value for value in _pairs(tree, "libraryfolders") if isinstance(value, list)]
    if not containers:
        raise VdfError("libraryfolders.vdf has no libraryfolders object.")
    values: list[str] = []
    for key, value in containers[0]:
        if not key.isdigit():
            continue
        if isinstance(value, str):
            values.append(value)
        else:
            path_value = _first_string(value, "path")
            if path_value is not None:
                values.append(path_value)
    return values


def _validate_declared_library(value: str, root: SteamRoot) -> Path:
    if not value or _has_unsafe_text(value):
        raise VdfError("A Steam library path is empty or contains control characters.")
    path = Path(value).expanduser()
    if not path.is_absolute() or ".." in path.parts:
        raise VdfError(f"A Steam library path is not absolute and traversal-free: {value!r}")

    flatpak_home_path = Path.home() / ".local/share/Steam"
    if "Flatpak Steam" in root.source_types and path == flatpak_home_path:
        path = root.path
    resolved = _safe_resolve(path, require_directory=True)
    _safe_resolve(resolved / "steamapps", require_directory=True)
    return resolved


def discover_steam_libraries(roots: Sequence[SteamRoot]) -> tuple[list[SteamLibrary], list[str]]:
    libraries: dict[tuple[int, int], SteamLibrary] = {}
    diagnostics: list[str] = []

    def add_library(path: Path, source_types: Iterable[str]) -> None:
        key = _physical_key(path)
        if key not in libraries:
            libraries[key] = SteamLibrary(path=path, source_types=set())
        libraries[key].source_types.update(source_types)

    for root in roots:
        add_library(root.path, root.source_types)
        vdf_path = root.path / "steamapps/libraryfolders.vdf"
        if not vdf_path.is_file():
            continue
        try:
            tree = parse_vdf(_read_metadata(vdf_path))
            for value in _library_values(tree):
                try:
                    add_library(_validate_declared_library(value, root), root.source_types)
                except (CameraFixError, OSError) as exc:
                    diagnostics.append(f"Ignored unsafe or unavailable Steam library {value!r}: {exc}")
        except (CameraFixError, OSError) as exc:
            diagnostics.append(f"Ignored malformed Steam library metadata {vdf_path}: {exc}")
    return list(libraries.values()), diagnostics


def parse_app_manifest(path: Path) -> dict[str, str]:
    tree = parse_vdf(_read_metadata(path))
    states = [value for value in _pairs(tree, "appstate") if isinstance(value, list)]
    if not states:
        raise VdfError("The app manifest has no AppState object.")
    state = states[0]
    app_id = _first_string(state, "appid")
    install_dir = _first_string(state, "installdir")
    state_flags = _first_string(state, "stateflags")
    if app_id != str(CATALOGUE.steam_app_id):
        raise VdfError(f"The app manifest does not identify App ID {CATALOGUE.steam_app_id}.")
    if not install_dir or _has_unsafe_text(install_dir):
        raise VdfError("The app manifest has no safe installdir value.")
    pure = PurePosixPath(install_dir)
    if pure.is_absolute() or not pure.parts or any(part in ("", ".", "..") for part in pure.parts) or "\\" in install_dir:
        raise VdfError("The app manifest installdir contains unsafe traversal or separators.")
    if state_flags is not None:
        try:
            if int(state_flags) & 1:
                raise VdfError("The app manifest marks this installation as uninstalled.")
        except ValueError as exc:
            raise VdfError("The app manifest has an invalid StateFlags value.") from exc
    return {"appid": app_id, "installdir": install_dir, "stateflags": state_flags or ""}


def _steam_type(source_types: Iterable[str]) -> str:
    values = sorted(set(source_types))
    if values == ["Native Steam"]:
        return "Native Steam"
    if values == ["Flatpak Steam"]:
        return "Flatpak Steam"
    return " / ".join(values) if values else "Steam library"


def _is_elf(path: Path) -> bool:
    try:
        if not path.is_file():
            return False
        with path.open("rb") as stream:
            return stream.read(4) == b"\x7fELF"
    except OSError:
        return False


def is_feral_installation(game_directory: Path) -> bool:
    launch_script = game_directory / "TombRaider.sh"
    binaries = (game_directory / "TombRaider", game_directory / "bin/TombRaider")
    return launch_script.is_file() and any(_is_elf(candidate) for candidate in binaries)


def _manifest_installation(library: SteamLibrary, manifest: Path) -> tuple[Optional[Installation], Optional[str]]:
    steamapps = _safe_resolve(library.path / "steamapps", require_directory=True)
    resolved_manifest = _safe_resolve(manifest, require_file=True)
    if not _is_relative_to(resolved_manifest, steamapps):
        raise VdfError("The app manifest resolves outside its declared Steam library.")
    metadata = parse_app_manifest(resolved_manifest)
    common = _safe_resolve(steamapps / "common", require_directory=True)
    unresolved_game = common.joinpath(*PurePosixPath(metadata["installdir"]).parts)
    try:
        game_directory = _safe_resolve(unresolved_game, require_directory=True)
    except CameraFixError:
        return None, f"App ID {CATALOGUE.steam_app_id} has an incomplete installation at {unresolved_game}."
    if not _is_relative_to(game_directory, common) or not _is_relative_to(game_directory, library.path):
        raise VdfError("The app manifest game directory resolves outside its declared Steam library.")

    executable_path = game_directory / TARGET_FILENAME
    if not executable_path.exists():
        if is_feral_installation(game_directory):
            return None, FERAL_MESSAGE
        return None, f"App ID {CATALOGUE.steam_app_id} is installed at {game_directory}, but {TARGET_FILENAME} is absent. The Steam installation may be incomplete."
    executable = _safe_resolve(executable_path, require_file=True)
    if not _is_relative_to(executable, game_directory) or not _is_relative_to(executable, library.path):
        raise VdfError(f"{TARGET_FILENAME} resolves outside its declared Steam game directory.")
    return (
        Installation(
            executable=executable,
            game_directory=game_directory,
            library=library.path,
            manifest=resolved_manifest,
            steam_type=_steam_type(library.source_types),
        ),
        None,
    )


def discover_installations(home: Optional[Path] = None) -> tuple[list[Installation], list[str]]:
    roots = discover_steam_roots(home)
    libraries, diagnostics = discover_steam_libraries(roots)
    found: dict[tuple[int, int], Installation] = {}
    for library in libraries:
        manifest = library.path / f"steamapps/appmanifest_{CATALOGUE.steam_app_id}.acf"
        if not manifest.is_file():
            continue
        try:
            installation, diagnostic = _manifest_installation(library, manifest)
            if diagnostic and diagnostic not in diagnostics:
                diagnostics.append(diagnostic)
            if installation:
                key = _physical_key(installation.executable)
                existing = found.get(key)
                if existing and existing.steam_type != installation.steam_type:
                    combined = _steam_type((existing.steam_type, installation.steam_type))
                    found[key] = Installation(
                        executable=existing.executable,
                        game_directory=existing.game_directory,
                        library=existing.library,
                        manifest=existing.manifest,
                        steam_type=combined,
                    )
                elif not existing:
                    found[key] = installation
        except (CameraFixError, OSError) as exc:
            diagnostics.append(f"Ignored invalid App ID {CATALOGUE.steam_app_id} metadata in {library.path}: {exc}")
    return list(found.values()), diagnostics


def _installation_from_library(executable: Path, game_directory: Path, library: Path, steam_type: str) -> Installation:
    manifest = library / f"steamapps/appmanifest_{CATALOGUE.steam_app_id}.acf"
    resolved_manifest = _safe_resolve(manifest, require_file=True)
    metadata = parse_app_manifest(resolved_manifest)
    expected_game = _safe_resolve(library / "steamapps/common" / Path(*PurePosixPath(metadata["installdir"]).parts), require_directory=True)
    if expected_game != game_directory:
        raise CameraFixError("The selected executable does not match the installdir recorded for Steam App ID 203160.")
    if not _is_relative_to(executable, expected_game) or executable.parent != expected_game:
        raise CameraFixError("The selected executable resolves outside the Steam game directory.")
    return Installation(executable, game_directory, library, resolved_manifest, steam_type)


def resolve_manual_installation(value: str) -> Installation:
    if not value or _has_unsafe_text(value):
        raise CameraFixError("The manually selected path is empty or contains control characters.")
    raw = Path(value).expanduser()
    if raw.is_dir():
        raw_game = raw
        raw_executable = raw / TARGET_FILENAME
        if not raw_executable.exists():
            game = _safe_resolve(raw_game, require_directory=True)
            if is_feral_installation(game):
                raise CameraFixError(FERAL_MESSAGE)
            raise CameraFixError(f"The selected directory does not contain {TARGET_FILENAME}: {game}")
    else:
        raw_game = raw.parent
        raw_executable = raw
    game_directory = _safe_resolve(raw_game, require_directory=True)
    executable = _safe_resolve(raw_executable, require_file=True)
    if executable.name.casefold() != TARGET_FILENAME.casefold():
        if _is_elf(executable):
            raise CameraFixError(FERAL_MESSAGE)
        raise CameraFixError(f"The selected file must be named {TARGET_FILENAME}.")
    if not _is_relative_to(executable, game_directory) or executable.parent != game_directory:
        raise CameraFixError("The selected executable resolves outside the selected game directory.")

    common = game_directory.parent
    if common.name != "common" or common.parent.name != "steamapps":
        raise CameraFixError("Manual selection must point to the App ID 203160 installation inside a Steam library.")
    library = _safe_resolve(common.parent.parent, require_directory=True)
    if not _is_relative_to(game_directory, library):
        raise CameraFixError("The selected game directory resolves outside its Steam library.")
    flatpak_parts = "/".join(library.parts)
    steam_type = "Flatpak Steam" if "/.var/app/com.valvesoftware.Steam/" in f"/{flatpak_parts}/" else "Native or external Steam library"
    return _installation_from_library(executable, game_directory, library, steam_type)


def _u16(data: bytes, offset: int) -> int:
    if offset < 0 or offset + 2 > len(data):
        raise CameraFixError("The PE file is truncated.")
    return struct.unpack_from("<H", data, offset)[0]


def _u32(data: bytes, offset: int) -> int:
    if offset < 0 or offset + 4 > len(data):
        raise CameraFixError("The PE file is truncated.")
    return struct.unpack_from("<I", data, offset)[0]


def parse_pe_metadata(data: bytes) -> PeMetadata:
    if len(data) < 256:
        raise CameraFixError("The file is too small to be a valid Windows PE executable.")
    if data[:4] == b"\x7fELF":
        raise CameraFixError("The selected file is a native Linux ELF binary. The Feral native Linux port is not supported.")
    if data[:2] != b"MZ":
        raise CameraFixError("The DOS MZ signature is missing.")
    pe_offset = _u32(data, 0x3C)
    if pe_offset < 0x40 or pe_offset > len(data) - 96 or data[pe_offset:pe_offset + 4] != b"PE\x00\x00":
        raise CameraFixError("The Windows PE signature is missing, corrupt, or outside the file.")
    machine = _u16(data, pe_offset + 4)
    section_count = _u16(data, pe_offset + 6)
    optional_size = _u16(data, pe_offset + 20)
    characteristics = _u16(data, pe_offset + 22)
    optional = pe_offset + 24
    if not 1 <= section_count <= 96 or optional_size < 112:
        raise CameraFixError("The PE headers are incomplete or invalid.")
    section_table = optional + optional_size
    if section_table + section_count * 40 > len(data) or not (characteristics & 0x0002):
        raise CameraFixError("The PE headers extend beyond the file or do not describe an executable image.")
    optional_magic = _u16(data, optional)
    if optional_magic != 0x010B:
        raise CameraFixError(f"The PE optional header is not 32-bit PE32 (0x{optional_magic:04X}).")
    checksum_offset = optional + 64
    stored_checksum = _u32(data, checksum_offset)
    subsystem = _u16(data, optional + 68)
    number_of_directories = _u32(data, optional + 92)
    if number_of_directories < 3 or optional_size < 120:
        raise CameraFixError("The PE has no readable version-resource directory.")
    resource_rva = _u32(data, optional + 112)
    resource_size = _u32(data, optional + 116)
    if resource_rva == 0 or resource_size < 16:
        raise CameraFixError("The PE has no version resource.")

    sections = []
    for index in range(section_count):
        entry = section_table + index * 40
        virtual_size = _u32(data, entry + 8)
        virtual_address = _u32(data, entry + 12)
        raw_size = _u32(data, entry + 16)
        raw_offset = _u32(data, entry + 20)
        if raw_offset + raw_size > len(data):
            raise CameraFixError("A PE section extends beyond the file.")
        sections.append((virtual_address, max(virtual_size, raw_size), raw_offset, raw_size))

    def rva_to_offset(rva: int, size: int = 1) -> int:
        for virtual_address, span, raw_offset, raw_size in sections:
            if virtual_address <= rva and rva + size <= virtual_address + span:
                delta = rva - virtual_address
                if delta + size > raw_size:
                    break
                return raw_offset + delta
        raise CameraFixError("A PE resource points outside mapped section data.")

    resource_base = rva_to_offset(resource_rva, min(resource_size, 16))

    def directory_entries(relative_offset: int) -> list[tuple[int, int]]:
        directory = resource_base + relative_offset
        named = _u16(data, directory + 12)
        identified = _u16(data, directory + 14)
        total = named + identified
        if total > 4096 or directory + 16 + total * 8 > len(data):
            raise CameraFixError("The PE resource directory is malformed.")
        return [(_u32(data, directory + 16 + i * 8), _u32(data, directory + 20 + i * 8)) for i in range(total)]

    root_entries = directory_entries(0)
    version_entry = next((entry for entry in root_entries if not (entry[0] & 0x80000000) and (entry[0] & 0xFFFF) == 16), None)
    if version_entry is None:
        raise CameraFixError("The PE version resource is missing.")
    target = version_entry[1]
    for _ in range(4):
        if target & 0x80000000:
            children = directory_entries(target & 0x7FFFFFFF)
            if not children:
                raise CameraFixError("The PE version resource directory is empty.")
            target = children[0][1]
            continue
        data_entry = resource_base + target
        version_rva = _u32(data, data_entry)
        version_size = _u32(data, data_entry + 4)
        if version_size < 52 or version_size > MAX_METADATA_BYTES:
            raise CameraFixError("The PE version resource has an invalid size.")
        version_offset = rva_to_offset(version_rva, version_size)
        version_blob = data[version_offset:version_offset + version_size]
        signature_offset = version_blob.find(b"\xBD\x04\xEF\xFE")
        if signature_offset < 0 or signature_offset + 52 > len(version_blob):
            raise CameraFixError("The PE version resource has no valid VS_FIXEDFILEINFO.")
        version_ms = _u32(version_blob, signature_offset + 8)
        version_ls = _u32(version_blob, signature_offset + 12)
        file_version = f"{version_ms >> 16}.{version_ms & 0xFFFF}.{version_ls >> 16}.{version_ls & 0xFFFF}"
        return PeMetadata(
            machine=machine,
            optional_magic=optional_magic,
            subsystem=subsystem,
            stored_checksum=stored_checksum,
            checksum_offset=checksum_offset,
            file_version=file_version,
            section_count=section_count,
            is_expected_architecture=machine == CATALOGUE.machine and optional_magic == CATALOGUE.optional_magic,
            is_gui_executable=subsystem == CATALOGUE.subsystem,
            is_supported_version=file_version == CATALOGUE.file_version,
        )
    raise CameraFixError("The PE version resource nesting is invalid.")


def find_all(data: bytes, pattern: bytes) -> tuple[int, ...]:
    offsets = []
    start = 0
    while start <= len(data) - len(pattern):
        offset = data.find(pattern, start)
        if offset < 0:
            break
        offsets.append(offset)
        start = offset + 1
    return tuple(offsets)


def analyse_patterns(data: bytes) -> tuple[PatternState, ...]:
    states = []
    for patch in CATALOGUE.patches:
        original_offsets = find_all(data, patch.original)
        patched_offsets = find_all(data, patch.patched)
        explanation = None
        if len(original_offsets) == patch.expected_count and not patched_offsets:
            classification = "Unpatched"
        elif not original_offsets and len(patched_offsets) == patch.expected_count:
            classification = "Patched"
        elif not original_offsets and not patched_offsets:
            classification = "Missing"
            explanation = "Neither the complete original sequence nor the complete patched sequence was found."
        elif len(original_offsets) > patch.expected_count or len(patched_offsets) > patch.expected_count:
            classification = "Duplicated"
            explanation = "A complete sequence occurs more than once, so there is no unique patch location."
        else:
            classification = "Conflicting"
            explanation = "Original and patched sequences are both present, so the intended location is not unambiguous."
        states.append(
            PatternState(
                key=patch.key,
                name=patch.name,
                classification=classification,
                explanation=explanation,
                original_offsets=original_offsets,
                patched_offsets=patched_offsets,
                original=patch.original,
                patched=patch.patched,
            )
        )
    return tuple(states)


def inspect_bytes(data: bytes, path: Path) -> Inspection:
    pe = parse_pe_metadata(data)
    patterns = analyse_patterns(data)
    reason = None
    state = "Unsupported"
    if not pe.is_expected_architecture:
        reason = f"This is not the expected 32-bit x86 PE executable (machine 0x{pe.machine:04X})."
    elif not pe.is_gui_executable:
        reason = "This PE file is not a Windows GUI executable."
    elif not pe.is_supported_version:
        reason = f"File version {pe.file_version} is unsupported. Steam build {CATALOGUE.steam_build} must report {CATALOGUE.file_version}."
    else:
        bad = [pattern for pattern in patterns if pattern.classification not in ("Unpatched", "Patched")]
        if bad:
            reason = " ".join(f"{pattern.name}: {pattern.classification} - {pattern.explanation}" for pattern in bad)
        else:
            patched_count = sum(pattern.classification == "Patched" for pattern in patterns)
            state = "Unpatched" if patched_count == 0 else "CompletelyPatched" if patched_count == len(patterns) else "PartiallyPatched"
    return Inspection(path=path, data=data, size=len(data), sha256=sha256_bytes(data), pe=pe, patterns=patterns, state=state, reason=reason)


def inspect_executable(path: Path, *, require_target_name: bool = True) -> Inspection:
    resolved = _safe_resolve(path, require_file=True)
    if require_target_name and resolved.name.casefold() != TARGET_FILENAME.casefold():
        raise CameraFixError(f"The selected file must be named {TARGET_FILENAME}.")
    try:
        data = resolved.read_bytes()
    except OSError as exc:
        raise CameraFixError(f"The selected executable cannot be read: {resolved}") from exc
    return inspect_bytes(data, resolved)


def sidecar_paths(executable: Path) -> tuple[Path, Path]:
    return Path(os.fspath(executable) + BACKUP_SUFFIX), Path(os.fspath(executable) + MANIFEST_SUFFIX)


def validate_backup(executable: Path) -> BackupValidation:
    backup_path, manifest_path = sidecar_paths(executable)
    backup_exists = backup_path.is_file()
    manifest_exists = manifest_path.is_file()
    if not backup_exists and not manifest_exists:
        return BackupValidation(False, False, "No original backup and manifest exist yet.", backup_path, manifest_path)
    if not backup_exists or not manifest_exists:
        return BackupValidation(False, True, "The backup set is incomplete. Neither sidecar will be overwritten or trusted.", backup_path, manifest_path)
    try:
        if manifest_path.stat().st_size > 1024 * 1024:
            raise CameraFixError("The backup manifest is unreasonably large.")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if int(manifest.get("SchemaVersion", -1)) != MANIFEST_SCHEMA:
            raise CameraFixError(f"Unsupported backup manifest schema: {manifest.get('SchemaVersion')}")
        if str(manifest.get("OriginalFilename", "")).casefold() != TARGET_FILENAME.casefold():
            raise CameraFixError(f"The backup manifest does not identify {TARGET_FILENAME}.")
        inspection = inspect_executable(backup_path, require_target_name=False)
        if inspection.state != "Unpatched":
            raise CameraFixError("The backup is not a completely original supported executable.")
        if int(manifest.get("Size", -1)) != inspection.size:
            raise CameraFixError("The backup size does not match its manifest.")
        if str(manifest.get("FileVersion", "")) != inspection.pe.file_version:
            raise CameraFixError("The backup file version does not match its manifest.")
        if str(manifest.get("SHA256", "")).upper() != inspection.sha256:
            raise CameraFixError("The backup SHA-256 does not match its manifest.")
        return BackupValidation(True, True, "", backup_path, manifest_path, manifest, inspection)
    except (OSError, ValueError, TypeError, json.JSONDecodeError, CameraFixError) as exc:
        return BackupValidation(False, True, str(exc), backup_path, manifest_path)


def _fsync_directory(directory: Path) -> None:
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    try:
        descriptor = os.open(directory, flags)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    except OSError:
        # Atomic rename is still authoritative; not every mounted filesystem
        # permits directory fsync from an unprivileged process.
        pass


def _write_exclusive(path: Path, data: bytes, mode: int = 0o600) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    try:
        view = memoryview(data)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise CameraFixError(f"Writing stopped unexpectedly: {path}")
            view = view[written:]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def snapshot_file(path: Path) -> FileSnapshot:
    details = path.stat()
    if not stat.S_ISREG(details.st_mode):
        raise CameraFixError(f"The target is no longer a regular file: {path}")
    return FileSnapshot(details.st_dev, details.st_ino, details.st_size, details.st_mtime_ns, sha256_file(path))


def ensure_snapshot(path: Path, expected: FileSnapshot) -> None:
    current = snapshot_file(path)
    if current != expected:
        raise CameraFixError(f"{TARGET_FILENAME} changed during preparation. Refusing to replace it.")


def create_original_backup(executable: Path) -> tuple[bool, BackupValidation]:
    inspection = inspect_executable(executable)
    if inspection.state != "Unpatched":
        raise CameraFixError(f"A new original backup may be created only from a completely unpatched supported executable. Current state: {inspection.state}.")
    existing = validate_backup(executable)
    if existing.exists:
        if existing.valid and existing.inspection and existing.inspection.sha256 == inspection.sha256:
            return False, existing
        if existing.valid:
            raise CameraFixError("A valid original backup exists but does not match this executable. It will not be overwritten.")
        raise CameraFixError(f"Backup sidecars exist but are not trustworthy: {existing.reason} They will not be overwritten.")

    backup_path, manifest_path = sidecar_paths(executable)
    snapshot = snapshot_file(executable)
    backup_created = False
    manifest_created = False
    try:
        _write_exclusive(backup_path, inspection.data)
        backup_created = True
        if sha256_file(backup_path) != inspection.sha256:
            raise CameraFixError("The new backup failed byte-for-byte SHA-256 verification.")
        ensure_snapshot(executable, snapshot)
        manifest = {
            "SchemaVersion": MANIFEST_SCHEMA,
            "Tool": TOOL_NAME,
            "OriginalFilename": TARGET_FILENAME,
            "FileVersion": inspection.pe.file_version,
            "Size": inspection.size,
            "SHA256": inspection.sha256,
            "StoredPEChecksum": f"0x{inspection.pe.stored_checksum:08X}",
            "CreatedUtc": _datetime.datetime.now(_datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
            "OriginalResolvedPath": os.fspath(executable.resolve()),
            "ManagerVersion": MANAGER_VERSION,
            "PatchCatalogueVersion": CATALOGUE.version,
        }
        manifest_data = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
        _write_exclusive(manifest_path, manifest_data)
        manifest_created = True
        _fsync_directory(executable.parent)
        validation = validate_backup(executable)
        if not validation.valid:
            raise CameraFixError(f"The new backup set failed validation: {validation.reason}")
        return True, validation
    except Exception:
        if backup_created and not manifest_created:
            try:
                backup_path.unlink()
            except OSError:
                pass
        raise


def _regions_from_original(inspection: Inspection) -> list[tuple[PatchDefinition, int]]:
    regions = []
    by_key = {patch.key: patch for patch in CATALOGUE.patches}
    for state in inspection.patterns:
        if state.classification != "Unpatched" or len(state.original_offsets) != 1:
            raise CameraFixError(f"Cannot establish an original region for {state.name}: {state.classification}.")
        regions.append((by_key[state.key], state.original_offsets[0]))
    regions.sort(key=lambda item: item[1])
    for index, (patch, offset) in enumerate(regions):
        if offset < 0 or offset + len(patch.original) > inspection.size:
            raise CameraFixError("A patch region lies outside the executable.")
        if index and regions[index - 1][1] + len(regions[index - 1][0].original) > offset:
            raise CameraFixError("Patch regions overlap.")
    return regions


def outside_region_sha256(data: bytes, regions: Sequence[tuple[PatchDefinition, int]]) -> str:
    digest = hashlib.sha256()
    cursor = 0
    for patch, offset in sorted(regions, key=lambda item: item[1]):
        if offset < cursor or offset + len(patch.original) > len(data):
            raise CameraFixError("Patch regions overlap or lie outside the executable.")
        digest.update(data[cursor:offset])
        cursor = offset + len(patch.original)
    digest.update(data[cursor:])
    return digest.hexdigest().upper()


def validate_understood_live_against_backup(live: Inspection, backup: Inspection) -> list[tuple[PatchDefinition, int]]:
    if live.state == "Unsupported":
        raise CameraFixError(f"The live executable is unsupported: {live.reason}")
    if live.size != backup.size:
        raise CameraFixError("The live executable size differs from the verified original backup.")
    regions = _regions_from_original(backup)
    live_states = {state.key: state for state in live.patterns}
    for patch, expected_offset in regions:
        state = live_states[patch.key]
        if state.classification not in ("Unpatched", "Patched"):
            raise CameraFixError(f"{state.name} is not in an understood state.")
        offsets = state.original_offsets if state.classification == "Unpatched" else state.patched_offsets
        if len(offsets) != 1 or offsets[0] != expected_offset:
            raise CameraFixError(f"{state.name} moved relative to the verified original backup.")
    if outside_region_sha256(live.data, regions) != outside_region_sha256(backup.data, regions):
        raise CameraFixError("The live executable contains changes outside the verified camera-patch regions.")
    return regions


def prepare_complete_patch(original: Inspection) -> tuple[bytes, list[tuple[PatchDefinition, int]], str]:
    regions = _regions_from_original(original)
    prepared = bytearray(original.data)
    for patch, offset in regions:
        if prepared[offset:offset + len(patch.original)] != patch.original:
            raise CameraFixError(f"Original bytes are wrong at the {patch.name} region.")
        prepared[offset:offset + len(patch.patched)] = patch.patched
    result = bytes(prepared)
    if len(result) != original.size or outside_region_sha256(result, regions) != outside_region_sha256(original.data, regions):
        raise CameraFixError("Prepared patch changed the file size or bytes outside the permitted regions.")
    verification = inspect_bytes(result, original.path)
    if verification.state != "CompletelyPatched":
        raise CameraFixError("Prepared patch did not produce one complete patched sequence for every fix.")
    return result, regions, verification.sha256


def _write_prepared_near(target: Path, data: bytes, prefix: str) -> Path:
    target_stat = target.stat()
    descriptor, temporary_name = tempfile.mkstemp(prefix=prefix, suffix=".tmp", dir=target.parent)
    temporary = Path(temporary_name)
    try:
        temporary_stat = os.fstat(descriptor)
        if temporary_stat.st_dev != target_stat.st_dev:
            raise CameraFixError("The temporary file is not on the target filesystem; atomic replacement is unavailable.")
        if hasattr(os, "fchmod"):
            os.fchmod(descriptor, stat.S_IMODE(target_stat.st_mode))
        else:
            os.chmod(temporary, stat.S_IMODE(target_stat.st_mode))
        if hasattr(os, "fchown") and (temporary_stat.st_uid, temporary_stat.st_gid) != (target_stat.st_uid, target_stat.st_gid):
            os.fchown(descriptor, target_stat.st_uid, target_stat.st_gid)
        view = memoryview(data)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise CameraFixError("Writing the prepared executable stopped unexpectedly.")
            view = view[written:]
        os.fsync(descriptor)
    except Exception:
        os.close(descriptor)
        try:
            temporary.unlink()
        except OSError:
            pass
        raise
    os.close(descriptor)
    prepared_stat = temporary.stat()
    if os.name == "posix" and stat.S_IMODE(prepared_stat.st_mode) != stat.S_IMODE(target_stat.st_mode):
        temporary.unlink(missing_ok=True)
        raise CameraFixError("The temporary executable did not preserve file permissions.")
    if os.name == "posix" and (prepared_stat.st_uid, prepared_stat.st_gid) != (target_stat.st_uid, target_stat.st_gid):
        temporary.unlink(missing_ok=True)
        raise CameraFixError("The temporary executable did not preserve file ownership.")
    return temporary


def _manifest_snapshot(path: Path) -> Optional[FileSnapshot]:
    return snapshot_file(path) if path.is_file() else None


def steam_update_reason(installation: Installation) -> Optional[str]:
    steamapps = installation.library / "steamapps"
    for candidate in (steamapps / "downloading" / str(CATALOGUE.steam_app_id), steamapps / "temp" / str(CATALOGUE.steam_app_id)):
        if candidate.exists():
            return f"Steam appears to be downloading or updating App ID {CATALOGUE.steam_app_id}: {candidate}"
    return None


def game_running(executable: Path, proc_root: Path = Path("/proc")) -> bool:
    target_bytes = os.fsencode(os.fspath(executable.resolve()))
    try:
        processes = list(proc_root.iterdir())
    except OSError:
        return False
    for process in processes:
        if not process.name.isdigit():
            continue
        try:
            command = (process / "cmdline").read_bytes().split(b"\x00")
            environment = (process / "environ").read_bytes().split(b"\x00")
        except OSError:
            continue
        if target_bytes in command:
            return True
        app_id_matches = any(item in (b"SteamAppId=203160", b"SteamGameId=203160", b"STEAM_COMPAT_APP_ID=203160") for item in environment)
        if app_id_matches:
            for argument in command:
                normalized = argument.replace(b"\\", b"/").rstrip(b"/")
                if normalized.rsplit(b"/", 1)[-1].lower() == b"tombraider.exe":
                    return True
    return False


def assert_directory_writable(directory: Path) -> None:
    probe: Optional[Path] = None
    try:
        descriptor, name = tempfile.mkstemp(prefix=".TombRaiderCameraFix-write-test-", suffix=".tmp", dir=directory)
        probe = Path(name)
        os.close(descriptor)
        probe.unlink()
    except OSError as exc:
        if probe is not None:
            try:
                probe.unlink()
            except OSError:
                pass
        raise CameraFixError(
            "The game directory is not writable. Check the library's mount ownership and permissions, then try again as your normal Steam user. Do not run this tool with sudo."
        ) from exc


def assert_operation_safe(installation: Installation) -> tuple[FileSnapshot, Optional[FileSnapshot]]:
    if game_running(installation.executable):
        raise CameraFixError("Tomb Raider appears to be running. Close the game and try again.")
    update_reason = steam_update_reason(installation)
    if update_reason:
        raise CameraFixError(update_reason + ". Wait for Steam to finish, then try again.")
    assert_directory_writable(installation.game_directory)
    return snapshot_file(installation.executable), _manifest_snapshot(installation.manifest)


def _recheck_operation_safe(installation: Installation, executable_snapshot: FileSnapshot, manifest_snapshot: Optional[FileSnapshot]) -> None:
    if game_running(installation.executable):
        raise CameraFixError("Tomb Raider started while the replacement was being prepared. Nothing was replaced.")
    update_reason = steam_update_reason(installation)
    if update_reason:
        raise CameraFixError(update_reason + ". Nothing was replaced.")
    ensure_snapshot(installation.executable, executable_snapshot)
    if _manifest_snapshot(installation.manifest) != manifest_snapshot:
        raise CameraFixError("Steam changed the app manifest during preparation. Nothing was replaced.")


def _transactional_replace(
    installation: Installation,
    prepared: Path,
    prepared_hash: str,
    executable_snapshot: FileSnapshot,
    manifest_snapshot: Optional[FileSnapshot],
    final_validator: Callable[[], None],
    failure_point: str,
) -> None:
    target = installation.executable
    rollback = _write_prepared_near(target, target.read_bytes(), ".TombRaiderCameraFix-rollback-")
    rollback_hash = sha256_file(rollback)
    replaced = False
    preserve_rollback = False
    try:
        if failure_point == "after_temp_write":
            raise CameraFixError("Simulated failure after temporary-file preparation.")
        _recheck_operation_safe(installation, executable_snapshot, manifest_snapshot)
        if sha256_file(prepared) != prepared_hash:
            raise CameraFixError("The prepared executable changed before replacement.")
        if failure_point == "before_replace":
            raise CameraFixError("Simulated failure before atomic replacement.")
        os.replace(prepared, target)
        replaced = True
        _fsync_directory(target.parent)
        if failure_point == "after_replace":
            raise CameraFixError("Simulated failure after atomic replacement.")
        final_validator()
        if failure_point == "after_final_verification":
            raise CameraFixError("Simulated failure after final verification.")
    except Exception as original_error:
        if replaced:
            try:
                os.replace(rollback, target)
                _fsync_directory(target.parent)
                replaced = False
                if sha256_file(target) != rollback_hash:
                    raise CameraFixError("The rollback hash does not match the pre-operation executable.")
            except Exception as rollback_error:
                preserve_rollback = True
                raise CameraFixError(f"The operation failed: {original_error}. Automatic rollback also failed: {rollback_error}. A verified rollback file remains at {rollback}.") from rollback_error
        raise
    finally:
        for temporary in (prepared, rollback):
            if temporary == rollback and preserve_rollback:
                continue
            try:
                if temporary.exists():
                    temporary.unlink()
            except OSError:
                pass


def apply_fix(installation: Installation, failure_point: str = "none") -> dict:
    live = inspect_executable(installation.executable)
    if live.state == "Unsupported":
        raise CameraFixError(f"Refusing to patch an unsupported executable. {live.reason}")
    if live.state == "CompletelyPatched":
        return {"changed": False, "message": "All three camera fixes are already applied.", "sha256": live.sha256}
    executable_snapshot, manifest_snapshot = assert_operation_safe(installation)
    backup_created = False
    if live.state == "Unpatched":
        backup_created, backup = create_original_backup(installation.executable)
        if failure_point == "after_backup":
            raise CameraFixError("Simulated failure after backup creation.")
    else:
        backup = validate_backup(installation.executable)
        if not backup.valid:
            raise CameraFixError(f"The executable is partly patched and no trustworthy original backup is available. {backup.reason}")
    assert backup.inspection is not None
    validate_understood_live_against_backup(live, backup.inspection)
    prepared_data, _, expected_hash = prepare_complete_patch(backup.inspection)
    prepared = _write_prepared_near(installation.executable, prepared_data, ".TombRaiderCameraFix-patch-")
    disk_inspection = inspect_executable(prepared, require_target_name=False)
    if disk_inspection.state != "CompletelyPatched" or disk_inspection.sha256 != expected_hash or disk_inspection.size != backup.inspection.size:
        prepared.unlink(missing_ok=True)
        raise CameraFixError("The temporary patched executable failed independent verification.")

    def final_validator() -> None:
        final = inspect_executable(installation.executable)
        if final.state != "CompletelyPatched" or final.sha256 != expected_hash or final.size != backup.inspection.size:
            raise CameraFixError("The live executable failed final post-replacement verification.")

    _transactional_replace(installation, prepared, expected_hash, executable_snapshot, manifest_snapshot, final_validator, failure_point)
    return {
        "changed": True,
        "message": "All three camera fixes were applied and verified.",
        "original_sha256": backup.inspection.sha256,
        "patched_sha256": expected_hash,
        "backup_created": backup_created,
    }


def restore_original(installation: Installation, failure_point: str = "none") -> dict:
    backup = validate_backup(installation.executable)
    if not backup.valid or not backup.inspection or not backup.manifest:
        raise CameraFixError(f"The original backup cannot be trusted, so restoration was refused. {backup.reason}")
    live = inspect_executable(installation.executable)
    if live.sha256 == backup.inspection.sha256:
        return {"changed": False, "message": f"{TARGET_FILENAME} already matches the recorded original byte for byte.", "sha256": live.sha256}
    validate_understood_live_against_backup(live, backup.inspection)
    executable_snapshot, manifest_snapshot = assert_operation_safe(installation)
    prepared = _write_prepared_near(installation.executable, backup.inspection.data, ".TombRaiderCameraFix-restore-")
    expected_hash = backup.inspection.sha256
    temporary_inspection = inspect_executable(prepared, require_target_name=False)
    if temporary_inspection.state != "Unpatched" or temporary_inspection.sha256 != expected_hash:
        prepared.unlink(missing_ok=True)
        raise CameraFixError("The temporary restore copy failed independent verification.")

    def final_validator() -> None:
        final = inspect_executable(installation.executable)
        if final.state != "Unpatched" or final.sha256 != expected_hash or final.size != backup.inspection.size:
            raise CameraFixError("The restored executable failed final verification.")

    _transactional_replace(installation, prepared, expected_hash, executable_snapshot, manifest_snapshot, final_validator, failure_point)
    return {"changed": True, "message": f"Original {TARGET_FILENAME} restored and verified byte for byte.", "sha256": expected_hash}


def format_status(installation: Installation) -> str:
    inspection = inspect_executable(installation.executable)
    backup = validate_backup(installation.executable)
    lines = [
        f"Selected executable: {installation.executable}",
        f"Steam installation: {installation.steam_type}",
        f"Steam App ID:      {CATALOGUE.steam_app_id}",
        f"Detected version:  {inspection.pe.file_version}",
        f"Current state:     {inspection.state}",
        f"SHA-256:           {inspection.sha256}",
    ]
    if inspection.reason:
        lines.append(f"Reason:             {inspection.reason}")
    for pattern in inspection.patterns:
        lines.append(f"  {pattern.name}: {pattern.classification} (original: {pattern.original_count}; patched: {pattern.patched_count})")
    if backup.valid and backup.inspection:
        lines.append(f"Original backup:   verified ({backup.inspection.sha256})")
    elif backup.exists:
        lines.append(f"Original backup:   present but not trusted ({backup.reason})")
    else:
        lines.append("Original backup:   not created yet")
    lines.extend(
        [
            "Proton validation: the supported Windows executable was checked directly.",
            "This tool does not change or conclusively detect Steam's compatibility selection.",
            "Launch the game through Steam with Proton enabled.",
        ]
    )
    return "\n".join(lines)


def ensure_linux_runtime() -> None:
    if sys.platform != "linux":
        raise CameraFixError("The Linux release must be run on Linux.")
    machine = platform.machine().casefold()
    if machine not in ("x86_64", "amd64"):
        raise CameraFixError(f"Only x86_64 desktop Linux is supported. Detected architecture: {machine or 'unknown'}.")
    get_euid = getattr(os, "geteuid", None)
    if get_euid is not None and get_euid() == 0:
        raise CameraFixError("Do not run this patcher as root or with sudo. Run it as your normal Steam user.")


def _write_installation_record(installation: Installation) -> None:
    for value in (installation.steam_type, os.fspath(installation.executable)):
        sys.stdout.buffer.write(os.fsencode(value) + b"\x00")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("command", choices=("discover", "resolve", "status", "apply", "restore"))
    parser.add_argument("--path")
    parser.add_argument("--nul", action="store_true")
    parser.add_argument(
        "--failure-point",
        default="none",
        choices=("none", "after_backup", "after_temp_write", "before_replace", "after_replace", "after_final_verification"),
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args(argv)
    try:
        ensure_linux_runtime()
        if args.command == "discover":
            installations, diagnostics = discover_installations()
            for diagnostic in diagnostics:
                print(diagnostic, file=sys.stderr)
            for installation in installations:
                _write_installation_record(installation)
            return 0
        if args.command == "resolve":
            if not args.path:
                raise CameraFixError("Manual resolution requires --path.")
            _write_installation_record(resolve_manual_installation(args.path))
            return 0
        if not args.path:
            raise CameraFixError(f"{args.command} requires --path.")
        installation = resolve_manual_installation(args.path)
        if args.command == "status":
            print(format_status(installation))
        elif args.command == "apply":
            result = apply_fix(installation, args.failure_point)
            print(result["message"])
            if result.get("changed"):
                print(f"Original SHA-256: {result['original_sha256']}")
                print(f"Patched SHA-256:  {result['patched_sha256']}")
        elif args.command == "restore":
            result = restore_original(installation, args.failure_point)
            print(result["message"])
            print(f"Original SHA-256: {result['sha256']}")
        return 0
    except (CameraFixError, OSError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
# END GENERATED SOURCE: src/CameraFixEngineLinux.py
__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON_END__
