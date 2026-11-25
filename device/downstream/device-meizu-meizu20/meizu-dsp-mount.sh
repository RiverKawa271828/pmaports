#!/bin/sh
# Meizu 20: mount the dsp partition of the active slot read-only at
# /mnt/dsp. The audiopd session daemon (hexagonrpcd -P audiopd) serves
# the DSP's file requests (SPF module libraries, fastrpc_shell_0) from
# here through its HexagonFS aliases - /vendor/dsp,
# /data/vendor/audio_dsp and /usr/lib/qcom/adsp all resolve onto
# <root>/dsp when started with "-R /mnt -d adsp".
#
# Read-only on purpose: the dsp partition is an Android OTA deliverable
# (ext4), never written from pmOS. Slot comes from qbootctl (GPT
# attributes, not cmdline - our kernel bakes a fixed cmdline); b is the
# pmOS slot and the fallback.
#
# r83: bounded retry for the boot-early timing hazard (2026-11-20 plasma
# round: on some boots the by-partlabel symlink is not populated yet
# when the unit runs; manual restart heals). Wait for the device node in
# the script instead of a systemd Restart= - an unlimited-retry oneshot
# sitting in the boot path is the r66 multi-user deadlock shape.

slot="$(/usr/bin/qbootctl -c 2>/dev/null | awk '{print $NF}')"
case "$slot" in
	a|b) ;;
	*) slot=b ;;
esac

dev="/dev/disk/by-partlabel/dsp_$slot"
if [ ! -b "$dev" ]; then
	dev="/dev/disk/by-partlabel/dsp_b"
fi

n=0
while [ ! -b "$dev" ] && [ "$n" -lt 10 ]; do
	n=$((n + 1))
	sleep 1
done

if [ ! -b "$dev" ]; then
	echo "meizu-dsp-mount: no dsp partition found" >&2
	exit 1
fi

mkdir -p /mnt/dsp

if ! mountpoint -q /mnt/dsp; then
	mount -o ro "$dev" /mnt/dsp
fi
