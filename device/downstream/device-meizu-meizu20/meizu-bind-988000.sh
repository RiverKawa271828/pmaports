#!/bin/sh
# Meizu 20 (m2381): safe i2c_qcom_geni load - 988000 (i2c_hub_2) only.
# VERDICT 2026-09-30 (unattended round): 988000.i2c is SAFE (whitelist candidate)
# - bind returned instantly, i2c-3 adapter appeared, nb7vpq904m typec-retimer
# bound ("inverted data lanes mapping"), fsa4480@42 -ENODEV (harmless).
# 880000.i2c remains LETHAL - do NOT extend this to it.
# Same pattern as meizu-touch-load.sh; binding is session-only (lost on reboot).
echo 0 > /sys/bus/platform/drivers_autoprobe
modprobe i2c_qcom_geni
echo 988000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 1 > /sys/bus/platform/drivers_autoprobe
