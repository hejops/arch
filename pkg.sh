#!/usr/bin/env bash
# intended to be run on a system with most of the basics
# bash is required for arrays
set -euo pipefail

if stat ~/arch | grep -Fq 'Uid: (    0/    root)'; then
	sudo chown -R joseph ~/arch
	# can also chgrp, but not necessary
fi

# TODO: allow shutdown/reboot without sudo

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

# MAIN=($(grep < ./packages.txt -Po '^[^# ]+' | xargs))
IFS=" " read -r -a MAIN <<< "$(grep < ./packages.txt -Po '^[^# ]+' | xargs)"

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
	rsync -vua ~/dotfiles/ .
	rm -r ~/dotfiles
	xrdb -merge ~/.Xresources

	# TODO: separate window?
	vim

	cd
	git clone https://github.com/hejops/scripts
	bash ~/scripts/links ~/scripts
	dwmstatus &

fi

if ! systemctl status cronie | grep -F '(running)'; then
	systemctl enable cronie
	systemctl start cronie
	crontab ~/.cron
	crontab -l
fi

# TODO urxvt addons? "local" workarounds?

# curl -sJLO https://repo.anaconda.com/archive/Anaconda3-2022.05-Linux-x86_64.sh
# sh Anaconda3-2022.05-Linux-x86_64.sh
# eval "$(/home/joseph/anaconda3/bin/conda shell.bash hook)"
# conda init

if ! command -v trizen; then
	# sudo pacman -Sy --needed base-devel git
	git clone https://aur.archlinux.org/trizen.git
	cd trizen
	makepkg -si # NOT sudo
	cd ..
	rm -rf trizen
fi

IFS=" " read -r -a AUR <<< "$(grep < ./aur.txt -Po '^[^# ]+' | xargs)"
# TODO: noconfirm?
trizen -S --needed "${AUR[@]}"

setup_ff() { #{{{

	# TODO: ensure browser open first?
	# TODO: install tst first?
	if [[ ! -f ~/.mozilla/firefox/4clnophl.default/extensions.txt ]]; then
		xargs < ~/.mozilla/firefox/4clnophl.default/extensions.txt -n1 firefox
	fi

	if [[ ! -f ~/.mozilla/native-messaging-hosts/tridactyl.json ]]; then
		# if ! find ~/.mozilla -name 'tridactyl.json' | grep .; then
		curl \
			-fsSl https://raw.githubusercontent.com/tridactyl/native_messenger/master/installers/install.sh \
			-o /tmp/trinativeinstall.sh &&
			sh /tmp/trinativeinstall.sh 1.22.1
		# TODO: version might need to match
		# tridactyl :source not really necessary, just restart
	fi

	# TODO: policies.json -- only on ESR?
	# TODO: remove all search engines and bookmarks
	# https://github.com/dm0-/installer/blob/6cf8f0bbdc91757579bdcab53c43754094a9a9eb/configure.pkg.d/firefox.sh#L95
	# https://github.com/mozilla/policy-templates/blob/master/README.md
	# https://teddit.net/r/firefox/comments/7fr039/how_to_add_custom_search_engines/dqelr3g/#c

	# TODO: restore addon settings (primarily ublock and cookiediscard)
	# everything in storage/default/moz-extension* is binary/encrypted -- sad!

	# TODO: cookies.sqlite -- block cookies to avoid youtube consent screen
	# INSERT INTO moz_cookies VALUES(5593,'^firstPartyDomain=youtube.com','CONSENT','PENDING+447','.youtube.com','/',1723450203,1660378445948074,1660378204032779,1,0,0,1,0,2);

}

setup_ff

#}}}

# media

mkdir -p ~/wallpaper

if ! scrobbler list-users | grep hejops; then
	scrobbler add-user hejops
	# check that scrobbler works
	scrobbler now-playing hejops testartist testtrack
fi

nicowish -r
# TODO: download columns not saved/restored properly; minor issue

# TODO: regenerate ~/.config/mpv/queue

setup_mail() { #{{{

	# very slow, should be done last

	systemctl status --user mbsync | grep loaded && return

	systemctl enable --user mbsync.timer
	systemctl start --user mbsync.timer

	systemctl status --user mbsync | grep -F '(running)' && return

	[[ -f ~/.passwd/gmail.txt ]] && return

	grep < ~/.mbsyncrc -v '#' | grep -Po '\.mail.+' | xargs mkdir -pv
	mkdir -p ~/.passwd

	notmuch new

	read -r -p "Gmail password (leave blank to generate in browser): " gmail_pw < /dev/tty
	if [[ -n $gmail_pw ]]; then
		echo "$gmail_pw" > ~/.passwd/gmail.txt
	else
		firefox "https://myaccount.google.com/apppasswords"
		read -r -p "Gmail password: " gmail_pw < /dev/tty
		if [[ -n $gmail_pw ]]; then
			echo "$gmail_pw" > ~/.passwd/gmail.txt
		else
			echo "Aborted"
			exit 1
		fi
	fi

	# TODO: first should fail, complaining about missing near side dirs -- just rerun lol
	mbsync -Va || :
	mbsync -Va
	# mailtag
	systemctl restart --user mbsync.timer

	exit
}

#}}}

setup_mail

# setup hardware (audio, mouse, MIDI, etc) {{{

# prevent wifi from powering down
# MT7921K/mt7921e (card/driver) sucks
# sudo dmesg -w | grep wlp:
# wlp2s0: Limiting TX power to 20 (20 - 0) dBm as advertised by 78:dd:12:0e:d0:32

# sudo iwconfig wlp2s0 power off
# nope

# iwlwifi driver does not appear to have this issue
if ! lspci -knn | grep knn; then
	echo "pmf=2" | sudo tee /etc/wpa_supplicant/wpa_supplicant.config
fi

# if laptop, don't suspend on lid close
if [[ -d /proc/acpi/button/lid ]]; then
	sed < /etc/systemd/logind.conf 's|#HandleLidSwitch=suspend|HandleLidSwitch=ignore|' |
		sudo tee /etc/systemd/logind.conf
fi

# pulseaudio -D -- dwm startup?

# TODO: if USB speaker, raise volume to 90
# amixer set Master 90%

# asoundconf list
# HDMI is usually not what we want
# asoundconf set-default-card PCH
# amixer sset Master unmute
# echo "Testing sound..."
# speaker-test -c 2 -D plughw:1

# can be done earlier
# sudo usermod -a -G audio joseph
# sudo usermod -a -G realtime joseph

# fix speaker hum?
# https://unix.stackexchange.com/a/513491
# comment out suspend-on-idle in
# /etc/pulse/system.pa
# /etc/pulse/default.pa
# didn't work

# https://wiki.archlinux.org/title/TrackPoint#udev_rule
# https://gist.githubusercontent.com/noromanba/11261595/raw/478cf4c4d9b63f1e59364a6f427ffccd63db5e1e/thinkpad-trackpoint-speed.mkd
# for persistent rules, udev rules must be created
cat << EOF | sudo tee /etc/udev/rules.d/10-trackpoint.rules
ACTION=="add", SUBSYSTEM=="input", ATTR{name}=="TPPS/2 IBM TrackPoint", ATTR{device/sensitivity}="240", ATTR{device/press_to_select}="1"
EOF

# # i2c-dev is the module, i2c is the group (i think)
# # per-login, potentially superseded by modules-load
# sudo usermod -aG i2c "$(whoami)"
# sudo modprobe i2c-dev
# echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c"' | sudo tee /etc/udev/rules.d/10-local_i2c_group.rules

# https://wiki.archlinux.org/title/Kernel_module#Automatic_module_loading
echo 'i2c-dev' | sudo tee /etc/modules-load.d/i2c-dev.conf

# }}}

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
	doq
	gdown
	jupytext
	lastpy
	pandas
	python-mpv # TODO: taggenre import fails?
	tabulate
)

# pip aborts install if a single arg produces an error
cat ~/scripts/*.py |
	grep -Po '^(from|import) \w+' |
	awk '{print $2}' |
	sort -u |
	xargs -n1 pip --exists-action i install

echo "Setup complete!"
exit 0

TEX=(

	# biblatex	use packaged one; source version will produce conflict with biber
	csquotes
	logreq
)

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
