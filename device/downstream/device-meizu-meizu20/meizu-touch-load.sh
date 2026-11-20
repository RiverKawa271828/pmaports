#!/bin/sh
# Meizu 20 (m2381): safe i2c_qcom_geni load - touch SE + camera hub only.
# 880000.i2c is LETHAL on this chain (2026-09-29 freeze, no panic, pstore empty).
# Never let udev coldplug bind all SEs: blacklist keeps the module unloaded,
# this script loads it with drivers_autoprobe=0 and binds a90000 (touch) +
# 98c000 (hub_3 camera path) + 988000 (hub_2 pm8008i) only —— 108 轮两连 boot
# 手踢固化（r69 自动踢还债）+ r72 补 hub_2（pm8008i = GD2 前摄供电 blocker）。
echo 0 > /sys/bus/platform/drivers_autoprobe
modprobe i2c_qcom_geni
echo a90000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 98c000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 988000.i2c > /sys/bus/platform/drivers/geni_i2c/bind
echo 1 > /sys/bus/platform/drivers_autoprobe

# r102 相机轮（2026-11-20）：platform drivers_autoprobe=0 窗口吞掉 pm8008 mfd
# regulator 细胞 —— i2c 客户端不受影响（i2c 总线有独立 autoprobe 位），mfd 细胞
# 落在 platform 总线上恰逢窗口，而 drivers_autoprobe_store 只翻标志永不 rescan
# （drivers/base/bus.c 实锤）→ 相机 PMIC 全轨不注册 → s5k3p9sx deferred 永挂。
# 修法 = force-bind 细胞（重试环等异步 mfd probe），再补绑传感器（deferred 在
# regulator_register 时不自动重跑，手动 bind 是可靠 retrigger）。
# r72（2026-11-21）：r71 环只盯「已存在」的细胞 —— pm8008i 的 .2.auto 若在本环
# 跑完后才生成（mfd 异步 probe 输给循环），MISS=0 提前 break，细胞永挂 NO-DRIVER
# （112 轮 boot 复现实锤）。改为显式等待两颗细胞都存在+都有 driver（20s 预算），
# 环内对已存在未绑定的照旧 force-bind。
N=0
while [ $N -lt 20 ]; do
	OK=1
	for CELL in pm8008-regulator.1.auto pm8008-regulator.2.auto; do
		C=/sys/bus/platform/devices/$CELL
		[ -e "$C" ] || { OK=0; continue; }
		[ -e "$C/driver" ] || { OK=0; echo "$CELL" > /sys/bus/platform/drivers/qcom-pm8008-regulator/bind 2>/dev/null; }
	done
	[ "$OK" = "1" ] && break
	N=$((N+1))
	sleep 1
done
[ -e /sys/bus/i2c/devices/0-002d/driver ] || echo 0-002d > /sys/bus/i2c/drivers/s5k3p9sx/bind 2>/dev/null
