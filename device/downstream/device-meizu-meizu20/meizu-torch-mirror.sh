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
# both chips; 0 turns them off.
# ringlight-boot coexistence: the boot animation runs on raw i2c after
# rmmod-ing leds_sy7808, so during the show the writes below fail
# silently (nodes absent) and the animation is untouched; after the
# show's ExecStopPost modprobe re-probes the driver (registers reset,
# torch cleared), the periodic re-assert restores the torch to whatever
# plasma still believes - no stuck "tile says on, lamps dark" state.
# s2idle: systemd freezes services during suspend, so the loop costs
# nothing while asleep.
IN=/sys/class/leds/white:flash/brightness
T1=/sys/class/leds/white:flash_1/brightness
T2=/sys/class/leds/white:flash_2/brightness
last=x
n=0
while :; do
	b=$(cat "$IN" 2>/dev/null) || { sleep 1; continue; }
	case "$b" in
	0) v=0 ;;
	*) v=17 ;;
	esac
	n=$((n + 1))
	# apply on change, else re-assert every ~4.8s (12 x 0.4s)
	if [ "$b" != "$last" ] || [ $((n % 12)) -eq 0 ]; then
		last=$b
		echo "$v" > "$T1" 2>/dev/null
		echo "$v" > "$T2" 2>/dev/null
	fi
	sleep 0.4
done
