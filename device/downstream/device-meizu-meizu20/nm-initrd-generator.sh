#!/bin/sh
# Meizu 20 (device pkg r51): shadows networkmanager-systemd initrd generator
# (nm-initrd-generator.sh exits 1 on this non-initrd system every boot).
# We never boot via an initrd; do nothing, exit 0.
exit 0
