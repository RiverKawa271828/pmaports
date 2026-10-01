#!/bin/sh
# Meizu 20 (m2381): ordered audio chain bring-up (WCD9385 SWR + macros).
# 2026-10-01 device day findings baked in:
#  - modules.alias autoload is unreliable on this platform: modules end up
#    LOADED but never PROBED (macros/pinctrl/swr all unbound, silent).
#    Only a full rmmod + ordered modprobe reliably re-probes them.
#  - order matters: pinctrl-lpass-lpi first (swr pinctrl-0 dependency),
#    then the four macros (they register the mclk clocks swr needs),
#    then soundwire_qcom (two buses, WCD slaves enumerate), then the
#    machine driver gets a kick so deferred links re-probe.
#  - rmmod snd_soc_wcd938x while the swr TX storm is ACTIVE freezes the
#    SoC (2026-10-01, one fastboot rescue). Safe only with the buses
#    down - meizu-noswr.service unbinds 6d30000 early in boot, so this
#    script's teardown phase runs in a zero-storm window.
# Serialization: chain tail of pas -> touch -> amps -> retimer -> audio.
set -x

# 0) teardown (buses are unbound via meizu-noswr, zero storm here)
# Belt and braces: unbind both masters ourselves in case noswr ran
# before the swr driver ever probed (its echo would have been a no-op
# and the buses could be up and storming by now).
echo 6ad0000.soundwire > /sys/bus/platform/drivers/qcom-soundwire/unbind 2>/dev/null
echo 6d30000.soundwire > /sys/bus/platform/drivers/qcom-soundwire/unbind 2>/dev/null
sleep 1
modprobe -r snd_soc_sc8280xp 2>/dev/null
modprobe -r snd_soc_qcom_sdw 2>/dev/null
modprobe -r snd_soc_wcd938x 2>/dev/null
modprobe -r snd_soc_wcd938x_sdw 2>/dev/null
modprobe -r soundwire_qcom 2>/dev/null
modprobe -r snd_soc_lpass_wsa_macro 2>/dev/null
modprobe -r snd_soc_lpass_tx_macro 2>/dev/null
modprobe -r snd_soc_lpass_rx_macro 2>/dev/null
modprobe -r snd_soc_lpass_va_macro 2>/dev/null
modprobe -r pinctrl-sm8550-lpass-lpi 2>/dev/null
sleep 1

# 1) ordered load
modprobe pinctrl-sm8550-lpass-lpi
sleep 2
modprobe snd_soc_lpass_va_macro
sleep 2
modprobe snd_soc_lpass_rx_macro
sleep 2
modprobe snd_soc_lpass_tx_macro
sleep 2
modprobe snd_soc_lpass_wsa_macro
sleep 3
modprobe soundwire_qcom
sleep 6

# 2) machine driver kick (wcd938x_sdw comes back via udev modalias when
# the slaves enumerate; re-probing the card picks up the links)
modprobe -r snd_soc_sc8280xp 2>/dev/null
modprobe snd_soc_sc8280xp
