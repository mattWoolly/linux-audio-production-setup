#!/bin/bash
# pipewire-switch.sh
# Switch from PulseAudio + JACK to PipeWire.
#
# Run this once to migrate your audio stack to PipeWire.
# PipeWire will handle DAW audio (via JACK compatibility), system audio
# (via PulseAudio compatibility), and USB audio hardware simultaneously.
#
# See docs/pipewire.md for full setup guide and manual steps.

set -e

echo "=== Switching to PipeWire ==="
echo ""

# -----------------------------------------------------------------------
# Step 1: Stop existing audio servers
# -----------------------------------------------------------------------
echo "[1/5] Stopping existing audio servers..."

jack_control stop 2>/dev/null || true
pkill -x jackd 2>/dev/null || true
pkill -x jackdbus 2>/dev/null || true
pkill -x a2jmidid 2>/dev/null || true
systemctl --user stop pulseaudio.service pulseaudio.socket 2>/dev/null || true

sleep 1

# -----------------------------------------------------------------------
# Step 2: Mask PulseAudio
# -----------------------------------------------------------------------
echo "[2/5] Masking PulseAudio..."
systemctl --user mask pulseaudio.service pulseaudio.socket

# -----------------------------------------------------------------------
# Step 3: Enable and start PipeWire
# -----------------------------------------------------------------------
echo "[3/5] Starting PipeWire..."
systemctl --user unmask pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber

sleep 3

# Verify
FAILED=0
for svc in pipewire pipewire-pulse wireplumber; do
    STATUS=$(systemctl --user is-active "$svc" 2>/dev/null)
    if [ "$STATUS" != "active" ]; then
        echo "  WARNING: $svc is $STATUS"
        FAILED=1
    fi
done

if [ "$FAILED" -eq 0 ]; then
    echo "  All PipeWire services active."
else
    echo ""
    echo "One or more services failed to start. Check:"
    echo "  systemctl --user status pipewire pipewire-pulse wireplumber"
    exit 1
fi

# -----------------------------------------------------------------------
# Step 4: Install JACK compatibility shim
# -----------------------------------------------------------------------
echo "[4/5] Installing JACK compatibility shim..."

SHIM_SRC="/usr/share/doc/pipewire/examples/ld.so.conf.d/pipewire-jack-x86_64-linux-gnu.conf"
SHIM_DEST="/etc/ld.so.conf.d/pipewire-jack-x86_64-linux-gnu.conf"

if [ ! -f "$SHIM_SRC" ]; then
    echo "  WARNING: Shim source not found at $SHIM_SRC"
    echo "  Is pipewire-jack installed? Try: sudo apt install pipewire-jack"
    echo "  Skipping this step. JACK apps may not connect to PipeWire."
else
    sudo cp "$SHIM_SRC" "$SHIM_DEST"
    sudo ldconfig
    echo "  JACK shim installed and ldconfig updated."
fi

# -----------------------------------------------------------------------
# Step 5: Report status
# -----------------------------------------------------------------------
echo "[5/5] Verifying..."
echo ""
pactl info | grep -E "Server Name|Default Sink|Sample Spec"
echo ""
RATE=$(jack_samplerate 2>/dev/null || echo "unavailable")
echo "JACK sample rate: ${RATE}"
echo ""

echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  - Set your sample rate in ~/.config/pipewire/pipewire.conf.d/audioconfig.conf"
echo "    (see docs/pipewire.md Step 3 for the config file contents)"
echo "  - Use qpwgraph for patchbay routing (replaces QjackCtl)"
echo "  - If JACK apps were running, kill and relaunch them"
echo ""
echo "To roll back: see docs/pipewire.md Rollback section"
