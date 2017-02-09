#!/usr/bin/env bash
set -x

if [ $# -ne 5 ]; then
    echo "usage: "_$(basename $0)_" <ROOT_SIZE> <HOSTNAME> <USERNAME> <BOOTSTRAP_URL> <AUTHORIZED_KEYS>"
    echo "You can find the bootstrap image here: https://www.archlinux.org/download/"
    exit
fi

ROOT_SIZE=$1
HOSTNAME=$2
USERNAME=$3
BOOTSTRAP=$4
AUTHORIZED_KEYS=$5

BOOTSTRAP_NAME=$(echo "$BOOTSTRAP" | rev | cut -d"/" -f1 | rev)

fdisk /dev/sda << EOF
o
n



+512M
n




a
1
w
EOF

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 10000 --use-random /dev/sda2
cryptsetup luksOpen /dev/sda2 encrypted-system

vgcreate system /dev/mapper/encrypted-system
lvcreate -L $ROOT_SIZE system -n data
lvcreate -l +100%FREE system -n swap

mkfs.btrfs -f /dev/sda1
mkfs.btrfs -f /dev/mapper/system-data
mkswap /dev/mapper/system-swap

mount /dev/mapper/system-data /mnt/

btrfs subvolume create /mnt/__root
btrfs subvolume create /mnt/__installer

umount /mnt
mount /dev/mapper/system-data /mnt -o subvol=__installer
mkdir /mnt/installation
mount /dev/mapper/system-data /mnt/installation -o subvol=__root
mkdir /mnt/installation/boot
mount /dev/sda1 /mnt/installation/boot

ID_CRYPTEDEVICE=$(blkid /dev/sda2 -o value -s UUID)
ID_SYSTEM_DATA=$(blkid /dev/mapper/system-data -o value -s UUID)

swapon /dev/mapper/system-swap

cd /mnt
curl -O $BOOTSTRAP
curl -O $AUTHORIZED_KEYS

tar xf $BOOTSTRAP_NAME -C /mnt root.x86_64 --strip 1

echo "Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch" > /mnt/etc/pacman.d/mirrorlist

/mnt/bin/arch-chroot /mnt pacman-key --init
/mnt/bin/arch-chroot /mnt pacman-key --populate archlinux
/mnt/bin/arch-chroot /mnt pacstrap -d -G /installation base base-devel btrfs-progs grub openssh vim zsh grml-zsh-config

/mnt/bin/genfstab /mnt >> /mnt/installation/etc/fstab

echo "$HOSTNAME" > /mnt/installation/etc/hostname

echo "en_US.UTF-8 UTF-8" > /mnt/installation/etc/locale.gen

echo "LANG=en_US.UTF-8" > /mnt/installation/etc/locale.conf

echo "[Match]
Name=ens3

[Network]
DHCP=yes" > /mnt/installation/etc/systemd/network/wired.network

echo "
#custom config

LogLevel VERBOSE

PermitRootLogin No
PasswordAuthentication no

KexAlgorithms curve25519-sha256@libssh.org
Ciphers aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com" >> /mnt/installation/etc/ssh/sshd_config
/mnt/bin/arch-chroot /mnt/installation locale-gen

/mnt/bin/arch-chroot /mnt/installation sed -i "s/^HOOKS=.*/HOOKS=\"base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck\"/g" /etc/mkinitcpio.conf
/mnt/bin/arch-chroot /mnt/installation mkinitcpio -p linux

/mnt/bin/arch-chroot /mnt/installation grub-install --recheck /dev/sda
/mnt/bin/arch-chroot /mnt/installation grub-mkconfig -o /boot/grub/grub.cfg
/mnt/bin/arch-chroot /mnt/installation sed -i "s/\/vmlinuz-linux.*/\/vmlinuz-linux cryptdevice=UUID=$ID_CRYPTEDEVICE:encrypted-system root=UUID=$ID_SYSTEM_DATA rootflags=subvol=__root quiet/g" /boot/grub/grub.cfg

/mnt/bin/arch-chroot /mnt/installation systemctl enable sshd
/mnt/bin/arch-chroot /mnt/installation systemctl enable systemd-networkd
/mnt/bin/arch-chroot /mnt/installation systemctl enable systemd-resolved
/mnt/bin/arch-chroot /mnt/installation systemctl enable systemd-timesyncd

/mnt/bin/arch-chroot /mnt/installation sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers

/mnt/bin/arch-chroot /mnt/installation passwd -l root
/mnt/bin/arch-chroot /mnt/installation passwd -d root
/mnt/bin/arch-chroot /mnt/installation chsh root -s /bin/zsh
/mnt/bin/arch-chroot /mnt/installation su root -c "touch ~/.zshrc"

/mnt/bin/arch-chroot /mnt/installation useradd -m -G wheel -s /bin/zsh $USERNAME
/mnt/bin/arch-chroot /mnt/installation /bin/sh -c "passwd $USERNAME"
/mnt/bin/arch-chroot /mnt/installation su $USERNAME -c "touch ~/.zshrc"

/mnt/bin/arch-chroot /mnt/installation su $USERNAME -c "mkdir -m 700 ~/.ssh"
/mnt/bin/arch-chroot /mnt/installation su $USERNAME -c "touch ~/.ssh/authorized_keys"
/mnt/bin/arch-chroot /mnt/installation chmod 600 /home/$USERNAME/.ssh/authorized_keys

rm -f /mnt/installation/etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /mnt/installation/etc/resolv.conf
rm -f /mnt/installation/etc/localtime && ln -s /usr/share/zoneinfo/UTC /mnt/installation/etc/localtime

cat /mnt/authorized_keys > /mnt/installation/home/$USERNAME/.ssh/authorized_keys

cd /

umount /mnt/installation/boot
umount /mnt/installation
umount /mnt

mount /dev/mapper/system-data /mnt/
btrfs subvolume delete /mnt/__installer

umount /mnt
