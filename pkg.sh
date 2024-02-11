#!/usr/bin/env bash
# intended to be run on a system with most of the basics
# bash is required for arrays
set -euo pipefail

if
	stat ~/arch | grep -Fq root
then
	sudo chown -R joseph ~/arch
	# can also chgrp, but not necessary
fi

# TODO: allow shutdown/reboot without sudo

fix_pacman_keys() {
	# TODO check when this is necessary
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

# IFS=" " read -r -a MAIN <<< "$(grep < ./packages.txt -Po '^[^# 	]+' | xargs)"
# sudo pacman -S --needed "${MAIN[@]}"

grep < ./packages.txt -Po '^[^# \t]+' | xargs sudo pacman -S --needed

setup_git_ssh() {
	# without ssh, you cannot clone -any- repo. but with ssh, you can clone
	# public and private repos.

	# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key
	# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account#adding-a-new-ssh-key-to-your-account

	ssh-keygen -t ed25519 -C "hejops1@gmail.com"
	eval "$(ssh-agent -s)"
	ssh-add ~/.ssh/gh_hejops # private

	# xclip -sel c ~/.ssh/gh_hejops.pub
	# firefox https://github.com/settings/ssh/new

	# https://cli.github.com/manual/gh_auth_login
	MACHINE="$(cat /sys/devices/virtual/dmi/id/product_name)"
	gh auth login
	gh ssh-key add ~/.ssh/gh_hejops.pub --title "$MACHINE"
	if ! ssh -T git@github.com; then
		echo "ssh setup failed"
		exit 1
	fi
}

ssh -T git@github.com || setup_git_ssh

# if ! [[ -f "$HOME/.git-credentials" ]]; then
# 	git config --global credential.helper store
# 	echo "Setting up Github PAT..."
# 	xdg-open "https://github.com/settings/tokens/new" > /dev/null
# 	read -r -p "PAT: " PAT < /dev/tty
# 	echo "https://hejops:$PAT@github.com" |
# 		tr -d ' ' |
# 		tee "$HOME/.git-credentials"
# fi

# get dotfiles and scripts
# in future, dotfiles will be public

cd

# https://www.chezmoi.io/quick-start/#using-chezmoi-across-multiple-machines
# chezmoi init https://github.com/hejops/dotfiles.git # public
chezmoi init git@github.com:hejops/dotfiles.git # private

# # git clone git@github.com:hejops/dotfiles.git
# git clone https://github.com/hejops/dotfiles
# git clone https://github.com/hejops/scripts
#
# read -r -p "Stop here and reorganise dotfiles and scripts with stow in mind"
#
# # to do this, we will need at least ranger and some git aliases
# mkdir -p ~/.config
# ln -vsf ~/dotfiles/.config/ranger ~/.config
# ln -vsf ~/dotfiles/.bash_aliases ~
#
# mkdir -p ~/dotfiles2
# ranger ~/dotfiles ~/dotfiles2
#
# # do the restructure...
#
# cd ~/dotfiles2
#
# git init
# git branch -M master
# git add .
# git commit -v
# firefox https://github.com/new &
# read -rp 'Repo name (not URL!): ' repo
# git remote add origin "https://github.com/hejops/$repo"
# git push -u origin master
#
# cd
# rm -rf ~/.config ~/.bash_aliases ~/.mozilla
# exit 0
#
# # now everything should be installed via stow
# git clone https://github.com/hejops/dotfiles
# ~/dotfiles/install

git clone https://github.com/hejops/scripts
~/scripts/install

# let Lazy and Mason do their thing...
kitty -e nvim &

# bash ~/scripts/links ~/scripts # create symlinks in .local/bin
# dwmstatus &

systemctl --user start pipewire-pulse.service

if ! systemctl status cronie | grep -F '(running)'; then
	systemctl enable cronie
	systemctl start cronie
	crontab ~/.config/cron
	crontab -l
fi

if ! command -v trizen; then
	# sudo pacman -Sy --needed base-devel git
	git clone https://aur.archlinux.org/trizen.git
	cd trizen
	makepkg -si # NOT sudo
	cd ..
	rm -rf trizen
fi

# IFS=" " read -r -a AUR <<< "$(grep < ./aur.txt -Po '^[^# ]+' | xargs)"
# # TODO: noconfirm?
# trizen -S --needed "${AUR[@]}"

grep < ./aur.txt -Po '^[^# ]+' | xargs trizen -S --needed
sudo chown -R joseph /opt/bizhawk/ # https://aur.archlinux.org/packages/bizhawk-monort#comment-93784

setup_ff() { # {{{

	# https://askubuntu.com/a/73480
	# https://devicetests.com/install-firefox-addon-command-line
	# https://github.com/LukeSmithxyz/LARBS/blob/22c637b5fb551b6a1476a7e57a950fc03293e240/static/larbs.sh#L227C1-L239C6
	# https://stackoverflow.com/a/37739112

	# FF_PROFILE_DIR=~/.mozilla/firefox/4clnophl.default/extensions
	FF_PROFILE_DIR=~/.mozilla/extensions

	addons=(

		# tabcenter-reborn
		auto-tab-discard
		cookie-autodelete
		tree-style-tab
		tridactyl-vim
		ublock-origin
	)

	tmpdir=$(mktemp -d)
	for addon in "${addons[@]}"; do
		if [ "$addon" = ublock-origin ]; then
			addonurl="$(
				curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest |
					grep -E 'browser_download_url.*\.firefox\.xpi' |
					cut -d'"' -f4
				# shame about the positional indexing
				# jq -r .assets[1].browser_download_url
			)"
		else
			addonurl="$(curl -sL "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" |
				grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
		fi
		file="${addonurl##*/}"
		curl -sJLO "$addonurl" > "$tmpdir/$file"
		id="$(unzip -p "$file" manifest.json | grep '"id"' | cut -d'"' -f4)"
		# id="${id%\"*}"
		# id="${id##*\"}"
		mv "$file" "$FF_PROFILE_DIR/$id.xpi"
	done

	# TODO: https://github.com/Aethlas/fflz4

	if [ ! -f ~/.mozilla/native-messaging-hosts/tridactyl.json ]; then
		curl \
			-fsSl https://raw.githubusercontent.com/tridactyl/native_messenger/master/installers/install.sh \
			-o /tmp/trinativeinstall.sh &&
			sh /tmp/trinativeinstall.sh master
		# tridactyl :source not really necessary, just restart
	fi

	# TODO: remove search engines except ddg; policies.json is ESR-only,
	# tragic...
	# https://mozilla.github.io/policy-templates/#searchengines--remove

	# https://github.com/Alex313031/Mercury/blob/673aa3e8f3fcbf3436b12186212708d3aa7b853c/policies/policies.json#L11
	# https://github.com/dm0-/installer/blob/6cf8f0bbdc91757579bdcab53c43754094a9a9eb/configure.pkg.d/firefox.sh#L95
	# https://github.com/yokoffing/Betterfox/blob/master/policies.json
	# https://mozilla.github.io/policy-templates/

	# TODO: restore addon settings (storage/default/moz-extension*)

	# ublock: google -- disable inline scripts

	sqlite3 "$FF_PROFILE_DIR/places.sqlite" "DELETE FROM moz_bookmarks;"
	sqlite3 "$FF_PROFILE_DIR/places.sqlite" "DELETE FROM moz_places;"

	# # TODO: cookies.sqlite -- block cookies on consent.youtube.com
	# sqlite3 $FF_PROFILE_DIR/cookies.sqlite "INSERT INTO moz_cookies VALUES(5593,'^firstPartyDomain=youtube.com','CONSENT','PENDING+447','.youtube.com','/',1723450203,1660378445948074,1660378204032779,1,0,0,1,0,2);"
	# INSERT INTO moz_cookies VALUES(2358,'^firstPartyDomain=youtube.com','CONSENT','PENDING+675','.youtube.com','/',1727208372,1664136373196881,1664136373196881,1,0,0,1,0,2);

}

setup_ff

# }}}

# media

wallset

if ! scrobbler list-users | grep hejops; then
	scrobbler add-user hejops
	# check that scrobbler works
	scrobbler now-playing hejops testartist testtrack
	# TODO: curl check
fi

nicowish -r

setup_mail() { # {{{

	# very slow, should be done last

	systemctl status --user mbsync | grep loaded && return

	systemctl enable --user mbsync.timer
	systemctl start --user mbsync.timer

	systemctl status --user mbsync | grep -F '(running)' && return

	# create mail dirs
	grep < ~/.mbsyncrc -v '#' |
		grep -F '.mail' |
		awk -F' ' '{print $NF}' |
		xargs mkdir -pv
	mkdir -p ~/.passwd

	# idempotent?
	notmuch new

	if [ ! -f ~/.passwd/gmail.txt ]; then

		read -r -p "Gmail password (leave blank to generate in browser): " gmail_pw < /dev/tty
		if [ -z "$gmail_pw" ]; then
			firefox "https://myaccount.google.com/apppasswords"
			read -r -p "Gmail password: " gmail_pw < /dev/tty
			if [ -n "$gmail_pw" ]; then
				echo "$gmail_pw" > ~/.passwd/gmail.txt
			else
				echo "Aborted"
				exit 1
			fi
		else
			echo "$gmail_pw" > ~/.passwd/gmail.txt
		fi
	fi

	# TODO: first should fail, complaining about missing near side dirs --
	# just rerun lol
	mbsync -Va || :
	mbsync -Va
	# mailtag
	systemctl restart --user mbsync.timer

	exit
}

# }}}

setup_mail

# setup hardware (audio, mouse, MIDI, etc) {{{

# prevent wifi from powering down
# MT7921K/mt7921e (card/driver) sucks
# sudo dmesg -w | grep wlp:
# wlp2s0: Limiting TX power to 20 (20 - 0) dBm as advertised by 78:dd:12:0e:d0:32 -- this is actually normal behaviour

# TODO: not sure which of these (if any) definitively solves the problem

# sudo iwconfig wlp2s0 power off -- doesn't seem to work, and not persistent

# echo "options iwlwifi 11n_disable=1 swcrypto=1 power_save=0" | sudo tee /etc/modprobe.d/iwlwifi.conf

# # iwlwifi driver does not appear to have this issue
# if ! lspci -knn | grep knn; then
# 	echo "pmf=2" | sudo tee /etc/wpa_supplicant/wpa_supplicant.config
# fi

# laptop only
if [ -d /proc/acpi/button/lid ]; then
	# don't suspend on lid close
	# sed < /etc/systemd/logind.conf 's|#HandleLidSwitch=suspend|HandleLidSwitch=ignore|' |
	# 	sudo tee /etc/systemd/logind.conf
	sudo sed -i 's|#HandleLidSwitch=suspend|HandleLidSwitch=ignore|' /etc/systemd/logind.conf

	# increase trackpoint sensitivity, and enable press to select

	# https://gist.githubusercontent.com/noromanba/11261595/raw/478cf4c4d9b63f1e59364a6f427ffccd63db5e1e/thinkpad-trackpoint-speed.mkd
	# https://wiki.archlinux.org/title/TrackPoint#udev_rule

	cat << EOF | sudo tee /etc/udev/rules.d/10-trackpoint.rules
ACTION=="add", SUBSYSTEM=="input", ATTR{name}=="TPPS/2 IBM TrackPoint", ATTR{device/sensitivity}="240", ATTR{device/press_to_select}="1"
EOF

fi

# https://github.com/goodboy/dotrc/blob/d22573e6de1d6edab5322ac128e4c82a2f1b4310/system/udev_rules/keyboard.rules
# UDEV  [3416.376998] bind     /devices/pci0000:00/0000:00:08.1/0000:04:00.4/usb3/3-1 (usb)
# ensure setxkbmap is run after every keyboard connect (essential for KVM)
cat << EOF | sudo tee /etc/udev/rules.d/kinesis.rules
ACTION=="add|bind|change", SUBSYSTEM=="usb", ENV{DISPLAY}=":0", ENV{HOME}="/home/$(whoami)", RUN+="/usr/bin/setxkbmap -layout us -option -option compose:rctrl,caps:menu"
EOF

vol --auto

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

# groupadd i2c
# # relogin required (?)
# # i2c-dev is the module, i2c is the group (i think)
# # per-login, potentially superseded by modules-load
# sudo usermod -aG i2c "$(whoami)"
# sudo modprobe i2c-dev
# echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c"' | sudo tee /etc/udev/rules.d/10-local_i2c_group.rules

# enable ddcutil
# i2c allows control of display hardware
# https://wiki.archlinux.org/title/Kernel_module#Automatic_module_loading
echo 'i2c-dev' | sudo tee /etc/modules-load.d/i2c-dev.conf

# }}}

if ! ls "$HOME/.config/etc/"*sf2; then
	choria=(

		https://www.musical-artifacts.com/artifacts/1474/Chorium_fork.sf2
		https://www.philscomputerlab.com/uploads/3/7/2/3/37231621/choriumreva.sf2
		https://www.pistonsoft.com/soundfonts/chorium.sf2
	)

	for ch in "${choria[@]}"; do
		curl -sJLO "$ch" && break
	done

	sf2_file=${ch##*/}
	mv "$sf2_file" "$HOME/.config/etc"
	sf2_file="$HOME/.config/etc/$sf2_file"

	[ ! -d /usr/share/soundfonts ] && sudo mkdir /usr/share/soundfonts
	sudo ln -s "$sf2_file" /usr/share/soundfonts/default.sf2

	echo "soundfont \"$sf2_file\"" > "$HOME/.config/timidity.cfg"

	mkdir -p "$HOME/.config/audacious"
	cat <<- EOF > "$HOME/.config/audacious/config"
		[amidiplug]
		fsyn_soundfont_file=$sf2_file
	EOF

fi

# installed to ~/.local/bin by default; this is included in $PATH
PIPS=(

	# doq
	# gdown
	# tabulate
	black
	jupytext
	lastpy # why?
	pandas
	pylint
	python-mpv
)

# pip install "${PIPS[@]}"
python -m pip install "${PIPS[@]}"

CARGO=(

	funzzy
)

rustup default stable
cargo install "${CARGO[@]}"

# pip aborts install if a single arg produces an error
# TODO: remove package imports (false positive)
cat ~/scripts/*.py |
	grep -Po '^(from|import) \w+' |
	awk '{print $2}' |
	sort -u |
	# xargs -n1 pip --exists-action i install
	xargs -n1 python -m pip --exists-action i install

# install gtk theme
cd
rm -rf ~/.local/share/themes/materia-custom
cp -r /usr/share/themes/Materia ~/.local/share/themes/materia-custom
cd ~/.local/share/themes
prettier -w ./materia-custom/gtk-4.0/gtk-dark.css
patch ./materia-custom/gtk-4.0/gtk-dark.css ./gtk-dark.diff

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

exit

# jupyter nbextension install --py jupytext --user
# jupyter nbextension enable --py jupytext --user

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

/bin/gh auth login

mkdir ~/.local/share/gnupg # otherwise cannot import keys
gpg --gen-key              # not strictly necessary

# unsf -- sudo make -f Makefile.linux install
# cp /usr/share/applications/ranger.desktop "$HOME/.local/share/applications"
