#!/bin/bash

SOURCE=/sdcard/DCIM 
SOURCE2=/sdcard/Music/

SOURCE3=/sdcard/beatbox/
SOURCE4=/sdcard/syncnotes/
DESTINATION2=/home/sanbotbtrfs/Desktop/songs/phonesync/
DESTINATION3=/home/sanbotbtrfs/Desktop/1/Pixel_backup/beatboxsync/
DESTINATION4=/home/sanbotbtrfs/Desktop/1/Pixel_backup/syncnotes/
DESTINATION=/home/sanbotbtrfs/Desktop/1/Pixel_backup/rsync-data/
SITESOURCE=/home/sanbotbtrfs/Documents/savedpage/offlinesite 
SITEDEST=/data/data/com.termux/files/usr/share/apache2/default-site/htdocs
TUNERROR=0
volcontol()
{
	ssh -i ~/laptopkey sanbot@localhost -p 2222 "pactl set-sink-volume @DEFAULT_SINK@  $1% "  

	toast=$( ssh -i ~/laptopkey sanbot@localhost -p 2222   pactl list  sinks | awk -F /   '/^[[:space:]]Volume/ {print $2}' )   
	termux-toast -g top "$toast" 

}
sshtunnel()
{
	host=$(ping -c 1   laptop.local )
	if [[ $? -ne 0 ]]
	then 
		host=$(ip neigh show |awk '/([0-9]{1,3}\.){3}[0-9]{1,3}.+(wlan[10]|rndis0)/ {print $1}' |nmap -p 6666  --open -iL   - |grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' -o  )

			echo 'mdns scan failed======'
	else 

			host=$( echo "$host" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'  |head -n 1 )
	fi 
	if [[ -z $host ]] 
		then
			termux-notification --ongoing -t 'no server  in network '  --sound --alert-once --id 10 ;
			TUNERROR=1 
		else  
			ssh -o "StrictHostKeyChecking=no"  -i ~/laptopkey -N   -l sanbot "$host" -L:2222:localhost:22  -L:6800:localhost:6800  -L:1935:localhost:1935 -L:8096:localhost:8096  -L:8080:localhost:80 -L:6666:localhost:6666 -L:8081:localhost:8085 -L:4533:localhost:4533  -L:4445:localhost:445  &
			TUNERROR=0 
	fi
}


cleanup()
{
	echo 'cleaning up!'
	pkill -x ssh 
	rm ~/flag ~/flagnet 
	termux-notification -t done --id 10 
	exit 0 
}

trap cleanup 1 2 3 6 14 15  ;
#subnet=$( ip route  show   |awk  '/wlan1/ {print $1}' )
#host=$(  nmap --open    -p 8096    $subnet  |grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' );
if [[ ! -f ~/flagnet ]] 
then 
	echo 1 > ~/flagnet 
	flagnet=1
else 
	flagnet=$(cat ~/flagnet)
fi 
if [[ ! -f ~/flag ]]
then 
	echo 0 > ~/flag 
	flag=0
else 
	flag=$(cat ~/flag )
fi

#if [[ ! -f ~/speecin ]] 
#then 
#	mkfifo ~/speechin 
#fi 

while true 
do
	
	ip addr show |grep -e rndis0  -e wlan0 -e wlan1  |grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' 
	if [ $? -eq 0 ]
	then 

		if [[ $(ip neigh |wc -l ) -lt 1 ]] 
		then
			echo 'no client' 

			termux-notification --ongoing -t 'no client connected'  --sound --alert-once --id 10 
			flagnet=1
		else

			echo 'local network detected  ' 
			if(( flagnet== 0  ))
			then 
			termux-notification  --ongoing  --id 10 -t 'local network connected'  --sound --alert-once
				flagnet=1 
				echo 1 > ~/flagnet  
			fi
			
			if (( flag == 0 ))
			then
			     sshtunnel
			fi 
			echo "return code= $TUNERROR" 
			if (( TUNERROR == 0 ))
			then

			echo  "sync started of=> $SOURCE , $SOURCE2 , $SOURCE3,$SOURCE4  " |sed 's/\/sdcard\///g'  >~/transferlog  
#--info=PROGRESS,FLIST2 
				rsync -za --info=PROGRESS,COPY   -e "ssh -p 2222 -l sanbot -i ~/laptopkey "  $SOURCE sanbot@localhost:$DESTINATION >> ~/transferlog   
						
				rsync -za  --info=PROGRESS,COPY    -e "ssh -p 2222 -l sanbot -i ~/laptopkey "  $SOURCE2 sanbot@localhost:$DESTINATION2 >> ~/transferlog    

				rsync -za  --info=PROGRESS,COPY  -e "ssh -p 2222 -l sanbot -i ~/laptopkey "  $SOURCE3 sanbot@localhost:$DESTINATION3 >> ~/transferlog    

				rsync -za  --delete --info=PROGRESS,COPY   -e "ssh -p 2222 -l sanbot -i ~/laptopkey "  $SOURCE4 sanbot@localhost:$DESTINATION4 >> ~/transferlog   
				rsync -za  --delete --info=PROGRESS,COPY   -e "ssh -p 2222 -l sanbot -i ~/laptopkey "    sanbot@localhost:$SITESOURCE $SITEDEST  >> ~/sitetransferlog 2>&1    
				
			if [[ $? -eq 0 ]]
			then 
				flag=1
				echo 1 > ~/flag 
			else
				
				termux-notification --alert-once  --id 10 --ongoing -t 'ssh tunnel error retrying...' 
				flag=0
			fi 

				curvol="$( ssh -i ~/laptopkey sanbot@localhost -p 2222   pactl list  sinks | awk -F /   '/^[[:space:]]Volume/ {print $2}' )"    
	        		 cat  ~/transferlog  | termux-notification --id 10 --alert-once --ongoing --button1 '+'  --button1-action "ssh -i ~/laptopkey sanbot@localhost -p 2222 pactl set-sink-volume @DEFAULT_SINK@  +5%  ; "     --button2 '-'   --button2-action "ssh -i ~/laptopkey sanbot@localhost -p 2222 pactl set-sink-volume @DEFAULT_SINK@  -5% "  --button3 $curvol  --button3-action 'echo 0' 
				 #'termux-speech-to-text > ~/speechin'  

				 #cat  ~/speechin |ssh -p 2222 -i ~/laptopkey sanbot@localhost 'export DISPLAY=:0 && xargs xdotool type'



				 # sleep 0.1 ;
			fi
	fi
	else 
		pkill -x -9 ssh
		echo 'network disconnected  '
		if (( flagnet == 1 ))
		then 
			termux-notification  -t 'local network disconnected' --ongoing --id 10  --sound --alert-once 
			flagnet=0
			echo 0 > ~/flagnet 
		fi 
		flag=0
		echo 0 >~/flag 

	fi 

   sleep 0.1;
done


