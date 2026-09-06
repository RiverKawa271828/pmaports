#!/bin/sh
# phoenix-dsp-recovery: converge out of the probabilistic DSP "degraded"
# boot state (no sound card + no SSC sensors) with a single automatic reboot.
#
# Background (evidence/dsp-degraded/): ~20-30% of boots the ADSP firmware
# finishes its init "dice roll" by entering low power it can never wake from
# (qcom_stats adsp Count frozen, last_entered>last_exited). No host-side
# lever exists (PDC routing / attach timing / LCX-LMX keep-on all tested and
# rejected). A warm reboot converges to a healthy boot (empirically ~100%,
# the degradation is per-boot independent).
#
# This service waits for the DSP service chain to settle, then if BOTH sound
# card and accelerometer are missing (= degraded), reboots once. A persist
# counter prevents a reboot loop if the next boot is degraded again -- after
# the second consecutive attempt it gives up and leaves the device as-is.
set -u

# Wait for ADSP/hexagonrpcd/sensors to finish coming up before judging.
sleep 100

card=$(aplay -l 2>/dev/null | grep -c '^card')
ssc=$(ssccli --sensor accelerometer --timeout 2 2>&1 |
    grep -c 'Accelerometer sensor measurement')

# Healthy: do nothing.
if [ "$card" -ge 1 ] || [ "$ssc" -ge 1 ]; then
    # Clear the recovery counter so a future degraded boot can retry.
    rm -f /mnt/vendor/persist/phoenix/dsp-recovery-count 2>/dev/null
    exit 0
fi

# Degraded. Use a persistent counter to allow at most 2 consecutive reboots.
counter=/mnt/vendor/persist/phoenix/dsp-recovery-count
mkdir -p "$(dirname "$counter")" 2>/dev/null
n=0
[ -f "$counter" ] && n=$(cat "$counter" 2>/dev/null || echo 0)
n=$((n + 1))

logger -t phoenix-dsp-recovery \
    "degraded boot detected (card=$card ssc=$ssc), recovery attempt $n/2"
echo "$n" > "$counter" 2>/dev/null

if [ "$n" -lt 2 ]; then
    logger -t phoenix-dsp-recovery "rebooting to converge"
    sync
    reboot
fi

logger -t phoenix-dsp-recovery "still degraded after 2 attempts, giving up"
exit 0
