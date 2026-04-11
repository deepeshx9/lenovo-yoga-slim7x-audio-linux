# lenovo-yoga-slim7x-audio-linux
Audio DSP port efforts for the Lenovo Yoga Slim 7X (14Q8X9) on Linux (Implementation of speakersafetyd pending; see Issues)

Warning: Do not run any code on your hardware. This project is extremely experimental and may damage your hardware. This porject provides absolutely no warranty.

`Start of devlog:`

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

  * Smart Amp Expects: S32_LE @ 48 kHz


# Implementation of DSP pseudo-logic and creation of UCM profile (7th April 2026)

1) UCM profile (HiFI.conf) and DSP pseudo-logic (10-crossover.conf) created
2) Future roadmap set to reverse engineering proprietary DSP logic over from Windows
3) VISENSE / SoftClip logic to be implemented in future
4) Static binary analysis of Windows blobs (.dll/.sys) and ETW required


# UCM profiles carried over from the main alsa-ucm-conf project (9th April 2026)
1) UCM profiles merged from main also-ucm-conf upstream project
2) DSP framework is still incomplete (VISENSE / SoftClip not integrated fully) [speakersafetyd to be ported over]

# .sys core Windows driver files' analysis (11th April 2026)
1) Ghidra and pseudo-C code obtained
2) Project structure improved

