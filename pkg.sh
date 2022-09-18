#!/usr/bin/env bash
# intended to be run on a system with most of the basics
# bash is required for arrays
set -euo pipefail

# QUERY="pacman -Ss"
AURINSTALL="trizen --get"
PIPINSTALL="pip3 install"
PKGMGR=pacman

if stat ~/arch | grep -q 'Uid: (    0/    root)'; then
	sudo chown -R joseph ~/arch
fi

fix_pacman_keys() {
	# TODO check first
	# https://bbs.archlinux.org/viewtopic.php?pid=1984300#p1984300
	# enable ntp and ensure the time correct
	sudo timedatectl set-ntp 1
	timedatectl status

	# create pacman master key, reload keys from keyring resources
	sudo rm -fr /etc/pacman.d/gnupg
	sudo pacman-key --init
	sudo pacman-key --populate
}

# fix_pacman_keys

sudo pacman -Syu

MAIN=$(grep < ./packages.txt -Po '^[^# ]+' | xargs)

sudo pacman -S --needed "${MAIN[@]}"

if ! [[ -f "$HOME/.git-credentials" ]]; then
	git config --global credential.helper store
	echo "Setting up Github PAT..."
	xdg-open "https://github.com/settings/tokens/new" > /dev/null
	read -r -p "PAT: " PAT < /dev/tty
	echo "https://hejops:$PAT@github.com" |
		tr -d ' ' |
		tee "$HOME/.git-credentials"

	# get dotfiles and scripts

	cd
	git clone https://github.com/hejops/dotfiles
	rm -rf "$HOME/.mozilla"
	rsync -vua dotfiles/ .
	xrdb -merge .Xresources

	cd
	git clone https://github.com/hejops/scripts
	bash scripts/links ~/scripts

fi

mkdir -p ~/wallpaper

# when connected to monitor (x230), behaves like ignore anyway?
# x240 behaves like it should

# cat /etc/systemd/logind.conf |
# 	sed 's|#HandleLidSwitch=suspend|HandleLidSwitch=ignore|' |
# 	sudo tee /etc/systemd/logind.conf

systemctl enable cronie
systemctl start cronie
crontab ~/.cron
crontab -l

# TODO urxvt addons? "local" workarounds?

setup_mail() {

	systemctl enable --user mbsync.timer
	systemctl start --user mbsync.timer

	grep < .mbsyncrc -v '#' | grep -Po '\.mail.+' | xargs mkdir -p
	mkdir -p ~/.passwd

	# notmuch new

	# TODO: regenerate gmail app password ~/.passwd/gmail.txt
	# firefox https://myaccount.google.com/apppasswords

	# mbsync -Va #&
	# mailtag
}

setup_mail

setup_ff() {

	if ! find .mozilla -name 'tridactyl.json' | grep .; then
		curl \
			-fsSl https://raw.githubusercontent.com/tridactyl/native_messenger/master/installers/install.sh \
			-o /tmp/trinativeinstall.sh &&
			sh /tmp/trinativeinstall.sh 1.22.1
		# TODO: tridactyl :source
	fi

	jq < ~/.mozilla/firefox/4clnophl.default/extensions.json -r .addons[].sourceURI |
		grep xpi$ |
		xargs -n1 firefox

	# TODO: cookies.sqlite -- block cookies to avoid youtube consent screen
	# INSERT INTO moz_cookies VALUES(5593,'^firstPartyDomain=youtube.com','CONSENT','PENDING+447','.youtube.com','/',1723450203,1660378445948074,1660378204032779,1,0,0,1,0,2);

}

# setup hardware (audio, mouse, MIDI, etc) {{{

# pulseaudio -D -- dwm startup?

# TODO: if USB speaker, raise volume to 90
# amixer set Master 90%

# asoundconf list
# HDMI is usually not what we want
# asoundconf set-default-card PCH
# amixer sset Master unmute
# echo "Testing sound..."
# speaker-test -c 2 -D plughw:1

sudo usermod -a -G audio joseph
sudo usermod -a -G realtime joseph

# fix speaker hum?
# https://unix.stackexchange.com/a/513491
# comment out suspend-on-idle in
# /etc/pulse/system.pa
# /etc/pulse/default.pa
# didn't work

# https://wiki.archlinux.org/title/TrackPoint#udev_rule
# https://gist.githubusercontent.com/noromanba/11261595/raw/478cf4c4d9b63f1e59364a6f427ffccd63db5e1e/thinkpad-trackpoint-speed.mkd
# not persistent:
# echo 255 | sudo tee /sys/devices/platform/i8042/serio1/serio2/speed
# echo 180 | sudo tee /sys/devices/platform/i8042/serio1/serio2/sensitivity

cat << EOF | sudo tee /etc/udev/rules.d/10-trackpoint.rules
ACTION=="add", SUBSYSTEM=="input", ATTR{name}=="TPPS/2 IBM TrackPoint", ATTR{device/sensitivity}="240", ATTR{device/press_to_select}="1"
EOF
#}}}

# curl -sJLO https://repo.anaconda.com/archive/Anaconda3-2022.05-Linux-x86_64.sh
# sh Anaconda3-2022.05-Linux-x86_64.sh
# eval "$(/home/joseph/anaconda3/bin/conda shell.bash hook)"
# conda init

if [ ! -x trizen ]; then
	# sudo pacman -Sy --needed base-devel git
	git clone https://aur.archlinux.org/trizen.git
	cd trizen
	makepkg -si # NOT sudo
	cd
	rm -r trizen
fi

AUR=$(grep < ./aur.txt -v '#' | xargs)
# TODO: no prompt?
trizen -S --needed "${AUR[@]}"

if ! scrobbler list-users | grep hejops; then
	scrobber add-user hejops
fi

# TODO: regenerate ~/.config/mpv/queue

echo "Setup complete!"
exit 0

# sudo mkdir /usr/share/soundfonts
# sudo ln -s "/run/media/joseph/My Passport/files/gp/sf2/Chorium.sf2" /usr/share/soundfonts/default.sf2
#
# wildmidi requires /etc/wildmidi/wildmidi.cfg

# misc
# https://github.com/Aethlas/fflz4

# installed to .local/bin by default; this is included in $PATH
PIPS=(

	# biopython
	# cget https://github.com/jaseg/python-mpv/raw/main/mpv.py
	# modlamp
	# rope
	# vim-vint
	black
	gdown
	jupytext
	lastpy
	pandas
	python-mpv # TODO: import fails, better to curl from source directly
	tabulate
)

TEX=(

	# biblatex	use packaged one; source version will produce conflict with biber
	csquotes
	logreq
)

# grep < scripts/*.py -Po '^(from|import) \w+' | awk '{print $2}' | sort -u | xargs -n1 pip install

# gdown "https://drive.google.com/uc?export=download&confirm=Qdl2&id=1sARoDPCJi9eix9ed2WNjXiTRc5yu7ipL"
# TODO: move sf2 to somewhere
# TODO: set PCH? device in Qjackctl.conf
# TODO: set soundfont in Qsynth.conf

pip install "${PIPS[@]}"

exit

jupyter nbextension install --py jupytext --user
jupyter nbextension enable --py jupytext --user

setup_xdg_mime() {
	# fonts are set in: .Xresources, firefox, rofi, dwm, .config/gtk-3.0/settings.ini
	# set xdgs -- ~/.config/mimeapps.list
	# https://github.com/mwh/dragon

	xdg-mime default firefox.desktop image/jpeg
	xdg-mime default firefox.desktop image/png
	xdg-mime default org.pwmt.zathura.desktop application/pdf
	xdg-mime default ranger.desktop inode/directory
	xdg-mime default vim.desktop text/plain # TODO: https://unix.stackexchange.com/a/231302
}

setup_printer() {
	# GUI
	system-config-printer
	sudo cat /etc/cups/printers.conf
}

setup_autologin() {
	# https://wiki.archlinux.org/title/getty#Virtual_console
	# should NOT be done on a machine that will be taken outdoors
	cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf
	[Service]
	ExecStart=
	ExecStart=-/usr/bin/agetty --autologin joseph --noclear %I $TERM
EOF
}

# unsf -- sudo make -f Makefile.linux install
# cp /usr/share/applications/ranger.desktop "$HOME/.local/share/applications"
