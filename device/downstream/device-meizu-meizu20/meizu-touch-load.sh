#!/bin/sh
# Meizu 20 (m2381): safe i2c_qcom_geni load - touch SE only.
# 880000.i2c is LETHAL on this chain (2026-09-29 freeze, no panic, pstore empty).
# Never let udev coldplug bind all SEs: blacklist keeps the module unloaded,
# this script loads it with drivers_autoprobe=0 and binds a90000 (touch) only.
echo 0 > /sys/bus/platform/drivers_autoprobe
modprobe i2c_qcom_geni
echo a90000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 1 > /sys/bus/platform/drivers_autoprobe
