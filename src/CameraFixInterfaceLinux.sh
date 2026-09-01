#!/usr/bin/env bash
# Linux launcher source template for the generated one-file release.
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
# shellcheck disable=SC2329
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
__TOMB_RAIDER_CAMERA_FIX_LINUX_PYTHON_END__
