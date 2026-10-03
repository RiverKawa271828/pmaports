#!/bin/sh
# Temporary min-brightness clamp guard (kernel clamp pending, r50+).
# AMOLED at DCS <~30 is invisible: userspace (powerdevil slider) can
# park the panel black with no way back. Poll and bounce to the floor.
B=/sys/class/backlight/ae94000.dsi.0/brightness
c=$(cat "$B" 2>/dev/null) || exit 0
case "$c" in ''|*[!0-9]*) exit 0 ;; esac
[ "$c" -ge 50 ] || echo 50 > "$B"
