#!/usr/bin/env bash
# ==============================================================================
# ALSA, UCM, PipeWire & EasyEffects Configurator for Lenovo Yoga Slim 7X
# Repository: https://github.com/master2619/lenovo-yoga-slim7x-audio-linux
# ==============================================================================

# Strict bash execution parameters
set -euo pipefail

# --- Visual Output Parameters ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAGENTA='\033[0;35m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

# --- Configuration & System Paths ---
REPO_URL="https://github.com/deepeshx9/lenovo-yoga-slim7x-audio-linux.git"
TMP_DIR=$(mktemp -d -t alsa-yoga-XXXXXX)
TIMESTAMP=$(date +%s)
ROLLBACK_LOG="/tmp/yoga_audio_rollback_${TIMESTAMP}.log"
RUN_LOG="/tmp/yoga_audio_install_${TIMESTAMP}.log"

# Directories
UCM_BASE_DIR="/usr/share/alsa/ucm2"
QCOM_DIR="${UCM_BASE_DIR}/Qualcomm/x1e80100"
CARD_CONF_DIR="${UCM_BASE_DIR}/conf.d/X1E80100LENOVOY"
DSP_DIR="/usr/share/easyeffects/irs"
PW_CONF_DIR="/etc/pipewire/pipewire.conf.d"
WP_CONF_DIR="/etc/wireplumber/wireplumber.conf.d"

# Global State
GLOBAL_OVERWRITE=false
REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "root")}

# --- Helper Functions ---
log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" >> "$RUN_LOG"; }
echo_step() { echo -e "${C_CYAN}${C_BOLD}[*]${C_RESET} $1"; log "STEP: $1"; }
echo_success() { echo -e "${C_GREEN}${C_BOLD}[+]${C_RESET} $1"; log "SUCCESS: $1"; }
echo_warn() { echo -e "${C_YELLOW}${C_BOLD}[!]${C_RESET} $1"; log "WARN: $1"; }
echo_error() { echo -e "${C_RED}${C_BOLD}[x]${C_RESET} $1"; log "ERROR: $1"; }

ask_proceed() {
    local prompt_text="$1"
    echo ""
    while true; do
        read -p "$(echo -e ${C_MAGENTA}${C_BOLD}"? ${prompt_text} (y/n): "${C_RESET})" choice
        case "$choice" in
            [Yy]* ) log "User approved: $prompt_text"; return 0 ;;
            [Nn]* ) log "User denied: $prompt_text"; return 1 ;;
            * ) echo -e "${C_RED}Please answer yes (y) or no (n).${C_RESET}" ;;
        esac
    done
}

cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        log "Cleaned up temporary directory: $TMP_DIR"
    fi
}
trap cleanup EXIT

# --- Rollback Mechanism ---
rollback() {
    echo ""
    echo_warn "Initiating rollback sequence..."
    if [ ! -f "$ROLLBACK_LOG" ]; then
        echo_step "No rollback log found. Nothing to revert."
        return 0
    fi

    # Read log backwards to undo in reverse order
    while IFS= read -r line; do
        ACTION=$(echo "$line" | cut -d':' -f1)
        FILE_PATH=$(echo "$line" | cut -d':' -f2-)

        if [ "$ACTION" == "NEW" ]; then
            if [ -f "$FILE_PATH" ]; then
                rm -f "$FILE_PATH"
                echo_step "Removed newly created file: $FILE_PATH"
                log "ROLLBACK - Removed: $FILE_PATH"
            fi
        elif [ "$ACTION" == "OVERWRITTEN" ]; then
            if [ -f "${FILE_PATH}.bak" ]; then
                mv "${FILE_PATH}.bak" "$FILE_PATH"
                echo_step "Restored backup: $FILE_PATH"
                log "ROLLBACK - Restored: $FILE_PATH"
            fi
        elif [ "$ACTION" == "DIR_CREATED" ]; then
            # Only remove if directory is empty to avoid breaking system
            if [ -d "$FILE_PATH" ] && [ -z "$(ls -A "$FILE_PATH" 2>/dev/null)" ]; then
                rmdir "$FILE_PATH"
                echo_step "Removed empty created directory: $FILE_PATH"
                log "ROLLBACK - Removed Dir: $FILE_PATH"
            fi
        fi
    done < <(tac "$ROLLBACK_LOG" 2>/dev/null || tail -r "$ROLLBACK_LOG")
    
    echo_success "Rollback complete."
}

error_handler() {
    local line_no=$1
    echo ""
    echo_error "An unexpected error occurred at line $line_no!"
    log "CRITICAL ERROR at line $line_no"
    if ask_proceed "Do you want to roll back changes made so far?"; then
        rollback
    else
        echo_step "Keeping current state. Exiting."
    fi
    exit 1
}
trap 'error_handler ${LINENO}' ERR

# --- Smart Installation Logic ---
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "DIR_CREATED:$dir" >> "$ROLLBACK_LOG"
        echo_step "Created required directory: $dir"
        log "Created directory: $dir"
    fi
}

safe_install() {
    local src="$1"
    local dest_dir="$2"
    local dest_file="$dest_dir/$(basename "$src")"

    ensure_dir "$dest_dir"

    if [ -f "$dest_file" ]; then
        if [ "$GLOBAL_OVERWRITE" = false ]; then
            echo ""
            echo_warn "Conflict: ${C_BOLD}$(basename "$dest_file")${C_RESET} already exists in ${dest_dir}."
            while true; do
                read -p "$(echo -e ${C_YELLOW}"Overwrite this file? [y(yes) / n(no) / a(all)]: "${C_RESET})" ow_choice
                case "$ow_choice" in
                    [Aa]* ) GLOBAL_OVERWRITE=true; log "User chose OVERWRITE_ALL"; break ;;
                    [Yy]* ) break ;;
                    [Nn]* ) echo_step "Skipped $(basename "$src")"; log "Skipped $dest_file"; return 0 ;;
                    * ) echo -e "${C_RED}Please answer y, n, or a.${C_RESET}" ;;
                esac
            done
        fi
        
        cp -a "$dest_file" "${dest_file}.bak"
        echo "OVERWRITTEN:$dest_file" >> "$ROLLBACK_LOG"
        echo_step "Overwrote & Backed up to: ${dest_file}.bak"
        log "Backed up and Overwrote $dest_file"
    else
        echo "NEW:$dest_file" >> "$ROLLBACK_LOG"
        echo_step "Installed new file: $dest_file"
    fi

    cp "$src" "$dest_file"
    log "Installed $src to $dest_file"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

clear
echo -e "${C_BLUE}${C_BOLD}"
echo "=========================================================================="
echo "    Lenovo Yoga Slim 7X (X1E80100) Audio Enablement CLI Wizard            "
echo "    Configures: ALSA UCM, PipeWire, WirePlumber, and DSP/EasyEffects      "
echo "=========================================================================="
echo -e "${C_RESET}"

# 1. Pre-flight checks
if [ "$EUID" -ne 0 ]; then
    echo_error "Root privileges required."
    echo_step "Please re-run with: sudo $0"
    exit 1
fi

touch "$ROLLBACK_LOG" "$RUN_LOG"
log "--- New Installation Session Started ---"
log "Targeting User Session: $REAL_USER"

# 2. Start Wizard
if ! ask_proceed "Begin the Audio Setup Wizard for X1E80100"; then
    echo_error "Aborted by user."
    exit 0
fi

# 3. Clone Repository
if ask_proceed "Download latest audio files from GitHub repository"; then
    echo_step "Fetching repository..."
    if git clone --quiet "$REPO_URL" "$TMP_DIR/repo"; then
        echo_success "Repository cloned successfully."
    else
        echo_error "Failed to clone repository. Check internet connection."
        exit 1
    fi
else
    echo_error "Repository is required to proceed. Aborting."
    exit 1
fi

cd "$TMP_DIR/repo"

# 4. ALSA Configuration
if ask_proceed "Install and map ALSA UCM Topology files"; then
    echo_step "Deploying ALSA configs..."
    
    if [ -f "X1E80100LENOVOY.conf" ]; then
        safe_install "X1E80100LENOVOY.conf" "$CARD_CONF_DIR"
    else
        echo_warn "Main card config X1E80100LENOVOY.conf not found."
    fi

    for conf_file in *.conf; do
        [ "$conf_file" == "X1E80100LENOVOY.conf" ] && continue
        # Filter out obvious pipewire/wireplumber files from ALSA dir
        if [[ ! "$conf_file" =~ pipewire|wireplumber ]]; then
            safe_install "$conf_file" "$QCOM_DIR"
        fi
    done
    
    if [ -f "alsa_controls.txt" ]; then safe_install "alsa_controls.txt" "$QCOM_DIR"; fi
    echo_success "ALSA topology mapped."
fi

# 5. PipeWire & WirePlumber Configuration
if ask_proceed "Install and link PipeWire and WirePlumber audio routing files"; then
    echo_step "Verifying directories and deploying PipeWire/WirePlumber configs..."
    
    # We will search the repo for configs explicitly meant for pw/wp
    PW_FOUND=0
    for conf_file in *.conf; do
        if [[ "$conf_file" =~ "pipewire" ]]; then
            safe_install "$conf_file" "$PW_CONF_DIR"
            PW_FOUND=1
        elif [[ "$conf_file" =~ "wireplumber" ]]; then
            safe_install "$conf_file" "$WP_CONF_DIR"
            PW_FOUND=1
        fi
    done

    if [ $PW_FOUND -eq 0 ]; then
        echo_step "No explicit PipeWire/WirePlumber overrides found in repo. (ALSA UCM will be used directly by PipeWire)."
    else
        echo_success "PipeWire / WirePlumber routing configured."
    fi
fi

# 6. EasyEffects & DSP Initialization
if ask_proceed "Install DSP Filters and EasyEffects Impulse Responses (IRS)"; then
    echo_step "Deploying IRS and WAV filter files..."
    
    DSP_FOUND=0
    for dsp_file in *.irs *.wav; do
        if [ -f "$dsp_file" ]; then
            safe_install "$dsp_file" "$DSP_DIR"
            DSP_FOUND=1
        fi
    done
    
    if [ $DSP_FOUND -eq 1 ]; then
        echo_success "DSP Filters linked to EasyEffects path: $DSP_DIR"
    else
        echo_step "No DSP filters (.irs/.wav) found in repo to deploy."
    fi
fi

# 7. Service Reloads & Connections
echo ""
echo -e "${C_BLUE}==========================================================================${C_RESET}"
echo_step "File deployment complete. Ready to initialize audio subsystems."

if ask_proceed "Restart audio services to apply all configurations now (Recommended)"; then
    
    # Reload ALSA
    echo_step "Reloading ALSA state..."
    alsactl restore &>/dev/null || echo_warn "Audio locked by current process, ALSA will load on reboot."
    
    # Reload PipeWire/WirePlumber for the active user
    if [ "$REAL_USER" != "root" ]; then
        USER_UID=$(id -u "$REAL_USER")
        USER_RUNTIME="/run/user/$USER_UID"
        
        echo_step "Restarting PipeWire ecosystem for user: $REAL_USER"
        sudo -u "$REAL_USER" XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user daemon-reload || true
        
        if sudo -u "$REAL_USER" XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user restart wireplumber pipewire pipewire-pulse; then
            echo_success "PipeWire and WirePlumber successfully restarted and linked."
        else
            echo_error "Failed to restart user audio services. A reboot is required."
        fi
        
        # Poke EasyEffects to reload if installed
        if command -v easyeffects &> /dev/null; then
            echo_step "Attempting to restart EasyEffects background service..."
            sudo -u "$REAL_USER" easyeffects --quit &>/dev/null || true
            sleep 1
            sudo -u "$REAL_USER" easyeffects --gapplication-service &>/dev/null &
            echo_success "EasyEffects instructed to load new filters."
        fi
    else
        echo_warn "Running strictly as root with no active user session. Please reboot to apply PipeWire changes."
    fi
fi

# 8. Finalize
echo ""
echo_success "Wizard Completed Successfully."
echo_step "Logs saved to: $RUN_LOG"
echo_step "If everything sounds good, no further action is required!"
echo ""

if ask_proceed "Wait, did this break your audio? Do you want to ROLLBACK everything"; then
    rollback
    if [ "$REAL_USER" != "root" ]; then
        USER_UID=$(id -u "$REAL_USER")
        sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user restart wireplumber pipewire &>/dev/null || true
    fi
    echo_step "System returned to original state."
else
    echo_step "Changes kept. You may want to reboot your system for full hardware initialization."
fi

exit 0
