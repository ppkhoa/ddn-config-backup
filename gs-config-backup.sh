#! /bin/bash

# This script will backup network and Linux configuration in preparation for
# GRIDScaler 4.0 upgrade/reinstall.
# This script is meant to run on each GRIDScaler server.
# The current version of the script supports the standard GS installation, 
# it does not back up configurations for applications not included with original GS installation.

# For support/feedback with the script, contact Khoa Pham (kpham@ddn.com) or Ed Stack (estack@ddn.com).

# Changelogs has been moved to GitHub wiki: https://github.com/ppkhoa/gs-config-backup/wiki


###############################################################################
# Define hostname
#
nodename=$(hostname)

###############################################################################
#
# Create backup temporary directory current system time and hostname
#
start_time=$(date +%Y%m%d%H%M%S)
gsbackup_dir="/tmp/$nodename-gsbackup-$start_time"
doc_only="/tmp/$nodename-doconly-$start_time"
esbackup_dir="/tmp/$nodename-esbackup-$start_time"

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
function gs_backup {
	dir=$(pwd)
	# Create folders for backup
	mkdir $gsbackup_dir $doc_only
	# SSH Keys
	echo -e "${YELLOW}Backing up SSH key...${NC}"
	cp -r --parents /root/.ssh/* $gsbackup_dir
	cp -r --parents /etc/ssh/* $gsbackup_dir

	# GPFS config
	echo -e "${YELLOW}Backing up GPFS configuration...${NC}"
	rsync -av /var/mmfs $gsbackup_dir/var --exclude afm

	# Linux and network config
	echo -e "${YELLOW}Backing up network configurations...${NC}"
	cp -r --parents /etc/networks $gsbackup_dir
	cp -r --parents /etc/resolv.conf  $gsbackup_dir
	cp -r --parents /etc/ntp.conf  $gsbackup_dir
	cp -r --parents /etc/iproute2/rt_tables  $gsbackup_dir
	cp -r --parents /etc/sysconfig/network-scripts/ifcfg-* $doc_only
	cp -r --parents /etc/sysconfig/network-scripts/ifcfg-* $gsbackup_dir

	# Hosts file
	echo -e "${YELLOW}Backing up hosts file...${NC}"
	cp -r --parents /etc/hosts $gsbackup_dir

	# DDN config files
	echo -e "${YELLOW}Backing up DDN config...${NC}"
	cp -r --parents /etc/ddn/*.conf $gsbackup_dir

	# Generic Linux config
	echo -e "${YELLOW}Backing up Linux config...${NC}"
	cp -r --parents /etc/sysconfig/clock $gsbackup_dir
	cp -r --parents /etc/sysconfig/network  $gsbackup_dir
	document
	# Once finished, pack all files into one archive then remove the folder, 
	# keeping the archive with same folder structure
	# Tar the folder with -v for debugging purposes, output can be hidden in later version.
	echo -e "${YELLOW}Finished! Packing up...${NC}"

	# Pack up data collected, to be restored later.
	cd $gsbackup_dir && tar -zcvf $nodename-gsbackup-$start_time.gz * && mv $nodename-gsbackup-$start_time.gz /$dir && rm -rf $gsbackup_dir

	# Pack up document only data, will not be used for restoring.
	printf "${YELLOW}Packing up document-only configuration...\n\n${NC}"
	cd $doc_only && tar -zcvf $nodename-doconly-$start_time.gz * && mv $nodename-doconly-$start_time.gz /$dir && rm -rf $doc_only
	echo -e "${YELLOW}Cleaning up..."
	echo -e "${GREEN}All done! ${NC}Backup can be found at ${YELLOW}$nodename-gsbackup-$start_time.gz"
	echo -e "${NC}For reference only data (not used for restore), it can be found at ${YELLOW}$nodename-doconly-$start_time.gz${NC}"
	printf "\nIf you received any cp error, make sure the file exist and/or affected services are configured.\n\n"
	printf "To restore after the upgrade/reinstall, use ${YELLOW}\"bash gs-config-backup.sh -r <path-to-file>/$nodename-gsbackup-$start_time.gz\"\n${NC}"
	echo -e "${ORANGE}Remember to copy both files listed above to a different node before performing GRIDScaler 4.0 upgrade/reinstall.${NC}"
	echo -e "${ORANGE}Do not change the filename! The restore script depends on it.${NC}"
}

###############################################################################
#
# EXAScaler backup section
#

function es_backup {
	echo "test"
	# es_backup function goes here
}

###############################################################################
#
# Document only section
#

function document {

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
}

###############################################################################
#
# EXAScaler restore section
#

function es_restore {
	echo "test"
	# es_restore function goes here
}


###############################################################################
#
# Restore GPFS configuration
#

function gs_restore {
	local restore_path=$1
	local restore_file=$(basename $1)
	if $(echo $OPTARG | if grep -q gs; then echo true; else echo false; fi)
		then
			local hostname_restore=$(echo "$restore_file" | awk '{split($0,a,"-gsbackup-\\w{1,}.gz"); print a[1]}')  # Extract hostnames from restore archive, assuming filename hasn't changed
		else
			local hostname_restore=$(echo "$restore_file" | awk '{split($0,a,"-backup-\\w{1,}.gz"); print a[1]}') # Backward compatible with previous version of the script
	fi
	echo -e "${YELLOW}Creating recovery archive, just in case...${ORANGE}"
	mkdir /root/.ssh.ddnbak 
	cp -r  /root/.ssh/* /root/.ssh.ddnbak
	mkdir /etc/ssh.ddnbak
	cp -r /etc/ssh /etc/ssh.ddnbak
	
	# GPFS config
	cp -r /var/mmfs /var/mmfs.ddnbak
	
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
	
	cp -r /etc/sysconfig/network-scripts /etc/sysconfig/network-scripts.ddnbak
	
	echo -e "${YELLOW}Restoring configuration...${NC}"
	tar -C / -xzvf $restore_path
	
	echo -e "${YELLOW}Restoring network configuration...${NC}"
	network_restore

	echo -e "${YELLOW}Setting hostname...${NC}"
	(set -x; hostnamectl set-hostname $hostname_restore) # set -x to print command
	echo -e "${YELLOW}Setting timezone... ${NC}(If there's no /etc/clock available, this step will fail and the error can be ignored)"
	(set -x; timedatectl set-timezone $(cat /etc/sysconfig/clock | grep ZONE | sed 's/ /_/g; s/^[^=]*=//g; s/"//g'))
	echo -e "${YELLOW}Fixing host keys permissions...${NC}"
	chmod 600 /etc/ssh/ssh_host_*
	echo -e "${YELLOW}Performing hosts scan...${NC}"
	sshkeyscan
	printf "${YELLOW}Cleaning up...\n${NC}"
	echo -e "${GREEN}Reboot the node to apply the settings.${NC}"
	printf "\nIf you received any mv error, check the source "
	printf "to confirm it exist and make sure you only run the restore once.\n\n"
}

###############################################################################
#
# Restore network configuration
#
function network_restore {
	current_interface=$(ls /sys/class/net/);
	old_interface=$(ls /etc/sysconfig/network-scripts/)
	mac="";
	echo -e "${ORANGE}Do you want the script to attempt migrating network configuration (if HWADDR isn't defined in the old config, this might not work properly)? [y/N] ${NC}"
	read -r response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
	then
		for o in $old_interface;
		do
			for c in $current_interface;
			do
				if [[ "ifcfg-$c" = "$o" ]];
				then 
					mac=""; # do something
				elif [[ "$(cat /sys/class/net/$c/address)" = "$(grep HWADDR /etc/sysconfig/network-scripts/$o | cut -c 8-25 | tr '[:upper:]' '[:lower:]')" ]];
				then
					mac=$(cat /sys/class/net/$c/address);
					echo -e "${YELLOW}Migrating network configuration to new interface name: "$mac "is going from" $o "to" "ifcfg-"$c "${NC}";
					$(touch /etc/sysconfig/network-scripts/ifcfg-$c && cat /etc/sysconfig/network-scripts/$o > /etc/sysconfig/network-scripts/ifcfg-$c && sed -i -e "s@eth[0-9]@$c@" /etc/sysconfig/network-scripts/ifcfg-$c)
					# make sure the file exist, transfer config, overwriting post-install. Search for eth* and replace it with new name in ifcfg-* 
				else
					mac="";
				fi
			done
		done
	else
		echo "${YELLOW}Skipping network migration${NC}"
	fi
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
	echo "GRIDScaler 4.0 upgrade/reinstall."
	echo "This script is meant to run on each GRIDScaler server."
	echo "The current version of the script supports the standard GS installation, "
	echo "it does not back up configurations for applications not included with original GS installation."
	echo "Specify operation you want to use:"
	echo "-b for backup"
	echo "-c to clean up recovery archive files. Make sure everything's working before using this option"
	echo "-r <path-to-file> for restore"
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
			echo "Choose a product listed below then hit RETURN to continue:"
			PS3='Select which product to backup -> '
			select PRODUCT in "GRIDScaler" "EXAScaler" "Quit";
			do 
				case $PRODUCT in
					"GRIDScaler")
						echo -e "${GREEN}Backup option for GRIDScaler selected. Starting...${NC}"
						gs_backup
						echo -e ${NC}
						exit 0;
						;;
					"EXAScaler")
						echo -e "${GREEN}Backup option for GRIDScaler selected. Starting... (Under construction, will do nothing)${NC}"
						#es_backup will go here
						exit 0;
						;;
					"Quit")
						echo -e "${ORANGE}Exiting...${NC}"
						exit 0;
						;;
					*)
						echo -e "${RED}Invalid option or no option specified${NC}"
						exit 1;
						;;
				esac
			done
			echo -e ${NC}
			exit 0;
			;;
		h) 
			help; 
			echo -e ${NC}
			exit 0
			;;
		r)
			# Identify ES or GS archive
			echo -e "${GREEN}Restore option selected. Using $OPTARG"
			echo -e "Validating backup integrity..."
			echo -e ${NC}
			if [ ! -f $OPTARG ]; 
			then
				echo -e "${RED}File does not exist! Make sure you are using the right file.${NC}";
				exit 1;
			fi
			if ($(gunzip -c $OPTARG | tar t > /dev/null));
			then
				# Check for 'es' in filename
				if $(echo $OPTARG | grep -q esbackup)
				then
					echo -e "${GREEN}File validated! Detected EXAScaler backup.${NC}"
					echo "es_restore here"
				# Check for 'gs' or 'backup' in filename. 
				# 'backup' is included for backward compatibility 
				# with previous version of the script
				elif $(echo $OPTARG | grep -q 'gsbackup\|backup')
				then
					echo -e "${GREEN}File validated! Detected GRIDScaler backup.${NC}"
					gs_restore $OPTARG
				else
					echo -e "${RED}Cannot determine product. Make sure you are using the archive generated by the backup process. Consult with DDN Support when in doubt."
				fi
			else
				echo -e "${RED}Wrong file type or backup is corrupted! Make sure you picked the backup archive"
				echo -e ${NC}
				
			fi
			echo -e ${NC}
			exit 0;
			;;
		s)
			echo -e "${GREEN}SSH Key scan option selected.";
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
