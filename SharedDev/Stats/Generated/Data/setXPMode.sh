#!/bin/bash

MODE=$1

rm XPData.txt
if [ "${MODE}" == "FAST" ]; then
    echo "Setting XP to FAST"
    ln -s XPData-FAST.txt XPData.txt
elif [ "${MODE}" == "NORMAL" ]; then
    echo "Resetting to default"
    rm XPData.txt
elif [ "${MODE}" == "80" ]; then
    echo "Setting XP to -80"
    ln -s XPData-80.txt XPData.txt
else
    echo "Default :: Setting XP to normal"
    ln -s XPData-67.txt XPData.txt
fi
