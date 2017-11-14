#!/bin/bash
set -x
apt-get install -y grub-efi syslinux-common syslinux
if ! which gparted > /dev/null; then
  echo -e "Command not found! Install? (y/n) \c"
  read
  if [ "$REPLY" = "y" ]; then
    sudo apt-get install gparted
    exit 0
  fi
fi
if ! which grub-install > /dev/null; then
  echo -e "Command not found! Install? (y/n) \c"
  read
  if [ "$REPLY" = "y" ]; then
    sudo apt-get install grub2-common
    exit 0
  fi
fi
if [ "$1" == "" ]; then
  echo "usb.sh usbdrive iso"
  exit 1
else
  USB="$1"
fi
if [ "$2" == "" ]; then
  echo "usb.sh usbdrive iso"
  exit 1
else
  ISO="$2"
fi
umount ${USB}* 
set -e
parted ${USB} --script mktable gpt
parted ${USB} --script mkpart EFI fat16 1MiB 10MiB
parted ${USB} --script mkpart live fat16 10MiB 3GiB
parted ${USB} --script mkpart persistence ext4 3GiB 100%
parted ${USB} --script set 1 msftdata on
parted ${USB} --script set 2 legacy_boot on
parted ${USB} --script set 2 msftdata on

sleep 1

mkfs.vfat -n EFI ${USB}1
mkfs.vfat -n LIVE ${USB}2
mkfs.ext4 -F -L persistence ${USB}3

set +e
umount /tmp/usb-efi
umount /tmp/usb-live
umount /tmp/usb-persistence
umount /tmp/live-iso
set -e
rm -rf /tmp/usb-efi 
rm -rf /tmp/usb-live 
rm -rf /tmp/usb-persistence
rm -rf /tmp/live-iso

mkdir /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
mount ${USB}1 /tmp/usb-efi
mount ${USB}2 /tmp/usb-live
mount ${USB}3 /tmp/usb-persistence
mount -oro ${ISO} /tmp/live-iso

ls -l /tmp/live-iso/
cp -ar /tmp/live-iso/* /tmp/usb-live

echo "/ union" > /tmp/usb-persistence/persistence.conf

grub-install --removable --target=x86_64-efi --boot-directory=/tmp/usb-live/boot/ --efi-directory=/tmp/usb-efi ${USB}

dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/gptmbr.bin of=${USB}
syslinux --install ${USB}2

mv /tmp/usb-live/isolinux /tmp/usb-live/syslinux
mv /tmp/usb-live/syslinux/isolinux.bin /tmp/usb-live/syslinux/syslinux.bin
mv /tmp/usb-live/syslinux/isolinux.cfg /tmp/usb-live/syslinux/syslinux.cfg

sed --in-place 's#isolinux/splash#syslinux/splash#' /tmp/usb-live/boot/grub/grub.cfg

sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 persistence/}' /tmp/usb-live/boot/grub/grub.cfg /tmp/usb-live/syslinux/menu.cfg

sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 keyboard-layouts=us locales=en_US.UTF-8/}' /tmp/usb-live/boot/grub/grub.cfg /tmp/usb-live/syslinux/menu.cfg

umount /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
rmdir /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
