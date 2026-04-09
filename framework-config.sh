#!/usr/bin/env bash
# ==============================================================================
# ALSA, UCM, and PipeWire Configurator for Lenovo Yoga Slim 7X (X1E80100)
# Repository: https://github.com/master2619/lenovo-yoga-slim7x-audio-linux
# ==============================================================================

# Strict bash execution parameters for maximum robustness
set -euo pipefail

# --- Visual Output Parameters ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

# --- Configuration & System Paths ---
REPO_URL="https://github.com/master2619/lenovo-yoga-slim7x-audio-linux.git"
TMP_DIR=$(mktemp -d -t alsa-yoga-XXXXXX)
TIMESTAMP=$(date +%s)
ROLLBACK_LOG="/tmp/yoga_audio_rollback_${TIMESTAMP}.log"
RUN_LOG="/tmp/yoga_audio_install_${TIMESTAMP}.log"

# ALSA Paths
UCM_BASE_DIR="/usr/share/alsa/ucm2"
QCOM_DIR="${UCM_BASE_DIR}/Qualcomm/x1e80100"
CARD_CONF_DIR="${UCM_BASE_DIR}/conf.d/X1E80100LENOVOY"

# DSP / PipeWire / WirePlumber Paths
DSP_DIR="/usr/share/easyeffects/irs"               # Standard system dir for Impulse Responses
PW_CONF_DIR="/etc/pipewire/pipewire.conf.d"        # System-wide PipeWire drop-ins
WP_CONF_DIR="/etc/wireplumber/wireplumber.conf.d"  # System-wide WirePlumber drop-ins

# --- Helper Functions ---
log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" >> "$RUN_LOG"; }
echo_step() { echo -e "${C_CYAN}${C_BOLD}[*]${C_RESET} $1"; log "STEP: $1"; }
echo_success() { echo -e "${C_GREEN}${C_BOLD}[+]${C_RESET} $1"; log "SUCCESS: $1"; }
echo_warn() { echo -e "${C_YELLOW}${C_BOLD}[!]${C_RESET} $1"; log "WARN: $1"; }
echo_error() { echo -e "${C_RED}${C_BOLD}[x]${C_RESET} $1"; log "ERROR: $1"; }

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
        fi
    done < <(tac "$ROLLBACK_LOG" 2>/dev/null || tail -r "$ROLLBACK_LOG") # Reverse order rollback
    
    echo_success "Rollback complete."
}

# Trap errors to offer rollback automatically on failure
error_handler() {
    local line_no=$1
    echo ""
    echo_error "An unexpected error occurred at line $line_no!"
    read -p "$(echo -e ${C_YELLOW}"Do you want to roll back changes made so far? (y/N): "${C_RESET})" choice
    case "$choice" in 
        y|Y ) rollback ;;
        * ) echo_step "Keeping current state. Temporary files cleaned up." ;;
    esac
    exit 1
}
trap 'error_handler ${LINENO}' ERR

# --- Smart Deployment Logic ---
safe_install() {
    local src="$1"
    local dest_dir="$2"
    local dest_file="$dest_dir/$(basename "$src")"

    # Create destination directory if it doesn't exist
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
        log "Created directory: $dest_dir"
    fi

    if [ -f "$dest_file" ]; then
        # Check if contents are identical to avoid unnecessary backups
        if cmp -s "$src" "$dest_file"; then
            echo_step "Skipping $(basename "$src") - identical file already exists."
            return 0
        fi
        
        cp -a "$dest_file" "${dest_file}.bak"
        echo "OVERWRITTEN:$dest_file" >> "$ROLLBACK_LOG"
        echo_step "Backed up & Overwrote: $dest_file"
        log "Backed up $dest_file to ${dest_file}.bak"
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
echo "============================================================"
echo "    Lenovo Yoga Slim 7X (X1E80100) Audio Enablement         "
echo "    Advanced Installer: ALSA + PipeWire + DSP Filters       "
echo "============================================================"
echo -e "${C_RESET}"

# 1. Pre-flight checks
if [ "$EUID" -ne 0 ]; then
    echo_error "This script requires root privileges to modify system audio paths."
    echo_step "Please re-run with: sudo $0"
    exit 1
fi

REQUIRED_CMDS=("git" "systemctl" "alsactl")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo_error "Required command '$cmd' not found. Please install it."
        exit 1
    fi
done

touch "$ROLLBACK_LOG" "$RUN_LOG"
echo_step "Logs initialized."
log "Starting installation process."

# 2. User Confirmation
echo ""
echo_warn "This script will deploy experimental audio and DSP configurations."
echo_warn "Target directories include:"
echo "  - ALSA: /usr/share/alsa/ucm2"
echo "  - DSP:  $DSP_DIR"
echo "  - PipeWire: $PW_CONF_DIR & $WP_CONF_DIR"
echo ""
read -p "$(echo -e ${C_GREEN}${C_BOLD}"Are you sure you want to proceed? (y/N): "${C_RESET})" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo_error "Aborted by user."
    exit 0
fi

echo ""

# 3. Clone Repository
echo_step "Fetching repository from GitHub..."
if ! git clone --quiet "$REPO_URL" "$TMP_DIR/repo"; then
    echo_error "Failed to clone repository. Check your internet connection."
    exit 1
fi
echo_success "Repository cloned successfully."

# 4. Extract and Place Files (Smart Routing)
echo_step "Analyzing and deploying configuration files..."
cd "$TMP_DIR/repo"

# 4.a ALSA UCM Topology Routing
if [ -f "X1E80100LENOVOY.conf" ]; then
    safe_install "X1E80100LENOVOY.conf" "$CARD_CONF_DIR"
else
    echo_warn "X1E80100LENOVOY.conf not found. Topology may be incomplete."
fi

for conf_file in *.conf; do
    # Skip the main card config
    [ "$conf_file" == "X1E80100LENOVOY.conf" ] && continue
    
    # Route PipeWire / WirePlumber specific configs if they exist
    if [[ "$conf_file" == *"pipewire"* ]]; then
        safe_install "$conf_file" "$PW_CONF_DIR"
    elif [[ "$conf_file" == *"wireplumber"* ]]; then
        safe_install "$conf_file" "$WP_CONF_DIR"
    else
        # Default fallback for sequence and component configs is the Qualcomm ALSA dir
        safe_install "$conf_file" "$QCOM_DIR"
    fi
done

# 4.b DSP & Impulse Response Routing
for dsp_file in *.irs *.wav; do
    # Check if the glob actually matched files (avoids *.irs literal if none exist)
    if [ -f "$dsp_file" ]; then
        safe_install "$dsp_file" "$DSP_DIR"
    fi
done

# 4.c Extras
if [ -f "alsa_controls.txt" ]; then 
    safe_install "alsa_controls.txt" "$QCOM_DIR"
fi

echo_success "File deployment completed."

# 5. Service Reloads
echo ""
echo_step "Applying configurations to audio services..."

# Reload ALSA state globally
if alsactl restore &>/dev/null; then
    echo_success "ALSA state restored."
else
    echo_warn "Could not apply ALSA state immediately (normal if audio is currently locked)."
fi

# Attempt to restart user-level PipeWire/WirePlumber services intelligently
if [ -n "${SUDO_USER:-}" ]; then
    echo_step "Restarting PipeWire & WirePlumber for user: $SUDO_USER"
    sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" systemctl --user daemon-reload
    sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" systemctl --user restart wireplumber pipewire pipewire-pulse || echo_warn "Failed to restart PipeWire automatically."
else
    echo_warn "Could not detect SUDO_USER. You may need to manually restart PipeWire."
fi

# 6. Finalize
echo ""
echo_success "Installation Complete."
echo_step "Execution log saved to: $RUN_LOG"
echo_step "A system reboot is highly recommended to ensure all DSP modules initialize cleanly."
echo ""

# Post-install option to rollback immediately
read -p "$(echo -e ${C_YELLOW}"Test your audio. Does it sound broken? Do you want to rollback right now? (y/N): "${C_RESET})" rb_choice
if [[ "$rb_choice" =~ ^[Yy]$ ]]; then
    rollback
    # Attempt to restart services after rollback
    [ -n "${SUDO_USER:-}" ] && sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" systemctl --user restart wireplumber pipewire pipewire-pulse &>/dev/null
else
    echo_step "Installation finalized. Enjoy your audio!"
fi

exit 0
