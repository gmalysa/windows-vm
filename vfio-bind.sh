#!/bin/bash

for dev in "0000:09:00.0" "0000:09:00.1" "0000:09:00.2" "0000:09:00.3"; do
	vendor=$(cat "/sys/bus/pci/devices/$dev/vendor")
	device=$(cat "/sys/bus/pci/devices/$dev/device")
	if [ -e /sys/bus/pci/devices/$dev/driver ]; then
		echo $dev > /sys/bus/pci/devices/$dev/driver/unbind
	fi
	echo $vendor $device > /sys/bus/pci/drivers/vfio-pci/new_id
done

chgrp -R kvm /dev/vfio
chmod -R 0660 /dev/vfio
