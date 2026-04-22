# Audio DSP Hardware Enablement for Lenovo Yoga Slim 7x (Linux)

> **DANGER: HARDWARE DAMAGE RISK **
> This is an experimental, low-level reverse-engineering project interacting directly with the raw smart amplifier (WSA8845). **Running this code without understanding it carries a real risk of physically destroying your laptop speakers.** > There is absolutely no warranty. Test at your own risk.

## Overview
This project provides the missing DSP (Digital Signal Processing) and hardware safety layers for the Lenovo Yoga Slim 7x (Snapdragon X Elite / 14Q8X9) on Linux. 

Currently, upstream Linux distributions default to a "crippled but safe" woofer-only audio profile to avoid hardware damage. This project aims to unlock the full 4-speaker flagship audio experience by porting the proprietary Windows acoustic tuning and thermal safety mathematics over to the open-source Linux stack.

## Architecture
This project uses a strict separation of concerns, splitting physical hardware protection from acoustic user-space tuning:

* **Level 0:** Kernel driver: Should VISENSE and SoftClip in /proc/sound
* **Level 1:** User-space PipeWire/WirePlumber profiles (`DSP/10-crossover.conf`) and ALSA UCM configurations (`alsa-ucm2-conf/`) replicating the proprietary Dolby Atmos biquad EQ and crossover frequencies. We are thinking of porting over speakersafetyd daemon to this laptop, but it is highly optimistic to be sure about it.

## Current Status
* **ALSA UCM Routing:** Implemented (from Upstream alsa-ucm-conf project)
* **PipeWire DSP Crossover:** Implemented but untested
* **Speakersafetyd Port:** In Progress

## Installation & Testing
*Note: You must explicitly pass `snd-soc-x1e80100.i_accept_the_danger=1` to your kernel parameters for these configurations to fully apply.*

We provide automated deployment scripts in the `/deployers` directory:
1. **User-space Only (`framework-configuration.sh`):** Safely installs the ALSA UCM and PipeWire topologies and intilializes speakersafetyd.
2. **Bare-metal Deployer (`kernel_compile-deploy.sh`):** An interactive script that downloads, patches, compiles, and installs a Release Candidate kernel with our custom driver math baked in.

## Contributing
We are actively looking for help with DSP reverse-engineering, ALSA UCM validation, and kernel fixed-point math. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR or Issue.
