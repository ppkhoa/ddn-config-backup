#! /bin/bash

# This script will backup network and Linux configuration in preparation for
# GRIDSCaler 4.0 upgrade/reinstall.
# This script is meant to run on each GRIDSCaler server.
# The current version of the script supports the standard GS installation, 
# it does not back up configurations for applications not included with original GS installation.

# For support/feedback with the script, contact Khoa Pham (kpham@ddn.com) or Ed Stack (estack@ddn.com).

# Version 3.0.1 (KP):
#	Removed restore archive placement requirements.
# Version 3.0 (KP): 
#	Added SSH Key scan
#	Added host keys backup/restore (could pose security risk, might need to be reconsidered)
#	Fixed permissions for host keys
#	Added setting hostname after restore
#	Improved parameters detection
# Version 2.4 (KP): 
#	Added colors! (green = success, yellow = info, orange = warning, red = error)
# Version 2.3.1 (KP): 
#	Simplify untar and cleanup operation
#	Changed recovery name from .bak to .ddnbak to prevent deleting user's files
# Version 2.3 (KP): 
#	Simplify restore input check
#	Added more description for restore procedure
#	Changed recovery archive action from mv to cp for improve redundancy.
# Version 2.2 (KP): 
#	Minor fixes for messages
# Version 2.1 (KP): 
#	Added cleanup option for deleting backed up files post-restore
# 	Added checks to prevent wiping the whole system
# Version 2.0 (KP): 
#	Added backup option
#	Added help section
# Version 1.1 (KP): 
#	Added more files to backup
#	Added document only section
#	Simplified backup directory creation
# Version 1.0 (KP): 
#	Initial release

###############################################################################
# Define hostname
#
nodename=$(hostname)

###############################################################################
#
# Create backup temporary directory current system time and hostname
#
start_time=$(date +%Y%m%d%H%M%S)
backup_dir="/tmp/$nodename-backup-$start_time"
doc_only="/tmp/$nodename-doconly-$start_time"
ext="gz"

###############################################################################
#
# Define colors
#
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

###############################################################################
#
# Backup configurations (to be restored)
#
function backup {
	# Create folders for backup
	mkdir $backup_dir $doc_only
	# SSH Keys
	echo -e "${YELLOW}Backing up SSH key...${NC}"
	cp -r --parents /root/.ssh/* $backup_dir
	cp -r --parents /etc/ssh/* $backup_dir

	# GPFS config
	echo -e "${YELLOW}Backing up GPFS configuration...${NC}"
	cp -r --parents /var/mmfs $backup_dir

	# Linux and network config
	echo -e "${YELLOW}Backing up network configurations...${NC}"
	cp -r --parents /etc/networks $backup_dir
	cp -r --parents /etc/resolv.conf  $backup_dir
	cp -r --parents /etc/ntp.conf  $backup_dir
	cp -r --parents /etc/iproute2/rt_tables  $backup_dir

	# Hosts file
	echo -e "${YELLOW}Backing up hosts file...${NC}"
	cp -r --parents /etc/hosts $backup_dir

	# DDN config files
	echo -e "${YELLOW}Backing up DDN config...${NC}"
	cp -r --parents /etc/ddn/*.conf $backup_dir

	# Generic Linux config
	echo -e "${YELLOW}Backing up Linux config...${NC}"
	cp -r --parents /etc/sysconfig/clock $backup_dir
	cp -r --parents /etc/sysconfig/network  $backup_dir

	###############################################################################
	#
	# Document only section
	#
	echo -e "${YELLOW}Documenting interface configuration...${NC}"
	cp -r --parents /etc/sysconfig/network-scripts/ifcfg-* $doc_only 

	# Hostname, in different format
	echo -e "${YELLOW}Documenting hostname...${NC}"
	hostname > $doc_only/hostname.out 
	hostname -s > $doc_only/hostname_s.out 
	hostname -f > $doc_only/hostname_f.out 
	lsscsi > $doc_only/lsscsi.out 

	# Multipath
	echo -e "${YELLOW}Documenting multipath configuration files...${NC}"
	cp -r --parents /etc/multipath.conf $doc_only

	# DDN stuff
	echo -e "${YELLOW}Documenting DDN config...${NC}"
	cp -r --parents /etc/ddn/*.conf $doc_only
	cp -r --parents /opt/ddn/bin/tune_devices.sh $doc_only

	# Routing tables
	echo -e "${YELLOW}Documenting routing tables...${NC}"
	ip route show table all > $doc_only/ip_route_show_table_all.out
	ip rule show > $doc_only/ip_rule_show.out && ip route > $doc_only/ip_route.out 
	ip a > $doc_only/ip_a.out

	# Generic Linux config
	echo -e "${YELLOW}Documenting Linux config...${NC}"
	cp -r --parents /etc/fstab $doc_only
	chkconfig --list > $doc_only/chkconfig-list.out
	cp -r --parents /etc/sysctl.conf $doc_only
	cp -r /etc/sysconfig  $doc_only

	# Once finished, pack all files into one archive then remove the folder, 
	# keeping the archive with same folder structure
	# Tar the folder with -v for debugging purposes, output can be hidden in later version.
	echo -e "${YELLOW}Finished! Packing up...${NC}"

	# Pack up data collected, to be restored later.
	cd $backup_dir && tar -zcvf $nodename-backup-$start_time.gz * && mv $nodename-backup-$start_time.gz /tmp && rm -rf $backup_dir

	# Pack up document only data, will not be used for restoring.
	printf "${YELLOW}Packing up document only configuration...\n\n${NC}"
	cd $doc_only && tar -zcvf $nodename-doconly-$start_time.gz * && mv $nodename-doconly-$start_time.gz /tmp && rm -rf $doc_only
	echo -e "${YELLOW}Cleaning up..."
	echo -e "${GREEN}All done! ${NC}Backup can be found at ${YELLOW}$backup_dir.gz"
	echo -e "${NC}For reference only data (not used for restore), it can be found at ${YELLOW}$doc_only.gz${NC}"
	printf "\nIf you received any cp error, make sure the file exist and/or affected services are configured.\n\n"
	printf "To restore after the upgrade/reinstall, use ${YELLOW}\"bash gs-config-backup.sh -r $nodename-backup-$start_time.gz\"\n${NC}(script and archive must in the same non-root folder)\n"
	echo -e "${ORANGE}Remember to copy this file to a different node before performing GRIDScaler 4.0 upgrade/reinstall.${NC}"
	echo -e "${ORANGE}Do not change the filename since the restore script depends on it.${NC}"
}

###############################################################################
#
# Restore configuration
#

function restore {
	local restore_path=$1
	local restore_file=$(basename $1)
	local hostname_restore=$(echo "$restore_file" | awk '{split($0,a,"-backup-\\w{1,}.gz"); print a[1]}')  # Extract hostnames from restore archive, assuming filename hasn't changed
	cp $restore_path /
	echo -e "${YELLOW}Creating recovery archive, just in case...${ORANGE}"
	mkdir /root/.ssh.ddnbak 
	cp -r  /root/.ssh/* /root/.ssh.ddnbak
	mkdir /etc/ssh.ddnbak
	cp -r /etc/ssh /etc/ssh.ddnbak
	
	# GPFS config
	mkdir /var/mmfs.ddnbak
	cp -r --parents  /var/mmfs/* /var/mmfs.ddnbak
	
	# Linux and network config
	cp  /etc/networks /etc/networks.ddnbak
	cp  /etc/resolv.conf  /etc/resolv.conf.ddnbak
	cp  /etc/ntp.conf /etc/ntp.conf.ddnbak
	cp /etc/iproute2/rt_tables  /etc/iproute2/rt_tables.ddnbak

	# Hosts file
	cp  /etc/hosts /etc/hosts.ddnbak

	# DDN config files
	mkdir /etc/ddn.ddnbak
	cp -r --parents /etc/ddn/* /etc/ddn.ddnbak

	# Generic Linux config
	cp -r  /etc/sysconfig/clock /etc/sysconfig/clock.ddnbak
	cp -r  /etc/sysconfig/network  /etc/sysconfig/network.ddnbak
	
	echo -e "${YELLOW}Restoring configuration...${NC}"
	tar -C / -xzvf $restore_path
	echo -e "${YELLOW}Setting hostname...${NC}"
	(set -x; hostnamectl set-hostname $hostname_restore) #set -x to print command
	echo -e "${YELLOW}Fixing host keys permissions...${NC}"
	chmod 700 /etc/ssh/ssh_host_*
	#rc=${status: -1} # Get the exit code for untar process
	#if [ $rc -ne 0 ] # If fails, do not continue and exit with error code 1 to prevent damage to filesystem
	#then
	#	printf "\nCannot find the specified archive or the file is corrupted!\n";
	#	exit 1;
	#fi
	printf "${YELLOW}Cleaning up...\n${NC}"
	rm -rf /$restore_file # If user used * as the file name, the script shouldn't reach this point
	echo -e "${GREEN}Reboot the node to apply the settings.${NC}"
	printf "\nIf you received any mv error, check the source "
	printf "to confirm it exist and make sure you only run the restore once.\n\n"
}


###############################################################################
#
# Clean up unneeded recovery files
#
function cleanup {
	printf "${YELLOW}Cleaning up backed up files...\n${NC}"
	rm -rf /root/.ssh.ddnbak
	rm -rf /var/mmfs.ddnbak
	rm -rf /etc/*.ddnbak
	rm -rf /etc/ddn.ddnbak
	rm -rf /etc/sysconfig/*.ddnbak
	printf "${GREEN}Done!\n${NC}"
}

###############################################################################
#
# Scan all hosts listed in /etc/hosts and add the host keys to /root/.ssh/known_hosts
#
function sshkeyscan {
	echo -e "${YELLOW}Grabbing IPs and hostnames from /etc/hosts...${NC}"
	awk '{for(i=1;i<=NF;i++) print $i }' /etc/hosts | sort | uniq > sshkeyhosts.txt # For every line in the hosts file, get IP address and all hostname, sort and filter duplicates
	echo -e "${YELLOW}Backing up existing known_hosts..."
	mv /root/.ssh/known_hosts /root/.ssh/known_hosts.bak
	echo -e "${YELLOW}Scanning all hosts for SSH host keys...${NC}"
	ssh-keyscan -f sshkeyhosts.txt > /root/.ssh/known_hosts # Scan all the hosts and add them to known_hosts
	echo -e "${GREEN}Done!${NC}"	
	rm -f sshkeyhosts.txt
}

function help {
	echo ""
	echo "This script will backup network and Linux configuration in preparation for"
	echo "GRIDSCaler 4.0 upgrade/reinstall."
	echo "This script is meant to run on each GRIDSCaler server."
	echo "The current version of the script supports the standard GS installation, "
	echo "it does not back up configurations for applications not included with original GS installation."
	echo "Specify operation you want to use:"
	echo "-b for backup"
	echo "-c to clean up recovery archive files. Make sure everything's working before using this option"
	echo "-r <filename> for restore, must be in the same non-root folder as the script"
	echo "-s to scan all hosts from /etc/hosts for SSH host keys"
}

###############################################################################
# Main ()
#
if [ $# -eq 0 ]
  then
    echo -e "${ORANGE}No arguments supplied, showing help${NC}"
	help
	exit 0;
fi
options=':bchsr:'
while getopts $options opt; do
	case $opt in
		b) 
			echo -e "${GREEN}Backup option selected. Starting backup process..."
			backup
			echo -e ${NC}
			exit 0;
			;;
		h) 
			help; 
			echo -e ${NC}
			exit 0
			;;
		r)
			echo -e "${GREEN}Restore option selected. Using $OPTARG"
			if [ ${OPTARG: -2} != $ext ]
			then
				echo -e "${RED}Wrong file type! Make sure you picked the backup archive"
				echo -e ${NC}
			else
				restore $OPTARG
				echo -e ${NC}
			fi
			echo -e ${NC}
			exit 0;
			;;
		s)
			echo -e "${GREEN}SSH Key scan option selected.";
			#do something
			sshkeyscan
			echo -e ${NC}
			exit 0;
			;;
		c)
			echo -e "${GREEN}Cleanup action selected.";
			cleanup
			echo -e ${NC}
			exit 0;
			;;
		:) 
			echo -e "${ORANGE}Missing archive name to restore from"; 
			echo -e ${NC}
			exit 1
			;;
		\?) 
			echo -e "${ORANGE}Unrecognized option, use -h for help"; 
			echo -e ${NC}
			exit 0
			;;
	esac
done
