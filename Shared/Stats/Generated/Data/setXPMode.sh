#!/bin/bash

MODE=$1

rm XPData.txt
if [ "${MODE}" == "FAST" ]; then
    echo "Setting XP to FAST"
    ln -s XPData-FAST.txt XPData.txt
else
    echo "Default :: Setting XP to normal"
    ln -s XPData-67.txt XPData.txt
fi
