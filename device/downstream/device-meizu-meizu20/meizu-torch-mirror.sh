#!/bin/sh
# Mirror plasma-mobile's flashlight quicksetting onto the real SY7808
# torch LEDs. plasma-mobile v6.8.3 flashlightutil.cpp picks the first
# leds-class device whose sysname matches "*:torch|*:flash" - on this
# device that is the pm8550 white:flash node, a physically dead channel
# (stock-era verdict: the lamps are fed by the SY7808 internal boost,
# not any PMIC rail), so the toggle wrote a node that can never light.
# The real LEDs (white:flash_1/2, leds-sy7808) don't match the globs,
# and sysnames cannot be renamed from userspace. Brightness writes emit
# no uevents either (verified 2026-11-28: udevadm monitor shows zero
# change events) - hence this poll loop. Any nonzero write to
# white:flash/brightness becomes torch level 17 (=300mA stock clamp) on
# both chips; 0 turns them off. Level 17 = max_brightness of white:flash
# (255) clamped to the leds-sy7808 torch range.
# rmmod window: ringlight-boot's ExecStartPre removes leds_sy7808; the
# retry branch resets `last` so the state is re-applied once the module
# (and the nodes) come back via ExecStopPost modprobe.
# s2idle: systemd freezes services during suspend, so the loop costs
# nothing while asleep.
IN=/sys/class/leds/white:flash/brightness
T1=/sys/class/leds/white:flash_1/brightness
T2=/sys/class/leds/white:flash_2/brightness
last=x
while :; do
	b=$(cat "$IN" 2>/dev/null) || { last=x; sleep 1; continue; }
	if [ "$b" != "$last" ]; then
		last=$b
		case "$b" in
		0) v=0 ;;
		*) v=17 ;;
		esac
		echo "$v" > "$T1" 2>/dev/null
		echo "$v" > "$T2" 2>/dev/null
	fi
	sleep 0.4
done
