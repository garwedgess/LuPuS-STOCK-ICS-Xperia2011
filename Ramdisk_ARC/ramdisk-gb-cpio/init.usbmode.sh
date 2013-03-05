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

TAG="usb"
USB_FUNC_TABLE="/system/etc/usbmode.table"
COMMENT="#"

comp()
{
  case $1 in
    $2)
      return 0
      ;;
  esac
  return 1
}

ADB_PROP=$(/system/bin/getprop persist.service.adb.enable)
ENG_PROP=$(/system/bin/getprop persist.usb.eng)
RNDIS_PROP=$(/system/bin/getprop usb.rndis.enable)
PCC_PROP=$(/system/bin/getprop usb.pcc.enable)
STORAGE_PROP=$(/system/bin/getprop persist.usb.storagemode)

PROP="${ADB_PROP:-0}${ENG_PROP:-0}${RNDIS_PROP:-0}${PCC_PROP:-0}"
STORAGEMODE_PROP="${STORAGE_PROP:-msc}"

while read LINE
do

  set -- $LINE

  if comp $1 $COMMENT ; then
    continue
  fi

  if ! comp $1 $STORAGEMODE_PROP ; then
    continue
  fi

  if ! comp $2 $PROP ; then
    continue
  fi

  RNDIS=$3
  MSC=$4
  MTP=$5
  ADB=$6
  MODEM=$7
  NMEA=$8
  DIAG=$9
  USBSTATE=$10

  if comp $MODEM "1" ; then
    /system/bin/start port-bridge
  else
    /system/bin/stop port-bridge
  fi

  if comp $ADB "1" ; then
    /system/bin/start adbd
  else
    /system/bin/stop adbd
  fi

  echo $RNDIS > /sys/class/usb_composite/rndis/enable
  echo $MSC > /sys/class/usb_composite/usb_mass_storage/enable
  echo $MTP > /sys/class/usb_composite/mtp/enable
  echo $MODEM > /sys/class/usb_composite/modem/enable
  echo $NMEA > /sys/class/usb_composite/nmea/enable
  echo $DIAG > /sys/class/usb_composite/diag/enable
  echo "0" > /sys/class/usb_composite/accessory/enable

  /system/bin/log -t $TAG -p d "USB STATE: $USBSTATE"

  exit 0

done < $USB_FUNC_TABLE

/system/bin/log -t $TAG -p e "There is no matching USB mode:$PROP"

exit 1
