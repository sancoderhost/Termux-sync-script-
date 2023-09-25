#!/bin/bash

source ./main.conf 

TUNERROR=0
volcontol()
{
	ssh -i $IDENTITY_KEY sanbot@localhost -p $SSHPORT "pactl set-sink-volume @DEFAULT_SINK@  $1% "  

	toast=$( ssh -i $IDENTITY_KEY sanbot@localhost -p $SSHPORT   pactl list  sinks | awk -F /   '/^[[:space:]]Volume/ {print $2}' )   
	termux-toast -g top "$toast" 

}
sshtunnel()
{
	host=$(ping -c 1   $HOSTDOMAIN )
	if [[ $? -ne 0 ]]
	then 
		host=$(ip neigh show |awk '/([0-9]{1,3}\.){3}[0-9]{1,3}.+(wlan[10]|rndis0)/ {print $1}' |nmap -p $SCANPORT  --open -iL   - |grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' -o  )

			echo 'mdns scan failed======'
	else 

			host=$( echo "$host" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'  |head -n 1 )
	fi 
	if [[ -z $host ]] 
		then
			termux-notification --ongoing -t 'no server  in network '  --sound --alert-once --id 10 ;
			TUNERROR=1 
		else  
			ssh -o "StrictHostKeyChecking=no"  -i $IDENTITY_KEY -N   -l sanbot "$host" -L:$SSHPORT:localhost:22 &  
			# Load the configuration file and parse it line by line
			if [[ -f "service.csv" ]]; then
				while IFS=',' read -r service  localport  remoteport ; do
						echo "forwarding for $service the $remoteport to $localport"
						
						ssh -o "StrictHostKeyChecking=no"  -i $IDENTITY_KEY -N   -l sanbot "$host" -L:$localport:localhost:$remoteport &   

				done < "./service.csv"
			else
				echo "Service.csv Configuration file 'config.csv' not found."
				exit 1
fi
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
dircreate()
{

		if [[ -f "config.csv" ]]; then
			while IFS=',' read -r task source destination; do
				echo "creating destination dir $destination "
				ssh -i $IDENTITY_KEY  -p $SSHPORT sanbot@localhost mkdir -p "$destination"
			done < "config.csv"
		else
			echo "Configuration file 'config.csv' not found."
			exit 1
		fi
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
			    # Check if the directories exist, and create them if not
			     dircreate
			fi 
			echo "return code= $TUNERROR" 
			if (( TUNERROR == 0 ))
			then

			sources=()
		if [[ -f "config.csv" ]]; then
			while IFS=',' read -r task source destination; do
				echo "running $task "
		#echo  "sync started of=> $" |sed 's/\/sdcard\///g'  >~/transferlog  
				#appending list of sources to array $sources 
				sources+=($source)
				rsync -zavP   -e "ssh -p $SSHPORT -l sanbot -i $IDENTITY_KEY "  $source  sanbot@localhost:$destination >> ~/transferlog   
				#copy_files "$source" "$destination"
			done < "config.csv"
		else
			echo "Configuration file 'config.csv' not found."
			exit 1
		fi
			echo  "sync started of=> ${sources[@]}" |sed 's/\/sdcard\///g'  >~/transferlog  
#--info=#PROGRESS,FLIST2 
				
			if [[ $? -eq 0 ]]
			then 
				flag=1
				echo 1 > ~/flag 
			else
				
				termux-notification --alert-once  --id 10 --ongoing -t 'ssh tunnel error retrying...' 
				flag=0
			fi 

				curvol="$( ssh -i $IDENTITY_KEY sanbot@localhost -p $SSHPORT   pactl list  sinks | awk -F /   '/^[[:space:]]Volume/ {print $2}' )"    
	        		 cat  ~/transferlog  | termux-notification --id 10 --alert-once --ongoing --button1 '+'  --button1-action "ssh -i $IDENTITY_KEY sanbot@localhost -p $SSHPORT pactl set-sink-volume @DEFAULT_SINK@  +5%  ; "     --button2 '-'   --button2-action "ssh -i $IDENTITY_KEY sanbot@localhost -p $SSHPORT pactl set-sink-volume @DEFAULT_SINK@  -5% "  --button3 $curvol  --button3-action 'echo 0' 
				 #'termux-speech-to-text > ~/speechin'  

				 #cat  ~/speechin |ssh -p $SSHPORT -i $IDENTITY_KEY sanbot@localhost 'export DISPLAY=:0 && xargs xdotool type'



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


