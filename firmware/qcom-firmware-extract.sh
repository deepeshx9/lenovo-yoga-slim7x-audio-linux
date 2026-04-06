#!/bin/bash

set -e
set -u

WIN_FW_PATH="Windows/System32/DriverStore/FileRepository"

search_path=""
while getopts ":d:" opt; do
	case ${opt} in
		d)
			search_path="${OPTARG}"
			;;
		?)
			exit 1
			;;
	esac
done

device_model="$(tr -d '\0' </proc/device-tree/model)"
case "$device_model" in
	"Acer Swift 14 AI (SF14-11)")
		device_path="ACER/SF14-11"
		;;
	"ASUS Vivobook S 15")
		device_path="ASUSTeK/vivobook-s15"
		;;
	"Dell XPS 13 9345")
		device_path="dell/xps13-9345"
		;;
	"HP Omnibook X 14")
		device_path="hp/omnibook-x14"
		;;
	"Lenovo ThinkPad T14s Gen 6")
		device_path="LENOVO/21N1"
		;;
	"Lenovo Yoga Slim 7x")
		device_path="LENOVO/83ED"
		;;
	"Microsoft Surface Laptop 7 (13.8 inch)")
		device_path="microsoft/Romulus"
		;;
	"Samsung Galaxy Book4 Edge")
		device_path="SAMSUNG/galaxy-book4-edge"
		;;
	*)
		printf "error: Device is currently not supported" >&2
		;;
esac

device_canonical=$(echo "$device_path" | \
  tr '[:upper:]' '[:lower:]' | tr -d '-' | tr '/' '-')

tmpdir="$(mktemp -p /tmp -d fwfetch.XXXXXXXX)"
mkdir -p "$tmpdir/dislocker"
mkdir -p "$tmpdir/mnt"

function cleanup {
	umount -qRf "$tmpdir/mnt"
	umount -qRf "$tmpdir/dislocker"
	rm -rf "$tmpdir"
}
trap cleanup EXIT

# Find BitLocker Partition on NVME
part=$(lsblk -l -o NAME,FSTYPE | grep nvme0n1 | grep BitLocker | cut -d" " -f1)

# If we cant find a non-bitlocker'd part, pick the first ntfs part and try to mount
nobitlocker=0
if [ -z "$part" ]; then
	part=$(lsblk -l -o NAME,FSTYPE | grep -E -m 1 "(^nvme[0-9]n[0-9]p[0-9]{1,2}\s+ntfs$)" | cut -d" " -f1)
	nobitlocker=1
fi

if [ -z "$part" ]; then
	printf "error: Failed to find windows partition" >&2
	exit 1
fi

if [ -z "$search_path" ]; then
	echo "Mounting Windows partition ${part}..."
	# Decrypt and mount
	if [ "$nobitlocker" -eq 0 ]; then
		dislocker --readonly "/dev/$part" -- "$tmpdir/dislocker"
		mount -t ntfs-3g -oloop,ro "$tmpdir/dislocker/dislocker-file" "$tmpdir/mnt"
	fi
	if [ "$nobitlocker" -eq 1 ]; then
		mount -t ntfs-3g -o ro "/dev/$part" "$tmpdir/mnt"
	fi
	search_path="${tmpdir}/mnt/${WIN_FW_PATH}"
fi

# Create Package boilerplate
pkgver="$(date +'%Y%m%d')"
pkgname="qcom-x1e-firmware-extracted-${device_canonical}"
pkgpath="${tmpdir}/${pkgname}"
mkdir -p "${pkgpath}"
fw_install_path="/lib/firmware/updates/qcom/x1e80100/${device_path}"

cat <<EOF> "${pkgpath}/qcom-x1e-firmware-extracted-${device_canonical}.spec"
Name: qcom-x1e-firmware-extracted-${device_canonical}
Version: ${pkgver}
Release:  1%{?dist}
Summary: Extracted Snapdragon X Elite firmware for ${device_model}
License: LicenseRef-Undefined
BuildArch:  aarch64
Source0: adsp_dtbs.elf
Source1: adspr.jsn
Source2: adsps.jsn
Source3: adspua.jsn
Source4: battmgr.jsn
Source5: cdsp_dtbs.elf
Source6: cdspr.jsn
Source7: qcadsp8380.mbn
Source8: qccdsp8380.mbn
Source9: qcdxkmsuc8380.mbn

%global source_date_epoch_from_changelog 0

%description
Extracted Snapdragon X Elite firmware for ${device_model}
This package is automatically generated and includes firmware
files extracted from a local Windows installation.

%prep
cp \$RPM_SOURCE_DIR/adsp_dtbs.elf .
cp \$RPM_SOURCE_DIR/adspr.jsn .
cp \$RPM_SOURCE_DIR/adsps.jsn .
cp \$RPM_SOURCE_DIR/adspua.jsn .
cp \$RPM_SOURCE_DIR/battmgr.jsn .
cp \$RPM_SOURCE_DIR/cdsp_dtbs.elf .
cp \$RPM_SOURCE_DIR/cdspr.jsn .
cp \$RPM_SOURCE_DIR/qcadsp8380.mbn .
cp \$RPM_SOURCE_DIR/qccdsp8380.mbn .
cp \$RPM_SOURCE_DIR/qcdxkmsuc8380.mbn .
mkdir -p %{buildroot}${fw_install_path}

%build

%install
install -Dm644 adsp_dtbs.elf %{buildroot}${fw_install_path}/adsp_dtbs.elf
install -Dm644 adspr.jsn %{buildroot}${fw_install_path}/adspr.jsn
install -Dm644 adsps.jsn %{buildroot}${fw_install_path}/adsps.jsn
install -Dm644 adspua.jsn %{buildroot}${fw_install_path}/adspua.jsn
install -Dm644 battmgr.jsn %{buildroot}${fw_install_path}/battmgr.jsn
install -Dm644 cdsp_dtbs.elf %{buildroot}${fw_install_path}/cdsp_dtbs.elf
install -Dm644 cdspr.jsn %{buildroot}${fw_install_path}/cdspr.jsn
install -Dm644 qcadsp8380.mbn %{buildroot}${fw_install_path}/qcadsp8380.mbn
install -Dm644 qccdsp8380.mbn %{buildroot}${fw_install_path}/qccdsp8380.mbn
install -Dm644 qcdxkmsuc8380.mbn %{buildroot}${fw_install_path}/qcdxkmsuc8380.mbn

%files
${fw_install_path}/adsp_dtbs.elf
${fw_install_path}/adspr.jsn
${fw_install_path}/adsps.jsn
${fw_install_path}/adspua.jsn
${fw_install_path}/battmgr.jsn
${fw_install_path}/cdsp_dtbs.elf
${fw_install_path}/cdspr.jsn
${fw_install_path}/qcadsp8380.mbn
${fw_install_path}/qccdsp8380.mbn
${fw_install_path}/qcdxkmsuc8380.mbn

EOF
cd "${tmpdir}"

# Extract FW files
fw_files="adsp_dtbs.elf
adspr.jsn
adsps.jsn
adspua.jsn
battmgr.jsn
cdsp_dtbs.elf
cdspr.jsn
qcadsp8380.mbn
qccdsp8380.mbn
qcdxkmsuc8380.mbn"

echo "Extracting firmware from $search_path"
for f_path in ${fw_files}; do
	echo -e "\t${f_path}"
	fw_path="$(find "${search_path}" -name "${f_path}" -exec ls -t {} + | head -n1)"
	cp "${fw_path}" "${pkgpath}/"
done

cd ${pkgpath}

source /etc/os-release

echo "Building package ${pkgname}..."
# Pack and install
fedpkg --release f${VERSION_ID} local

echo "Installing ${pkgname}..."
dnf list --installed ${pkgname} > /dev/null \
 && dnf reinstall -y "aarch64/${pkgname}-${pkgver}-1.fc${VERSION_ID}.aarch64.rpm" > /dev/null \
 || dnf install -y "aarch64/${pkgname}-${pkgver}-1.fc${VERSION_ID}.aarch64.rpm" > /dev/null

dracut --regenerate-all --force

echo -e "$(tput bold)Done! Reboot to load the added firmware files. $(tput sgr0)"
