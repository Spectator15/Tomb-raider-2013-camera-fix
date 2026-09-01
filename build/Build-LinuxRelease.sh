#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly repository_root
readonly interface_path="$repository_root/src/CameraFixInterfaceLinux.sh"
readonly engine_path="$repository_root/src/CameraFixEngineLinux.py"
readonly catalogue_path="$repository_root/src/CameraFixPatches.json"
readonly output_path=${1:-"$repository_root/TombRaider-Camera-Fix-Linux.sh"}

python3 - "$interface_path" "$engine_path" "$catalogue_path" "$output_path" <<'PYTHON'
import base64
import json
import os
import pathlib
import sys

interface_path, engine_path, catalogue_path, output_path = map(pathlib.Path, sys.argv[1:])
marker = "#__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON__"
ending = "__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON_END__"
placeholder = "__CAMERAFIX_PATCH_CATALOGUE_BASE64__"


def read_required(path):
    if not path.is_file():
        raise SystemExit(f"Required Linux release source is missing: {path}")
    data = path.read_bytes()
    if not data:
        raise SystemExit(f"Required Linux release source is empty: {path}")
    try:
        return data.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    except UnicodeDecodeError as exc:
        raise SystemExit(f"Required Linux release source is not UTF-8: {path}") from exc


interface = read_required(interface_path).rstrip("\n")
engine = read_required(engine_path).rstrip("\n")
catalogue_text = read_required(catalogue_path)
template_notice = "# Linux launcher source template for the generated one-file release."
generated_notice = "# GENERATED FILE: contributors should edit the Linux sources under src/."
try:
    json.loads(catalogue_text)
except json.JSONDecodeError as exc:
    raise SystemExit(f"Patch catalogue is invalid JSON: {exc}") from exc

if interface.splitlines().count(marker) != 1 or interface.splitlines().count(ending) != 1:
    raise SystemExit("The Linux interface template must contain exactly one Python marker and ending line.")
if interface.splitlines().count(template_notice) != 1:
    raise SystemExit("The Linux interface template must contain exactly one generated-file notice placeholder.")
if placeholder not in engine or engine.count(placeholder) != 1:
    raise SystemExit("The Linux engine must contain exactly one patch-catalogue placeholder.")
if marker in engine or ending in engine:
    raise SystemExit("Linux embedding markers may appear only in the interface template.")

catalogue_bytes = catalogue_text.encode("utf-8")
encoded_catalogue = base64.b64encode(catalogue_bytes).decode("ascii")
interface = interface.replace(template_notice, generated_notice)
engine = engine.replace(placeholder, encoded_catalogue)
generated_python = "\n".join(
    (
        "# BEGIN GENERATED SOURCE: src/CameraFixEngineLinux.py",
        engine,
        "# END GENERATED SOURCE: src/CameraFixEngineLinux.py",
    )
)
interface_lines = interface.splitlines()
marker_index = interface_lines.index(marker)
interface_lines[marker_index:marker_index + 1] = [marker, generated_python]
release = "\n".join(interface_lines) + "\n"

unresolved = ("__CAMERAFIX_", "@@CAMERAFIX_")
if any(value in release for value in unresolved):
    raise SystemExit("The generated Linux release contains an unresolved build marker.")
if release.splitlines().count(marker) != 1 or release.splitlines().count(ending) != 1:
    raise SystemExit("The generated Linux release has invalid embedding markers.")
if "\r" in release:
    raise SystemExit("The generated Linux release contains non-LF line endings.")
if os.path.isabs(str(interface_path)) and str(interface_path) in release:
    raise SystemExit("The generated Linux release contains a machine-specific source path.")

output_path = output_path.resolve()
if not output_path.parent.is_dir():
    raise SystemExit(f"Output directory does not exist: {output_path.parent}")
output_path.write_bytes(release.encode("utf-8"))
output_path.chmod(0o755)
print(f"Built: {output_path}")
PYTHON
