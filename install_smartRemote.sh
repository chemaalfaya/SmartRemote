#! /bin/bash

# Constants
PATH_NETWORK_INTERFACES="/etc/network/interfaces"
PATH_DNSMASQ="/etc/dnsmasq.conf"
PATH_HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
PATH_RC_LOCAL="/etc/rc.local"
PATH_CRDA="/etc/default/crda"

DEFAULT_SSID="DEFAULT_SSID"
DEFAULT_PASS="DEFAULT_PASSWORD"
DEFAULT_CRDA="JP"

# Clearing display
#clear

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
