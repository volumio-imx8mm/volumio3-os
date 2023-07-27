#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for FETMX8MM-C device board
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="arm64"
BUILD="armv8"
UINITRD_ARCH="arm64"

### Device information
DEVICENAME="FETMX8MM-C"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="imx8mm"

# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/volumio-imx8mm/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=8
BOOT_END=72
BOOT_TYPE=msdos  # msdos or gpt
BOOT_USE_UUID=no # Add UUID to fstab
INIT_TYPE="init" # init.{x86/nextarm/nextarm_tvbox}


# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "fuse")
# Packages that will be installed
PACKAGES=("mc" "libbrotli1" "libmicrohttpd12")


### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib"
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if=${PLTDIR}/${DEVICEBASE}/u-boot/flash.bin of=${LOOP_DEV} seek=33 bs=1k conv=notrunc
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

### Chroot tweaks
# Will be run in chroot (before other things)
device_chroot_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  sed -i "s/mmcblk0p1/mmcblk1p1/g" /etc/fstab
  cat /etc/fstab

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"
  ln -s "/lib/" "/usr/lib"
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  log "Running device_image_tweaks_post" "ext"
  log "Creating boot.scr"
  mkimage -A arm64 -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  log "Converting initrd to u-boot format"
  mv "${ROOTFSMNT}"/boot/volumio.initrd "${ROOTFSMNT}"/boot/volumio.initrd.cpio.gz
  mkimage -A arm64 -T ramdisk -O linux -d "${ROOTFSMNT}"/boot/volumio.initrd.cpio.gz "${ROOTFSMNT}"/boot/volumio.initrd
}
