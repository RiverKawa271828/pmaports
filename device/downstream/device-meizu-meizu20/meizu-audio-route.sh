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
# 2. PIN THE OPERATING POINT (r32): signal path = THROUGH the CS35L45
#    on-chip DSP (DACPCM Source=DSP_TX1) with the packaged speaker-
#    protection firmware - this is how stock/flyme runs both amps
#    (mixer_paths "spk_prot": DSP1 Enable=1 + Digital 817 == our raw
#    409); the DSP limits in real time from IV sense, which is why
#    flyme can drive the amps at full registers without tripping the
#    short-error protection (our r30 409-through-DSP tests: zero
#    errors, user reports less noise vs the bypass path).
#    SPK (@31, bottom) = stock registers: Digital 409 / Analog 3.
#    RCV (@30, top)    = r33: stock full registers (Digital 409 / Analog 3)
#    once the per-amp stack is in place - kernel fork b52b99bfc6de builds
#    wm_adsp part names from sound-name-prefix so @30 loads the RCV-tuned
#    DSP limiter (firmware r3, harvested from this device's stock vendor
#    image), and @30 full gain without THAT limiter would be the exact
#    mistake stock avoids (small driver, spk limiter is not tuned for it).
#    Guard (both required, else stay at T4c 183/1):
#      - firmware files on disk: cirrus/cs35l45-rcv-dsp1-spk-prot.{wmfw,bin}
#      - kernel log shows wm_adsp part = "cs35l45-rcv" (new driver active)
#    The wmfw itself is only requested at first stream preload, so there
#    is no dmesg success trace at route time - file presence + part string
#    is the practical proxy; the flashing-session acceptance (short error
#    count + ear) closes the loop.
#    Stereo VERIFIED on-device (2026-10-05, user ear): L=top @30 (rcv,
#    loads left.bin protection), R=bottom @31 (spk, right.bin) - matches
#    the stock per-amp protection naming exactly, no swap needed. The
#    old "R never reaches @30" verdict was the 183/1 near-mute masking
#    the left channel; APM live print ch=2 confirms the DSP receives
#    stereo (T2 closed, no copp defect).
#    r34 loudness round (2026-10-05 device session, user ear A/B): the
#    T4c-era pads are retired now that the per-amp DSP protection is
#    verified (0 short errors through 0dBFS sine loops at full gain):
#      - stream volume 26214 (40%, -8dB bypass-era pad) -> 65535
#      - digital 409 (0dB, stock route value) -> 457 (+12dB, mainline
#        ALSA max; flyme max slider lands here or below - their XML 817
#        is raw 0dB, their playing dump was below max)
#      - analog stays 3 (19dB = field max, 2-bit AMP_GAIN_PCM)
#    Remaining loudness reserve = flyme fast-switch scene deltas
#    (cirrus,fast-switch: spk/rcv-music|game|movie|voice.txt, vendored
#    MBC ceiling retunes) - never harvested, needs a stock boot day.
#    - the stream volume must be nonzero or the FE stays mute; the
#      44-char truncated name below IS the real control name (the full
#      "...Playback Volume" name does not exist - set it and you
#      silently keep the zero default).
# Values converge with the r32 UCM files so pulseaudio's own UCM init
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

# r30: no output suppression - every cset result is logged so a boot
# log doubles as mixer-state evidence (the vanishing-controls bug made
# silent cset failures indistinguishable from successes).

# r33: RCV full registers only with the per-amp firmware stack in place.
# r34: full registers raised to the +12dB digital headroom (see header).
RCV_DIG=183
RCV_ANA=1
SPK_DIG=457
if [ -f /lib/firmware/cirrus/cs35l45-rcv-dsp1-spk-prot.wmfw ] \
	&& [ -f /lib/firmware/cirrus/cs35l45-rcv-dsp1-spk-prot.bin ] \
	&& dmesg | grep -q 'wm_adsp firmware part = "cs35l45-rcv"'; then
	RCV_DIG=457
	RCV_ANA=3
	echo "meizu-audio-route: per-amp RCV stack detected - @30 full registers 457/3"
else
	echo "meizu-audio-route: per-amp RCV stack NOT detected - @30 stays gentle 183/1"
fi

for c in \
	'SECONDARY_MI2S_RX Audio Mixer MultiMedia1:on,off' \
	'stream0.vol_ctrl0 MultiMedia1 Playback Volu:65535' \
	'SPK DACPCM Source:3' \
	'RCV DACPCM Source:3' \
	'SPK AMP Enable Switch:on' \
	'RCV AMP Enable Switch:on' \
	"SPK Digital PCM Volume:$SPK_DIG" \
	"RCV Digital PCM Volume:$RCV_DIG" \
	'SPK Analog PCM Volume:3' \
	"RCV Analog PCM Volume:$RCV_ANA"
do
	name=${c%%:*}
	val=${c#*:}
	amixer -c 0 cset "name=$name" "$val" >/dev/null \
		|| echo "meizu-audio-route: FAILED cset '$name' '$val'"
done

echo "meizu-audio-route: $CARD bound and pinned (RCV=$RCV_DIG/$RCV_ANA, SPK=$SPK_DIG/3, stream=100%)"

# r33 drift re-pin: pulseaudio applies UCM (which still pins RCV 183/1 -
# UCM csets cannot carry the runtime guard) once it claims the card, and
# again on every profile enable. Re-assert RCV (and SPK, r34: UCM pins
# SPK 409) when they drifted. Only the loudness direction can "lose"
# (reverted to 183/409 = quieter, never louder);
# 30s x 20 covers late pulse starts; after the loop a manual profile
# switch may revert @30 until next boot - accepted residual, safe direction.
i=0
while [ $i -lt 20 ]; do
	sleep 30
	for pair in "RCV:$RCV_DIG" "SPK:$SPK_DIG"; do
		amp=${pair%%:*}
		target=${pair#*:}
		cur=$(amixer -c 0 cget "name=$amp Digital PCM Volume" 2>/dev/null \
			| grep -o "values=[0-9]*" | tail -1 | cut -d= -f2)
		if [ "$cur" != "$target" ]; then
			amixer -c 0 cset "name=$amp Digital PCM Volume" "$target" >/dev/null \
				|| echo "meizu-audio-route: FAILED re-pin $amp Digital"
			# UCM also drags RCV analog back to 1; only re-assert it here
			# so a failed digital cset never leaves analog mismatched.
			if [ "$amp" = "RCV" ]; then
				amixer -c 0 cset "name=RCV Analog PCM Volume" "$RCV_ANA" >/dev/null \
					|| echo "meizu-audio-route: FAILED re-pin RCV Analog"
			fi
			echo "meizu-audio-route: re-pinned $amp (was $cur, target $target)"
		fi
	done
	i=$((i + 1))
done
