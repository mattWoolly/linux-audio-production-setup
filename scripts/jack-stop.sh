#!/bin/bash
# jack-stop.sh
# Stop JACK and related processes cleanly.

echo "Stopping JACK..."
jack_control stop 2>/dev/null || true

echo "Stopping a2jmidid..."
pkill -x a2jmidid 2>/dev/null || true

echo "Done."
