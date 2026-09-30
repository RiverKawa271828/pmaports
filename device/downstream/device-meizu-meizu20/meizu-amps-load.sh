#!/bin/sh
# Meizu 20 (m2381): safe i2c_qcom_geni load - i2c10 (888000) only.
# 2026-10-01 r36 device day: binding 888000.i2c brings up both CS35L45
# amps instantly (1-0030 RCV + 1-0031 SPK, REVID A0). 888000 is NOT the
# 880000 latch bus (different wrapper, parent qupv3_id_1) and 880000
# stays LETHAL - blacklist must stay.
# Same pattern as meizu-touch-load.sh; binding is session-only (lost on
# reboot), so meizu-amps.service re-runs this every boot.
echo 0 > /sys/bus/platform/drivers_autoprobe
modprobe i2c_qcom_geni
echo 888000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 1 > /sys/bus/platform/drivers_autoprobe
