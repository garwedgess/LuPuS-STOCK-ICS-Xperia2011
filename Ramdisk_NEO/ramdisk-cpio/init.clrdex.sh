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
# * Copyright 2012 Sony Ericsson Mobile Communications AB.            *
# * All rights, including trade secret rights, reserved.              *
# *********************************************************************
#
# Delete all files in the dalvik-cache to make sure there is enough
# space on the data partition when doing an upgrade.
# The dalvik-cache is only cleared if the $MARK file is not present.
# The name of the MARK file should be changed for each upgrade.
# NOTE!
# This functionality should is obsoleted on edream6 and later products
# where the same functionality can be included in the update package.
#
TAG="clrdex"
DST="/data/dalvik-cache"
#
# The MARK variable is the name of a file which if present disables clean
# up of dex files.
#
MARK="clear-done-ics"

check_file_exists()
{
  /system/bin/log -t $TAG -p i "Checking $1 ..."
  if `/system/bin/ls $1 > /dev/null`; then
    return 0
  else
    return 1
  fi
}

if ! check_file_exists $DST/$MARK ; then
  /system/bin/log -t $TAG -p i "Clearing dalvik cache ..."
  /system/bin/rm  $DST/*
  /system/bin/touch $DST/$MARK
  /system/bin/chmod 0644 $DST/$MARK
fi

