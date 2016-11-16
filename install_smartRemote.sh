#! /bin/bash

# Constants
PATH_NETWORK_INTERFACES="/etc/network/interfaces"
PATH_DNSMASQ="/etc/dnsmasq.conf"
PATH_HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
PATH_RC_LOCAL="/etc/rc.local"
PATH_CRDA="/etc/default/crda"
PATH_ETC_MODULES="/etc/modules"
PATH_BOOT_CONFIG="/boot/config.txt"
PATH_HARDWARE_CONF="/etc/lirc/hardware.conf"

DEFAULT_SSID="DEFAULT_SSID"
DEFAULT_PASS="DEFAULT_PASSWORD"
DEFAULT_CRDA="JP"

# Clearing display
clear

# Check if script is running as root
if [ $(id -u) != 0 ]; then
	echo 1>&2 "Error: Please run the script as root (sudo $0)"
	echo 1>&2 "exited with code 1"
	exit 1;
fi

# Welcome message
echo "*******************************************************************************"
echo "This script will install and configure all packages needed to convert your"
echo "raspberry pi 3 in a SmartRemote device"
echo ""
echo "Created by Chema Alfaya Montero <chemaalfaya@gmail.com>"
echo "*******************************************************************************"
echo ""

# Getting script path
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
if [ -z "$MY_PATH" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi

# Update the system
echo "+ Updating the system"
apt-get -y update | sed 's/^/    /'
#apt-get -y upgrade | sed 's/^/    /'





# Install lirc
echo "+ Installing lirc"
apt-get -y install lirc | sed 's/^/    /'

# Configure lirc
echo "+ Configuring lirc"

#	 Configure the driver
cp "$MY_PATH/data/files/etc-modules" "$PATH_ETC_MODULES"
chown root:root "$PATH_ETC_MODULES"
chmod 644 "$PATH_ETC_MODULES"

#	 Replace or add system configuration parameters on /boot/config.txt
dtoverlay_line="$(awk '/dtoverlay/{ print NR; exit }' $PATH_BOOT_CONFIG)"
if [ "$dtoverlay_line" ]
then
	command="sed -i '"$dtoverlay_line"d' "$PATH_BOOT_CONFIG
	eval $command
fi
gpio_in_pin_line="$(awk '/gpio_in_pin/{ print NR; exit }' $PATH_BOOT_CONFIG)"
if [ "$gpio_in_pin_line" ]
then
	command="sed -i '"$gpio_in_pin_line"d' "$PATH_BOOT_CONFIG
	eval $command
fi
gpio_out_pin_line="$(awk '/gpio_out_pin/{ print NR; exit }' $PATH_BOOT_CONFIG)"
if [ "$gpio_out_pin_line" ]
then
	command="sed -i '"$gpio_out_pin_line"d' "$PATH_BOOT_CONFIG
	eval $command
fi

if [ "$dtoverlay_line" ]
then
	dtoverlay_line=$(( $dtoverlay_line - 1))
	sed -i ''$dtoverlay_line'a \dtoverlay=lirc-rpi\ndtparam=gpio_in_pin=23\ndtparam=gpio_out_pin=22' $PATH_BOOT_CONFIG
else
	echo "dollar"
	sed -i '$a \dtoverlay=lirc-rpi\ndtparam=gpio_in_pin=23\ndtparam=gpio_out_pin=22' $PATH_BOOT_CONFIG
fi

#	 Set the HW config file
cp "$MY_PATH/data/files/hardware.conf" "$PATH_HARDWARE_CONF"
chown root:root "$PATH_HARDWARE_CONF"
chmod 644 "$PATH_HARDWARE_CONF"





# Install node.js
echo "+ Installing node.js"
node_last_version=$(wget https://nodejs.org/dist/latest/ -q -O - | grep `uname -m`'.tar.gz' | perl -n -e '/href=\"(.+).tar.gz\".*/ && print "$1"')
rm "$MY_PATH/$node_last_version".tar.gz
rm -rf "$MY_PATH/$node_last_version"
wget https://nodejs.org/dist/latest/"$node_last_version".tar.gz
tar -xvf "$node_last_version".tar.gz
cd "$MY_PATH/$node_last_version"
cp -R * /usr/local/
cd "$MY_PATH"
rm "$MY_PATH/$node_last_version".tar.gz
rm -rf "$MY_PATH/$node_last_version"





# Install ws-lirc
echo "+ Installing ws-lirc"
git clone https://github.com/chemaalfaya/ws-lirc.git
cd "$MY_PATH/ws-lirc"
npm install --unsafe-perm
cd "$MY_PATH"





# Install hostapd and dnsmasq
echo "+ Installing hostapd and dnsmasq"
apt-get -y install hostapd dnsmasq | sed 's/^/    /'

# Configure dnsmasq
echo "+ Configuring dnsmasq"
cp "$MY_PATH/data/files/dnsmasq.conf" "$PATH_DNSMASQ"
chown root:root "$PATH_DNSMASQ"
chmod 644 "$PATH_DNSMASQ"

# Configure hostapd
echo "+ Configuring hostapd"
HWaddr=$(ifconfig wlan0 | grep 'HWaddr' | awk -F"HWaddr " '{print $2}')
HWaddr="${HWaddr// }"
AP_SSID="SmartRemote_$HWaddr"
AP_PASS=$(echo "$HWaddr" | rev)

#	 Replace ssid and wpa_passphrase on hostapd.conf
ssid_line="$(awk '/ssid/{ print NR; exit }' $MY_PATH/data/files/hostapd.conf)"
command="sed -i '"$ssid_line"s/.*/ssid="$AP_SSID"/' "$MY_PATH/data/files/hostapd.conf
eval $command

wpa_passphrase_line="$(awk '/wpa_passphrase/{ print NR; exit }' $MY_PATH/data/files/hostapd.conf)"
command="sed -i '"$wpa_passphrase_line"s/.*/wpa_passphrase="$AP_PASS"/' "$MY_PATH/data/files/hostapd.conf
eval $command

cp "$MY_PATH/data/files/hostapd.conf" "$PATH_HOSTAPD_CONF"
chown root:root "$PATH_HOSTAPD_CONF"
chmod 644 "$PATH_HOSTAPD_CONF"

# Configure network interfaces
echo "+ Configuring network interfaces"
cp "$MY_PATH/data/files/network-interfaces" "$PATH_NETWORK_INTERFACES"
chown root:root "$PATH_NETWORK_INTERFACES"
chmod 644 "$PATH_NETWORK_INTERFACES"

# Install scripts
echo "+ Installing scripts"
cp "$MY_PATH/data/scripts/hostapdstart" "/usr/local/bin/hostapdstart"
chown root:staff "/usr/local/bin/hostapdstart"
chmod 667 "/usr/local/bin/hostapdstart"

cp "$MY_PATH/data/scripts/wificonnect" "/usr/local/bin/wificonnect"
chown root:staff "/usr/local/bin/wificonnect"
chmod 667 "/usr/local/bin/wificonnect"

# Add script to boot sequence
echo "+ Adding script to boot sequence"
exists="$(awk '/hostapdstart/{ print NR; exit }' $PATH_RC_LOCAL)"
if [ ! "$exists" ]
then
	exit_0_line="$(awk '/exit 0/{last=NR} END{ print last}' $PATH_RC_LOCAL)"
	sed -i -e ''$exit_0_line'i \hostapdstart >1&\n' $PATH_RC_LOCAL
fi

# Change regdomain
echo ""
regdomain="JP"
while true
do
	echo -n "Do you want to set your wifi card region domain? [Y,n]: "
	read change_regdomain
	case $change_regdomain in
		y|Y|YES|yes|Yes)
			regdomains=($(regdbdump /lib/crda/regulatory.bin | perl -n -e '/country ([A-Za-z]{2}):.*/ && print "$1\n"'))
			echo "Valid region domains: "
			printf '%s, ' "${regdomains[@]}"
			echo ""
			while true
			do
				echo -n "Enter the region domain code and press [ENTER]: "
				read regdomain
				if ([ ${#regdomain} -eq 2 ] && [[ "${regdomains[*]}" == *"$regdomain"* ]])
				then
					echo "Setting your wifi card region domain to: $regdomain"
					break
				else
					echo "Please enter a valid region domain code"
				fi
			done
			break ;;
		n|N|no|NO|No)
			echo "Setting your wifi card region domain to 'JP' (default)"
			break ;;
		*) echo "Please enter only 'Y' or 'n'"
	esac
done

#	 Replace REGDOMAIN on crda
regdomain_line="$(awk '/REGDOMAIN/{last=NR} END{ print last}' $PATH_CRDA)"
command="sed -i '"$regdomain_line"s/.*/REGDOMAIN="$regdomain"/' "$PATH_CRDA
eval $command
iw reg set $regdomain

# Connect to wifi
while true
do
	echo -n "Do you want to connect to a wifi network now? [Y,n]: "
	read connect
	case $connect in
		y|Y|YES|yes|Yes)
			wificonnect
			break ;;
		n|N|no|NO|No) break ;;
		*) echo "Please enter only 'Y' or 'n'"
	esac
done

# Rebooting system
echo "You must reboot your system for changes to take effect (sudo reboot)"
