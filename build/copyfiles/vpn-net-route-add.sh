#!/bin/bash

DROUTE=$(ip route | grep default | awk '{print $3}'); 

ip route add 192.168.0.0/16 via $DROUTE; iptables -I OUTPUT -d 192.168.0.0/16 -j ACCEPT;
ip route add 10.0.0.0/8 via $DROUTE; iptables -I OUTPUT -d 10.0.0.0/8 -j ACCEPT;
ip route add 172.16.0.0/12 via $DROUTE; iptables -I OUTPUT -d 172.16.0.0/12 -j ACCEPT;

exit 0
