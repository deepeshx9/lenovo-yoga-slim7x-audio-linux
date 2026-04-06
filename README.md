# lenovo-yoga-slim7x-audio-linux
Audio Topology/UCM port efforts for the Lenovo Yoga Slim 7X on Linux

# Audio codec and hardware path scan on Windows (6th April 2026)

1) ACPI (DSDT) dump extracted as "acpi-x1e-lenys7x-342026" in "firmware"
2) More extracted firmware files from Windows (not hosted; proprietary binaries; use qcom-firmware-extract tool instead)

Findings (06/04/2026):
  1) UCM files are missing in standard Ubuntu install
  2) Audio topology is already linked
