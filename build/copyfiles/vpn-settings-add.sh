###!/bin/bash
#!/usr/bin/env bash


### Adding Settings For VPN Connection

### Configure strongSwan

cp /etc/ipsec.conf /etc/ipsec.conf.bk

cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

conn $VPN_NAME
  auto=add
  keyexchange=ikev1
  authby=secret
  type=transport
  left=%defaultroute
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
  ike=aes128-sha1-modp2048
  esp=aes128-sha1
EOF

cp /etc/ipsec.secrets /etc/ipsec.secrets.bk

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets


### Configure xl2tpd 

cp /etc/xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf.bk

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac $VPN_NAME]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name "$VPN_USER"
password "$VPN_PASSWORD"
EOF

chmod 600 /etc/ppp/options.l2tpd.client


### Adding vars VPN_NAME and VPN_SERVER_IP to file /root/.config_files/vpn-conn-up.sh
sed -i "s/^VPN_NAME=/VPN_NAME=$VPN_NAME/" /root/.config_files/vpn-conn-up.sh;
sed -i "s/^VPN_SERVER_IP=/VPN_SERVER_IP=$VPN_SERVER_IP/" /root/.config_files/vpn-conn-up.sh;


### Add run scripts in crontab
# Script /root/.config_files/vpn-conn-up.sh added by build Dockerfile
# Script /root/.config_files/vpn-logs-rotate.sh added by build Dockerfile

crontab << EOF
SHELL=/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
*/2 * * * * /root/.config_files/vpn-conn-up.sh >> /root/vpn-conn-up.log
0 */1 * * * /root/.config_files/vpn-logs-rotate.sh
EOF

