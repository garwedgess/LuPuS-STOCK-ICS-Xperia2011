#!/sbin/busybox sh
set +x
_PATH="$PATH"
export PATH=/sbin
# set time & date
TIME=`/sbin/busybox date +"%d-%m-%Y %r"`

# delete old lupuslog
if [ -f /lupus_log.txt ]; then
	busybox rm -f /lupus_log.txt
fi

busybox cd /
exec >> /lupus_log.txt 2>&1
busybox rm /init

# start log
busybox echo "*********************************************" >> /lupus_log.txt
busybox echo "[---Start boot @: $TIME---]" >> /lupus_log.txt
busybox echo "---------------------------------------------" >> /lupus_log.txt
busybox echo "" >> /lupus_log.txt

# include device specific vars
source /sbin/bootrec-device

# create directories
busybox mkdir -m 755 -p /system
busybox mkdir -m 755 -p /cache
busybox mkdir -m 755 -p /dev/block
busybox mkdir -m 755 -p /dev/input
busybox mkdir -m 555 -p /proc
busybox mkdir -m 755 -p /sys

# create device nodes
busybox mknod -m 600 /dev/block/mmcblk0 b 179 0
busybox mknod -m 600 ${BOOTREC_SYSTEM_NODE}
busybox mknod -m 600 ${BOOTREC_CACHE_NODE}
busybox mknod -m 600 ${BOOTREC_EVENT_NODE}
busybox mknod -m 666 /dev/null c 1 3

# mount filesystems
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys
busybox mount -t yaffs2 ${BOOTREC_SYSTEM} /system
busybox mount -t yaffs2 ${BOOTREC_CACHE} /cache

busybox echo "[CPU] Fixing frequencies at boot" >> /lupus_log.txt
# fixing CPU clocks to avoid issues in recovery
echo 1017600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 249600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq


# trigger amber LED
busybox echo 0 > ${BOOTREC_LED_RED}
busybox echo 0 > ${BOOTREC_LED_GREEN}
busybox echo 255 > ${BOOTREC_LED_BLUE}
# trigger vibrator
echo 90 > /sys/class/timed_output/vibrator/enable

# keycheck
busybox cat ${BOOTREC_EVENT} > /dev/keycheck&
busybox sleep 1

# create lupus.prop
if [ ! -e /system/lupus.prop ]; then
	busybox echo "#" > /system/lupus.prop
	busybox echo "# LuPuS KERNEL PROPERTIES" >> /system/lupus.prop
	busybox echo "#" >> /system/lupus.prop
	busybox echo "recovery.choice=cwm" >> /system/lupus.prop
fi

# android ramdisk
busybox echo "[ANDROID] Extracting ramdisk.cpio" >> /lupus_log.txt


# check if system is ICS or GB
ramdisk_choice=`busybox cat /system/build.prop | busybox grep "ro.build.version.release=" | busybox sed "s/ro.build.version.release=//g"`

# check if device is GSM or CDMA
gsm_cdma=`busybox cat /system/build.prop | busybox grep "ro.product.device=" | busybox sed "s/ro.product.device=//g"`


if [[ $ramdisk_choice == "4.0.4" ]] || [[ $ramdisk_choice == "4.0.3" ]]
then
	busybox echo "[*] Loading ICS ramdisk" >> /lupus_log.txt
	load_image=/sbin/ramdisk.cpio.lzma
elif [[ $ramdisk_choice == "2.3.3" ]] || [[ $ramdisk_choice == "2.3.4" ]] || [[ $ramdisk_choice == "2.3.7" ]]
then
	if [[ $gsm_cdma == "R800x" ]]
  	then
		busybox echo "[*] Device is CDMA" >> /lupus_log.txt
		load_image=/sbin/ramdisk-gb-cdma.cpio.lzma
		busybox echo "[*] Loading CDMA GB ramdisk" >> /lupus_log.txt
	elif [[ $gsm_cdma == "R800i" ]]
	then
		busybox echo "[*] Device is GSM" >> /lupus_log.txt
		load_image=/sbin/ramdisk-gb.cpio.lzma
		busybox echo "[*] Loading GB ramdisk" >> /lupus_log.txt
	else
		# trigger vibrator
		echo 150 > /sys/class/timed_output/vibrator/enable
		# red led
		busybox echo 255 > ${BOOTREC_LED_RED}
		busybox sleep 3
		# power off
		busybox poweroff
	fi
fi
busybox sleep 2

# Choose recovery
# check which recovery was selected in LuPuS menu
recover=`busybox cat /system/lupus.prop | busybox grep "recovery.choice=" | busybox sed "s/recovery.choice=//g"`

# boot decision
if [ -s /dev/keycheck -o -e /cache/recovery/boot ]
then
	busybox echo "" >> /lupus_log.txt
	busybox echo "[RECOVERY] Entering" >> /lupus_log.txt
	busybox rm -fr /cache/recovery/boot
	# trigger purple led
	busybox echo 255 > ${BOOTREC_LED_RED}
	busybox echo 0 > ${BOOTREC_LED_GREEN}
	busybox echo 255 > ${BOOTREC_LED_BLUE}
	# trigger vibration
	echo 60 > /sys/class/timed_output/vibrator/enable
	# power off leds
	busybox echo 0 > ${BOOTREC_LED_RED}
	busybox echo 0 > ${BOOTREC_LED_GREEN}
	busybox echo 0 > ${BOOTREC_LED_BLUE}
	
	# recovery choice
	if [[ $recover == "cwm" ]] || [[ $recover == "CWM" ]]
		then
			load_image=/sbin/ramdisk-cwm.cpio.lzma
	elif [[ $recover == "twrp" ]] || [[ $recover == "TWRP" ]]
		then
			load_image=/sbin/ramdisk-twrp.cpio.lzma
	else
			load_image=/sbin/ramdisk-cwm.cpio.lzma
	fi

else
	# poweroff LED
	busybox echo 0 > ${BOOTREC_LED_RED}
	busybox echo 0 > ${BOOTREC_LED_GREEN}
	busybox echo 0 > ${BOOTREC_LED_BLUE}
fi

# kill the keycheck process
busybox pkill -f "busybox cat ${BOOTREC_EVENT}"

# unpack the ramdisk image
busybox lzcat ${load_image} | busybox cpio -i
busybox echo "[*] Booting Android" >> /lupus_log.txt

# fix usb mounting on GB & su
if [[ $ramdisk_choice == "2.3.3" ]] || [[ $ramdisk_choice == "2.3.4" ]] || [[ $ramdisk_choice == "2.3.7" ]]
then
echo /dev/block/mmcblk0 > /sys/devices/platform/msm_hsusb/gadget/lun0/file
if [[ ! -f /system/app/Superuser.apk ]] || [[ ! -f /system/app/SuperSU.apk ]] && [[ ! -f /system/xbin/su ]] || [[ ! -f /system/bin/su ]]; then
		busybox mount -o remount rw /system
		busybox cp -f /res/auto_root/su /system/xbin/
		busybox chown root.root /system/xbin/su
		busybox chmod 6755 /system/xbin/su
		# copy new superuser apk
		busybox cp /res/auto_root/SuperSU.apk /system/app/
		busybox chown root.root /system/app/SuperSU.apk
		busybox chmod 0644 /system/app/SuperSU.apk
		busybox mount -o remount ro /system
	if [ -f /system/autorooted ]; then
		busybox rm -f /system/autorooted
	elif [ -f /system/autoroot ]; then 
		busybox rm /system/autoroot
			
		fi
	fi
fi

# create links
cd sbin
source init-links.sh
cd ..

# unmount filesystems
busybox umount /system
busybox umount /cache
busybox umount /proc
busybox umount /sys

busybox rm -fr /dev/*
export PATH="${_PATH}"
exec /init
