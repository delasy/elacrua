#!/usr/bin/env bash

# Copyright (c) Aaron Delasy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ETH_INTERFACE=$(/sbin/ip route | awk '/default/ { print $5 }')
VPNIPPOOL='10.10.10.0/24'
VPNDNS='1.1.1.1,1.0.0.1'

function print_header {
  printf "\n\033[0;34m${1}\033[0m\n\n"
}

function print_error {
  printf "\n\033[0;31m${1}\033[0m\n\n"
}

function exit_with_error {
  print_error "${1}"
  exit 1
}

if [[ $(id -u) != 0 ]]; then
  exit_with_error 'Please run this script as root (e.g. sudo ./install.sh)'
fi


print_header 'Please answer some questions'

read -p 'Enter hostname for VPN (e.g. example.com): ' VPNHOST
read -p 'Enter sysadmin email address (e.g. aaron@example.com): ' USERMAIL
read -p 'Enter timezone (e.g. Europe/Berlin): ' USERTIMEZONE
read -p 'VPN username (e.g. aaron): ' VPNUSERNAME
read -s -p 'VPN password (NOTE: without quotes): ' VPNPASSWORD


print_header '\nInstalling required packages'

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y software-properties-common

apt-get upgrade -y --with-new-pkgs
apt-get autoremove -y

add-apt-repository ppa:certbot/certbot -y

apt-get install -y certbot \
                   strongswan \
                   libcharon-extra-plugins \
                   iptables-persistent \
                   libstrongswan-extra-plugins

timedatectl set-timezone ${USERTIMEZONE}


print_header "Configuring Let's Encrypt"

mkdir -p /etc/letsencrypt

echo '# https://github.com/delasy/elacrua

rsa-key-size = 4096
pre-hook = /sbin/iptables -I INPUT -p tcp --dport 80 -j ACCEPT
post-hook = /sbin/iptables -D INPUT -p tcp --dport 80 -j ACCEPT
renew-hook = /usr/sbin/ipsec reload && /usr/sbin/ipsec secrets' > /etc/letsencrypt/cli.ini

certbot certonly --non-interactive --standalone --preferred-challenges http --agree-tos --email ${USERMAIL} -d ${VPNHOST}


print_header 'Configuring strongSwan'

ln -f -s /etc/letsencrypt/live/${VPNHOST}/chain.pem /etc/ipsec.d/cacerts/chain.pem

ln -s /etc/apparmor.d/usr.lib.ipsec.charon /etc/apparmor.d/disable
ln -s /etc/apparmor.d/usr.lib.ipsec.stroke /etc/apparmor.d/disable
apparmor_parser -R /etc/apparmor.d/usr.lib.ipsec.charon
apparmor_parser -R /etc/apparmor.d/usr.lib.ipsec.stroke

mv /etc/ipsec.conf /etc/ipsec.conf.original

echo "# https://github.com/delasy/elacrua

config setup
  charondebug=\"ike 1, knl 1, cfg 0\"
  uniqueids=no

conn ikev2-vpn
  auto=add
  compress=no
  type=tunnel
  keyexchange=ikev2
  fragmentation=yes
  forceencaps=yes
  dpdaction=clear
  dpddelay=30s
  rekey=no
  left=%any
  leftid=@${VPNHOST}
  leftcert=/etc/letsencrypt/live/${VPNHOST}/cert.pem
  leftsendcert=always
  leftsubnet=0.0.0.0/0
  right=%any
  rightid=%any
  rightauth=eap-mschapv2
  rightsourceip=${VPNIPPOOL}
  rightdns=${VPNDNS}
  rightsendcert=never
  eap_identity=%identity" > /etc/ipsec.conf

echo "${VPNHOST} : RSA \"/etc/letsencrypt/live/${VPNHOST}/privkey.pem\"
${VPNUSERNAME} : EAP \"${VPNPASSWORD}\"" > /etc/ipsec.secrets

ipsec restart


print_header 'Configuring Firewall'

iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

iptables -A FORWARD --match policy --pol ipsec --dir in --proto esp -s ${VPNIPPOOL} -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d ${VPNIPPOOL} -j ACCEPT
iptables -t nat -A POSTROUTING -s ${VPNIPPOOL} -o ${ETH_INTERFACE} -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s ${VPNIPPOOL} -o ${ETH_INTERFACE} -j MASQUERADE

iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s ${VPNIPPOOL} -o ${ETH_INTERFACE} \
  -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP

netfilter-persistent save
netfilter-persistent reload

echo '

# https://github.com/delasy/elacrua

net.ipv4.ip_forward = 1
net.ipv4.ip_no_pmtu_disc = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0' >> /etc/sysctl.conf

sysctl -p


print_header 'Rebooting server'

reboot
