# lenovo-yoga-slim7x-audio-linux
Audio DSP/UCM port efforts for the Lenovo Yoga Slim 7X (14Q8X9) on Linux    [Hardware damaged counter: 1]

Warning: Do not run any code on your hardware. This project is extremely experimental and may damage your hardware. This porject provides absolutely no warranty.

# Audio hardware path scan referencing Windows (6th April 2026)

1) ACPI (DSDT) dump extracted in "firmware"
2) More extracted firmware files from Windows (not hosted; proprietary binaries; use qcom-firmware-extract tool instead)

Findings (06/04/2026):
  1) UCM files are missing in standard Ubuntu install
  2) Speaker protection is missing in mainline linux
  3) Audio topology is already linked and loaded
  * Topology: Quad-speaker (2x2 split)

  * Enumerators: 2x SoundWire Masters active

  * Endpoints: 4x WSA8845 Smart Amplifiers


# Implementation of DSP pseudo-logic and creation of UCM profile (7th April 2026)

1) UCM profile (HiFI.conf) and DSP pseudo-logic (10-crossover.conf) created
2) Future roadmap set to reverse engineering proprietary DSP logic over from Windows
