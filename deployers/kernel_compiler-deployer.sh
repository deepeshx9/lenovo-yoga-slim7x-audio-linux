#!/usr/bin/env bash

set -o pipefail

# --- Configuration & Variables ---
ROLLBACK_DIR="$(pwd)/rollback"
BUILD_DIR="$(pwd)/kernel_build"
REPO_DIR="$(pwd)/github_patch_repo"

WSA_DEST_PATH="sound/soc/codecs/wsa884x.c"
X1E_DEST_PATH="sound/soc/qcom/x1e80100.c" 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}        Snapdragon X Elite RC Kernel Deployer         ${NC}"
echo -e "${BLUE}=======================================================${NC}"

# --- Helper Functions ---

prompt_action() {
    local message="$1"
    while true; do
        read -p "$(echo -e "${YELLOW}${message} [y/n]: ${NC}")" yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

setup_directories() {
    echo -e "${BLUE}[*] Initializing working directories...${NC}"
    mkdir -p "$ROLLBACK_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$ROLLBACK_DIR/boot"
}

# --- Core Logic ---

setup_directories

# 1. Fetch Latest RC Kernel URL from kernel.org
if prompt_action "Fetch the latest Release Candidate (RC) kernel from kernel.org?"; then
    echo -e "${BLUE}[*] Querying kernel.org API for latest mainline/RC release...${NC}"
    
    KERNEL_URL=$(curl -s https://kernel.org/releases.json | grep -o '"download": "[^"]*"' | grep "tar.xz" | grep "rc" | head -n 1 | cut -d'"' -f4)
    
    if [ -z "$KERNEL_URL" ]; then
        echo -e "${YELLOW}[!] Active RC tag not parsed cleanly from JSON feed. Attempting fallback scraping...${NC}"
        KERNEL_URL=$(curl -s https://kernel.org/ | grep -A 2 "latest_mainline" | grep -o 'https://.*\.tar\.xz' | head -n 1)
    fi

    if [ -z "$KERNEL_URL" ]; then
        echo -e "${RED}[X] Failed to auto-resolve RC kernel URL from kernel.org. Exiting.${NC}"
        exit 1
    fi

    KERNEL_TARBALL=$(basename "$KERNEL_URL")
    
    echo -e "${GREEN}[+] Target Found: ${KERNEL_URL}${NC}"
    
    if prompt_action "Download and extract ${KERNEL_TARBALL}?"; then
        cd "$BUILD_DIR" || exit 1
        wget -c "$KERNEL_URL"
        
        echo -e "${BLUE}[*] Extracting kernel archive...${NC}"
        tar -xf "$KERNEL_TARBALL"
        
        KERNEL_SRC_DIR=$(tar -tf "$KERNEL_TARBALL" | head -n 1 | cut -d'/' -f1)
        echo -e "${GREEN}[+] Extracted Source Directory: ${BUILD_DIR}/${KERNEL_SRC_DIR}${NC}"
        cd ..
    else
        echo -e "${RED}[X] Kernel extraction aborted.${NC}"
        exit 1
    fi
else
    KERNEL_SRC_DIR=$(ls -d "$BUILD_DIR"/linux-* 2>/dev/null | head -n 1 | rev | cut -d'/' -f1 | rev)
    if [ -z "$KERNEL_SRC_DIR" ]; then
        echo -e "${RED}[X] No existing kernel source found in ${BUILD_DIR}. Exiting.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}[!] Skipping remote fetch. Using source inside ${BUILD_DIR}/${KERNEL_SRC_DIR}${NC}"
fi

# 2. Fetch files from GitHub and Replace Local Targets
if prompt_action "Fetch patch source files from GitHub and overwrite kernel driver targets?"; then
    GH_REPO_URL="https://github.com/deepeshx9/lenovo-yoga-slim7x-audio-linux.git"
    
    read -p "Press Enter to use default repo ($GH_REPO_URL) or paste a new URL: " USER_REPO
    GH_REPO_URL=${USER_REPO:-$GH_REPO_URL}
    
    if [ -d "$REPO_DIR" ]; then
        rm -rf "$REPO_DIR"
    fi
    
    echo -e "${BLUE}[*] Cloning repository...${NC}"
    git clone "$GH_REPO_URL" "$REPO_DIR"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}[X] Failed to clone patch repository.${NC}"
        exit 1
    fi

    SRC_WSA="$REPO_DIR/linux/${WSA_DEST_PATH}"
    SRC_X1E="$REPO_DIR/linux/${X1E_DEST_PATH}"

    if [ ! -f "$SRC_WSA" ] || [ ! -f "$SRC_X1E" ]; then
        echo -e "${RED}[X] Could not find the required source files at the expected repo paths.${NC}"
        echo -e "Expected WSA: $SRC_WSA"
        echo -e "Expected X1E: $SRC_X1E"
        exit 1
    fi

    FULL_KERNEL_PATH="$BUILD_DIR/$KERNEL_SRC_DIR"
    
    # Confirm exact local paths inside target tree
    echo -e "${YELLOW}Target paths inside kernel tree:${NC}"
    echo -e "WSA Driver Target: ${FULL_KERNEL_PATH}/${WSA_DEST_PATH}"
    echo -e "X1E Driver Target: ${FULL_KERNEL_PATH}/${X1E_DEST_PATH}"
    
    if prompt_action "Execute replacement and generate rollback checkpoints for these drivers?"; then
        if [ -f "${FULL_KERNEL_PATH}/${WSA_DEST_PATH}" ]; then
            cp "${FULL_KERNEL_PATH}/${WSA_DEST_PATH}" "$ROLLBACK_DIR/wsa884x.c.bak"
        fi
        if [ -f "${FULL_KERNEL_PATH}/${X1E_DEST_PATH}" ]; then
            cp "${FULL_KERNEL_PATH}/${X1E_DEST_PATH}" "$ROLLBACK_DIR/x1e80100.c.bak"
        fi
        
        # Copy over new files
        cp "$SRC_WSA" "${FULL_KERNEL_PATH}/${WSA_DEST_PATH}"
        cp "$SRC_X1E" "${FULL_KERNEL_PATH}/${X1E_DEST_PATH}"
        echo -e "${GREEN}[+] Replacement complete. Original files backed up to ./rollback/${NC}"
    else
        echo -e "${YELLOW}[!] Skipping source code modifications.${NC}"
    fi
fi

# 3. Handle Kernel Configuration (.config)
cd "$BUILD_DIR/$KERNEL_SRC_DIR" || exit 1

if prompt_action "Extract current machine configuration and prepare kernel .config?"; then
    echo -e "${BLUE}[*] Searching for reference kernel configuration...${NC}"
    
    if [ -f "/proc/config.gz" ]; then
        zcat /proc/config.gz > .config
        echo -e "${GREEN}[+] Config extracted via /proc/config.gz${NC}"
    elif [ -f "/boot/config-$(uname -r)" ]; then
        cp "/boot/config-$(uname -r)" .config
        echo -e "${GREEN}[+] Config copied from /boot/config-$(uname -r)${NC}"
    else
        echo -e "${YELLOW}[!] Running config not found. Generating default arm64 defconfig...${NC}"
        make defconfig
    fi
    
    cp .config "$ROLLBACK_DIR/kernel_config.bak"
fi

# 4. Modify Configuration Options (Secure Boot Stripping and Driver Enforcement)
if prompt_action "Modify .config to disable Secure Boot validation checks and enforce sound drivers?"; then
    echo -e "${BLUE}[*] De-authorizing local key-signing elements (Fixing Ubuntu downstream compiler traps)...${NC}"
    
    if [ -f "scripts/config" ]; then
        ./scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
        ./scripts/config --set-str SYSTEM_REVOCATION_KEYS ""
        ./scripts/config --undefine MODULE_SIG_KEY
        ./scripts/config --disable MODULE_SIG_ALL
        
        # Enforce required Snapdragon Audio / Soundwire driver pipelines
        ./scripts/config --enable SOUNDWIRE
        ./scripts/config --enable SOUNDWIRE_QCOM
        ./scripts/config --module SND_SOC_WSA884X
        ./scripts/config --module SND_SOC_QCOM_X1E80100
    else
        sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config
        sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config
        sed -i 's/CONFIG_MODULE_SIG_KEY=.*/# CONFIG_MODULE_SIG_KEY is not set/g' .config
        echo "CONFIG_SOUNDWIRE=y" >> .config
        echo "CONFIG_SOUNDWIRE_QCOM=m" >> .config
        echo "CONFIG_SND_SOC_WSA884X=m" >> .config
        echo "CONFIG_SND_SOC_QCOM_X1E80100=m" >> .config
    fi
    
    echo -e "${BLUE}[*] Re-generating configuration state via make olddefconfig...${NC}"
    make olddefconfig
    echo -e "${GREEN}[+] Core configuration finalized.${NC}"
fi

# 5. Compilation Phase
if prompt_action "Begin compiling the new kernel? (This takes significant time)"; then
    THREADS=$(nproc)
    echo -e "${BLUE}[*] Compiling kernel and system modules using ${THREADS} threads...${NC}"
    
    make -j"$THREADS"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[X] Kernel compilation failed.${NC}"
        if prompt_action "Roll back modified source configurations?"; then
            cp "$ROLLBACK_DIR/wsa884x.c.bak" "${WSA_DEST_PATH}" 2>/dev/null
            cp "$ROLLBACK_DIR/x1e80100.c.bak" "${X1E_DEST_PATH}" 2>/dev/null
            echo -e "${GREEN}[+] Changes restored to pre-patch state.${NC}"
        fi
        exit 1
    fi
    echo -e "${GREEN}[+] Compilation Phase Successful.${NC}"
fi

# 6. Deployment Phase
DEPLOY_SUCCESS=0

if prompt_action "Attempt standard kernel installation via 'make install'?"; then
    echo -e "${BLUE}[*] Executing elevated modules_install...${NC}"
    sudo make modules_install
    
    echo -e "${BLUE}[*] Executing elevated core install...${NC}"
    sudo make install
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Traditional installation completed successfully.${NC}"
        DEPLOY_SUCCESS=1
    else
        echo -e "${YELLOW}[!] 'make install' routine failed or not fully supported on this distribution layout.${NC}"
    fi
fi

# Manual Deployment Fallback Routine
if [ $DEPLOY_SUCCESS -eq 0 ]; then
    if prompt_action "Fallback to direct deployment path (manual file injection to /boot)?"; then
        KERNEL_VERSION=$(make kernelrelease)
        echo -e "${BLUE}[*] Target Release Identity detected as: ${KERNEL_VERSION}${NC}"
        
        if [ -f "/boot/vmlinuz-${KERNEL_VERSION}" ]; then
            cp "/boot/vmlinuz-${KERNEL_VERSION}" "$ROLLBACK_DIR/boot/vmlinuz-${KERNEL_VERSION}.bak"
        fi
        if [ -f "/boot/initrd.img-${KERNEL_VERSION}" ]; then
            cp "/boot/initrd.img-${KERNEL_VERSION}" "$ROLLBACK_DIR/boot/initrd.img-${KERNEL_VERSION}.bak"
        fi

        echo -e "${BLUE}[*] Performing staging install of modules...${NC}"
        sudo make modules_install

        echo -e "${BLUE}[*] Injecting core kernel image into /boot...${NC}"
        if [ -f "arch/arm64/boot/Image" ]; then
            sudo cp arch/arm64/boot/Image "/boot/vmlinuz-${KERNEL_VERSION}"
        elif [ -f "arch/arm64/boot/vmlinuz.efi" ]; then
            sudo cp arch/arm64/boot/vmlinuz.efi "/boot/vmlinuz-${KERNEL_VERSION}"
        else
            echo -e "${RED}[X] Could not locate compiled image in standard build target trees.${NC}"
            exit 1
        fi

        # Dynamically build initrd matching current platform tools
        echo -e "${BLUE}[*] Detecting runtime initrd generator...${NC}"
        if command -v update-initramfs &> /dev/null; then
            echo -e "${BLUE}[*] Using update-initramfs platform engine...${NC}"
            sudo update-initramfs -c -k "${KERNEL_VERSION}"
        elif command -v dracut &> /dev/null; then
            echo -e "${BLUE}[*] Using dracut deployment engine...${NC}"
            sudo dracut --kver "${KERNEL_VERSION}" --force
        else
            echo -e "${YELLOW}[!] No standard automated initialization ramdisk builder found.${NC}"
            echo -e "${YELLOW}[!] You will need to build an initrd manually for image variant: ${KERNEL_VERSION}${NC}"
        fi

        echo -e "${GREEN}[+] Binary transfer stage completed.${NC}"
        echo -e "${YELLOW}[!] Manual Bootloader Configuration Required!${NC}"
        echo -e "${YELLOW}Ensure your GRUB, systemd-boot, or custom device-tree initialization configuration targets:${NC}"
        echo -e "Kernel Path:  /boot/vmlinuz-${KERNEL_VERSION}"
        echo -e "Initrd Path:  /boot/initrd.img-${KERNEL_VERSION} (if successfully generated)"
    else
        echo -e "${RED}[X] Core deployment sequence terminated by operator.${NC}"
    fi
fi

echo -e "${BLUE}=======================================================${NC}"
echo -e "${GREEN}             Execution Sequence Concluded             ${NC}"
echo -e "${BLUE}=======================================================${NC}"