# Troubleshooting

## PipeWire

### All three services won't start

Check if any are masked:

```bash
systemctl --user status pipewire pipewire-pulse wireplumber
```

If masked (`Loaded: masked`), unmask before enabling:

```bash
systemctl --user unmask pipewire.service pipewire-pulse.service wireplumber.service
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber
```

### REAPER / DAW says "JACK server not running"

Most likely the JACK shim isn't in place. Check:

```bash
ldconfig -p | grep "libjack.so " | head -3
```

The first result should point to a path containing `pipewire-0.3/jack`. If it points to `/lib/x86_64-linux-gnu/libjack.so` instead, the shim isn't installed. Follow Step 4 in [pipewire.md](pipewire.md).

If the shim is installed but the DAW still fails, it may have been launched before the shim was in place. Restart the DAW.

### Overwitch silently fails to mount device

The device is seen by USB but the JACK connection fails. Check the journal:

```bash
journalctl --user -b | grep -i overwitch | tail -30
```

If you see `jack server is not running or cannot be started`, Overwitch loaded the old jackd2 library before the PipeWire shim was in place. Kill all Overwitch processes and relaunch:

```bash
pkill -f overwitch
# relaunch from app launcher
```

### Wrong sample rate after restart

PipeWire config not loading. Verify:

```bash
ls ~/.config/pipewire/pipewire.conf.d/
pactl info | grep "Sample Spec"
```

If the file exists but rate is still wrong, restart PipeWire:

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### No audio at all after switching to PipeWire

Check what the default sink is:

```bash
pactl info | grep "Default Sink"
pactl list short sinks
```

If the sink shows `@DEFAULT_SINK@` or the wrong device, set it explicitly:

```bash
pactl set-default-sink alsa_output.your-device-name
```

Find the correct name from `pactl list short sinks`.

### Crackling / xruns in DAW

Increase the quantum (buffer size):

```bash
# Temporary, takes effect immediately:
pw-metadata -n settings 0 clock.force-quantum 1024

# Permanent: edit ~/.config/pipewire/pipewire.conf.d/audioconfig.conf
# Change default.clock.quantum = 1024
# Then restart PipeWire
```

Also check CPU governor — `performance` mode significantly reduces xruns:

```bash
# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Set performance mode (until reboot)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

---

## JACK + PulseAudio

### JACK crashes when PulseAudio is running

Do not use `module-jack-sink` or `module-jackdbus-detect`. Unload them:

```bash
pactl unload-module module-jack-sink 2>/dev/null
pactl unload-module module-jack-source 2>/dev/null
pactl unload-module module-jackdbus-detect 2>/dev/null
```

And prevent them from loading in `~/.config/pulse/default.pa`.

### JACK fails to start — "cannot lock down memory"

Add your user to the `audio` group and configure realtime limits:

```bash
sudo usermod -aG audio $USER
```

Check `/etc/security/limits.d/audio.conf` (created by jackd2 package). You may need to log out and back in.

### Interface not found at startup

The card index changed. Use the name-based lookup instead of hardcoded indices. See [jack-pulseaudio.md](jack-pulseaudio.md) and the startup script.

### No sound from browser/media players while JACK is running

PulseAudio may have lost its ALSA sink. Check:

```bash
pactl list short sinks
```

If no sinks are listed, PulseAudio lost its connection to ALSA. Restart it:

```bash
systemctl --user restart pulseaudio
```

---

## General

### How do I know which audio server is running?

```bash
pactl info | grep "Server Name"
# "PulseAudio (on PipeWire x.x.x)" = PipeWire with Pulse compatibility
# "PulseAudio" = plain PulseAudio
```

### How do I check for xruns?

With PipeWire:

```bash
pw-top
```

With JACK:

```bash
# QjackCtl shows xrun count in the status bar
# Or: journalctl --user -f | grep -i xrun
```

### USB audio interface not recognized

```bash
lsusb          # verify it's seen by USB
aplay -l       # verify ALSA sees it
dmesg | grep -i usb | tail -20  # check for USB errors
```

Try a different USB port (directly on motherboard, not a hub) and a different cable.
