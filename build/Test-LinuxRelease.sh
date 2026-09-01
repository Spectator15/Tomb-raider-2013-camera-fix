#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly repository_root
readonly build_script="$repository_root/build/Build-LinuxRelease.sh"
readonly release_path="$repository_root/TombRaider-Camera-Fix-Linux.sh"
readonly marker='#__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON__'
readonly ending='__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON_END__'
readonly source_begin='# BEGIN GENERATED SOURCE: src/CameraFixEngineLinux.py'
readonly source_end='# END GENERATED SOURCE: src/CameraFixEngineLinux.py'
test_root=$(mktemp -d "${TMPDIR:-/tmp}/TombRaiderCameraFixLinuxReleaseTests.XXXXXXXXXX")
readonly test_root

cleanup() {
    local resolved_test_root resolved_temp_root
    resolved_test_root=$(realpath -- "$test_root")
    resolved_temp_root=$(realpath -- "${TMPDIR:-/tmp}")
    case $resolved_test_root in
        "$resolved_temp_root"/TombRaiderCameraFixLinuxReleaseTests.*)
            rm -f -- \
                "$resolved_test_root/first.sh" \
                "$resolved_test_root/second.sh" \
                "$resolved_test_root/embedded.py" \
                "$resolved_test_root/engine.pyc" \
                "$resolved_test_root/tests.pyc" \
                "$resolved_test_root/embedded.pyc"
            rmdir -- "$resolved_test_root"
            ;;
        *)
            printf 'Refusing to remove unexpected test directory: %s\n' "$resolved_test_root" >&2
            return 1
            ;;
    esac
}
trap cleanup EXIT

python3 - "$repository_root" "$test_root" <<'PYTHON'
import pathlib
import py_compile
import sys

repository = pathlib.Path(sys.argv[1])
temporary = pathlib.Path(sys.argv[2])
py_compile.compile(repository / "src/CameraFixEngineLinux.py", cfile=temporary / "engine.pyc", doraise=True)
py_compile.compile(repository / "tests/test_linux.py", cfile=temporary / "tests.pyc", doraise=True)
PYTHON

"$build_script" "$test_root/first.sh"
"$build_script" "$test_root/second.sh"
cmp --silent "$test_root/first.sh" "$test_root/second.sh"
cmp --silent "$test_root/first.sh" "$release_path"
printf 'PASS  Linux release builds deterministically and matches the committed file\n'

if grep -q $'\r' "$release_path"; then
    printf 'Generated Linux release contains CR line endings.\n' >&2
    exit 1
fi
[[ -x $release_path ]]
[[ $(grep -Fxc -- "$marker" "$release_path") -eq 1 ]]
[[ $(grep -Fxc -- "$ending" "$release_path") -eq 1 ]]
[[ $(grep -Fxc -- '# GENERATED FILE: contributors should edit the Linux sources under src/.' "$release_path") -eq 1 ]]
marker_line=$(grep -Fnx -- "$marker" "$release_path" | cut -d: -f1)
source_begin_line=$(grep -Fnx -- "$source_begin" "$release_path" | cut -d: -f1)
source_end_line=$(grep -Fnx -- "$source_end" "$release_path" | cut -d: -f1)
ending_line=$(grep -Fnx -- "$ending" "$release_path" | cut -d: -f1)
(( marker_line < source_begin_line && source_begin_line < source_end_line && source_end_line < ending_line ))
if grep -Eq '__CAMERAFIX_|@@CAMERAFIX_' "$release_path"; then
    printf 'Generated Linux release contains an unresolved marker.\n' >&2
    exit 1
fi
if grep -Eq '([A-Za-z]:\\Users\\|/home/[^/]+/|github_pat_|gho_)' "$release_path"; then
    printf 'Generated Linux release contains a machine-specific path or credential-like value.\n' >&2
    exit 1
fi
printf 'PASS  Linux release uses LF, is executable, and has resolved markers\n'

awk -v marker="$marker" -v ending="$ending" '
    $0 == ending { if (found) exit }
    found { print }
    $0 == marker { found = 1 }
' "$release_path" > "$test_root/embedded.py"
python3 - "$test_root/embedded.py" "$test_root/embedded.pyc" <<'PYTHON'
import py_compile
import sys

py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)
PYTHON
bash -n "$repository_root/src/CameraFixInterfaceLinux.sh"
bash -n "$repository_root/build/Build-LinuxRelease.sh"
bash -n "$repository_root/build/Test-LinuxRelease.sh"
bash -n "$release_path"
shellcheck \
    "$repository_root/src/CameraFixInterfaceLinux.sh" \
    "$repository_root/build/Build-LinuxRelease.sh" \
    "$repository_root/build/Test-LinuxRelease.sh" \
    "$release_path"
printf 'PASS  Python, Bash, embedded source, and ShellCheck validation\n'

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v tests.test_linux
"$release_path" --help >/dev/null
printf 'PASS  Generated Linux launcher help entry point\n'

if find "$repository_root" -type f \( -iname 'TombRaider.exe' -o -iname 'steam_api.dll' \) -print -quit | grep -q .; then
    printf 'A game executable or DLL is present in the repository.\n' >&2
    exit 1
fi
printf 'PASS  Repository contains no TombRaider.exe or steam_api.dll\n'
