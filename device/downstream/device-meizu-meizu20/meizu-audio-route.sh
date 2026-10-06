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
# 2. PIN THE OPERATING POINT (r41): signal path = DIRECT DRIVE, DSP out
#    of the path (RCV DACPCM=ASP_RX1 slot0/L, SPK DACPCM=ASP_RX2 slot1/R;
#    the T4c-era default that the r32..r35 csets had overridden).
#    Verdict basis (2026-10-06, unattended forensics + user timeline):
#    - through-DSP (DACPCM=DSP_TX1, r32..r40) paid a FULL wmfw+bin
#      re-download on EVERY stream start (cs_dsp_power_down drops the
#      image; journal shows ~2s of DSP1 firmware lines per stream, both
#      amps) = the "volume key needs several presses" latency, plus
#      PLL-unlock / global-error-239 storms while the DSP ran = the
#      noise/snow domain.
#    - direct drive shows ZERO kernel audio lines across park/resume
#      cycles (verified on-device) = real-time start, no DSP-path
#      glitch domain. User timeline: clean + real-time exactly in the
#      T4c direct-drive era; degradation tracks the r32 DSP path and
#      the r33-r35 full-register raise.
#    Operating point (r44, 2026-10-06 loudness round, user-tested):
#      stream volume 58981 (90%, user-called conservative compromise),
#      SPK Digital 409 / Analog 3 (= the stock raw registers: flyme
#      playing dump 817-vendored == 409; direct drive has no limiter
#      compression, so perceived loudness runs above flyme at the
#      same slider position), RCV Digital 251 / Analog 1 (small unit:
#      r30 proved 409-direct trips its short-error protection; 251 =
#      55% of the trip point). Zero short/PLL errors through the
#      user's max-volume music session. Do NOT play full-scale sines
#      at max volume.
#    True stock parity (limiter + fast-switch scene deltas + flyme
#    volume curve) = through-DSP path with the kernel preload fix -
#    deferred to the flyme stock forensics day (user call, 2026-10-06).
#    Direct-mode stereo (slot0->@30 L, slot1->@31 R) pending user ear
#    re-judgment on this configuration.
#    - the stream volume must be nonzero or the FE stays mute; the
#      44-char truncated name below IS the real control name (the full
#      "...Playback Volume" name does not exist - set it and you
#      silently keep the zero default).
# Values deliberately do NOT converge with the UCM files here (UCM pins
# its own numbers on profile enable); the drift re-pin loop below is
# the authority for the digital/analog levels.
# Idempotent; pure userspace; opens no PCM device (pulseaudio may own
# hw:0,0) - amixer only touches controls.

CARD=MEIZU20
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

# r30: no output suppression - every cset result is logged so a boot
# log doubles as mixer-state evidence (the vanishing-controls bug made
# silent cset failures indistinguishable from successes).

for c in \
	'SECONDARY_MI2S_RX Audio Mixer MultiMedia1:on,off' \
	'stream0.vol_ctrl0 MultiMedia1 Playback Volu:58981' \
	'RCV DACPCM Source:1' \
	'SPK DACPCM Source:2' \
	'SPK AMP Enable Switch:on' \
	'RCV AMP Enable Switch:on' \
	'SPK Digital PCM Volume:409' \
	'RCV Digital PCM Volume:251' \
	'SPK Analog PCM Volume:3' \
	'RCV Analog PCM Volume:1' \
	'MultiMedia3 Mixer TX_CODEC_DMA_TX_3:on,off' \
	'VA_AIF1_CAP Mixer DEC0:on' \
	'VA DMIC MUX0:1' \
	'VA DEC0 MUX:0'
do
	name=${c%%:*}
	val=${c#*:}
	amixer -c 0 cset "name=$name" "$val" >/dev/null \
		|| echo "meizu-audio-route: FAILED cset '$name' '$val'"
done

echo "meizu-audio-route: $CARD bound and pinned (direct drive: RCV=ASP_RX1 251/1, SPK=ASP_RX2 409/3, stream=90%)"

# r33 drift re-pin, r41 targets: pulseaudio applies UCM (which pins its
# own numbers) once it claims the card and again on every profile
# enable. Re-assert the T4c-era point when it drifted; the loudness
# direction is intentionally NOT guarded anymore (the 457/full-register
# era is retired, see header).
i=0
while [ $i -lt 20 ]; do
	sleep 30
	for pair in "RCV:251" "SPK:409"; do
		amp=${pair%%:*}
		target=${pair#*:}
		cur=$(amixer -c 0 cget "name=$amp Digital PCM Volume" 2>/dev/null \
			| grep -o "values=[0-9]*" | tail -1 | cut -d= -f2)
		if [ "$cur" != "$target" ]; then
			amixer -c 0 cset "name=$amp Digital PCM Volume" "$target" >/dev/null \
				|| echo "meizu-audio-route: FAILED re-pin $amp Digital"
			if [ "$amp" = "RCV" ]; then
				amixer -c 0 cset "name=RCV Analog PCM Volume" 1 >/dev/null \
					|| echo "meizu-audio-route: FAILED re-pin RCV Analog"
			fi
			echo "meizu-audio-route: re-pinned $amp (was $cur, target $target)"
		fi
	done
	i=$((i + 1))
done
