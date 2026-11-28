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
#     (show wins for its duration); after the show's ExecStopPost
#     modprobe the pending old-state restore re-applies the torch.
#   - torch turned ON while a show is playing (fresh user action): the
#     failed write detects the show and STOPS it (flashlight wins).
#   - "off" during a show is a no-op (no override intent).
# v4 fix (user-reported long dark gap): the v3 override trigger sat on
# the periodic re-assert path too, so a pre-show torch killed a freshly
# started show ~4.8s in (the later action must win) and the torch then
# waited for the next 4.8s boundary. Now the two intents are separate
# flags: a fresh change may stop the show; the pre-show restore only
# retries (every tick, not on the 4.8s boundary) - the post-show gap
# collapses to the show's own modprobe time (~1s).
# s2idle: systemd freezes services during suspend, so the loop costs
# nothing while asleep.
IN=/sys/class/leds/white:flash/brightness
T1=/sys/class/leds/white:flash_1/brightness
T2=/sys/class/leds/white:flash_2/brightness
last=x
force=0  # fresh user change pending: may override (stop) a show
retry=0  # pending apply, never overrides (old-state restore / show wait)
n=0
while :; do
	b=$(cat "$IN" 2>/dev/null) || { sleep 1; continue; }
	case "$b" in
	0) v=0 ;;
	*) v=17 ;;
	esac
	if [ "$b" != "$last" ]; then
		force=1
		retry=1
	fi
	n=$((n + 1))
	if [ "$force" = 1 ] || [ "$retry" = 1 ] || [ $((n % 12)) -eq 0 ]; then
		if echo "$v" > "$T1" 2>/dev/null; then
			echo "$v" > "$T2" 2>/dev/null
			last=$b
			force=0
			retry=0
		else
			# nodes absent = a ringlight show owns the chips
			[ "$force" = 1 ] && [ "$v" != 0 ] && \
				systemctl stop ringlight-boot.service 2>/dev/null
			retry=1
		fi
	fi
	sleep 0.4
done
