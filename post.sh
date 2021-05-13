#!/usr/bin/env sh
set -eu

systemctl start NetworkManager.service
systemctl enable NetworkManager.service

ping -c 1 archlinux.org || nmtui

# https://www.davidtsadler.com/posts/installing-st-dmenu-and-dwm-in-arch-linux/
sudo pacman -S base-devel git libx11 libxft xorg-server xorg-xinit terminus-font

cd
git clone https://github.com/hejops/dwm
cd dwm
sudo make install
