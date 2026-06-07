# JACK + PulseAudio Setup (Fallback)

This approach runs JACK as the primary audio server for your DAW, with PulseAudio running alongside for system audio (browser, media players, etc.). It works well, but requires more manual management than PipeWire. Consider this if PipeWire causes problems on your system.

> **Recommended instead:** [pipewire.md](pipewire.md) — PipeWire solves this more cleanly and is the current standard on modern Linux.

## How It Works

JACK takes exclusive control of your audio interface at a fixed sample rate and buffer size, giving your DAW low-latency access. PulseAudio runs in parallel and talks to the same interface via ALSA's `dmix` layer. They share the device without a bridge, which avoids the crash-prone `module-jack-sink` approach.

The trade-off: PulseAudio defaults to 44.1 or 48kHz while JACK runs at 96kHz. ALSA's dmix handles the sample rate mismatch with resampling, which adds a small amount of latency and quality loss to system audio. For production recording this is acceptable since only JACK/DAW audio is at full quality.

## Prerequisites

```bash
sudo apt install jackd2 qjackctl pulseaudio a2jmidid
```

## Audio Interface Card Index

USB audio interfaces don't always get the same ALSA card index across reboots. Hardcoding `hw:1` or `hw:2` in your JACK config will break when the index changes. Instead, look up the card by name at startup.

Find your interface name:

```bash
cat /proc/asound/cards
```

The name in brackets (e.g. `[Onyx24]`) is what you'll use. See the startup script below for how to resolve it dynamically.

## JACK Configuration

Configure jackdbus with your interface and desired settings. Replace `YourInterfaceName` with the name from `/proc/asound/cards`:

```bash
jack_control ds alsa
jack_control dps device "hw:$(grep -l 'YourInterfaceName' /proc/asound/card*/id | grep -oE '[0-9]+')"
jack_control dps rate 96000
jack_control dps period 512
jack_control dps nperiods 2
jack_control eps realtime true
jack_control eps realtime-priority 75
jack_control start
```

Or use the included startup script (see [scripts/jack-start.sh](../scripts/jack-start.sh)).

## PulseAudio Configuration

The key is to disable the JACK bridge modules — they cause crashes. Instead let PulseAudio talk directly to ALSA while JACK runs independently.

In `~/.config/pulse/default.pa`, add:

```
### Disable JACK bridge modules (causes JACK crashes under load)
unload-module module-jack-sink
unload-module module-jack-source
unload-module module-jackdbus-detect
```

Or unload them at JACK startup time (see the startup script).

## MIDI

With this setup, ALSA MIDI devices won't automatically appear as JACK MIDI ports. Run `a2jmidid` to bridge them:

```bash
a2jmidid -e &
```

The `-e` flag exports hardware MIDI ports into JACK. Add this to your startup script.

## Startup Script

See [scripts/jack-start.sh](../scripts/jack-start.sh) for a complete startup script that:

- Finds your interface by name (not hardcoded index)
- Starts JACK via jackdbus
- Unloads the Pulse-JACK bridge modules
- Starts a2jmidid
- Launches QjackCtl

## Routing with QjackCtl

QjackCtl's patchbay lets you save and restore port connections. Once JACK and your JACK clients (DAW, Overwitch, etc.) are running, open the patchbay, connect ports, and save the preset. QjackCtl can activate the patchbay automatically on startup.

## Overwitch / Overbridge

[Overwitch](https://github.com/dagargo/overwitch) is an open-source implementation of Elektron's Overbridge protocol for Linux, enabling per-track audio streaming from Elektron hardware (Digitakt, Digitone, Analog series, etc.) over USB. It connects as a JACK client. It should connect automatically once JACK is running. If it fails silently, check that JACK is fully started before launching Overwitch, and verify with:

```bash
jack_lsp | grep -i digitakt
```

## Stopping JACK

Always stop JACK cleanly:

```bash
jack_control stop
```

Or use [scripts/jack-stop.sh](../scripts/jack-stop.sh).

Killing JACK mid-session can leave PulseAudio without an output until it reconnects to ALSA directly (usually auto-recovers within a few seconds).

## Latency Reference

| Period (frames) | Latency @ 44.1kHz | Latency @ 96kHz |
|---|---|---|
| 128 | ~2.9ms | ~1.3ms |
| 256 | ~5.8ms | ~2.7ms |
| 512 | ~11.6ms | ~5.3ms |
| 1024 | ~23.2ms | ~10.7ms |

Start with 512 frames for stability. Go lower only if you need it and your system can handle it.

## Known Issues

- **`module-jack-sink` crashes:** The Pulse-to-JACK bridge is unstable under load. Do not use it. Leave Pulse talking to ALSA directly.
- **Xruns at low buffer sizes:** If you get xruns, increase the period (512 → 1024) or check IRQ affinity and CPU governor (`performance` mode helps).
- **Interface not found:** If JACK fails to start, check that your interface is powered on and recognized by ALSA (`cat /proc/asound/cards`) before running the startup script.
