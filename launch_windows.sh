#!/bin/bash

# Options
# <>, y
DISABLE_HOST_VGA=y

# Options
# <>, y
ENABLE_VFIO_PCI=y

# Options
# <>, y
ENABLE_USB_KB=y

# Options:
# ac97 hda
ENABLE_SOUND=hda

# Options
# <>, y
ENABLE_DRIVER_FLOPPY=

# Options:
# <>, path to image to mount
# Images:
# /home/greg/qemu/en_windows_7_professional_with_sp1_x64_dvd_u_676939.iso"
# /home/greg/qemu/virtio-win-0.1.126.iso
#MOUNT_CDROM="/home/greg/qemu/en_windows_7_professional_with_sp1_x64_dvd_u_676939.iso"
#MOUNT_CDROM="/home/greg/qemu/virtio-win-0.1.126.iso"
MOUNT_CDROM=

# Options
# <>, y
ENABLE_VIRTIO_SCSI_HDD=y
HDD_PATH=/home/greg/qemu/windows7-bios-q35-steam.qcow2

# Options (any from "qemu-system-x86_64 -device help" under Networking)
# virtio-net e1000
NETWORK_MODE=virtio-net

# Options
# <>, y
ENABLE_HUGEPAGES=y

if [ -z "$DISABLE_HOST_VGA" ]; then
	VGA_STR="-vga std"
else
	VGA_STR="-vga none -nographic"
fi;

if [ -z "$ENABLE_VFIO_PCI" ]; then
	VFIO_STR=
else
	VFIO_STR=" -device vfio-pci,host=01:00.0,x-vga=on,multifunction=on"
	#VFIO_STR+=" -device vfio-pci,host=01:00.0,bus=root.1,addr=00.0,x-vga=on,multifunction=on,romfile=/home/greg/qemu/Gigabyte.GTX1070.8192.160624.rom"
	VFIO_STR+=" -device vfio-pci,host=01:00.1"

	# passthrough with a boot rom for the gpu (doesn't seem to work)
	#-device vfio-pci,host=01:00.0,bus=root.1,addr=00.0,x-vga=on,multifunction=on,romfile=/home/greg/qemu/Gigabyte.GTX1070.8192.160624.rom \
fi;

if [ -z "$ENABLE_USB_KB" ]; then
	USB_STR=
else
	USB_STR="-usb -device usb-host,vendorid=0x1532,productid=0x010d -device usb-host,vendorid=0x1532,productid=0x002f"
fi;

if [ -z "$ENABLE_SOUND" ]; then
	SOUND_STR=
else
	SOUND_STR="-soundhw ${ENABLE_SOUND}"
fi;

# Check for headset already plugged in and auto-passthrough, otherwise it has to be added with
# usb_add from the system console
lsusb | grep "046d:0a4d" > /dev/null
if [[ "$?" -eq 0 ]]; then
	SOUND_STR+=" -device usb-host,vendorid=0x046d,productid=0x0a4d"
fi;

# Check for blue snowball and pass through, otherwise it has to be added with usb_add from console
lsusb | grep "0d8c:0005" > /dev/null
if [[ "$?" -eq 0 ]]; then
	SOUND_STR+=" -device usb-host,vendorid=0x0d8c,productid=0x0005"
fi;

if [ -z "$ENABLE_DRIVER_FLOPPY" ]; then
	FLOPPY_STR=
else
	FLOPPY_STR="-fda /home/greg/qemu/virtio-win1.1.126_amd64.vfd"
fi;

if [ -z "$MOUNT_CDROM" ]; then
	CDROM_STR=
else
	CDROM_STR="-drive file=${MOUNT_CDROM},id=cdrom,if=none -device ide-cd,bus=ide.2,drive=cdrom"
fi;

if [ -z "$ENABLE_VIRTIO_SCSI_HDD" ]; then
	HD_STR="-drive file=${HDD_PATH},id=disk,format=qcow2,if=none,cache=none,aio=native,media=disk"
	HD_STR="${HD_STR} -device ide-hd,bus=ide.1,drive=disk"
	#HD_STR="${HD_STR} -drive file=/dev/sdd,if=none,id=g,format=raw,aio=threads,cache=none"
	#HD_STR="${HD_STR} -device virtio-blk-pci,drive=g"
#	HD_STR="${HD_STR} -device ide-hd,bus=ide.3,drive=g"
	HD_STR="${HD_STR} -drive file=/dev/sdc,if=none,id=g2,format=raw,aio=native,cache=none"
	HD_STR="${HD_STR} -device virtio-blk-pci,drive=g2"
else

	HD_STR="-object iothread,id=iothread0"
	HD_STR="${HD_STR} -device virtio-scsi-pci,iothread=iothread0,num_queues=8"

	HD_STR="${HD_STR} -drive file=${HDD_PATH},id=disk,format=qcow2,if=none,cache=writeback,aio=threads,discard=unmap,media=disk"
	HD_STR="${HD_STR} -device scsi-hd,drive=disk"

	HD_STR="${HD_STR} -drive if=none,file=/dev/sdc,if=none,id=g2,format=raw,aio=threads,cache=writeback,discard=unmap"
	HD_STR="${HD_STR} -device scsi-hd,drive=g2"

	HD_STR="${HD_STR} -drive if=none,file=/dev/sdd,if=none,id=g,format=raw,aio=threads,cache=writeback,discard=unmap"
	HD_STR="${HD_STR} -device scsi-hd,drive=g"
fi;
HD_STR+=" -boot order=dc,menu=on,"

if [ -z "$ENABLE_HUGEPAGES" ]; then
	MEM_STR=
else
	MEM_STR="-mem-path /dev/hugepages -mem-prealloc"
	mkdir -p /dev/hugepages
	mount -t hugetlbfs hugetlbfs /dev/hugepages
	sleep 1
	sysctl vm.nr_hugepages=8192
	sleep 1
fi;

NETWORK_STR="-netdev tap,ifname=tap0,script=no,downscript=no,id=ethport"
NETWORK_STR="${NETWORK_STR} -device ${NETWORK_MODE},netdev=ethport"

export QEMU_AUDIO_DRV="pa"
# QEMU_PA_SINK and QEMU_PA_SOURCE might need configuration
# Likely the source is the right thing to connect

# gpu works but can't boot without csm
	#-L /usr/share/edk2-ovmf -bios OVMF.fd \

# No display using coreboot+seabios, but it does briefly corrupt host display
	#-L . -bios coreboot.rom \
	#-L . -bios seabios.bin \

# Try to use git module with csm, doesn't work if the gpu has a romfile added
	#-L /usr/share/ovmf-x64 -bios ovmf-with-csm.fd \

QEMU_COMMAND="qemu-system-x86_64 -enable-kvm \
	-cpu host,kvm=off,hv_vapic,hv_time,hv_relaxed,hv_spinlocks=0x1fff,hv_vendor_id=vmgamingonly,host-cache-info=on \
	-smp sockets=1,cores=4,threads=2 \
	-monitor stdio \
	-nodefaults \
	-m 16G \
	-M q35 \
	-rtc base=localtime \
	\
	${VGA_STR} ${VFIO_STR} ${USB_STR} ${SOUND_STR} ${FLOPPY_STR} ${CDROM_STR} ${HD_STR} ${NETWORK_STR} ${MEM_STR} $@"

echo "${QEMU_COMMAND}"

$QEMU_COMMAND

if [ -z "$ENABLE_HUGEPAGES" ]; then
	USED_HUGEPAGES=1
else
	sysctl vm.nr_hugepages=0
	sleep 1
	umount /dev/hugepages
fi;

# Extra options collected here that haven't been added to config variables above:

	# To pass through hard drives directly:
	#-drive file=/dev/sdb,if=virtio,readonly \
	#-drive file=/dev/sdc,if=virtio,readonly \

	# For UEFI boot, which doesn't seem to work (boot loop with csm, output disappears in installer
	# for pure EFI)
	# also consider ovmf-git-pure-efi.fd and ovmf-git-vars-efi.fd
	#\
	#-drive if=pflash,format=raw,readonly,file=/usr/share/ovmf-x64/ovmf-git-with-csm.fd \
	#-drive if=pflash,format=raw,file=/usr/share/ovmf-x64/ovmf-git-vars-with-csm.fd \

