# Termux sync script 

This bash script allows files from phone to synced to your pc or laptop over network 
using ssh.

## Direction to use 
First before deploying edit these three config files 
- main.conf : Include your desired credentials for ssh and ports 
- syncpaths.csv : Here you provide  list source and  destination directory to want to sync.
- service.csv : list of ports to local port you want to forward 

# Deploy this script 
```bash 
nohup ./syncstuff.sh & 

```
