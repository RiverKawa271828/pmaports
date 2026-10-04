#!/bin/sh
# Meizu 20 (m2381) daily-use playback routing - audio daily round S1/S3 (2026-10-04).
# Two jobs, both required for a desktop that makes sound after every boot:
#
# 1. BIND RETRY. The snd-sc8280xp machine driver does not autoprobe (of
#    modalias T(null)) and a single early bind write fails with -EAGAIN
#    while the ADSP/q6 components are still down (~90s boot). Poll-retry
#    the bind until card0 exists. The separate meizu-sndcard-bind unit
#    stays as a harmless early belt-and-braces attempt.
#
# 2. PIN THE T4c OPERATING POINT (evidence:
#    meizu20-m1/artifacts-uefi/audio-resume-b-20261004/mixer-t4c.txt,
#    user ear-judged): FE MultiMedia1 -> BE SECONDARY_MI2S_RX ->
#    CS35L45 x2 (SPK 1-0031, RCV 1-0030).
#    - the stream volume must be nonzero or the FE stays mute; the
#      44-char truncated name below IS the real control name (the full
#      "...Playback Volume" name does not exist - set it and you
#      silently keep the zero default).
#    - Digital PCM stays at the T4c safe levels (SPK 251/457, RCV
#      183/457): 89% trips the RCV (@30) short-error overload
#      protection.
# Values converge with the r26 UCM files so pulseaudio's own UCM init
# (same numbers) cannot undo this operating point.
# Idempotent; pure userspace; opens no PCM device (pulseaudio may own
# hw:0,0) - amixer only touches controls.

CARD=MEIZU20Inf
BIND=/sys/bus/platform/drivers/snd-sc8280xp/bind

# r27: 150 x 3s = 450s budget. The ADSP boot (which the machine probe
# waits for) has been observed anywhere between ~75s and ~290s after
# boot (meizu-pas starts late on some boots); the first S3 attempt had
# a 270s budget and missed the ADSP by one retry cycle.
i=0
while [ $i -lt 150 ]; do
	test -d "/proc/asound/$CARD" && break
	echo sound > "$BIND" 2>/dev/null
	i=$((i + 1))
	sleep 3
done
test -d "/proc/asound/$CARD" || {
	echo "meizu-audio-route: card $CARD never appeared (ADSP up? amps bound?)"
	exit 1
}

# r29: no output suppression - every cset result is logged so a boot
# log doubles as mixer-state evidence (the vanishing-controls bug made
# silent cset failures indistinguishable from successes).
for c in \
	'SECONDARY_MI2S_RX Audio Mixer MultiMedia1:on,off' \
	'stream0.vol_ctrl0 MultiMedia1 Playback Volu:26214' \
	'SPK AMP Enable Switch:on' \
	'RCV AMP Enable Switch:on' \
	'SPK Digital PCM Volume:251' \
	'RCV Digital PCM Volume:183' \
	'SPK Analog PCM Volume:3' \
	'RCV Analog PCM Volume:1'
do
	name=${c%%:*}
	val=${c#*:}
	amixer -c 0 cset "name=$name" "$val" >/dev/null \
		|| echo "meizu-audio-route: FAILED cset '$name' '$val'"
done

echo "meizu-audio-route: $CARD bound and pinned to the T4c operating point"
