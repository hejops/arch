#!/usr/bin/env bash
# bash is required for arrays
set -euo pipefail

PKGMGR=pacman
INSTALL="sudo pacman -S"
QUERY="pacman -Ss"
AURINSTALL="trizen --get"
PIPINSTALL="pip3 install"

MAIN=(

	# TODO: trizen
	ack
	acpi
	asoundconf
	at
	cronie
	curl
	dash
	exa
	feh
	ffmpeg
	firefox
	flameshot
	fzf
	gnupg
	groff
	htop
	hunspell
	i3lock
	inetutils
	isync
	libnotify
	maim
	make
	man
	moreutils
	mpc
	mpd
	mpv
	ncmpcpp
	neomutt
	newsboat
	nodejs
	notmuch
	npm
	ntfs-3g
	pacman-contrib # checkupdates
	pavucontrol
	pcre
	pdftk
	picom
	python-pdftotext
	python-pip
	python3
	qjackctl
	qsynth
	ranger
	realtime-privileges
	recode
	rofi
	rsync
	rxvt-unicode
	shellcheck
	shfmt
	socat
	stylua
	sysstat # mpstat
	system-config-printer
	telegram-desktop
	texlive-bin
	texlive-core
	udiskie
	udisks2
	usbutils # lsusb
	vim
	xdg-utils
	xorg-xbacklight
	xorg-xinit
	xorg-xrandr
	xorg-xsetroot
	xournalpp
	youtube-dl
	zathura-pdf-mupdf
	zathura-ps
)

# TODO: chown arch

asoundconf list
# HDMI is usually not what we want
asoundconf set-default-card PCH
amixer sset Master unmute
echo "Testing sound..."
speaker-test -c 2 -D plughw:1

# sudo pacman -Sy --needed base-devel git
git clone https://aur.archlinux.org/trizen.git
cd trizen
sudo makepkg -si
cd

fix_pacman_keys() {
	# https://bbs.archlinux.org/viewtopic.php?pid=1984300#p1984300
	# enable ntp and ensure the time correct
	sudo timedatectl set-ntp 1
	timedatectl status

	# create pacman master key, reload keys from keyring resources
	sudo rm -fr /etc/pacman.d/gnupg
	sudo pacman-key --init
	sudo pacman-key --populate
}

fix_pacman_keys

sudo pacman -Syu
$INSTALL "${MAIN[@]}"

if ! [[ -f "$HOME/.git-credentials" ]]; then
	git config --global credential.helper store
	echo "Setting up Github PAT..."
	xdg-open "https://github.com/settings/tokens/new" > /dev/null
	read -r -p "PAT: " PAT < /dev/tty
	echo "https://hejops:$PAT@github.com" |
		tr -d ' ' |
		tee "$HOME/.git-credentials"
fi

# get dotfiles and scripts

cd
git clone https://github.com/hejops/dotfiles
rm -rf "$HOME/.mozilla"
rsync -vua dotfiles/ .
xrdb -merge .Xresources

cd
git clone https://github.com/hejops/scripts
bash scripts/links ~/scripts

# setup MIDI

sudo usermod -a -G audio joseph
sudo usermod -a -G realtime joseph
pip install gdown
gdown "https://drive.google.com/uc?export=download&confirm=Qdl2&id=1sARoDPCJi9eix9ed2WNjXiTRc5yu7ipL"
# TODO: move sf2 to somewhere
# TODO: set PCH? device in Qjackctl.conf
# TODO: set soundfont in Qsynth.conf

# crontab ~/.cron
# crontab -l

# fix speaker hum?
# https://unix.stackexchange.com/a/513491
# comment out suspend-on-idle in
# /etc/pulse/system.pa
# /etc/pulse/default.pa
# didn't work
#

# https://wiki.archlinux.org/title/TrackPoint#udev_rule
# https://gist.githubusercontent.com/noromanba/11261595/raw/478cf4c4d9b63f1e59364a6f427ffccd63db5e1e/thinkpad-trackpoint-speed.mkd
# not persistent:
# echo 255 | sudo tee /sys/devices/platform/i8042/serio1/serio2/speed
# echo 180 | sudo tee /sys/devices/platform/i8042/serio1/serio2/sensitivity

cat << EOF | sudo tee /etc/udev/rules.d/10-trackpoint.rules
ACTION=="add", SUBSYSTEM=="input", ATTR{name}=="TPPS/2 IBM TrackPoint", ATTR{device/sensitivity}="240", ATTR{device/press_to_select}="1"
EOF

exit

SERVICES=(

	mbsync
	mpd
)

systemctl enable
systemctl start

systemctl enable --user mbsync.timer
systemctl start --user mbsync.timer
# systemctl status

AUR=(

	# discord-ptb
	font-manager
	gruvbox-dark-gtk
	htop-vim
	lf-bin
	lowdown
	nsxiv # nsxiv-extra
	playitslowly
	scrobbler # https://github.com/hauzer/scrobbler#examples
	texlive-latexindent-meta
	tllocalmgr-git
	urxvt-perls
)

$AURINSTALL

# installed to .local/bin by default; this is included in $PATH
PIPS=(

	biopython
	jupytext
	lastpy
	modlamp
	rope
	vim-vint
)

$PIPINSTALL

jupyter nbextension install --py jupytext --user
jupyter nbextension enable --py jupytext --user

# set up credentials
GIT=(
	hejops/dwm
	hejops/dotfiles
	hejops/scripts
	# nsxiv/nsxiv	# muennich/sxiv discontinued
)

# mv dotfiles up

# create passwords for mail, lastfm
mkpass "$HOME/.passwd/gmail.gpg"
mkpass "$HOME/.passwd/lastfm.gpg"

mbsync -Va #&
# if HDD connected, start building mpd database & (takes a long time)

unsf -- sudo make -f Makefile.linux install

xdg-open https://github.com/hejops/dotfiles/raw/master/.mozilla/firefox/4clnophl.default/chrome/google.user.css
# stylus only accepts urls, not files

cp /usr/share/applications/ranger.desktop "$HOME/.local/share/applications"

setup_xdg_mime() {
	# fonts are set in: .Xresources, firefox, rofi, dwm, .config/gtk-3.0/settings.ini
	# set xdgs -- ~/.config/mimeapps.list
	# https://github.com/mwh/dragon

	xdg-mime default org.pwmt.zathura.desktop application/pdf
	xdg-mime default ranger.desktop inode/directory
	xdg-mime default vim.desktop text/plain + https://unix.stackexchange.com/a/231302
}

setup_printer() {
	# GUI
	system-config-printer
	sudo cat /etc/cups/printers.conf
}

setup_autologin() {
	# https://wiki.archlinux.org/title/getty#Virtual_console
	cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf
	[Service]
	ExecStart=
	ExecStart=-/usr/bin/agetty --autologin joseph --noclear %I $TERM
EOF
}
