# What is JACK?

JACK (JACK Audio Connection Kit) is a professional audio server for Linux (and macOS) that gives applications low-latency, synchronized access to audio hardware. It was the foundation of Linux pro audio for over two decades, and understanding it is essential for understanding why modern Linux audio works the way it does.

## The Core Idea

JACK operates on a simple but powerful model: one server, many clients. The JACK server takes exclusive control of your audio interface and runs a real-time processing loop at a fixed sample rate and buffer size. Applications — your DAW, a soft synth, an effects processor, a virtual patch cable — connect to JACK as clients, each exposing input and output ports. You route audio between them using a patchbay (QjackCtl, Catia, etc.), just like patching a hardware modular system.

The result is that latency is deterministic and shared. Every client in the graph processes audio in the same callback cycle. If you set JACK to 256 frames at 96kHz, you have ~2.7ms of latency — and every connected app is working within that same budget.

## A Brief History

**1999–2000:** JACK was conceived by Paul Davis (also the creator of Ardour) and first released around 2000. The motivation was simple: Linux had ALSA for talking to hardware, but no way for multiple pro audio applications to interconnect at low latency the way hardware gear could. JACK filled that gap.

**Early 2000s:** JACK gained traction in the Linux audio community. Ardour, Hydrogen, Rosegarden, and many other applications adopted it. The JACK ecosystem grew around the concept of the Linux Audio Developer's Simple Plugin API (LADSPA) and later LV2 for plugins.

**2003:** JACK transport protocol was introduced, allowing JACK clients to synchronize playback position and tempo — critical for DAW-to-DAW and DAW-to-sequencer workflows.

**2009:** **JACK2** (originally called jackdmp) was released by Stephane Letz. JACK2 added multi-core support (the original JACK was single-threaded) and dbus integration for easier session management. JACK2 became the standard on most Linux distributions.

**2010s:** JACK remained the standard for Linux pro audio, but its weakness became increasingly apparent: it demanded exclusive access to the audio interface and had no good story for system audio (browser, desktop notifications, media players). The `module-jack-sink` PulseAudio bridge existed but was unstable. Most users ran JACK for production and accepted that system audio would break.

**2020s:** PipeWire arrived and largely superseded JACK for most use cases, but JACK remains relevant — many applications still use the JACK API, and the JACK model of explicit port routing is conceptually powerful.

## How JACK Works

### The Processing Graph

JACK builds a directed graph of connected ports. Each client registers input and output ports, and the server determines the processing order based on the connections. Audio flows from outputs to inputs through the graph in a single pass per cycle.

```
[Overwitch (Digitakt)] ---> [REAPER track input]
[REAPER master out]    ---> [system:playback_1 (interface L)]
[REAPER master out]    ---> [system:playback_2 (interface R)]
```

### The Callback Model

JACK clients don't pull audio on demand — the server calls them. Each client implements a process callback that JACK invokes once per cycle. The callback receives a buffer of `nframes` samples, the client fills or consumes it, and returns. If a client misses its deadline, that's an **xrun** (overrun or underrun) — a glitch in the audio.

### Realtime Priority

For xrun-free operation, JACK runs with realtime scheduling priority. This means JACK (and its clients) can preempt normal OS processes. On Linux this requires either running as root (not recommended) or configuring the `audio` group with realtime limits in `/etc/security/limits.conf`. The `jackd2` package typically sets this up automatically.

### Ports and Connections

JACK ports are named, typed (audio or MIDI), and directional (input or output). The full port name is `client_name:port_name`, e.g. `reaper:output_1` or `system:capture_1`. Connections are made between an output port and an input port. Tools like `jack_connect`, QjackCtl, or Catia manage these connections.

## JACK vs ALSA

ALSA (Advanced Linux Sound Architecture) is the kernel-level audio layer — it's how software talks to hardware. JACK sits on top of ALSA. JACK opens the ALSA device, runs its own processing loop, and exposes ports to applications. Applications connect to JACK rather than ALSA directly.

The benefit: JACK abstracts the hardware. Clients don't need to know anything about the interface — they just connect ports.

The cost: JACK holds the ALSA device exclusively. Nothing else can open it directly while JACK is running.

## JACK and System Audio

This is JACK's historic weak point. PulseAudio (the traditional Linux system audio server) doesn't know about JACK. When JACK is running and holds the audio interface, PulseAudio loses its output. Two workarounds exist:

1. **`module-jack-sink`**: A PulseAudio module that creates a virtual sink that routes through JACK. Works in principle, but the bridge is notoriously unstable and can crash JACK under load.

2. **Separate interface**: Run JACK on your pro audio interface and PulseAudio on the onboard/HDMI audio. Avoids the conflict entirely, but means system audio and production audio come out of different devices.

Neither solution is satisfying. This is the problem PipeWire was built to solve.

## JACK Today

JACK isn't gone. The JACK API is still widely used — REAPER, Ardour, Bitwig, Carla, and hundreds of plugins and utilities speak JACK. On modern systems with PipeWire, the JACK API is typically implemented by PipeWire's compatibility layer (`pipewire-jack`), meaning applications use JACK semantics while PipeWire handles the actual audio routing. JACK the server may be replaced, but JACK the protocol lives on.

If you're running an older system, prefer the stability of a known-good stack, or are doing specialized work that PipeWire doesn't handle well (netjack, FreeBoB/FFADO for FireWire interfaces, etc.), a straight JACK setup remains a solid choice.

## Key Concepts Summary

| Term | Meaning |
|---|---|
| JACK server | The audio daemon that owns the hardware and runs the processing loop |
| JACK client | Any application that connects to the JACK server (DAW, synth, etc.) |
| Port | A named audio or MIDI endpoint on a client |
| Xrun | A missed deadline — causes an audible glitch |
| Period | The buffer size in frames (e.g. 512 frames) |
| Latency | Period ÷ sample rate × 1000 = ms (e.g. 512 / 96000 × 1000 = 5.3ms) |
| Patchbay | A tool for managing port connections (QjackCtl, Catia, qpwgraph) |
| a2jmidid | A utility that bridges ALSA MIDI ports into JACK MIDI |

## Further Reading

- [JACK Audio Connection Kit](https://jackaudio.org) — official site
- [JACK on the Linux Audio wiki](https://wiki.linuxaudio.org/wiki/jack)
- Paul Davis's writings on Linux audio (scattered across mailing lists and blogs — worth hunting down)
- `man jackd` on any system with jackd2 installed
