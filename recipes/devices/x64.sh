#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for x64 devices

#TODO: Streamline this with x86 so we can merge/unify them both.

## WIP: this should be refactored out to a higher level
# Aka base config for arm,armv7,armv8 and x86
# Base system
BASE="Debian"
ARCH="amd64"
BUILD="x64"

DEBUG_BUILD=no
### Device information
DEVICENAME="x64"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="x64"

# Disable to ensure the script doesn't look for `platform-xxx`
#We just need the bootloader files for now..
DEVICEREPO="http://github.com/volumio/platform-x86"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no # Temporary until the repo is fixed
KIOSKMODE=no

## Partition info
BOOT_START=1
BOOT_END=512
BOOT_TYPE=gpt # msdos or gpt
BOOT_USE_UUID=yes
INIT_TYPE="init.x86" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramfs
# Reveiw these for more mordern kernels?
MODULES=("overlay" "squashfs"
  # USB/FS modules
  "usbcore" "usb_common" "mmc_core" "mmc_block" "nvme_core" "nvme" "sdhci" "sdhci_pci" "sdhci_acpi"
  "ehci_pci" "ohci_pci" "uhci_hcd" "ehci_hcd" "xhci_hcd" "ohci_hcd" "usbhid" "hid_cherry" "hid_generic"
  "hid" "nls_cp437" "nls_utf8" "vfat"
  # Plymouth modules
  "intel_agp" "drm" "i915 modeset=1" "nouveau modeset=1" "radeon modeset=1"
  # Ata modules
  "acard-ahci" "ahci" "ata_generic" "ata_piix" "libahci" "libata"
  "pata_ali" "pata_amd" "pata_artop" "pata_atiixp" "pata_atp867x" "pata_cmd64x" "pata_cs5520" "pata_cs5530"
  "pata_cs5535" "pata_cs5536" "pata_efar" "pata_hpt366" "pata_hpt37x" "pata_isapnp" "pata_it8213"
  "pata_it821x" "pata_jmicron" "pata_legacy" "pata_marvell" "pata_mpiix" "pata_netcell" "pata_ninja32"
  "pata_ns87410" "pata_ns87415" "pata_oldpiix" "pata_opti" "pata_pcmcia" "pata_pdc2027x"
  "pata_pdc202xx_old" "pata_piccolo" "pata_rdc" "pata_rz1000" "pata_sc1200" "pata_sch" "pata_serverworks"
  "pata_sil680" "pata_sis" "pata_triflex" "pata_via" "pdc_adma" "sata_mv" "sata_nv" "sata_promise"
  "sata_qstor" "sata_sil24" "sata_sil" "sata_sis" "sata_svw" "sata_sx4" "ata_uli" "sata_via" "sata_vsc"
)

# Packages that will be installed
PACKAGES=(
  "linux-image-amd64" "firmware-linux"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  pkg_root="${PLTDIR/64/86}/packages-buster"

  log "Creating efi folders"
  mkdir -p "${ROOTFSMNT}"/boot/efi
  mkdir -p "${ROOTFSMNT}"/boot/efi/EFI/debian
  mkdir -p "${ROOTFSMNT}"/boot/efi/BOOT/
  log "Copying bootloaders and grub configuration template"
  mkdir -p "${ROOTFSMNT}"/boot/grub
  cp "${pkg_root}"/efi/BOOT/grub.cfg "${ROOTFSMNT}"/boot/efi/BOOT/grub.tmpl
  cp "${pkg_root}"/efi/BOOT/BOOTIA32.EFI "${ROOTFSMNT}"/boot/efi/BOOT/BOOTIA32.EFI
  cp "${pkg_root}"/efi/BOOT/BOOTX64.EFI "${ROOTFSMNT}"/boot/efi/BOOT/BOOTX64.EFI

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  log "Copying the Syslinux boot sector"
  dd conv=notrunc bs=440 count=1 if="${ROOTFSMNT}"/usr/lib/syslinux/mbr/gptmbr.bin of="${LOOP_DEV}"
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  #log "Running device_image_tweaks" "ext"
  :
}

# Will be run in chroot (before other things)
device_chroot_tweaks() {
  #log "Running device_image_tweaks" "ext"
  :
}

# Will be run in chroot - Pre initramfs
# TODO Try and streamline this!
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Preparing kernel stuff" "info"
  log "Getting the latest kernel filename and version"
  #shellcheck disable=SC2012 # We know it's going to be alphanumeric only!
  mapfile -t KRNL_VERS < <(ls -t /boot/vmlinuz* | sort)
  log "Found ${#KRNL_VERS[@]} kernel(s)" "${KRNL_VERS[@]}"
  KRNL=${KRNL_VERS[0]##*/}

  #TODO: Why not just symlink to /boot/vmlinuz
  # So that initramfs just needs to update that symlink, rather than adjusing boot files each time?
  # cur_vmlinuz=/boot/vmlinuz
  # new_vmlinuz=/boot/${KRNL}
  # # update vmlinuz symlink if required
  # if [[ ! -e ${cur_vmlinuz} ]] || [[ $(readlink ${cur_vmlinuz}) != "${new_vmlinuz}" ]]; then
  #   log "Updating ${cur_vmlinuz} to point to ${new_vmlinuz}"
  #   ln -sf "${new_vmlinuz}" "${cur_vmlinuz}"
  # else
  #   log "vmlinuz already points to:" "$(readlink ${cur_vmlinuz})"
  # fi
  # KRNL=$(ls -l /boot | grep vmlinuz | awk '{print $9}')
  # Since our boot partition is FAT, it doesn't support sylminks.
  IFS=- read -ra KVER <<<"$KRNL"
  log "Finished Kernel ${KVER[1]} installation" "okay" "${KRNL}"

  log "Preparing BIOS" "info"

  log "Installing Syslinux Legacy BIOS at ${BOOT_PART-?BOOT_PART is not known}"
  syslinux -v
  syslinux "${BOOT_PART}"

  log "Preparing boot configurations" "info"

  KERNEL_LOGLEVEL="loglevel=0" # Default to KERN_EMERG
  DISABLE_PN="net.ifnames=0"   # For legacy ifnames in buster

  # Build up the base parameters
  kernel_params=(
    # Bios stuff
    "biosdevname=0"
    # Boot screen stuff
    "splash" "plymouth.ignore-serial-consoles"
    # Output console device and options.
    "quiet"
    # Boot params
    "ro" "imgpart=UUID=%%IMGPART%%" "bootpart=UUID=%%BOOTPART%%" "datapart=UUID=%%DATAPART%%"
    # Image params
    "imgfile=/volumio_current.sqsh"
    # Disable linux logo during boot
    "logo.nologo"
    # Disable cursor
    "vt.global_cursor_default=0"
  )

  if [[ $DEBUG_IMAGE == yes ]]; then
    log "Creaing debug image" "wrn"
    KERNEL_LOGLEVEL="loglevel=8" # KERN_DEBUG
    kernel_params+=("debug")     # keep intiramfs logs
    # kernel_params+=("use_kmsg=yes") # intiramfs logs buffer
    log "Enabling ssh on boot"
    touch /boot/ssh
  fi
  kernel_params+=("${DISABLE_PN}")
  kernel_params+=("${KERNEL_LOGLEVEL}")

  log "Setting ${#kernel_params[@]} Kernel params:" "" "${kernel_params[*]}"

  log "Setting up syslinux and grub configs" "info"
  log "Creating run-time template for syslinux config"
  # Create a template for init to use later in `update_config_UUIDs`
  cat <<-EOF >/boot/syslinux.tmpl
	DEFAULT volumio
	LABEL volumio
	SAY Legacy Boot Volumio Audiophile Music Player (default)
	LINUX ${KRNL}
	APPEND ${kernel_params[@]}
	INITRD volumio.initrd
	EOF

  log "Creating syslinux.cfg from syslinux template"
  sed "s/%%IMGPART%%/${UUID_IMG}/g; s/%%BOOTPART%%/${UUID_BOOT}/g; s/%%DATAPART%%/${UUID_DATA}/g" /boot/syslinux.tmpl >/boot/syslinux.cfg

  log "Setting up Grub configuration"
  grub_tmpl=/boot/efi/BOOT/grub.tmpl
  grub_cfg=/boot/efi/BOOT/grub.cfg
  log "Inserting our kernel paramters to grub.tmpl"
  # Use a different delimiter as we might have some `/` paths
  sed -i "s|%%CMDLINE_LINUX%%|""${kernel_params[*]}""|g" ${grub_tmpl}

  log "Creating grub.cfg from grub template"
  cp ${grub_tmpl} ${grub_cfg}

  log "Inserting root and boot partition UUIDs (building the boot cmdline used in initramfs)"
  # Opting for finding partitions by-UUID
  sed -i "s/%%IMGPART%%/${UUID_IMG}/g" ${grub_cfg}
  sed -i "s/%%BOOTPART%%/${UUID_BOOT}/g" ${grub_cfg}
  sed -i "s/%%DATAPART%%/${UUID_DATA}/g" ${grub_cfg}
  sed -i "s/%%KRNL%%/${KRNL}/g" ${grub_cfg}
  sed -i "s/%%KVER%%/${KVER[1]}/g" ${grub_cfg}

  log "Finished setting up boot config" "okay"

  log "Creating fstab template to be used in initrd"
  sed "s/^UUID=${UUID_BOOT}/%%BOOTPART%%/g" /etc/fstab >/etc/fstab.tmpl
  log "Setting plymouth theme to volumio"
  plymouth-set-default-theme volumio

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Cleaning up /boot"
  ls -la /boot
  log "Removing original initrd" "$(ls -lh --block-size=M /boot/initrd.img*)"
  rm /boot/initrd.img-*
  log "Removing System.map" "$(ls -lh --block-size=M /boot/System.map-*)"
  rm /boot/System.map-*
}