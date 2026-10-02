#!/bin/sh
# Meizu 20 (m2381): SSC readiness gate + iio-sensor-proxy re-announce.
#
# The sensors PD (ADSP sensor_pd) registers its sns_client QRTR service
# (0x190) long after boot; iio-sensor-proxy runs earlier, scans, finds
# nothing and exits ("No sensors or missing kernel drivers") - and D-Bus
# name activation does NOT retry afterwards, so the proxy stays dead
# until something restarts it (liuqin pitfall
# docs/meizu20/liuqin-slpi-sensors-mining.md section 3.1).
#
# Cold-boot reality (r17, 2026-10-03): the ADSP firmware (and thus
# /dev/fastrpc-adsp) materialises ~75s into multi-user; the sensorspd
# unit restart-loops onto it every 3s, the sensor PD init takes ~15s
# more (incl. the bounded temp.json rebuild retry), and sns_client
# shows up around boot+90s. Probe every 10s for up to ~6 minutes after
# a settling pause, with the real end-to-end probe (ssccli sample).
# Non-fatal on timeout: the proxy can still be restarted by hand.
sleep 20
n=0
while [ "$n" -lt 35 ]; do
	if timeout 8 ssccli --sensor accelerometer --timeout 4 2>/dev/null \
		| grep -q "Accelerometer sensor measurement"
	then
		# plain restart: the boot-time proxy exited ("no sensors"), and
		# try-restart is a no-op on an inactive unit - the exact case
		# this gate exists for.
		systemctl restart iio-sensor-proxy.service 2>/dev/null || true
		exit 0
	fi
	n=$((n + 1))
	sleep 10
done
echo "SSC sensors never became ready; iio-sensor-proxy not re-announced" >&2
exit 0
