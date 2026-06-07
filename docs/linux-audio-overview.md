# Linux Audio: A Brief History and Architecture Overview

Linux audio has a reputation for being complicated. That reputation isn't entirely undeserved — but most of the complexity comes from layers of history, each solving a real problem that the previous layer left unaddressed. Understanding the stack helps enormously when things go wrong.

## The Layers

Modern Linux audio is built in layers, each sitting on top of the previous:

```
Applications (DAW, browser, media player, synth...)
        |
Audio Server (PipeWire / PulseAudio / JACK)
        |
ALSA (kernel audio subsystem)
        |
Hardware drivers (USB Audio Class, HDMI, HDA...)
        |
Audio hardware (interface, soundcard, onboard audio)
```

Each layer has a job:

- **Hardware + drivers**: make the physical device accessible to the OS
- **ALSA**: provide a kernel API for talking to audio hardware
- **Audio server**: manage multiple apps sharing the hardware, add routing and mixing
- **Applications**: make sounds

## ALSA: The Foundation (1998–present)

**Advanced Linux Sound Architecture** replaced the older OSS (Open Sound System) in the Linux kernel around 1998–2002. ALSA is the kernel-level audio subsystem — it provides device drivers and a userspace API for recording and playback.

Every sound device on Linux is ultimately accessed through ALSA. When you plug in a USB audio interface, ALSA enumerates it and assigns it a card number and device number. You address it as `hw:X,Y` where X is the card index and Y is the device index.

ALSA is stable, low-level, and ubiquitous. It's not going anywhere. But using ALSA directly from applications has limitations:

- Only one process can open an ALSA device at a time (without dmix)
- No automatic routing between applications
- No per-app volume control
- Latency is whatever the application sets — no shared timing

**dmix** is an ALSA plugin that provides software mixing, allowing multiple apps to share a device. It works but has limitations: no sample rate conversion between apps, no routing, and it's a config file hack rather than a real server.

These limitations drove the development of userspace audio servers.

## OSS: The Predecessor (1992–2002)

Before ALSA, Linux used **Open Sound System (OSS)**. OSS was simpler and had a clean `/dev/dsp` interface that many apps used. But it was proprietary (the v4 spec was commercial), had poor multi-app support, and lagged behind on modern hardware. ALSA replaced it in the mainline kernel with Linux 2.6 (2003). OSS4 was eventually open-sourced and exists as an alternative, but it's essentially irrelevant on modern Linux.

## ESD and aRts: Early Desktop Audio Servers (late 1990s)

The GNOME desktop shipped **Enlightened Sound Daemon (ESD)** and KDE shipped **aRts** (analog real-time synthesizer). Both were early userspace audio servers intended to let desktop apps share audio hardware.

Both were limited and slow. aRts had noticeable latency. ESD was CPU-heavy. Neither was suitable for pro audio. They're purely historical footnotes at this point — but they represent the first recognition that Linux needed a userspace audio routing layer.

## JACK: Pro Audio Arrives (2000–present)

**JACK** (see [what-is-jack.md](what-is-jack.md)) was designed from the ground up for professional audio. Low latency, explicit routing, real-time scheduling, synchronized clients. It solved the pro audio problem decisively.

What JACK didn't solve: the desktop audio problem. JACK was never meant to be a consumer audio server. It demanded exclusive hardware access and required manual configuration. Running JACK for your DAW meant your browser went silent.

For a long time, the standard advice was: "accept it." Serious audio work and casual desktop use lived in different worlds. You'd finish a session, stop JACK, restart PulseAudio, and get your system audio back.

## PulseAudio: Desktop Audio Grows Up (2004–present)

**PulseAudio** was created by Lennart Poettering (also the creator of systemd) starting around 2004. It was designed to solve the consumer desktop audio problem: automatic routing, per-app volume, network streaming, Bluetooth audio, hot-plugging devices, and mixing multiple streams without manual configuration.

PulseAudio succeeded at the desktop level. It became the default on Ubuntu, Fedora, and most major distros around 2007–2008. Browser audio, desktop sounds, and media players all Just Worked.

But PulseAudio had no pro audio story. It ran internally at 44.1 or 48kHz with no easy path to 96kHz. It wasn't JACK. The `module-jack-sink` bridge existed to let PulseAudio route through JACK, but it was fragile and caused crashes. The two servers remained in uneasy parallel.

## The Two-Server Era (roughly 2007–2021)

For over a decade, Linux audio was split:

- **Consumer use**: PulseAudio. Handles everything automatically. Doesn't crash. Doesn't care about latency.
- **Pro audio**: JACK. Low latency, explicit routing, real-time. Doesn't care about system audio.

Users who needed both — a producer who also wanted to watch YouTube — had to manage the transition manually. There were scripts, desktop launchers, startup managers. The community built tools like `cadence` (from the KXStudio project) to automate JACK startup and attempt the Pulse-JACK bridge more reliably. It worked, mostly, until it didn't.

This era produced a lot of the documentation and Stack Overflow answers you'll find if you search for Linux audio help today. Much of it is outdated. The two-server model is no longer the default on modern distros.

## PipeWire: Unification (2021–present)

**PipeWire** (see [what-is-pipewire.md](what-is-pipewire.md)) unified the stack. One server, PulseAudio compatibility, JACK compatibility, low latency, automatic routing. Fedora 34 shipped it by default in 2021; Ubuntu followed in 22.10; most major distros by 2022–2023.

For most users — including most pro audio users — PipeWire is the right answer today. The PulseAudio bridge problem is gone because there is no bridge: PipeWire *is* both servers.

## The Audio Stack Today

On a modern Linux system with PipeWire:

```
Firefox          REAPER           Spotify          Overwitch
   |                |                |                |
[PulseAudio API] [JACK API]   [PulseAudio API]   [JACK API]
   |                |                |                |
   +----------------+----------------+----------------+
                         |
                     PipeWire
                         |
                      WirePlumber
                    (session manager)
                         |
                       ALSA
                         |
                   Audio interface
```

Everything talks to PipeWire through whatever API it knows. PipeWire routes everything to the hardware through ALSA. The application doesn't know or care what the underlying architecture is.

## The Hardware Side

### USB Audio Class

Most modern audio interfaces use the **USB Audio Class** protocol — a standardized USB spec for audio devices that works without custom drivers. Class 1 (UAC1) is supported natively by the Linux kernel at up to 24-bit/96kHz. Class 2 (UAC2) supports higher sample rates and channel counts and is also supported natively in modern kernels (3.18+).

This means most modern USB interfaces (Focusrite Scarlett, Mackie Onyx, PreSonus, MOTU, etc.) work on Linux out of the box with no driver installation. They appear as standard ALSA devices.

### FireWire (IEEE 1394)

Older pro audio interfaces often used FireWire. Linux FireWire audio is handled by **FFADO** (Free FireWire Audio Drivers), which provides a JACK backend (`-d firewire`). FireWire audio on Linux is functional but largely frozen in development — most manufacturers have moved to USB, and new FireWire interfaces are rare.

### Thunderbolt

Thunderbolt audio interfaces are increasingly common. On Linux, Thunderbolt audio support varies. Some interfaces present as USB Audio Class over Thunderbolt and work fine. Others require proprietary drivers that don't exist on Linux.

### Overbridge / Overwitch

Elektron's **Overbridge** protocol streams audio and MIDI from Elektron instruments (Digitakt, Digitone, Analog series, etc.) over USB, presenting the instrument's individual audio channels as a multi-channel audio interface. Elektron doesn't officially support Linux, but the open-source **Overwitch** project implements the Overbridge protocol and presents the device as a JACK client. It works reliably on both JACK and PipeWire (via the JACK compatibility layer).

## MIDI on Linux

MIDI has its own parallel history on Linux:

- **ALSA MIDI**: The kernel ALSA subsystem handles MIDI as well as audio. Physical MIDI ports and USB MIDI devices appear as ALSA sequencer ports.
- **JACK MIDI**: JACK has its own MIDI port system, separate from ALSA sequencer. Apps using JACK MIDI connect via the JACK graph.
- **a2jmidid**: A bridge that makes ALSA MIDI ports appear as JACK MIDI ports, unifying the two systems.
- **PipeWire MIDI**: PipeWire handles MIDI natively and bridges between ALSA MIDI and JACK MIDI automatically. `a2jmidid` is no longer needed with PipeWire.

## Common Confusions

**"ALSA vs JACK vs PulseAudio vs PipeWire" — which do I use?**

They're not alternatives, they're layers. You always use ALSA (it's in the kernel). On top of that, you run one audio server: PipeWire (recommended for most users today), or JACK if you have specific requirements. PulseAudio is legacy — replaced by PipeWire's compatibility layer on modern systems.

**"My app says 'ALSA' in the audio settings, not 'JACK' or 'PulseAudio'"**

The app is talking to ALSA directly. This works but bypasses the audio server — meaning it might conflict with other audio. Configure the app to use PipeWire/JACK/PulseAudio if possible. If ALSA is the only option, look into the `pw-alsa` compatibility layer.

**"I see both `pulseaudio` and `pipewire-pulse` — which is running?"**

Check: `pactl info | grep "Server Name"`. If it says `PulseAudio (on PipeWire x.x.x)`, PipeWire is running with its PulseAudio compatibility layer. If it just says `PulseAudio`, you're on plain PulseAudio.

**"Do I still need a2jmidid?"**

Not with PipeWire. PipeWire bridges ALSA MIDI and JACK MIDI automatically. With a plain JACK setup (no PipeWire), yes — you still want `a2jmidid -e` running.

## Further Reading

- [Linux Audio wiki](https://wiki.linuxaudio.org) — the community reference
- [ALSA project](https://www.alsa-project.org)
- [JACK](https://jackaudio.org)
- [PipeWire](https://pipewire.org)
- [KXStudio](https://kx.studio) — curated Linux audio repos and tools, active community
- [linuxmusicians.com](https://linuxmusicians.com) — forum for Linux musicians and producers
- [Libre Music Production](https://libremusicproduction.com) — tutorials and guides
