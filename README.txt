(if not on ethernet)
iwctl --passphrase PASSWORD station wlan0 connect NETWORKNAME
curl -JLO https://raw.githubusercontent.com/hejops/arch/master/install.sh
sh install.sh

1. install.sh

- partitions, locale, bootloader, users
  - single root partition
  - swap partition, size equivalent to RAM
  - syslinux (BIOS/MBR)

2. post.sh

- services
- network
  - nmtui (NetworkManager)
- graphical environment
  - window manager: dwm
- git credentials

3. pkg.sh

- core packages
- dotfiles
- scripts

4. optional

