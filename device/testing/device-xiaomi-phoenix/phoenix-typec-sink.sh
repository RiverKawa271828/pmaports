#!/bin/sh
# phoenix-typec-sink: auto-recover the "stuck as source" typec state that
# follows unplugging from a PC and then plugging a plain (non-PD) charger:
# the port keeps sourcing and reverse-feeds the charger from our battery.
#
# Runs every 30s (phoenix-typec-sink.timer). No-op unless ALL of these
# hold: we are [source], a partner is attached, no USB device has been
# enumerated on our host bus (i.e. partner is data-less), and the SMB5
# charger reports Discharging. Deliberate host-mode hubs enumerate a
# usb_device within seconds and are therefore left alone -- unlike the
# low-battery rescue in phoenix-typec-recover, this never reverts, but it
# also never fires while real data hardware is present.
set -u

typec=/sys/class/typec/port0

[ -e "$typec/power_role" ] || exit 0
[ -d /sys/class/typec/port0-partner ] || exit 0

pr=$(cat "$typec/power_role" 2>/dev/null || echo "")
case "$pr" in
    *"[source]"*) ;;
    *) exit 0 ;;
esac

# Give deliberate hosts time to enumerate before judging them.
sleep 5
ls /sys/bus/usb/devices/ 2>/dev/null | grep -qE '^[0-9]+-[0-9]' && exit 0

charger=/sys/class/power_supply/pm8150b-charger
status=$(cat "$charger/status" 2>/dev/null || echo "")
[ "$status" = "Discharging" ] || exit 0

echo sink > "$typec/power_role" 2>/dev/null || exit 0
logger -t phoenix-typec-sink "power-only partner while stuck as source -- forced sink"
