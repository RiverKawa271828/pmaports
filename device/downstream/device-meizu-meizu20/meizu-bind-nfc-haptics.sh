#!/bin/sh
# Meizu 20 (m2381): bind the two boot-orphan GENI SEs - a80000 (i2c0, NFC
# nfc@28) and 994000 (i2c_hub_5, haptics AW8697 @0x5a).
# 2026-10-04 device day: both verified safe with live traffic on-device
# (a80000: nxp-nci probe + NCI handshake; 994000: bus scan + chip ID read
# over i2c). They never auto-bind at boot (autoprobe race family, same
# disease as 988000 pre-retimer-unit). 880000 stays LETHAL - do NOT extend.
echo 0 > /sys/bus/platform/drivers_autoprobe
modprobe i2c_qcom_geni 2>/dev/null || true
echo a80000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 994000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 1 > /sys/bus/platform/drivers_autoprobe
