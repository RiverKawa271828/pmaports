#!/bin/sh
# phoenix-sdp-cap: cap the SMB5 input current at the USB 2.0 SDP spec
# (500mA) while the attached source is classified as SDP.
#
# Kernel-side, BC1.2 (APSD) can leave a strict SDP port programmed with
# the DCP limit (1.5A); the port then buckles, USBIN collapses and the
# battery drains while "plugged in" (observed on phoenix, 2026-09-01).
# The driver gets a proper event-driven fix (kernel-patches/0033); this
# userspace cap is the stopgap for kernels without it.
#
# Runs every 10s (phoenix-sdp-cap.timer). No-op unless the charger psy
# reports "[SDP]" (the bracket marks the active type) with an input
# current limit above the SDP cap.

PS=/sys/class/power_supply/pm8150b-charger
[ -d "$PS" ] || exit 0

type=$(grep -m1 '^POWER_SUPPLY_USB_TYPE=' "$PS/uevent" | cut -d= -f2-)
case "$type" in
*"[SDP]"*) ;;
*) exit 0 ;;
esac

imax=$(grep -m1 '^POWER_SUPPLY_CURRENT_MAX=' "$PS/uevent" | cut -d= -f2)
case "${imax:-0}" in
''|*[!0-9]*) exit 0 ;;
esac

if [ "$imax" -gt 500000 ]; then
	echo 500000 > "$PS/current_max" 2>/dev/null &&
		logger -t phoenix-sdp-cap "SDP: capped input current $imax -> 500000"
fi
