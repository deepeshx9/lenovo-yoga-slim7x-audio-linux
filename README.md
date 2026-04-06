# lenovo-yoga-slim7x-audio-linux
Audio Topology/UCM port efforts for the Lenovo Yoga Slim 7X (14Q8X9) on Linux

# Audio codec and hardware path scan on Windows (6th April 2026)

1) ACPI (DSDT) dump extracted in "firmware"
2) More extracted firmware files from Windows (not hosted; proprietary binaries; use qcom-firmware-extract tool instead)

Findings (06/04/2026):
  1) UCM files are missing in standard Ubuntu install
  2) Audio topology is already linked
  * Topology: Quad-speaker (2x2 split)

  * Enumerators: 2x SoundWire Masters active

  * Endpoints: 4x WSA8845 Smart Amplifiers
