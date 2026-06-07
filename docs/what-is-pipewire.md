# What is PipeWire?

PipeWire is a modern Linux multimedia server that handles audio and video routing across the entire system. It replaces both PulseAudio (consumer audio) and JACK (pro audio) with a single unified daemon, solving the long-standing problem of getting system audio and low-latency DAW audio to coexist peacefully.

## The Core Idea

Where JACK said "one server, exclusive hardware access, explicit routing," and PulseAudio said "one server, automatic routing, consumer-friendly defaults," PipeWire says: **both, simultaneously, for everyone.**

PipeWire presents multiple compatibility interfaces at once:
- A **PulseAudio** API, so your browser, desktop, and media apps work unchanged
- A **JACK** API, so your DAW and pro audio tools work unchanged
- An **ALSA** API for legacy apps
- Its own native API for new applications

From an application's perspective, nothing changes. Firefox still thinks it's talking to PulseAudio. REAPER still thinks it's talking to a JACK server. PipeWire handles both under the hood.

## A Brief History

**2015:** Wim Taymans, a longtime GStreamer developer at Red Hat, began working on what would become PipeWire. The original goal was more modest: a unified video capture and sharing daemon for Linux (video being notoriously fragmented — Wayland, V4L2, screen capture all had different interfaces). At this point it was called **PipeWire** because it was conceived as a pipe for multimedia data.

**2017:** Taymans expanded the scope to audio, realizing that the same graph-based routing model could solve the PulseAudio/JACK split. The architecture borrowed heavily from JACK's graph model while adding PulseAudio's session management concepts.

**2018–2020:** Development accelerated. PipeWire gained a session manager (initially media-session, later WirePlumber) and the PulseAudio and JACK compatibility layers matured. Early adopters started using it, and Fedora began tracking it seriously.

**2021:** **Fedora 34** shipped PipeWire as the default audio server, replacing PulseAudio. This was the inflection point — a major distro betting on PipeWire by default. Ubuntu, Debian, Arch, and others followed in subsequent releases.

**2022–present:** PipeWire became the standard. Ubuntu 22.10 switched to PipeWire by default. Most major distros followed. The focus shifted from "does it work?" to "does it work for edge cases?" — FireWire interfaces, low-latency production, Bluetooth codecs, networked audio.

## How PipeWire Works

### The Graph

PipeWire's core is a media graph — nodes connected by links. A node can be a hardware device, an application, a filter, or a virtual device. Links carry data between node ports, similar to JACK's port connections.

The graph is managed by the **session manager** (WirePlumber), which decides what connects to what by default and enforces policy (which app gets priority, what happens when a Bluetooth headset connects, etc.).

### WirePlumber

WirePlumber is the brain that makes PipeWire behave intelligently. It:
- Automatically routes new audio streams to the default output device
- Restores saved volume levels and routing preferences
- Handles device hotplug (USB interfaces, Bluetooth, HDMI)
- Enforces routing policy (e.g. "this app should always go to this device")

WirePlumber replaced the earlier `media-session` daemon and is now the standard session manager. It's configurable via Lua scripts.

### The Compatibility Layers

**PulseAudio compatibility** (`pipewire-pulse`): A socket-compatible replacement for the PulseAudio daemon. Apps that use the libpulse client library connect to `pipewire-pulse` instead. From the app's perspective, it's PulseAudio — same API, same protocol.

**JACK compatibility** (`pipewire-jack`): A replacement `libjack.so` that implements the JACK client API but connects to PipeWire instead of a JACK server. Apps link against this library (via the system linker path) and get JACK semantics — port registration, the process callback model, transport sync — all routed through PipeWire.

**ALSA compatibility**: PipeWire can expose ALSA PCM devices via `pw-alsa`, allowing legacy ALSA-only apps to work through PipeWire.

### Scheduling

Like JACK, PipeWire uses a real-time scheduling model. The graph runs on a timer, processing each node in dependency order. Buffer sizes are configurable (`quantum` in PipeWire terminology, equivalent to JACK's `period`). Realtime priority is used to minimize latency and avoid xruns.

A key difference from JACK: PipeWire can handle multiple sample rates simultaneously in the same graph. An app running at 44.1kHz and a DAW running at 96kHz can coexist — PipeWire handles the sample rate conversion internally.

### Video

PipeWire also handles video streams — screen capture, camera access, and video routing between applications. This is particularly important for Wayland, where screen capture APIs were fragmented. Tools like OBS use PipeWire for screen capture on Wayland systems. This is separate from the audio stack but runs in the same daemon.

## Why It Matters for Pro Audio

Before PipeWire, the Linux pro audio workflow looked like this:

1. Start JACK, which takes exclusive control of your audio interface
2. Accept that browser audio is now broken (or fight with the Pulse-JACK bridge)
3. Hope the bridge doesn't crash JACK mid-session
4. When done recording, stop JACK, restart PulseAudio, get system audio back

With PipeWire:

1. Everything is always running
2. Browser audio works. DAW audio works. Overwitch works. Simultaneously.
3. Sample rate is set once, everything conforms to it
4. No manual service juggling

For most pro audio workflows this is a clear improvement. The main caveat is edge cases: some very specialized JACK configurations (network audio via NetJACK, certain FireWire interfaces, very aggressive latency requirements) may still work better with a dedicated JACK server.

## PipeWire vs JACK: Key Differences

| | JACK | PipeWire |
|---|---|---|
| Primary focus | Pro audio | All multimedia (audio + video) |
| System audio | Separate server (PulseAudio), bridge needed | Built-in, transparent |
| Hardware access | Exclusive ALSA lock | Shared, managed by session manager |
| Multi-rate | No (single rate per session) | Yes (per-stream SRC) |
| Session management | Manual (patchbay) | Automatic (WirePlumber) + manual override |
| Configuration | jackdbus / conf.xml | Drop-in .conf files, Lua scripts |
| Maturity | ~24 years | ~9 years (production-stable since ~2021) |
| JACK API support | Native | Compatibility layer (pipewire-jack) |

## PipeWire vs PulseAudio

PulseAudio was never designed for pro audio. It was designed for the desktop — auto-routing, per-app volume, Bluetooth, network streams. It works well for that. Its weaknesses in the pro audio space:

- Fixed internal clock at 44.1 or 48kHz — no path to 96kHz for DAW work
- Cannot act as a JACK server
- The JACK bridge (`module-jack-sink`) was fragile
- Latency was never a design goal

PipeWire does everything PulseAudio does (the compatibility layer means existing apps don't need changes) while also doing everything JACK does. For new systems there's essentially no reason to run PulseAudio.

## Key Concepts Summary

| Term | Meaning |
|---|---|
| Node | A participant in the PipeWire graph (app, device, filter) |
| Port | A data endpoint on a node (audio in/out, video in/out) |
| Link | A connection between two ports |
| WirePlumber | The session manager — handles policy, auto-routing, device events |
| pipewire-pulse | The PulseAudio compatibility daemon |
| pipewire-jack | The JACK compatibility library (libjack.so replacement) |
| Quantum | Buffer size in frames (equivalent to JACK's period) |
| pw-jack | Wrapper that forces an app to use the PipeWire JACK library |
| qpwgraph | GUI patchbay for PipeWire (equivalent to QjackCtl's patchbay) |
| pw-top | Real-time monitor of PipeWire graph nodes and timing |

## Useful Commands

```bash
# Graph monitor (like htop but for PipeWire)
pw-top

# List all nodes in the graph
pw-cli list-objects Node

# Check PipeWire version and server info
pw-cli info 0

# Force a specific quantum (buffer size) temporarily
pw-metadata -n settings 0 clock.force-quantum 512

# Force a specific sample rate temporarily
pw-metadata -n settings 0 clock.force-rate 96000

# Run an app with the JACK compatibility layer explicitly
pw-jack reaper

# Patchbay GUI
qpwgraph
```

## Further Reading

- [PipeWire Wiki](https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/home)
- [PipeWire FAQ](https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/FAQ)
- [WirePlumber docs](https://pipewire.pages.freedesktop.org/wireplumber/)
- [Linux Audio wiki](https://wiki.linuxaudio.org)
- Wim Taymans's talks at Linux Audio Conference and FOSDEM (available on YouTube)
