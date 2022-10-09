#!/bin/bash
BOOT_LOADER_PART_ONE=game_of_life_bl
BOOT_LOADER_PART_TWO=swapper_bl
DRIVE=/dev/c0d0

DATA=$1
TIMER=$2

if [ $# -lt 2 ]
then
    echo "Nie ma wszystkich danych potrzebnych do wykonania skryptu."
    exit 1
fi

if [ ! -f $DATA ]
then
    echo "Plik $DATA nie istnieje."
    exit 1
fi

if [[ $TIMER -lt 0 ]] || [[ $TIMER -gt 255 ]]
then
    echo "Liczba zmian statusu zegara jest spoza zakresu."
    exit 1
fi

dd bs=512 count=1 if=$DRIVE of=$DRIVE seek=2

dd bs=446 count=1 if=$BOOT_LOADER_PART_ONE of=$DRIVE

dd bs=512 count=1 if=$BOOT_LOADER_PART_TWO of=$DRIVE seek=1

dd bs=512 count=4 if=$DATA of=$DRIVE seek=3

printf \\$(printf '%03o' $TIMER) | dd bs=512 count=1 of=$DRIVE seek=7

reboot