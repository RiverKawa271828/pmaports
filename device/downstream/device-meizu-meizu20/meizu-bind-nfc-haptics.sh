#!/bin/sh
# Meizu 20 (m2381): bind the boot-orphan GENI SE 994000 (i2c_hub_5,
# haptics AW8697 @0x5a).
# 2026-10-04 device day: verified safe with live traffic on-device
# (994000: bus scan + chip ID read over i2c). It never auto-binds at
# boot (autoprobe race family, same disease as 988000 pre-retimer-unit).
# 880000 stays LETHAL - do NOT extend.
# a80000 (i2c0, NFC nfc@28) bind removed 2026-10-07: chip answers IRQs
# but NCI init never completes on mainline (suspect fw-download state);
# user verdict = remove from idle stack. Restore the a80000 bind line to
# re-enable NFC.
echo 0 > /sys/bus/platform/drivers_autoprobe
modprobe i2c_qcom_geni 2>/dev/null || true
echo 994000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 1 > /sys/bus/platform/drivers_autoprobe
