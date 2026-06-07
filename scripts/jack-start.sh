#!/bin/bash
# jack-start.sh
# Start JACK audio stack for pro audio production.
# Finds your USB audio interface by name rather than hardcoded card index,
# which avoids breakage when the index changes between reboots.
#
# Usage: ./jack-start.sh
# Customize INTERFACE_NAME and JACK settings below.

# -----------------------------------------------------------------------
# Configuration -- edit these to match your setup
# -----------------------------------------------------------------------

# The ALSA name of your audio interface as it appears in /proc/asound/cards
# Run: cat /proc/asound/cards
# Look for the name in brackets, e.g. [Onyx24], [M2], [USB], etc.
INTERFACE_NAME="Onyx24"

# JACK settings
SAMPLE_RATE=96000
PERIOD=512        # frames per period (lower = less latency, harder on CPU)
NPERIODS=2        # number of periods per buffer (2 is standard)
REALTIME_PRIO=75  # realtime priority (requires audio group + limits config)

# -----------------------------------------------------------------------

set -e

# Find the card index by name
CARD_INDEX=""
for id_file in /proc/asound/card*/id; do
    if grep -q "^${INTERFACE_NAME}$" "$id_file" 2>/dev/null; then
        CARD_INDEX=$(echo "$id_file" | grep -oE 'card[0-9]+' | tr -d 'card')
        break
    fi
done

if [ -z "$CARD_INDEX" ]; then
    echo "Error: Interface '${INTERFACE_NAME}' not found in ALSA cards."
    echo "Available cards:"
    cat /proc/asound/cards
    echo ""
    echo "Update INTERFACE_NAME in this script to match your interface."
    exit 1
fi

echo "Found ${INTERFACE_NAME} at card ${CARD_INDEX} (hw:${CARD_INDEX})"

# Stop any existing JACK instance cleanly
jack_control stop &>/dev/null || true
sleep 1

# Configure jackdbus
jack_control ds alsa
jack_control dps device "hw:${CARD_INDEX}"
jack_control dps rate "${SAMPLE_RATE}"
jack_control dps period "${PERIOD}"
jack_control dps nperiods "${NPERIODS}"
jack_control eps realtime true
jack_control eps realtime-priority "${REALTIME_PRIO}"

# Start JACK
jack_control start
sleep 2

# Verify
if ! jack_control status | grep -q started; then
    echo "Error: JACK failed to start."
    exit 1
fi

LATENCY=$(echo "scale=1; ${PERIOD} * 1000 / ${SAMPLE_RATE}" | bc)
echo "JACK started: ${SAMPLE_RATE}Hz, ${PERIOD} frames (~${LATENCY}ms), realtime prio ${REALTIME_PRIO}"

# Unload PulseAudio JACK bridge modules -- they cause crashes under load.
# PulseAudio will talk to ALSA directly instead (via dmix).
pactl unload-module module-jack-sink 2>/dev/null || true
pactl unload-module module-jack-source 2>/dev/null || true
pactl unload-module module-jackdbus-detect 2>/dev/null || true
echo "Pulse-JACK bridge modules unloaded."

# Bridge ALSA MIDI into JACK MIDI
if ! pgrep -x a2jmidid >/dev/null; then
    a2jmidid -e &
    sleep 1
    echo "a2jmidid started."
fi

# Launch QjackCtl for routing and monitoring (optional)
if command -v qjackctl >/dev/null && ! pgrep -x qjackctl >/dev/null; then
    qjackctl &
    echo "QjackCtl launched."
fi

echo ""
echo "JACK is running. Connect your DAW to JACK audio."
echo "To stop: ./jack-stop.sh or: jack_control stop"
