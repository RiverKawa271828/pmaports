#!/bin/sh
# Meizu 20 (m2381): poll the system-bus SensorProxy until it reports
# HasAccelerometer=true - i.e. until meizu-sensors-ready has re-announced
# iio-sensor-proxy with the SSC accelerometer present - then return and
# release plasma-mobile (ordered After=this unit), so kwin's single
# SensorProxy claim at session start is a populated proxy.
#
# Exit 0 on timeout too: plasma must never be blocked by sensor trouble;
# worst case is the pre-existing missing-rotation-tile behaviour.
n=0
while [ "$n" -lt 140 ]; do
	if busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy \
		net.hadess.SensorProxy HasAccelerometer 2>/dev/null | grep -q true
	then
		exit 0
	fi
	n=$((n + 1))
	sleep 2
done
echo "accel never reported ready; releasing plasma session anyway" >&2
exit 0
