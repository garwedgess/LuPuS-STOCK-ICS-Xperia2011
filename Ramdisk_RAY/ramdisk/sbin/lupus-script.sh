#!/sbin/busybox sh

# LuPuS Script (v1) - All in one

# set time
TIME=`/sbin/busybox date +"%r"`
export MOUNT="/system"

# check if /system exist as mountpoint.
if grep -qs $MOUNT /proc/mounts
then
	# mount system and create lupuslog
	/sbin/busybox mount -o remount rw /system
	# remove old log
if [ -f /data/local/tmp/lupuslog.txt ]; then
	/sbin/busybox rm -f /data/local/tmp/lupuslog.txt
fi
	# add to existing lupuslog
	/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt
	/sbin/busybox echo "=============================================" >> /data/local/tmp/lupuslog.txt
	/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt
	/sbin/busybox echo "           Running LuPuS Script" >> /data/local/tmp/lupuslog.txt
	/sbin/busybox echo "---------------------------------------------" >> /data/local/tmp/lupuslog.txt
	/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt	
	/sbin/busybox echo "[START] Mounting system as R/W" >> /data/local/tmp/lupuslog.txt
fi

/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt
/sbin/busybox echo "[WIFI] Checking for LuPuS wifi modules ">> /data/local/tmp/lupuslog.txt


	# load wifi modules if needed
	if [ -e /data/local/tmp/wifi-fix_v99 ]; then
		  # modules already exist
	  	  /sbin/busybox echo "[*] Existing wifi modules found.." >> /data/local/tmp/lupuslog.txt 
	elif [ ! -e /data/local/tmp/wifi-fix_v99 ]; then
		  # copy new modules if needed
				/sbin/busybox echo "[*] Move existing modules directory" >> /data/local/tmp/lupuslog.txt
				/sbin/busybox mv /system/lib/modules /system/lib/modules.old
				/sbin/busybox echo "[*] Push new modules" >> /data/local/tmp/lupuslog.txt
				/sbin/busybox mkdir /system/lib/modules/
				/sbin/busybox chmod 755 /system/lib/modules/
				/sbin/busybox cp -fr /res/modules/* /system/lib/modules/.
				/sbin/busybox echo "[*] Fixing permissions on new modules" >> /data/local/tmp/lupuslog.txt
				/sbin/busybox chmod 0644 /system/lib/modules/drivers/net/wireless/wl12xx/*
				/sbin/busybox chmod 0644 /system/lib/modules/net/mac80211/*
				/sbin/busybox chmod 0644 /system/lib/modules/net/wireless/*
				/sbin/busybox chmod 0644 /system/lib/modules/compat/*
				# create wifi marker
	  			/sbin/busybox touch /data/local/tmp/wifi-fix_v99
	  		    /sbin/busybox echo "[*] Installed new wifi modules " >> /data/local/tmp/lupuslog.txt
	fi

/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt



# Auto Root if SU.apk's or su binary is not present on device
/sbin/busybox echo "[ROOT] Checking if device is rooted.." >> /data/local/tmp/lupuslog.txt

if [[ -f /system/app/Superuser.apk ]] && [[ -e /system/bin/su ]]; then
		# found superuser
		/sbin/busybox echo "[*] Superuser.apk and su binary exist.." >> /data/local/tmp/lupuslog.txt
		/sbin/busybox echo "[*] Device already rooted.." >> /data/local/tmp/lupuslog.txt
elif [[ -f /system/app/SuperSU.apk ]] && [[ -e /system/bin/su ]]; then
		# found SuperSU
		/sbin/busybox echo "[*] SuperSU.apk and su binary already exist.." >> /data/local/tmp/lupuslog.txt
		/sbin/busybox echo "[*] Device already rooted.." >> /data/local/tmp/lupuslog.txt
elif [[ -f /data/app/Superuser.apk ]] && [[ -e /system/bin/su ]]; then
		# found superuser
		/sbin/busybox echo "[*] Superuser.apk and su binary already exist.." >> /data/local/tmp/lupuslog.txt
		/sbin/busybox echo "[*] Device already rooted.." >> /data/local/tmp/lupuslog.txt
elif [[ -f /data/app/SuperSU.apk ]] && [[ -e /system/bin/su ]]; then
		# found supersu
		/sbin/busybox echo "[*] SuperSU.apk and su binary already exist.." >> /data/local/tmp/lupuslog.txt
		/sbin/busybox echo "[*] Device already rooted.." >> /data/local/tmp/lupuslog.txt
elif [ ! -f /data/local/tmp/autoroot ]; then
		# if neither SU.apk is present install / root device
		/sbin/busybox echo "[*] Device not Rooted !! " >> /data/local/tmp/lupuslog.txt	
		/sbin/busybox echo "[*] Rooting now..." >> /data/local/tmp/lupuslog.txt 
		# remove previous SU.apk's
		/sbin/busybox rm -f /data/app/SuperSU.apk
		/sbin/busybox rm -f /data/app/Superuser.apk
		/sbin/busybox rm -f /system/app/SuperSU.apk
		/sbin/busybox rm -f /system/app/Superuser.apk
		# remove old binaries
		/sbin/busybox echo "[*] Removing old SU binary" >> /data/local/tmp/lupuslog.txt
		/sbin/busybox rm -f /system/xbin/su
		/sbin/busybox rm -f /system/bin/su
		/sbin/busybox echo "[*] Creating new SU binary" >> /data/local/tmp/lupuslog.txt
		/sbin/busybox cp -f /res/auto_root/su /system/xbin/
		/sbin/busybox echo "[*] Setting permissions" >> /data/local/tmp/lupuslog.txt
		/sbin/busybox chown root.root /system/xbin/su
		/sbin/busybox chmod 6755 /system/xbin/su
		/sbin/busybox cp -f /res/auto_root/su /system/bin/
		/sbin/busybox echo "[*] Setting permissions" >> /data/local/tmp/lupuslog.txt
		/sbin/busybox chown root.root /system/bin/su
		/sbin/busybox chmod 6755 /system/bin/su
		# copy new superuser apk
		/sbin/busybox cp /res/auto_root/SuperSU.apk /system/app/
		/sbin/busybox chown root.root /system/app/SuperSU.apk
		/sbin/busybox chmod 0644 /system/app/SuperSU.apk
		# create root marker
		/sbin/busybox touch /data/local/tmp/autoroot
		/sbin/busybox echo "[*] Root has been set.. " >> /data/local/tmp/lupuslog.txt
else 		
		/sbin/busybox echo "[*] Device already rooted.." >> /data/local/tmp/lupuslog.txt
fi

# make sure there is no autoroot script in ROM and remove if there is
/sbin/busybox echo "[*] Checking for autoroot scripts " >> /data/local/tmp/lupuslog.txt

	# check if ROM has an autoroot script
	if [ -f /system/autorooted ]; then
		/sbin/busybox echo "[*] Removing autoroot scripts (conflicts) " >> /data/local/tmp/lupuslog.txt
		/sbin/busybox rm -f /system/autorooted
	elif [ -f /system/autoroot ]; then 
			/sbin/busybox rm /system/autoroot
	elif [[ ! -f /system/autoroot ]] || [[ ! -f /system/autorooted ]]; then
			/sbin/busybox echo "[*] No autoroot script found in ROM " >> /data/local/tmp/lupuslog.txt
			
	fi

/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt

# [SQlite3] db vacuuming.
/sbin/busybox echo "[SQLITE] Search and vacuuming db" >> /data/local/tmp/lupuslog.txt

if [ ! -e /system/xbin/sqlite3 ];
then
if [ -e /system/mesa-stock ];
then
	/sbin/busybox cp -f /sbin/sqlite3 /system/xbin/sqlite3
	/sbin/busybox chmod 0755 /system/xbin/sqlite3
fi
	fi

if [ -e /system/xbin/sqlite3 ];
then
	for i in \
	`/sbin/busybox find ./ -iname "*.db"`
	do \
		/system/xbin/sqlite3 $i 'VACUUM;'
		/system/xbin/sqlite3 $i 'REINDEX;'
	done
fi	

/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt
/sbin/busybox echo "[INIT.D] Checking if device supports init.d" >> /data/local/tmp/lupuslog.txt
# make init.d directory
/sbin/busybox echo "[*] Creating init.d directory" >> /data/local/tmp/lupuslog.txt
/sbin/busybox mkdir -p /system/etc/init.d
/system/bin/logwrapper /sbin/busybox run-parts /system/etc/init.d
/sbin/busybox echo "[*] Init.d set.." >> /data/local/tmp/lupuslog.txt

if [ -e /system/system/etc/init.d/* ]; then
	# set permissions on init.d folder
	/sbin/busybox chmod -R 0777 /system/etc/init.d/*
fi

	
# Remount as Read ONLY
/sbin/busybox echo "" >> /data/local/tmp/lupuslog.txt
/sbin/busybox echo "[END] Mounting system as R/O" >> /data/local/tmp/lupuslog.txt
/sbin/busybox echo "---------------------------------------------" >> /data/local/tmp/lupuslog.txt
/sbin/busybox echo "  [---Finished boot @: $TIME---]" >> /data/local/tmp/lupuslog.txt
/sbin/busybox echo "*********************************************" >> /data/local/tmp/lupuslog.txt
# print lupus log to lupus/log.txt
alltext=`cat /data/local/tmp/lupuslog.txt`
/sbin/busybox echo "$alltext" >> /lupus_log.txt
# mount as r/o
/sbin/busybox mount -o remount ro /system
return 0
