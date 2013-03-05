#!/system/bin/sh
# *********************************************************************
# *  ____                      _____      _                           *
# * / ___|  ___  _ __  _   _  | ____|_ __(_) ___ ___ ___  ___  _ __   *
# * \___ \ / _ \| '_ \| | | | |  _| | '__| |/ __/ __/ __|/ _ \| '_ \  *
# *  ___) | (_) | | | | |_| | | |___| |  | | (__\__ \__ \ (_) | | | | *
# * |____/ \___/|_| |_|\__, | |_____|_|  |_|\___|___/___/\___/|_| |_| *
# *                    |___/                                          *
# *                                                                   *
# *********************************************************************
# * Copyright 2010 Sony Ericsson Mobile Communications AB.            *
# * All rights, including trade secret rights, reserved.              *
# *********************************************************************
#

TAG="hostapd"
SRC="/system/etc/wifi/softap"
DST="/data/misc/wifi/hostapd"

check_file_exists()
{
  /system/bin/log -t $TAG -p i "Checking $1 ..."
  if `/system/bin/ls $1 > /dev/null`; then
    return 0
  else
    return 1
  fi
}

if ! check_file_exists $DST/hostapd.conf ; then
  /system/bin/log -t $TAG -p i "Copying hostapd.conf to $DST ..."
  /system/bin/cat $SRC/hostapd.conf > $DST/hostapd.conf
fi

