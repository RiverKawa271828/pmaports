#!/bin/sh
# Meizu 20 (m2381): keep the media default sink on meizu-spk - r49 (2026-10-07).
#
# The /etc/pulse/default.pa.d/meizu20-spk-mono.pa drop-in creates the
# remap sink (media L+R onto the main speaker; earpiece stays earpiece)
# and calls set-default-sink - but it loses the session-start race:
# something in the plasma startup tail (plasma-pa / device presets)
# re-points the default at the raw ALSA sink AFTER pulse finished
# loading default.pa.d (observed on the 10-07 r48 boot: meizu-spk
# present, default = Built-in; a manual set after the session settles
# sticks, so the override is a one-shot at startup). This autostart
# loop re-asserts the default every 2s until it has survived 10s of a
# settled session, then exits for good - a manual change by the user
# after that is respected.
stable=0
i=0
while [ "$i" -lt 60 ]; do
	cur=$(pactl get-default-sink 2>/dev/null)
	if [ "$cur" = "meizu-spk" ]; then
		stable=$((stable + 1))
		[ "$stable" -ge 5 ] && exit 0
	else
		stable=0
		pactl list short sinks 2>/dev/null | grep -q meizu-spk \
			&& pactl set-default-sink meizu-spk 2>/dev/null
	fi
	sleep 2
	i=$((i + 1))
done
exit 0
