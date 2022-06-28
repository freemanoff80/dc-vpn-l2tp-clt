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


### Create Script For Up VPN Connection

cat > /root/.config_files/vpn-conn-up.sh <<EOF
#!/bin/bash

PPP_NAME=ppp0
STAGE=1

echo \$(date '+%d.%m.%y-%H:%M:%S')

ITERATION=0

while true;
    do

        if [ \$STAGE = 1 ]
            then
                if [ "\`ipsec status $VPN_NAME| grep -e "no match"\`" ];
                    then
                        ipsec up $VPN_NAME;
                        sleep 1;

                elif [ "\`ipsec status $VPN_NAME| grep -e "$VPN_NAME".*ESTABLISHED\`" ];
                    then
                        echo "+++ IPSEC Connection UP"
                        (( STAGE=2 ));

                else
                    echo "--- IPSEC Connection Unknown Error";
                    break;
                fi
        fi


        if [ \$STAGE = 2 ]
            then
                COUNT=0
                while true;
                    do
                        if [ -z "\`ip a|grep -e ^[0-9]*.*\$PPP_NAME:\`" ];
                            then
                                if [ \$COUNT -eq 0 ];
                                    then
                                        echo "??? PPP Interface Trying To Up";
                                        echo "c $VPN_NAME" > /var/run/xl2tpd/l2tp-control;
                                        sleep 1;
                                        (( COUNT++ ));

                                elif [ \$COUNT -gt 0 ] && [ $COUNT -le 5 ];
                                    then
                                        sleep 1;
                                        (( COUNT++ ));

                                elif [ \$COUNT -ge 5 ];
                                    then
                                        echo "--- PPP Interface Timeout Error";
                                        break;
                                fi
        
                        elif [ "\`ip a|grep -e ^[0-9]*.*\$PPP_NAME:\`" ];
                            then
                                echo "+++ PPP Interface UP"
                                (( STAGE=3 ));
                                break;
        
                        else
                            echo "--- PPP Interface Unknown Error";
                            break;
                        fi
                    done
        fi 


        if [ \$STAGE = 3 ]
            then
                DROUTE=\$(ip route | grep default | awk '{print \$3}'| grep -v ppp);
                if [ -z "\`ip route|grep -e ^$VPN_SERVER_IP.*via.*\$DROUTE.*dev\`" ];
                    then
                        route add $VPN_SERVER_IP gw \$DROUTE;
                        sleep 1;

                elif [ "\`ip route|grep -e ^$VPN_SERVER_IP.*via.*\$DROUTE.*dev\`" ];
                    then
                        echo "+++ Route To VPN Server ADD";
                        (( STAGE=4 ));

                else
                    echo "--- Route To VPN Server Unknown Error";
                    break;

                fi
        fi

        if [ \$STAGE = 4 ]
            then
                COUNT=0
                while [ \$COUNT -lt 10 ];
                    do
                        if [ -z "\`ip route|grep -e default.*\$PPP_NAME.*\`" ];
                            then
                                route add default dev \$PPP_NAME;
                                sleep 1;
                                (( COUNT++ ));
                            else
                                echo "+++ PPP Default Route \$PPP_NAME ADD";
                                (( STAGE=5 ));
                                break;
                        fi;
                    done
        fi

        if [ \$STAGE = 5 ]
            then
                echo "+++ VPN Connection UP Done!!! ";
                break;

        fi

        (( ITERATION++ ));
        if [ \$ITERATION -gt 1000 ]
            then
                echo "Too Match Trying";
                break;
        fi       

    done

echo "Outside VPN IP is: \`wget -qO- http://ipv4.icanhazip.com\`"

exit 0
EOF

chmod 700 /root/.config_files/vpn-conn-up.sh


crontab << EOF
SHELL=/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
*/2 * * * * /root/.config_files/vpn-conn-up.sh >> /root/vpn-conn-up.log
EOF

### Create Script For Add Network Routes And Filewall

cat > /root/.config_files/vpn-net-route-add.sh <<EOF
#!/bin/bash

DROUTE=\$(ip route | grep default | awk '{print \$3}') && 

ip route add 192.168.0.0/16 via \$DROUTE; iptables -I OUTPUT -d 192.168.0.0/16 -j ACCEPT;
ip route add 10.0.0.0/8 via \$DROUTE; iptables -I OUTPUT -d 10.0.0.0/8 -j ACCEPT;
ip route add 172.16.0.0/12 via \$DROUTE; iptables -I OUTPUT -d 172.16.0.0/12 -j ACCEPT;

exit 0
EOF

chmod 700 /root/.config_files/vpn-net-route-add.sh

