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
# Mutual override with ringlight-boot (user round 136+3): the boot
# animation runs on raw i2c after rmmod-ing leds_sy7808, so while a show
# is playing the writes below fail (nodes absent).
#   - show started while torch on: rmmod seizes the chips instantly
#     (show wins for its duration); the periodic re-assert restores the
#     torch after the show's ExecStopPost modprobe, matching what the
#     plasma tile still says.
#   - torch turned ON while a show is playing: the failed write detects
#     the show and STOPS it (flashlight wins); modprobe returns the
#     nodes and the next poll applies the torch.
#   - "off" during a show is a no-op (no override intent).
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
	if [ "$b" != "$last" ] || [ $((n % 12)) -eq 0 ]; then
		if echo "$v" > "$T1" 2>/dev/null; then
			echo "$v" > "$T2" 2>/dev/null
			last=$b
		elif [ "$v" != 0 ]; then
			# nodes absent = a ringlight show owns the chips:
			# flashlight overrides, stop the show. ExecStopPost
			# modprobe brings the nodes back and the next poll
			# applies the torch.
			systemctl stop ringlight-boot.service 2>/dev/null
		fi
	fi
	sleep 0.4
done
