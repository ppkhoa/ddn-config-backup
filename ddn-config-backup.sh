#! /bin/bash

# This script will backup network and Linux configuration in preparation for
# GRIDScaler 4.x upgrade/reinstall or EXAScaler 3.0 upgrade/reinstall.
# This script is meant to run on each GRIDScaler/EXAScaler server.
# The current version of the script supports the standard GS/ES installation, 
# it does not back up configurations for applications not included with original GS/ES installation.

# For support/feedback with the script, contact Khoa Pham (kpham@ddn.com).

# Changelogs has been moved to GitHub wiki: https://github.com/ppkhoa/ddn-config-backup/wiki


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
# Backup configurations
#
function net_backup() {
# network configuration
# $1 - backup target dir
# $2 - doc target dir
    local FNAME=net_backup
    if [ -z "$1" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local backup_dir=$1
		if [ ! -d $backup_dir ]; then 
			echo -e "`basename $0` error cannot find backup_dir $backup_dir"
			return 1
		fi
    fi

    if [ -z "$2" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
	else
		local doc_dir=$2
		if [ ! -d $doc_dir ]; then 
			echo -e "`basename $0` error cannot find doc_dir $doc_dir"
			return 1
		fi
    fi

    # Linux and network config
    echo -e "${YELLOW}Backing up network configurations...${NC}"
    cp -r --parents /etc/networks $backup_dir
    cp -r --parents /etc/resolv.conf  $backup_dir
    cp -r --parents /etc/ntp.conf  $backup_dir
    cp -r --parents /etc/iproute2/rt_tables  $backup_dir
    cp -r --parents /etc/sysconfig/network  $backup_dir
    cp -r --parents /etc/sysconfig/network-scripts/ifcfg-* $doc_dir
    cp -r --parents /etc/sysconfig/network-scripts/ifcfg-* $backup_dir
    [[ -e /etc/sysconfig/network-scripts/route-* ]] && (cp -r --parents /etc/sysconfig/network-scripts/route-* $backup_dir)

    [[ -e /etc/sysconfig/iptables ]] && (cp -r --parents /etc/sysconfig/iptables $backup_dir)

    ip link > $doc_dir/ip_link.out 2>&1
    ip addr > $doc_dir/ip_addr.out 2>&1
    ip route > $doc_dir/ip_route.out 2>&1

    #inifiniband
    ibv_devinfo > $doc_dir/ibv_devinfo.out 2>&1
    ibv_devices > $doc_dir/ibv_devices.out 2>&1
    sminfo > $doc_dir/sminfo.out 2>&1

    # Hosts file
    echo -e "${YELLOW}Backing up hosts file...${NC}"
    cp -r --parents /etc/hosts $backup_dir
    cp -r --parents /etc/hosts.* $backup_dir

    hostname --short > $doc_dir/hostname_s.out 
    hostname --fqdn > $doc_dir/hostname_f.out 
} # net_backup


function ssh_backup() {
# ssh keys & config
# $1 - backup target dir
# $2 - doc target dir
    local FNAME=ssh_backup
    if [ -z "$1" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local backup_dir=$1
		if [ ! -d $backup_dir ]; then 
			echo -e "`basename $0` error cannot find backup_dir $backup_dir"
			return 1
		fi
    fi

    if [ -z "$2" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local doc_dir=$2
		if [ ! -d $doc_dir ]; then 
			echo -e "`basename $0` error cannot find doc_dir $doc_dir"
			return 1
		fi
    fi

    # SSH Keys
    echo -e "${YELLOW}Backing up SSH key...${NC}"
    cp -r --parents /root/.ssh/* $backup_dir
    cp -r --parents /etc/ssh/* $backup_dir
} #ssh_backup


function ddn_backup() {
# ddn config
# $1 - backup target dir
# $2 - doc target dir
    local FNAME=ddn_backup
    if [ -z "$1" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local backup_dir=$1
		if [ ! -d $backup_dir ]; then 
			echo -e "`basename $0` error cannot find backup_dir $backup_dir"
			return 1
		fi
    fi

    if [ -z "$2" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local doc_dir=$2
		if [ ! -d $doc_dir ]; then 
			echo -e "`basename $0` error cannot find doc_dir $doc_dir"
			return 1
		fi
    fi

    # DDN config files
    echo -e "${YELLOW}Backing up DDN config...${NC}"
    # cp -r --parents /etc/ddn/*.conf $backup_dir # RHEL 7.4 compatibility issue
    cp -r --parents /opt/ddn/bin/tune_devices.sh $backup_dir
	mkdir /tmp/backup_dropbox
	echo -e "${ORANGE}A dropbox has been created at /tmp/backup_dropbox. Open a new SSH session and copy any files you want to back up here.${NC}" 
	echo -e "${ORANGE}All files and directories in this dropbox will be restored to /tmp/backup_dropbox after the reimage."
	echo -e "${ORANGE}If you do not have any file to backup or when you are done, press any key to continue...${NC}"
	read -n1 -r key
	cp -r --parents /tmp/backup_dropbox $backup_dir
 } #ddn_backup


function linux_backup() {
# misc linux config
# $1 - backup target dir
# $2 - doc target dir
    local FNAME=linux_backup
    if [ -z "$1" ]; then	
		echo -e "$FNAME backup target error input arguments"
		exit 1
    else
		local backup_dir=$1
		if [ ! -d $backup_dir ]; then 
			echo -e "`basename $0` error cannot find backup_dir $backup_dir"
			return 1
		fi
    fi

    if [ -z "$2" ]; then	
		echo -e "$FNAME doc target error input arguments"
		exit 1
    else
		local doc_dir=$2
		if [ ! -d $doc_dir ]; then 
			echo -e "`basename $0` error cannot find doc_dir $doc_dir"
			return 1
		fi
    fi

    # Generic Linux config
    echo -e "${YELLOW}Backing up Linux config...${NC}"
    [[ -e /etc/sysconfig/clock ]]&& (cp -r --parents /etc/sysconfig/clock $backup_dir )

    [[ -e /etc/sysctl.conf ]]&& (cp -r --parents /etc/sysctl.conf $backup_dir)
    [[ -d /etc/sysctl.d/ ]] && (cp -r --parents /etc/sysctl.d/ $backup_dir)
    #[[ -e /etc/modprobe.conf ]] && (cp -r --parents /etc/modprobe.conf $backup_dir) # RHEL 7.4 compatibility issue
    #cp -r --parents /etc/modprobe.d/ $backup_dir # RHEL 7.4 compatibility issue
    cp -r --parents /etc/sudoers $backup_dir
    cp -r --parents /etc/sudoers.d/ $backup_dir
    cp -r --parents /etc/logrotate.conf $backup_dir
    cp -r --parents /etc/logrotate.d/ $backup_dir

    cp -r --parents /etc/rc.d/rc.local $backup_dir
    cp -r --parents /etc/nsswitch.conf $backup_dir
	# Not recommended
    # cp -r --parents /etc/fstab $backup_dir  
    cp -r --parents /etc/exports $backup_dir  

    rpm -qa > $doc_dir/rpm_qa.out 2>&1
    chkconfig --list > $doc_dir/chkconfig_list.out 2>&1
} #linux_backup


function dev_backup() {
# block device config
# $1 - backup target dir
# $2 - doc target dir
    local FNAME=dev_backup
    if [ -z "$1" ]; then	
	echo -e "$FNAME backup target error input arguments"
	exit 1
    else
	local backup_dir=$1
	if [ ! -d $backup_dir ]; then 
	    echo -e "`basename $0` error cannot find backup_dir $backup_dir"
	    return 1
	fi
    fi

    if [ -z "$2" ]; then	
	echo -e "$FNAME doc target error input arguments"
	exit 1
    else
	local doc_dir=$2
	if [ ! -d $doc_dir ]; then 
	    echo -e "`basename $0` error cannot find doc_dir $doc_dir"
	    return 1
	fi
    fi
	
	# Moved to document only
    #cp -r --parents /etc/multipath.conf $backup_dir
    #cp -r --parents /etc/multipath.conf.ddn $backup_dir # duplicate original

    lsscsi --verbose --long > $doc_dir/lsscsi.out 2>&1
    lsblk --fs --all > $doc_dir/lsblk.out 2>&1
    ls -l /dev/mapper/ > $doc_dir/dm_devices.out 2>&1
} #dev_backup

###############################################################################
#
# GRIDScaler backup self-extracting package maker
#
function sfx_maker {
	dir=$1
	cat $dir/ddn-config-backup.sh $dir/$nodename-gsbackup-$start_time.gz > /$dir/$nodename-gsbackup-$start_time.ddnx
}

###############################################################################
#
# GRIDScaler backup section
#
function gs_backup {
	local FNAME=gs_backup
	dir=$(pwd)
	# Create folders for backup
	mkdir -vp $gsbackup_dir $doc_only

	ssh_backup $gsbackup_dir $doc_only
	net_backup $gsbackup_dir $doc_only
	ddn_backup $gsbackup_dir $doc_only
	linux_backup $gsbackup_dir $doc_only
	dev_backup $gsbackup_dir $doc_only
	document $gsbackup_dir $doc_only

	# GPFS config
	echo -e "${YELLOW}Backing up GPFS configuration...${NC}"
	rsync -av /var/mmfs $doc_only/var --exclude afm
	cp /var/mmfs/gen/mmsdrfs /var/mmfs/gen/mmsdrfs.old
	cp -r --parents /var/mmfs/gen/mmsdrfs.old $backup_dir
	rm -rf /var/mmfs/gen/mmsdrfs.old
	# rsync -av /var/mmfs $gsbackup_dir/var --exclude afm # No longer backup all GPFS configuration

	# Once finished, pack all files into one archive then remove the folder, 
	# keeping the archive with same folder structure
	# Tar the folder with -v for debugging purposes, output can be hidden in later version.
	echo -e "${YELLOW}Finished! Packing up...${NC}"

	# Pack up data collected, to be restored later.
	cd $gsbackup_dir && tar -zcvf $nodename-gsbackup-$start_time.gz * && mv -v $nodename-gsbackup-$start_time.gz $dir && cd /tmp && rm -rf $gsbackup_dir

	# Pack up document only data, will not be used for restoring.
	printf "${YELLOW}Packing up document-only configuration...\n\n${NC}"
	cd $doc_only && tar -zcvf $nodename-doconly-$start_time.gz * && mv -v $nodename-doconly-$start_time.gz $dir && cd /tmp && rm -rf $doc_only
	# test archives
    echo -e "${YELLOW}Cleaning up and check for corruption...${NC}"
    tar -tzf /$dir/$nodename-gsbackup-$start_time.gz 
    tar -tzf /$dir/$nodename-doconly-$start_time.gz
	printf "\n\n"
	echo "Choose an option listed below then hit RETURN to continue:"
	OPTION2='Select option -> '
	select OPTION in "Create backup archive" "Create self-extracting archive" ;
	do 
		case $OPTION in
			"Create backup archive")
				echo -e "${GREEN}Backup archive option for GRIDScaler selected...${NC}"
				echo -e "${GREEN}All done! ${NC}Backup can be found at ${YELLOW}$dir/$nodename-gsbackup-$start_time.gz${NC}"
				echo -e "${ORANGE}IMPORTANT! Run \"mmsdrrestore -p <working NSD server>\" to restore GPFS config${NC}"
				echo -e "${NC}For reference only data (not used for restore), it can be found at ${YELLOW}$dir/$nodename-doconly-$start_time.gz${NC}"
				printf "\nTo restore after the upgrade/reinstall, use ${YELLOW}\"bash ddn-config-backup.sh -r <path-to-file>/$nodename-gsbackup-$start_time.gz\"\n${NC}"
				echo -e "${ORANGE}Remember to copy both files listed above to a different node before performing GRIDScaler upgrade/reinstall.${NC}"
				echo -e "${ORANGE}Do not change the filename! The restore script depends on it.${NC}"
				echo -e ${NC}
				exit 0;
				;;
			"Create self-extracting archive")
				echo -e "${GREEN}Creating self-extracting archive...${NC}"
				echo -e ${NC}
				sfx_maker $dir
				rm -f /$dir/$nodename-gsbackup-$start_time.gz
				echo -e "${GREEN}All done! ${NC}Backup can be found at ${YELLOW}$dir/$nodename-gsbackup-$start_time.ddnx${NC}"
				echo -e "${ORANGE}IMPORTANT! Run \"mmsdrrestore -p <working NSD server>\" to restore GPFS config${NC}"
				echo -e "${NC}For reference only data (not used for restore), it can be found at ${YELLOW}$dir/$nodename-doconly-$start_time.gz${NC}"
				printf "\nTo restore after the upgrade/reinstall, use ${YELLOW}\"bash <path-to-file>/$nodename-gsbackup-$start_time.ddnx\"\n${NC}"
				echo -e "${ORANGE}Remember to copy both files listed above to a different node before performing GRIDScaler upgrade/reinstall.${NC}"
				echo -e "${ORANGE}Do not change the filename! The restore script depends on it.${NC}"
				exit 0;
				;;
			*)
				echo -e "${RED}Invalid option or no option specified. Default to option 1...${NC}"
				echo -e "${GREEN}Backup archive option for GRIDScaler selected...${NC}"
				echo -e "${GREEN}All done! ${NC}Backup can be found at ${YELLOW}$dir/$nodename-gsbackup-$start_time.gz${NC}"
				echo -e "${ORANGE}IMPORTANT! Run \"mmsdrrestore -p <working NSD server>\" to restore GPFS config${NC}"
				echo -e "${NC}For reference only data (not used for restore), it can be found at ${YELLOW}$dir/$nodename-doconly-$start_time.gz${NC}"
				printf "\nTo restore after the upgrade/reinstall, use ${YELLOW}\"bash ddn-config-backup.sh -r <path-to-file>/$nodename-gsbackup-$start_time.gz\"\n${NC}"
				echo -e "${ORANGE}Remember to copy both files listed above to a different node before performing GRIDScaler upgrade/reinstall.${NC}"
				echo -e "${ORANGE}Do not change the filename! The restore script depends on it.${NC}"
				echo -e ${NC}
				exit 0;
				;;
		esac
	done
}

###############################################################################
#
# EXAScaler backup section
#
function es_backup {
# backup EXAScaler 2.x systems
    local FNAME=es_backup
    dir=$(pwd)
    # Create folders for backup
    mkdir -vp $esbackup_dir $doc_only

    ssh_backup $esbackup_dir $doc_only
    net_backup $esbackup_dir $doc_only
    ddn_backup $esbackup_dir $doc_only
    linux_backup $esbackup_dir $doc_only
    dev_backup $esbackup_dir $doc_only
	document $esbackup_dir $doc_only

    echo -e "${YELLOW}Backing up Lustre /proc configuration...${NC}"

    # sys lnet config
    find /proc/sys/lnet -type f -print -exec cat {} \; > $doc_dir/lnet_sysproc.out
    # sys lustre config
    find /proc/sys/lustre -type f -print -exec cat {} \;> $doc_dir/lustre_sysproc.out
    # fs lustre config
    find /proc/fs/lustre/ -type f -maxdepth 1 -print -exec cat {} \; > $doc_dir/lustre_fsproc.out
    for n in /proc/fs/lustre/* ; do 
	if [ -d $n ]; then 
	    find ${n} -type f -print -exec cat {} \; > $doc_dir/`basename $n`_lustreproc.out 2>&1
	fi
    done

    # Once finished, pack all files into one archive then remove the folder, 
    # keeping the archive with same folder structure
    # Tar the folder with -v for debugging purposes, output can be hidden in later version.
    echo -e "${YELLOW}Finished! Packing up...${NC}"

    # Pack up data collected, to be restored later.
    cd $esbackup_dir && tar -zcvf $nodename-esbackup-$start_time.gz * && mv -v $nodename-esbackup-$start_time.gz $dir 

    # Pack up document only data, will not be used for restoring.
    printf "${YELLOW}Packing up document-only configuration...\n\n${NC}"
    cd $doc_only && tar -zcvf $nodename-doconly-$start_time.gz * && mv -v $nodename-doconly-$start_time.gz $dir 

    # test archives
    echo -e "${YELLOW}Cleaning up...${NC}"
    tar -tzf /$dir/$nodename-esbackup-$start_time.gz && cd /tmp && rm -rf $esbackup_dir
    tar -tzf /$dir/$nodename-doconly-$start_time.gz &&  cd /tmp && rm -rf $doc_only

    echo -e "${GREEN}All done! ${NC}Backup can be found at ${YELLOW}$dir/$nodename-esbackup-$start_time.gz${NC}"
    echo -e "${NC}For reference only data (not used for restore), it can be found at ${YELLOW}$dir/$nodename-doconly-$start_time.gz${NC}"

    echo -e "${ORANGE}Remember to copy both files listed above to a different node before performing EXAScaler upgrade/reinstall.${NC}"

} #es_backup

###############################################################################
#
# Document only section
#

function document {
# Generic document-only
# $1 - backup target dir
# $2 - doc target dir
    local FNAME=document
    if [ -z "$1" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local backup_dir=$1
		if [ ! -d $backup_dir ]; then 
			echo -e "`basename $0` error cannot find backup_dir $backup_dir"
			return 1
		fi
    fi

    if [ -z "$2" ]; then	
		echo -e "$FNAME error input arguments"
		exit 1
    else
		local doc_dir=$2
		if [ ! -d $doc_dir ]; then 
			echo -e "`basename $0` error cannot find doc_dir $doc_dir"
			return 1
		fi
    fi

    # Generic Linux config
    echo -e "${YELLOW}Backing up Linux config...${NC}"
    [[ -e /etc/sysconfig/clock ]]&& (cp -r --parents /etc/sysconfig/clock $backup_dir )
	echo -e "${YELLOW}Documenting interface configuration...${NC}"
	cp -r --parents /etc/sysconfig/network-scripts/ifcfg-* $doc_dir 

	# Hostname, in different format
	echo -e "${YELLOW}Documenting hostname...${NC}"
	hostname > $doc_dir/hostname.out 
	lsscsi > $doc_dir/lsscsi.out 

	# Multipath
	echo -e "${YELLOW}Documenting multipath configuration files...${NC}"
	cp -r --parents /etc/multipath.conf $doc_dir 

	# DDN stuff
	echo -e "${YELLOW}Documenting DDN config...${NC}"
	cp -r --parents /etc/ddn/*.conf $doc_dir
	cp -r --parents /opt/ddn/bin/tune_devices.sh $doc_dir 

	# Routing tables
	echo -e "${YELLOW}Documenting routing tables...${NC}"
	ip route show table all > $doc_only/ip_route_show_table_all.out
	ip rule show > $doc_only/ip_rule_show.out && ip route > $doc_dir/ip_route.out 
	ip a > $doc_dir/ip_a.out

	# Generic Linux config
	echo -e "${YELLOW}Documenting Linux config...${NC}"
	# cp -r --parents /etc/fstab $doc_dir 
	cp -r --parents /etc/sysctl.conf $doc_dir 
	
	cp -r /etc/sysconfig  $doc_dir 
}

###############################################################################
#
# EXAScaler restore section
#
function es_restore {
# TODO:
# set hostname (hostnamectl)
# restore ssh keys
# restore resolv.conf & ntp.conf
# restore /etc/hosts.* file
# restore /etc/sysconfig/clock (custom timezone)
# restore /etc/multipath.conf
# review custom sysctl & modprobe
# review network interface names 
#   review ifcfg-* HWADDR
#   NB: don't restore /etc/sysconfig/network
# review custom network routing and/or iptables
# review custom lustre proc config
	echo "Not implemented yet"
	# es_restore function goes here
}


###############################################################################
#
# Restore GPFS configuration
#

function gs_restore {
	local restore_path=$1
	local restore_file=$(basename $1)
	if $(echo $restore_file | if grep -q gs; then echo true; else echo false; fi)
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
	rm -f $restore_path
	
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
	echo -e "${ORANGE}IMPORTANT! After reboot run \"mmsdrrestore -p <working NSD server>\" to restore GPFS config\n${NC}"
	printf "\nIf you received any mv error, check the source "
	printf "to confirm it exist and make sure you only run the restore once.\n\n"
}

###############################################################################
#
# Self-extract GS restore
#
function sfx_gs_restore {
	local dir=$(pwd)
	local filename=`basename "$0" .ddnx`
	echo -e "${ORANGE}This is a self-extracting backup. Do you want to continue? (Choosing yes will start the restore process) [y/N] ${NC}"
	read -r response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
	then
		# Get line number where the backup archive starts
		tail -n+$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $filename.ddnx) $filename.ddnx > $filename.gz
	
		# Call restore function
		gs_restore $dir/$filename.gz
	else
		echo -e "${YELLOW}Exiting...${NC}"
		exit 0;
	fi
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
		echo -e "${YELLOW}Skipping network migration${NC}"
	fi
}

###############################################################################
#
# Back out option for failed restore. Revert back to new install/pre-upgrade 
# state (only applicable to config files)
#
function revert {
	printf "${YELLOW}Reverting changes...\n${NC}"
	# SSH keys
	[[ -e /root/.ssh.ddnbak ]]&& (cp -r --parents /root/.ssh.ddnbak /root/.ssh)
	[[ -e /etc/ssh.ddnbak ]]&& (cp -r --parents /etc/ssh.ddnbak /etc/ssh)
	
	# GPFS config
	[[ -e /var/mmfs.ddnbak ]]&& (cp -r --parents /var/mmfs.ddnbak /var/mmfs)

	
	# Linux and network config
	[[ -e /etc/networks.ddnbak ]]&& (cp -r --parents /etc/networks.ddnbak /etc/networks)
	[[ -e /etc/resolv.conf.ddnbak ]]&& (cp -r --parents /etc/resolv.conf.ddnbak /etc/resolv.conf)
	[[ -e /etc/ntp.conf.ddnbak ]]&& (cp -r --parents /etc/ntp.conf.ddnbak /etc/ntp.conf)
	[[ -e /etc/iproute2/rt_tables.ddnbak ]]&& (cp -r --parents /etc/iproute2/rt_tables.ddnbak /etc/iproute2/rt_tables)
	cp /etc/iproute2/rt_tables  /etc/iproute2/rt_tables.ddnbak

	# Hosts file
	[[ -e /etc/hosts.ddnbak ]]&& (cp -r --parents /etc/hosts.ddnbak /etc/hosts)

	# DDN config files
	[[ -e /etc/ddn.ddnbak ]]&& (cp -r --parents /etc/ddn.ddnbak /etc/ddn)


	# Generic Linux config
	[[ -e /etc/sysconfig/clock.ddnbak ]]&& (cp -r --parents /etc/sysconfig/clock.ddnbak /etc/sysconfig/clock)
	[[ -e /etc/sysconfig/network.ddnbak ]]&& (cp -r --parents /etc/sysconfig/network.ddnbak /etc/sysconfig/network)
	[[ -e /etc/sysconfig/network-scripts.ddnbak ]]&& (cp -r --parents /etc/sysconfig/network-scripts.ddnbak /etc/sysconfig/network-scripts)
	printf "${GREEN}Done!\n${NC}"
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
	[[ -e /root/.ssh/known_hosts ]] && (mv /root/.ssh/known_hosts /root/.ssh/known_hosts.bak)
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
	echo "-o to restore original files after a failed restore attempt"
	echo "-c to clean up recovery archive files. Make sure everything's working before using this option"
	echo "-r <path-to-file> for restore, if separate archive option was selected during backup"
	echo "-s to scan all hosts from /etc/hosts for SSH host keys"
}

###############################################################################
# Main ()
#
current_file=`basename "$0"`
if [ "$(tail -n1 $current_file)" == "__ARCHIVE_BELOW__" ]
then
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
							echo -e "${ORANGE}Please note that if you have any data management policy for GPFS, it will not be backed up unless it is stored in the dropbox.${NC}"
							echo -e "${ORANGE}Backup dropbox will be created later in the process, a prompt will let you know when to backup your extra files and directories${NC}"
							echo -e "${GREEN}Please type 'yes' to acknowledge this notice: ${NC}"
							read -r response
							if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
							then
								gs_backup
							else
								echo -e ${NC}
							fi
							exit 0;
							;;
						"EXAScaler")
							echo -e "${GREEN}Backup option for GRIDScaler selected. Starting... (Under construction, will do nothing)${NC}"
							es_backup
							echo -e ${NC}
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
			o)
				echo -e "${GREEN}Revert action selected.";
				revert
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
else 
	echo -e "${GREEN}Self-extract detected.${NC}"
	sfx_gs_restore
fi
exit 0

__ARCHIVE_BELOW__
