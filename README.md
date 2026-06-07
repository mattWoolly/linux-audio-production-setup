# Linux Audio Production Setup

A practical guide and reference for running a professional audio production environment on Linux — covering the history of Linux audio, how the stack works, DAWs, audio interfaces, USB hardware synthesizers, and general system audio all working simultaneously without conflicts.

## Use Case

The setup this guide is built around: a fully functional Linux workstation used for music production, where the following all need to work at the same time without conflicts:

- **Browser and system audio** — YouTube, streaming, desktop sounds
- **REAPER** — primary DAW, recording and mixing
- **Multi-channel USB audio interface** — tested with Mackie Onyx24 and Tascam Model 12, both class-compliant USB
- **Elektron hardware synthesizers** (Digitakt II) via [Overwitch](https://github.com/dagargo/overwitch) — an open-source implementation of Elektron's Overbridge protocol that streams individual audio channels from Elektron devices over USB and presents them as JACK clients

The Overwitch piece is what makes this setup non-trivial. Overwitch is a JACK client, which means it needs a running JACK server (or a JACK-compatible interface like PipeWire). Getting Overwitch, a multi-channel interface, REAPER, and system audio all playing nicely on the same machine is the core problem this guide solves.

Overwitch is not affiliated with this guide — it's an independent open-source project. Go give it a star: [github.com/dagargo/overwitch](https://github.com/dagargo/overwitch).

## The Problem

Linux audio has historically forced you to choose: either run JACK for your DAW with low latency, or run PulseAudio for system audio (browser, media players, etc.). Getting both at the same time reliably is non-trivial, and adding USB audio hardware like Elektron devices via Overwitch makes it harder still.

The specific symptoms this guide addresses:

- DAW (REAPER, Ardour, etc.) works fine via JACK, but browser/system audio goes silent or crackles
- Pulse-to-JACK bridge (`module-jack-sink`) causes JACK to crash under load
- Overwitch/Overbridge fails to connect when JACK is running
- Sample rate mismatches between JACK (96kHz) and PulseAudio (44.1/48kHz)
- Audio interface card index changes between boots, breaking startup scripts

## Approaches

| Approach | Status | Notes |
|---|---|---|
| [PipeWire](docs/pipewire.md) | **Current / Recommended** | Replaces both JACK and PulseAudio. Everything works simultaneously. |
| [JACK + PulseAudio](docs/jack-pulseaudio.md) | Working fallback | Good if PipeWire causes issues. Requires more manual management. |

## Background Reading

New to Linux audio? Start here:

- [Linux Audio: History and Architecture Overview](docs/linux-audio-overview.md) — how the whole stack fits together, from ALSA to PipeWire
- [What is JACK?](docs/what-is-jack.md) — the pro audio server that defined Linux audio for 20+ years
- [What is PipeWire?](docs/what-is-pipewire.md) — the modern replacement that unifies everything

## Quick Start

**Recommended (PipeWire):** see [docs/pipewire.md](docs/pipewire.md)

**Fallback (JACK + PulseAudio):** see [docs/jack-pulseaudio.md](docs/jack-pulseaudio.md)

**Something not working?** see [docs/troubleshooting.md](docs/troubleshooting.md)

## Scripts

| Script | Purpose |
|---|---|
| [scripts/pipewire-switch.sh](scripts/pipewire-switch.sh) | One-shot migration from PulseAudio/JACK to PipeWire |
| [scripts/jack-start.sh](scripts/jack-start.sh) | Start JACK stack (interface name lookup, a2jmidid, QjackCtl) |
| [scripts/jack-stop.sh](scripts/jack-stop.sh) | Stop JACK cleanly |

## Hardware Context

This guide was developed with:

- **Audio interfaces:** Mackie Onyx24, Tascam Model 12 (both USB class-compliant, no drivers needed)
- **Synthesizers:** Elektron Digitakt II via [Overwitch](https://github.com/dagargo/overwitch)
- **DAW:** REAPER
- **OS:** Ubuntu 24.04, Linux 6.17, x86-64

The principles apply broadly to any USB class-compliant audio interface and any JACK-based DAW. If your interface works with `aplay -l`, it'll work with this guide.

## Repository Structure

```
.
├── README.md
├── docs/
│   ├── linux-audio-overview.md   # History and architecture of Linux audio
│   ├── what-is-jack.md           # Deep dive on JACK
│   ├── what-is-pipewire.md       # Deep dive on PipeWire
│   ├── pipewire.md               # PipeWire setup guide (recommended)
│   ├── jack-pulseaudio.md        # JACK + PulseAudio setup guide (fallback)
│   └── troubleshooting.md        # Common problems and fixes
└── scripts/
    ├── pipewire-switch.sh        # Migrate to PipeWire
    ├── jack-start.sh             # Start JACK stack
    └── jack-stop.sh              # Stop JACK cleanly
```

## Contributing

Issues and PRs welcome. If you've got a different interface, distro, or DAW and something works differently for you, open an issue or PR — this guide is meant to grow.

## License

MIT
