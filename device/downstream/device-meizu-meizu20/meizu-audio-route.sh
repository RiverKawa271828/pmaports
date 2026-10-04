#!/bin/sh
# Meizu 20 (m2381) daily-use playback routing - audio daily round S1 (2026-10-04).
# Pins the card to the T4c-proven operating point (evidence:
# meizu20-m1/artifacts-uefi/audio-resume-b-20261004/mixer-t4c.txt, user
# ear-judged): FE MultiMedia1 -> BE SECONDARY_MI2S_RX -> CS35L45 x2
# (SPK 1-0031, RCV 1-0030).
# - the stream volume must be nonzero or the FE stays mute; the 44-char
#   truncated name below IS the real control name (the full
#   "...Playback Volume" name does not exist - set it and you silently
#   keep the zero default).
# - Digital PCM stays at the T4c safe levels (SPK 251/457, RCV 183/457):
#   89% trips the RCV (@30) short-error overload protection.
# Values converge with the r25 UCM files so pulseaudio's own UCM init
# (which now carries the same numbers) cannot undo this operating point.
# Idempotent; pure userspace; opens no PCM device (pulseaudio may own
# hw:0,0) - amixer only touches controls.

CARD=MEIZU20Inf
i=0
while [ $i -lt 150 ]; do
	test -d "/proc/asound/$CARD" && break
	i=$((i + 1))
	sleep 1
done
test -d "/proc/asound/$CARD" || {
	echo "meizu-audio-route: card $CARD never appeared (ADSP/bind floor?)"
	exit 1
}

amixer -c 0 cset name='SECONDARY_MI2S_RX Audio Mixer MultiMedia1' on,off >/dev/null
amixer -c 0 cset name='stream0.vol_ctrl0 MultiMedia1 Playback Volu' 26214 >/dev/null
amixer -c 0 cset name='SPK AMP Enable Switch' on >/dev/null
amixer -c 0 cset name='RCV AMP Enable Switch' on >/dev/null
amixer -c 0 cset name='SPK Digital PCM Volume' 251 >/dev/null
amixer -c 0 cset name='RCV Digital PCM Volume' 183 >/dev/null
amixer -c 0 cset name='SPK Analog PCM Volume' 3 >/dev/null
amixer -c 0 cset name='RCV Analog PCM Volume' 1 >/dev/null

echo "meizu-audio-route: $CARD pinned to the T4c operating point"
