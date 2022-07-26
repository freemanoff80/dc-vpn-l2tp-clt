#!/bin/bash

VPN_NAME=
VPN_SERVER_IP=

PPP_NAME=ppp0
STAGE=1

echo $(date '+%d.%m.%y-%H:%M:%S')

ITERATION=0

while true;
    do

        if [ $STAGE = 1 ]
            then
                if [ "$(ipsec status $VPN_NAME| grep -e 'no match')" ];
                    then
                        ipsec up $VPN_NAME;
                        sleep 1;

                elif [ "$(ipsec status $VPN_NAME| grep -e "$VPN_NAME".*ESTABLISHED)" ];
                    then
                        echo "+++ IPSEC Connection UP"
                        (( STAGE=2 ));

                else
                    echo "--- IPSEC Connection Unknown Error";
                    break;
                fi
        fi


        if [ $STAGE = 2 ]
            then
                COUNT=0
                while true;
                    do
                        if [ -z "$(ip a|grep -e ^[0-9]*.*$PPP_NAME:)" ];
                            then
                                if [ $COUNT -eq 0 ];
                                    then
                                        echo "??? PPP Interface Trying To Up";
                                        echo "c $VPN_NAME" > /var/run/xl2tpd/l2tp-control;
                                        sleep 1;
                                        (( COUNT++ ));

                                elif [ $COUNT -gt 0 ] && [ $COUNT -le 5 ];
                                    then
                                        sleep 1;
                                        (( COUNT++ ));

                                elif [ $COUNT -ge 5 ];
                                    then
                                        echo "--- PPP Interface Timeout Error";
                                        if [ "$(ping -c 3 $VPN_SERVER_IP &>/dev/null;echo $?)" -eq 0 ];then
                                                echo "+++ Connect To VPN_SERVER_IP "
                                                echo "!!! Restart IPSEC And XL2TP Services";
                                                ipsec restart;
                                                sleep 5;
                                                service xl2tpd restart;
                                                sleep 5;
                                        else
                                                echo "--- NOT Connect To VPN_SERVER_IP "
                                                exit 1;
                                        fi;
                                        break;
                                fi
        
                        elif [ "$(ip a|grep -e ^[0-9]*.*$PPP_NAME:)" ];
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


        if [ $STAGE = 3 ]
            then
                DROUTE=$(ip route | grep default | awk '{print $3}'| grep -v ppp);
                if [ -z "$(ip route|grep -e ^$VPN_SERVER_IP.*via.*$DROUTE.*dev)" ];
                    then
                        route add $VPN_SERVER_IP gw $DROUTE;
                        sleep 1;

                 elif [ "$(ip route|grep -e ^$VPN_SERVER_IP.*via.*$DROUTE.*dev)" ];
                    then
                        echo "+++ Route To VPN Server ADD";
                        (( STAGE=4 ));

                else
                    echo "--- Route To VPN Server Unknown Error";
                    break;

                fi
        fi

        if [ $STAGE = 4 ]
            then
                COUNT=0
                while [ $COUNT -lt 10 ];
                    do
                        if [ -z "$(ip route|grep -e default.*$PPP_NAME.*)" ];
                            then
                                route add default dev $PPP_NAME;
                                sleep 1;
                                (( COUNT++ ));
                            else
                                echo "+++ PPP Default Route $PPP_NAME ADD";
                                (( STAGE=5 ));
                                break;
                        fi;
                    done
        fi

        if [ $STAGE = 5 ]
            then
                echo "+++ VPN Connection UP Done!!! ";
                break;

        fi

        (( ITERATION++ ));
        if [ $ITERATION -gt 1000 ]
            then
                echo "Too Match Trying";
                break;
        fi       

    done

echo "Outside VPN IP is: $(wget -qO- http://ipv4.icanhazip.com)"

exit 0
