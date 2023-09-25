#!/data/data/com.termux/files/usr/bin/sh 
termux-job-scheduler -s /data/data/com.termux/files/home/check7.sh  --battery-not-low false --job-id 10 --persisted true 
avahi-daemon &
