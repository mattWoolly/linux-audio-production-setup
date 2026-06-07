# PipeWire Setup (Recommended)

PipeWire is the modern Linux audio server that replaces both PulseAudio and JACK. It presents itself simultaneously as a JACK server and a PulseAudio server, so your DAW, browser, media players, and USB audio hardware all work at the same time without bridges or manual routing tricks.

## Why PipeWire Over JACK + PulseAudio

The traditional approach of running JACK alongside PulseAudio requires a bridge module (`module-jack-sink`) to route system audio through JACK. This bridge is notoriously unstable under load and often causes JACK to crash or xrun. PipeWire eliminates the bridge entirely.

PipeWire also handles MIDI natively, so `a2jmidid` is no longer needed.

## Prerequisites

- Ubuntu 22.04+ (or equivalent — PipeWire is standard on most modern distros)
- `pipewire`, `pipewire-pulse`, `pipewire-jack`, `wireplumber` packages installed
- `qpwgraph` for visual patchbay routing (replaces QjackCtl)

Check what you have:

```bash
dpkg -l | grep -E "pipewire|wireplumber|qpwgraph"
```

Install if needed:

```bash
sudo apt install pipewire pipewire-pulse pipewire-jack wireplumber qpwgraph
```

## Step 1: Back Up Your Current Setup

Before switching, snapshot your current audio config:

```bash
mkdir -p ~/audio-backup
cp ~/.config/pulse/default.pa ~/audio-backup/ 2>/dev/null
cp ~/.config/jack/conf.xml ~/audio-backup/ 2>/dev/null
systemctl --user list-unit-files | grep -E "pipewire|pulseaudio|jack|wireplumber" > ~/audio-backup/service-state.txt
```

See [Rollback](#rollback) at the bottom of this doc for how to get back.

## Step 2: Disable PulseAudio, Enable PipeWire

Stop and mask PulseAudio so it doesn't start again:

```bash
systemctl --user stop pulseaudio.service pulseaudio.socket
systemctl --user mask pulseaudio.service pulseaudio.socket
```

Unmask and start PipeWire services (they may already be installed but masked):

```bash
systemctl --user unmask pipewire.service pipewire-pulse.service wireplumber.service
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber
```

Verify all three are active:

```bash
systemctl --user is-active pipewire pipewire-pulse wireplumber
```

All three should print `active`.

## Step 3: Set Sample Rate and Buffer Size

By default PipeWire runs at 48kHz. For pro audio you likely want 96kHz (or whatever your project sample rate is). Create a user config override:

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d
```

Create `~/.config/pipewire/pipewire.conf.d/audioconfig.conf`:

```
context.properties = {
    default.clock.rate          = 96000
    default.clock.allowed-rates = [ 44100 48000 96000 ]
    default.clock.quantum       = 512
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 2048
}
```

Adjust `default.clock.rate` and `default.clock.quantum` to match your needs:

| Quantum | Latency @ 48kHz | Latency @ 96kHz |
|---|---|---|
| 256 | ~5.3ms | ~2.7ms |
| 512 | ~10.7ms | ~5.3ms |
| 1024 | ~21.3ms | ~10.7ms |

Restart PipeWire to apply:

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

Verify:

```bash
pactl info | grep "Sample Spec"
# Should show: float32le 2ch 96000Hz (or whatever you set)
```

## Step 4: Make JACK Apps Use PipeWire

PipeWire includes a JACK compatibility shim (`pipewire-jack`), but your system may still have the real jackd2 libraries installed. You need to tell the dynamic linker to prefer PipeWire's JACK libraries so that DAWs and JACK clients connect to PipeWire instead of looking for a jackd server.

The `pipewire-jack` package ships an example config for exactly this:

```bash
sudo cp /usr/share/doc/pipewire/examples/ld.so.conf.d/pipewire-jack-x86_64-linux-gnu.conf \
    /etc/ld.so.conf.d/
sudo ldconfig
```

Verify the right libjack is first in the linker path:

```bash
ldconfig -p | grep "libjack.so " | head -3
# First result should point to /usr/lib/.../pipewire-0.3/jack/libjack.so
```

Any JACK app you launch after this will automatically connect to PipeWire.

> **Note:** If you had JACK apps already running when you did this (e.g. Overwitch), kill and relaunch them so they pick up the new library.

## Step 5: Verify JACK Connectivity

```bash
jack_samplerate    # should return your configured rate (e.g. 96000)
jack_lsp           # should list audio ports from your interface
```

## Step 6: Routing with qpwgraph

qpwgraph is the PipeWire equivalent of QjackCtl's patchbay. Launch it:

```bash
qpwgraph
```

You'll see nodes for each audio client (REAPER, Overwitch, browser, etc.) with ports you can connect by dragging. 

To save a patchbay and have it auto-restored:

1. Set up your connections in qpwgraph
2. **Patchbay > Save As** — save your `.qpwgraph` file somewhere persistent
3. **Patchbay > Activated** — tick this on; qpwgraph will enforce these connections whenever the relevant ports appear

To auto-launch qpwgraph on login with the patchbay active, create `~/.config/autostart/qpwgraph.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=qpwgraph
Comment=PipeWire patchbay
Exec=qpwgraph -a /path/to/your/patchbay.qpwgraph
X-GNOME-Autostart-enabled=true
```

## Overwitch / Overbridge

Overwitch connects to JACK. With the ldconfig shim in place (Step 4), it will automatically connect to PipeWire's JACK interface. Just launch Overwitch normally — no special configuration needed.

If Overwitch silently fails to mount your device, check the journal:

```bash
journalctl --user -b | grep -i overwitch | tail -30
```

The most common cause is that it launched before the ldconfig shim was in place and loaded the old jackd2 library. Kill it and relaunch:

```bash
pkill -f overwitch-service
pkill -f overwitch
# then relaunch from your app launcher
```

## Useful Commands

```bash
# Status
systemctl --user status pipewire pipewire-pulse wireplumber

# Restart (if something goes wrong)
systemctl --user restart pipewire pipewire-pulse wireplumber

# Check sample rate and ports
jack_samplerate
jack_lsp

# Check default output device
pactl info | grep -E "Default Sink|Sample Spec|Server Name"

# List all sinks (output devices)
pactl list short sinks

# Patchbay GUI
qpwgraph
```

## Rollback

To revert to PulseAudio + JACK, see [jack-pulseaudio.md](jack-pulseaudio.md) for the full setup, or if you saved a backup (Step 1):

```bash
# Stop PipeWire
systemctl --user stop pipewire pipewire-pulse wireplumber
systemctl --user disable pipewire pipewire-pulse wireplumber
systemctl --user mask pipewire.service pipewire-pulse.service

# Restore PulseAudio
systemctl --user unmask pulseaudio.service pulseaudio.socket
systemctl --user enable pulseaudio.service pulseaudio.socket
systemctl --user start pulseaudio.service

# Restore your config files from backup
cp ~/audio-backup/default.pa ~/.config/pulse/default.pa

# Remove the ldconfig shim
sudo rm /etc/ld.so.conf.d/pipewire-jack-x86_64-linux-gnu.conf
sudo ldconfig
```

Then follow the JACK startup steps in [jack-pulseaudio.md](jack-pulseaudio.md).
