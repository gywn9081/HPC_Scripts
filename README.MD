### default configuration options for the files

```
# --- Configs ---------------------------------------
HEAD_NODE="headnode"
USERNAME="mpiuser"
EXPECTED_UID="2642"
GATEWAY_ADDRESS="10.42.0.1/24"
HEAD_IP="10.42.0.111"
DNS_SERVERS="10.42.0.1,8.8.8.8"


# Cluster host list (Format: IP hostname)
CLUSTER_HOSTS="
10.42.0.111    headnode     // ip address for head node is supposed to be set to the first ip address in the subnet, but its set up to this now so we deal with it
10.42.0.101    compute01
10.42.0.102    compute02
10.42.0.103    compute03
"
```



1. have ubuntu server installed

2. configure `setup-static-network-slurm.sh` config variables

3. run `sudo setup-static-network-slurm.sh`

5. run `sudo install-openmp-mpi.sh`

6. configure `setup-mpiuser.sh` config variables

7. run `sudo setup-mpiuser.sh`

8. configure `setup-nfs.sh` config variables

WARNING: The below scripts are john coded. meaning the install + config stuff is merged into one file.
Mostly, this means that the scripts will only install the required programs if not connected to a network or at least the head node.
I would fix it. But I'm lazy. So...

regardless it will work, just be aware that there will be error messages 

9. run `sudo setup-nfs.sh`

10. configure `setup-home-folder.sh` config variables

11. run `setup-home-folder.sh`

12. configure `install-and-setup-ssh.sh` config variables

13. run `install-and-setup-ssh.sh`

14. configure `install-hydra.sh` config variables

15. run `install-hydra.sh`

