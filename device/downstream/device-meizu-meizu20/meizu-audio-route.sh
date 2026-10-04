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
#    Stereo slot logic (bottom=L/top=R candidate) is UNVERIFIED: the
#    R channel has not been observed reaching @30; T2 host forensics
#    (2026-10-05): FE=2ch, BE chain passes channels, i2s device module
#    runs with sd_line_idx=1 and no static slot tokens - actual wire
#    channel count is DSP-runtime, live probe pending.
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
RCV_DIG=183
RCV_ANA=1
if [ -f /lib/firmware/cirrus/cs35l45-rcv-dsp1-spk-prot.wmfw ] \
	&& [ -f /lib/firmware/cirrus/cs35l45-rcv-dsp1-spk-prot.bin ] \
	&& dmesg | grep -q 'wm_adsp firmware part = "cs35l45-rcv"'; then
	RCV_DIG=409
	RCV_ANA=3
	echo "meizu-audio-route: per-amp RCV stack detected - @30 full registers 409/3"
else
	echo "meizu-audio-route: per-amp RCV stack NOT detected - @30 stays gentle 183/1"
fi

for c in \
	'SECONDARY_MI2S_RX Audio Mixer MultiMedia1:on,off' \
	'stream0.vol_ctrl0 MultiMedia1 Playback Volu:26214' \
	'SPK DACPCM Source:3' \
	'RCV DACPCM Source:3' \
	'SPK AMP Enable Switch:on' \
	'RCV AMP Enable Switch:on' \
	"SPK Digital PCM Volume:409" \
	"RCV Digital PCM Volume:$RCV_DIG" \
	'SPK Analog PCM Volume:3' \
	"RCV Analog PCM Volume:$RCV_ANA"
do
	name=${c%%:*}
	val=${c#*:}
	amixer -c 0 cset "name=$name" "$val" >/dev/null \
		|| echo "meizu-audio-route: FAILED cset '$name' '$val'"
done

echo "meizu-audio-route: $CARD bound and pinned (RCV=$RCV_DIG/$RCV_ANA, SPK=409/3)"

# r33 drift re-pin: pulseaudio applies UCM (which still pins RCV 183/1 -
# UCM csets cannot carry the runtime guard) once it claims the card, and
# again on every profile enable. Re-assert RCV when it drifted. Only the
# loudness direction can "lose" (reverted to 183 = quieter, never louder);
# 30s x 20 covers late pulse starts; after the loop a manual profile
# switch may revert @30 until next boot - accepted residual, safe direction.
i=0
while [ $i -lt 20 ]; do
	sleep 30
	cur=$(amixer -c 0 cget "name=RCV Digital PCM Volume" 2>/dev/null \
		| grep -o "values=[0-9]*" | tail -1 | cut -d= -f2)
	if [ "$cur" != "$RCV_DIG" ]; then
		amixer -c 0 cset "name=RCV Digital PCM Volume" "$RCV_DIG" >/dev/null \
			|| echo "meizu-audio-route: FAILED re-pin RCV Digital"
		amixer -c 0 cset "name=RCV Analog PCM Volume" "$RCV_ANA" >/dev/null \
			|| echo "meizu-audio-route: FAILED re-pin RCV Analog"
		echo "meizu-audio-route: re-pinned RCV (was $cur, target $RCV_DIG)"
	fi
	i=$((i + 1))
done
