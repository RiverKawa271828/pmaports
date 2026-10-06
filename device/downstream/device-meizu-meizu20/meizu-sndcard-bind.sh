#!/bin/sh
# Meizu 20 (m2381) sound card attach floor - r48 (2026-10-07).
#
# History: the sound platform device ("sound", qcom,sm8550-sndcard) has
# an of:modalias without device_type, so udev never cold-binds it; every
# component must be attached by hand, in order:
#   6e80000.pinctrl (LPI) -> 6d44000.codec (va_macro) -> sound (machine).
# r47 added `echo 1 > drivers_autoprobe` before the kicks (device_attach
# honours the flag) and that fix was proven LIVE - but it failed at every
# real boot (r64 camera boot, flyme-return boot, 10-06 23:48 boot): the
# guard's 12ms execution window lands before the ADSP is up (GPR ready
# ~600ms later on fast boots; up to ~290s on old boot shapes) and inside
# the concurrent arbiter chain's autoprobe=0 windows. The kernel's
# deferred-probe auto-retry never rescues the three devices (empirical:
# stuck 20+ minutes; the boot+11s "deferred probe pending" dump lists
# aux_bridge/altmode but NOT the audio three), and meizu-audio-route's
# bind-retry alone cannot help - the machine probe hard-fails while its
# pinctrl/va upstream is unbound. Symptom: cs35l45 x2 probe fine, journal
# clean, /proc/asound/cards empty ("no soundcards").
# Fix: verify-and-retry. Each round: force autoprobe=1 (the whole arbiter
# chain is ordered BEFORE this unit now, but keep the belt), kick the
# three devices (idempotent, rc ignored), then CHECK the card; repeat
# every 2s until it exists. The loop rides out the ADSP window, any
# residual flag bounce, and any kick that no-ops for a reason we have
# not named yet - mechanism-agnostic by design. Exit 0 always:
# meizu-audio-route stays the loud canary when the card never comes up.
test -d /proc/asound/MEIZU20 && exit 0
i=0
while [ "$i" -lt 180 ]; do
	echo 1 > /sys/bus/platform/drivers_autoprobe 2>/dev/null
	echo 6e80000.pinctrl > /sys/bus/platform/drivers_probe 2>/dev/null
	if [ ! -d /sys/bus/platform/drivers/va_macro ]; then
		modprobe snd_soc_lpass_va_macro 2>/dev/null
		n=0
		while [ "$n" -lt 25 ] && [ ! -d /sys/bus/platform/drivers/va_macro ]; do
			usleep 200000
			n=$((n + 1))
		done
	fi
	echo 6d44000.codec > /sys/bus/platform/drivers_probe 2>/dev/null
	echo sound > /sys/bus/platform/drivers_probe 2>/dev/null
	if [ -d /proc/asound/MEIZU20 ]; then
		echo "meizu-sndcard-bind: card MEIZU20 attached (round $i)"
		exit 0
	fi
	usleep 2000000
	i=$((i + 1))
done
echo "meizu-sndcard-bind: card MEIZU20 never attached (180 rounds; ADSP up? amps bound?)"
exit 0
