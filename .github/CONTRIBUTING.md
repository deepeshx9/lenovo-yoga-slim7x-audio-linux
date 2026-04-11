# Contributing

Thanks for your interest in improving Linux audio support for the Lenovo Yoga Slim 7x. 

This is an experimental, low-level project involving DSP, Pipewire/Wireplumber DSP, ALSA UCM, and kernel driver work. Because we are interacting directly with hardware and DSP firmware, **there is a real risk of hardware damage** (specifically blowing out the speakers). There are no guarantees of stability yet. Please test at your own risk.

## Where we need help

We're currently focusing on a few major bottlenecks:

* **Kernel Driver Patching (`wsa884x.c` or `x1e80100.c`):** We need help with proper speaker amp initialization, safe sequencing to prevent hardware damage, and matching Windows' behavior.
* **Logic port-over from speakersafetyd:** speakersafetyd framework from AsahiLinux (originally meant for Apple Silicon Macs) can be useful in logic review.
* **DSP Reverse Engineering:** We are trying to understand the proprietary DSP logic from Windows, specifically regarding VISENSE (speaker protection) and SoftClip (dynamic limiting).
* **DSP Framework Integration:** Porting that logic into the Linux audio pipeline using ALSA, UCM profiles, and topology files.
* **UCM Configuration:** General cleanup, routing fixes, and validation of `.conf` files.

## Project philosophy

Linux audio stack for smart amp devices is not yet fully mature.
So we are aiming to implement device/board-specific speaker safety math into kernel mode drivers and the rest DSP and UCM math aligned with the usual Linux stack in userspace.

## How to contribute

Standard GitHub flow applies: fork, branch, commit, and open a PR. 

To keep things moving smoothly:
* **Keep it focused:** One feature or fix per PR.
* **Show your work:** Since this is hardware-level, PRs must include your testing methodology, `dmesg` logs, and clear observations of the audio behavior.
* **Test rigorously:** Before submitting, verify the system boots without crashes, audio works consistently, and there are no regressions (or hardware damage).

## Reporting Issues

If you're opening an issue, please include:
* Device model/variant/region (e.g., Yoga Slim 7x 14Q8X9 - IND - 32GB)
* Kernel version
* Relevant logs (`dmesg | grep -i audio`)
* A clear description of the behavior

If you’ve worked on DSP, audio drivers, or similar systems and see something off in our assumptions, feel free to challenge it.

This is a reverse-engineering-heavy project. Even if you aren't writing kernel code, sharing your hardware logs, traces, or Windows-to-Linux behavior comparisons is incredibly valuable. Thanks for pitching in.
