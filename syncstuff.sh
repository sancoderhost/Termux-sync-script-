#!/bin/bash

#Injecting startup file to start at boot 
if [  ! -e  ./firststart ] || [ "$(cat ./firststart )" -eq 0  ];
then 
		echo 1 > ./firststart ;
		if cp -v ./boot ~/.termux/boot/
		then 
				echo 'copied startup files successfully'
		fi
fi 
# Define an array of dependencies
dependencies=("termux-api" "nmap" "openssh")

# Function to check if a dependency is installed
is_dependency_installed() {
  local dependency_name="$1"
  command -v "$dependency_name" &>/dev/null
}

# Iterate through the array and install missing dependencies
for dependency in "${dependencies[@]}"; do
  if ! is_dependency_installed "$dependency"; then
    echo "Installing $dependency..."
    apt install -y "$dependency"
    if [ $? -eq 0 ]; then
      echo "$dependency is now installed."
    else
      echo "Failed to install $dependency. Exiting."
      exit 1
    fi
  else
    echo "$dependency is already installed."
  fi
done

# Main part of your script goes here
echo "All dependencies are satisfied. Running the main part of the script..."
# Your main script logic here

# End of script

source ./main.conf 

TUNERROR=0
volcontol()
{
	ssh -i $IDENTITY_KEY $USERNAME@localhost -p $SSHPORT "pactl set-sink-volume @DEFAULT_SINK@  $1% "  

	toast=$( ssh -i $IDENTITY_KEY $USERNAME@localhost -p $SSHPORT   pactl list  sinks | awk -F /   '/^[[:space:]]Volume/ {print $2}' )   
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
			ssh -o "StrictHostKeyChecking=no"  -i $IDENTITY_KEY -N   -l $USERNAME "$host" -L:$SSHPORT:localhost:22 &  
			# Load the configuration file and parse it line by line
			if [[ -f "service.csv" ]]; then
				while IFS=',' read -r service  localport  remoteport ; do
						echo "forwarding for $service the $remoteport to $localport"
						
						ssh -o "StrictHostKeyChecking=no"  -i $IDENTITY_KEY -N   -l $USERNAME "$host" -L:$localport:localhost:$remoteport &   

				done < "./service.csv"
			else
				echo "Service.csv Configuration file 'syncpaths.csv' not found."
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

		if [[ -f "syncpaths.csv" ]]; then
			while IFS=',' read -r task source destination; do
				echo "creating destination dir $destination "
				ssh -i $IDENTITY_KEY  -p $SSHPORT $USERNAME@localhost mkdir -p "$destination"
			done < "syncpaths.csv"
		else
			echo "Configuration file 'syncpaths.csv' not found."
			exit 1
		fi
}

trap cleanup 1 2 3 6 14 15  ;


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
			     
			fi 
			echo "return code= $TUNERROR" 
			if (( TUNERROR == 0 ))
			then
					dircreate

					sources=()
				if [[ -f "syncpaths.csv" ]]; then
					while IFS=',' read -r task source destination; do
						echo "running $task "
						#appending list of sources to array $sources 
						sources+=($source)
						rsync -zavP   -e "ssh -p $SSHPORT -l $USERNAME -i $IDENTITY_KEY "  $source  $USERNAME@localhost:$destination >> ~/transferlog   
					done < "syncpaths.csv"
				else
					echo "Configuration file 'syncpaths.csv' not found."
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

						curvol="$( ssh -i $IDENTITY_KEY $USERNAME@localhost -p $SSHPORT   pactl list  sinks | awk -F /   '/^[[:space:]]Volume/ {print $2}' )"    
						cat  ~/transferlog  | termux-notification --id 10 --alert-once --ongoing --button1 '+'  --button1-action "ssh -i $IDENTITY_KEY $USERNAME@localhost -p $SSHPORT pactl set-sink-volume @DEFAULT_SINK@  +5%  ; "     --button2 '-'   --button2-action "ssh -i $IDENTITY_KEY $USERNAME@localhost -p $SSHPORT pactl set-sink-volume @DEFAULT_SINK@  -5% "  --button3 $curvol  --button3-action 'echo 0' 




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


