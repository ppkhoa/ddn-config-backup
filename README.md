# ddn-config-backup
A simple script to backup/restore configuration, in case a GRIDScaler/EXAScaler node needs to be reinstalled/reimaged

## **About**
This script will backup network and Linux configuration in preparation for GRIDSCaler 4.x/EXAScaler 3.x upgrade/reinstall. This script is meant to run on each GRIDSCaler/EXAScaler server. The current version of the script supports the standard GS/ES installation, it does not back up configurations for applications not included with original GS/ES installation.

The script can also beuse to migrate configuration from CentOS/RHEL 6.x to CentOS/RHEL 7.x

## **Usage**
```
bash ddn-config-backup [-bchs] [-r filename]

-b for backup
-c to clean up recovery archive files. Make sure everything's working before using this option
-r <filename> for restore, must be in the same non-root (i.e. /root is okay, / is not) folder as the script
-s to scan all hosts from /etc/hosts for SSH host keys

```
## **Under the Hood**
This script used the following: ssh-keyscan, tar and awk. Make sure you have those available before running the script.

## **Support**
If you discovered a bug, let me know through email at `kpham` at `ddn` dot `com` or my personal email `ppkhoa` at `gmail` dot `com`.

If you came upon this script, while using GRIDScaler and looking to upgrade, contact DDN Support (`support` at `ddn` dot `com`)

## **Disclaimer**
DataDirect Networks, DDN, EXAScaler and GRIDScaler are trademarks of DataDirect Networks
