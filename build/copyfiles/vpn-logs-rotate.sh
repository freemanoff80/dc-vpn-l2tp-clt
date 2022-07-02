#!/bin/bash

NAMELOG=vpn-conn-up.log
PATH_TO_FILE=/root
TOTAL_LOGS=4

if [ $(du -k $PATH_TO_FILE/$NAMELOG |awk '{print $1}') -gt 100 ];
        then
                cp $PATH_TO_FILE/$NAMELOG $PATH_TO_FILE/$NAMELOG.$(date '+%d.%m.%y-%H:%M:%S') &&
                > $PATH_TO_FILE/$NAMELOG;
fi

testarray=($(ls -t $PATH_TO_FILE | grep $NAMELOG. | awk '{ print $NF }'));
for index in ${!testarray[*]};
do
        if [ $index -gt $TOTAL_LOGS ];
        then
                rm -f ${testarray[$index]};
        fi
done;
