# This is a minimal CentOS install designed to serve as a Docker base image.
#
# To keep this image minimal it only installs English language. You need to change
# dnf configuration in order to enable other languages.
#
###  Hacking on this image ###
# We assume this runs on a CentOS Linux 7/x86_64 machine, with virt ( or nested virt ) 
# enabled, use the build.sh script to build your own for testing

# text don't use cmdline -- https://github.com/rhinstaller/anaconda/issues/931
cmdline
# Firewall configuration
firewall --disabled
firstboot --disable
ignoredisk --only-use=vda

# Keyboard layouts
keyboard --vckeymap=us --xlayouts=''
# System language
lang en_US.UTF-8
# Network information
network --bootproto=dhcp --device=link --activate --onboot=on
network  --hostname=localhost.localdomain
# Shutdown after installation
shutdown

# Root password
rootpw --iscrypted --lock locked
# System services
services --disabled="chronyd"
# Do not configure the X Window System
skipx
# System timezone
timezone --isUtc --nontp Etc/UTC
# System bootloader configuration
bootloader --disabled
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype ext4 --grow

# Add nessasary repo for microdnf
repo --name="microdnf" --baseurl="https://buildlogs.centos.org/cah-0.0.1" --cost=100
repo --name="updates" --baseurl="http://mirror.centos.org/centos/7/updates/x86_64"

%packages --excludedocs --instLangs=en --nocore
bash
centos-release
microdnf
-audit-libs
-basesystem
-bind-libs-lite
-bind-license
-bind-license
-binutils
-cpio
-cracklib
-cracklib-dicts
-cryptsetup-libs
-dbus
-dbus-libs
-device-mapper
-device-mapper-libs
-dhclient
-dhcp-common
-dhcp-libs
-diffutils
-dosfstools
-dracut
-dracut-network
-e2fsprogs
-ethtool
-firewalld-filesystem
-*firmware
-freetype
-fuse-libs
-GeoIP
-gettext*
-gpg-pubkey
-gzip
-hardlink
-hostname
-initscripts
-iproute
-iptables
-iputils
-kernel
-kexec-tools
-kmod
-kmod-libs
-kpartx
-less
-libblkid
-libmnl
-libmount
-libnetfilter_conntrack
-libnfnetlink
-libpwquality
-libsemanage
-libss # used by e2fsprogs
#-libteam
-libuser
-libutempter
-libuuid
-lzo
-os-prober
-pam
-procps-ng
-qrencode-libs
-shadow-utils
-snappy
-systemd
-systemd-libs
-sysvinit-tools
-tar
#-teamd
-tree
-ustr
-vi

%end

# Post configure tasks for Docker
%post --erroronfail --log=/mnt/sysimage/root/anaconda-post.log
set -eux

microdnf remove acl audit-libs binutils cpio cracklib cracklib-dicts cryptsetup-libs dbus dbus-glib dbus-libs dbus-python device-mapper device-mapper-libs diffutils dracut e2fsprogs e2fsprogs-libs ebtables elfutils-libs firewalld firewalld-filesystem gdbm hardlink ipset ipset-libs iptables kmod kmod-libs kpartx libcap-ng libmnl libnetfilter_conntrack libnfnetlink libpwquality libselinux-python libsemanage libss libuser libutempter pam procps-ng python python-decorator python-firewall python-gobject-base python-libs python-slip python-slip-dbus qemu-guest-agent qrencode-libs shadow-utils systemd systemd-libs ustr util-linux xz
microdnf install procps
microdnf clean all

# Set install langs macro so that new rpms that get installed will
# only install langs that we limit it to.
LANG="en_US"
echo "%_install_langs ${LANG}" > /etc/rpm/macros.image-language-conf

find /usr/share/i18n -type f -not \( -name "en_US" -o -name POSIX -o -name "UTF-8.gz" \) -exec rm -rfv {} +
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d -not \( -name "en_US" -o -name POSIX \) -exec rm -rfv {} +

echo 'export LANG=en_US.UTF-8' > /etc/profile.d/locale.sh

cat > /root/.bashrc << EOF
alias ll='ls -l --color=auto' 2>/dev/null
alias l.='ls -d .* --color=auto' 2>/dev/null
alias ls='ls --color=auto' 2>/dev/null
EOF

echo 'container' > /etc/yum/vars/infra

# clear fstab
echo "# fstab intentionally empty for containers" > /etc/fstab

## Remove some things we don't need
rm -rf /boot /etc/firewalld  # unused directories
rm -rf /etc/sysconfig/network-scripts/ifcfg-*
rm -fv usr/share/gnupg/help*.txt
rm /usr/lib/rpm/rpm.daily
rm -rfv /usr/lib64/nss/unsupported-tools/  # unsupported
rm -rfv /var/lib/yum  # dnf info
rm -rfv /usr/share/icons/*  # icons are unused
rm -fv /usr/bin/pinky  # random not-that-useful binary

# statically linked stuff
rm -fv /usr/sbin/{glibc_post_upgrade.x86_64,sln}
ln /usr/bin/ln usr/sbin/sln

# we lose presets by removing /usr/lib/systemd but we do not care
rm -rfv /usr/lib/systemd

# if you want to change the timezone, bind-mount it from the host or reinstall tzdata
rm -fv /etc/localtime
mv /usr/share/zoneinfo/UTC /etc/localtime
rm -rfv  /usr/share/zoneinfo

## Systemd fixes
# no machine-id by default.
:> /etc/machine-id

## Final Pruning
rm -rfv /var/{cache,log}/* /tmp/*

%end

%post --interpreter=/usr/bin/sh --nochroot --logfile=/mnt/sysimage/root/anaconda-post-nochroot.log --erroronfail
set -eux
# https://bugzilla.redhat.com/show_bug.cgi?id=1343138
# Fix /run/lock breakage since it's not tmpfs in docker
# This unmounts /run (tmpfs) and then recreates the files
# in the /run directory on the root filesystem of the container
# NOTE: run this in nochroot because "umount" does not exist in chroot
umount /mnt/sysimage/run
# The file that specifies the /run/lock tmpfile is
# /usr/lib/tmpfiles.d/legacy.conf, which is part of the systemd
# rpm that isn't included in this image. We'll create the /run/lock
# file here manually with the settings from legacy.conf
# NOTE: chroot to run "install" because it is not in anaconda env
chroot /mnt/sysimage install -d /run/lock -m 0755 -o root -g root

%end
