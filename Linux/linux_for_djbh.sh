#!/bin/bash
#============================================================================
# File:         linux_for_djbh.sh      
# Author:       Li
# Mail:			sjm217@qq.com 
# Date:         2019.3
# Version       v2.0
#
# Description:
#		等级保护安全基线配置检查脚本，兼容Red-Hat CentOS，Oracle,项目地址：https://github.com/lis912/Evaluation_tools 
# Usage:
# 		./linux_for_djbh.sh &> filename.sh
#============================================================================

# 全局变量
DISTRO=
DISTRO_NUMBER=

ORACLE=
ORACLE_NUMBER=

MYSQL=
MYSQL_NUMBER=

DBS=

output_file_banner()
{
	echo "# ============================================================================"
	echo -e "# Describe: \t\t This file about security baseline check output" 			
	echo -e "# Running time:\t\t "`date +'%Y-%m-%d %H:%S'`
	echo "# ============================================================================"
	echo
}



#----------------------------------------------------------------------------
# Gets the system version info
#----------------------------------------------------------------------------
get_system_version()
{
	if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
		if grep -Eq "7." /etc/*-release; then
			DISTRO_NUMBER='7'
		elif grep -Eq "6." /etc/*-release; then
			DISTRO_NUMBER='6'
		elif grep -Eq "5." /etc/*-release; then
			DISTRO_NUMBER='5'
		elif grep -Eq "4." /etc/*-release; then
			DISTRO_NUMBER='4'
		else
			DISTRO_NUMBER='unknow'
		fi	
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RedHat'
		if grep -Eq "7." /etc/*-release; then
			DISTRO_NUMBER='7'
		elif grep -Eq "6." /etc/*-release; then
			DISTRO_NUMBER='6'
		elif grep -Eq "5." /etc/*-release; then
			DISTRO_NUMBER='5'
		elif grep -Eq "4." /etc/*-release; then
			DISTRO_NUMBER='4'
		else
			DISTRO_NUMBER='unknow'
		fi	
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
    else
        DISTRO='unknow'
    fi
}

#----------------------------------------------------------------------------
# Gets the database version info
#----------------------------------------------------------------------------
get_database_version()
{
	# 检查进程中是否运行Oracle监听进程，然后进一步获取版本号
	if [[ -n `netstat -pantu | grep tnslsnr` ]]; then
		ORACLE="Oracle"
		banner=`su - oracle << EOF 
sqlplus / as sysdba 
exit 
EOF`

		[[ $banner =~ "11g" ]] && ORACLE_NUMBER="11g"
	fi

	DBS="${ORACLE} ${ORACLE_NUMBER}		${MYSQL} ${MYSQL_NUMBER}"
}


#----------------------------------------------------------------------------
# Red-Hat or CentOS check
#----------------------------------------------------------------------------
redhat_or_centos_ceping()
{
	echo "#----------------------------------------------------------------------------"
	echo "# Information Collection"
	echo "#----------------------------------------------------------------------------"
	echo -e "Hardware platform: \t"`grep 'DMI' /var/log/dmesg | awk -F'DMI:' '{print $2}'` 
	echo -e "CPU model: \t"`cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq`
	echo -e "CPUS: \t\t\t\t" `cat /proc/cpuinfo | grep processor | wc -l | awk '{print $1}'`
	echo -e "CPU Type: \t\t\t" `cat /proc/cpuinfo | grep vendor_id | tail -n 1 | awk '{print $3}'`
	Disk=$(fdisk -l |grep 'Disk' |awk -F , '{print $1}' | sed 's/Disk identifier.*//g' | sed '/^$/d')
	echo -e "Disks info:\t\t\t ${Disk}\n${Line}"
	echo -e "System Version: \t" `more /etc/redhat-release`
	check_ip_format=`ifconfig | grep "inet addr"`
	if [ ! -n "$check_ip_format" ]; then
		# 7.x
		Ipddr=`ifconfig | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v 127 | awk '{print $2}'`
	else
		# 6.x
		Ipddr=`ifconfig | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v 127 | awk '{print $2}' | awk -F: '{print $2}'`
	fi
	echo -e "Hostname: \t\t\t" `hostname -s`
	echo -e "IP Address: \t\t ${Ipddr}" 
	echo -e "Middleware or webserver： "
	echo -e "DBS：\t\t ${DBS}"

	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Checking Empty password users"
	echo "#----------------------------------------------------------------------------"
	
	flag=
	null_password=`awk -F: 'length($2)==0 {print $1}' /etc/shadow`
	
	if [ -n "$null_password" ]; then
		flag='y'
		echo $null_password
	fi
	
	null_password=`awk -F: 'length($2)==0 {print $1}' /etc/passwd`
	if [ -n "$null_password" ]; then
		flag='y'
		echo $null_password
	fi
	
	null_password=`awk -F: '$2=="!" {print $1}' /etc/shadow`
	if [ -n "$null_password" ]; then
		flag='y'
		echo $null_password
	fi
	
	null_password=`awk -F: '$2!="x" {print $1}' /etc/passwd`
	if [ -n "$null_password" ]; then
		flag='y'
		echo $null_password
	fi
	
	[[ ! -n "$flag" ]] && echo "[Y] This system no empty password users!"
	
	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Checking UID=0 users"
	echo "#----------------------------------------------------------------------------"
	awk -F: '($3==0)' /etc/passwd
	echo
	
	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Password time out users"
	echo "#----------------------------------------------------------------------------"
	for timeout_usename in `awk -F: '$2=="!!" {print $1}' /etc/shadow`; do
		timeout_usenamelist+="$timeout_usename,"
	done
	echo ${timeout_usenamelist%?}
	echo
	
	echo
	echo "#----------------------------------------------------------------------------"
	echo "# May be No need users"
	echo "#----------------------------------------------------------------------------"
	for no_need_usename in `cat /etc/shadow | grep -E 'uucp|nuucp|lp|adm|sync|halt|news|operator|gopher' | awk -F: '{print $1}'`; do
		no_need_usenamelist+="$no_need_usename,"
	done
	echo ${no_need_usenamelist%?}
	echo


	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Policy of password Strength"
	echo "#----------------------------------------------------------------------------"
	cat /etc/login.defs | grep PASS | grep -v ^#
	echo
	
	case $DISTRO_NUMBER in
        7)
			passwordStrength=`cat /etc/pam.d/system-auth | grep -E 'pam_pwquality.so'`
			if [ ! -n "$passwordStrength" ]; then
				echo  "[X] After check '/etc/pam.d/system-auth', no pam_pwquality.so config"
			else
				echo $passwordStrength
			fi;;        		
        *)    
			passwordStrength=`cat /etc/pam.d/system-auth | grep -E 'pam_cracklib.so'`
			if [ ! -n "$passwordStrength" ]; then
				echo  "[X] After check '/etc/pam.d/system-auth', no pam_cracklib.so config"
			else
				echo $passwordStrength
			fi;;  
    esac
	echo

	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Policy of login failure"
	echo "#----------------------------------------------------------------------------"
	login_failure=`more /etc/pam.d/system-auth | grep tally`	
	if [ -n "$login_failure" ]; then
		echo $login_failure
	else
		echo  "[X] Warning: This system no login failure policy!"
	fi
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# Policy of ssh login failure"
	echo "#----------------------------------------------------------------------------"
	ssh_login_failure=`cat /etc/ssh/sshd_config | grep -v ^# | grep MaxAuthTries`
	if [ ! -n "$ssh_login_failure" ]; then
		echo  "[X] Warning: Remote management of ssh not set MaxAuthTries(3~5)! "
	else
		echo -e "ssh already set :  ${ssh_login_failure}." 
	fi
	echo
	
	
	
	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Login timeout lock, ('suggest config parameter: TMOUT >= 600s')"
	echo "#----------------------------------------------------------------------------"
	TMOUT=`cat /etc/profile | grep -n "TMOUT"`
	if [ -n "$TMOUT" ]; then
		echo $TMOUT	
	else
		echo  "[X] Warning: This system no set TMOUT!"
	fi
	echo

	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Checking some files access permission"
	echo "#----------------------------------------------------------------------------"
	ls -l /etc/shadow
	ls -l /etc/passwd
	ls -l /etc/group
	ls -l /etc/gshadow 
	ls -l /etc/profile
	ls -l /etc/crontab
	ls -l /etc/securetty 
	ls -l /etc/ssh/ssh_config
	ls -l /etc/ssh/sshd_config
	echo

	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Checking telnet and ftp status"
	echo "#----------------------------------------------------------------------------"
	telnet_or_ftp_status=`netstat -an | grep -E 'telnet | ftp | smtp'`
	if [ -n "$telnet_or_ftp_status" ]; then
		echo $telnet_or_ftp_status
	else	
		echo "[Y] This system no open 'telnet, ftp, smtp' server!"
	fi
	echo

	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Checking MAC(Mandatory access control) status"
	echo "#----------------------------------------------------------------------------"
	cat /etc/selinux/config | grep -v ^# | grep "SELINUX="
	echo

	echo
	echo "#----------------------------------------------------------------------------"
	echo "# Syslog and audit status"
	echo "#----------------------------------------------------------------------------"
	case $DISTRO_NUMBER in
        7)
			systemctl list-unit-files --type=service | grep "rsyslog"
			systemctl list-unit-files --type=service | grep "auditd";;      		
        *)    
			service --status-all | grep rsyslogd
			service auditd status;;        		
    esac
	echo
	
	
	echo
	echo "audit rules:" `auditctl -l`
	echo
	
	echo
	echo "#----------------------------------------------------------------------------"
	echo "# To see the first 10 rows of ‘/var/log/secure’"
	echo "#----------------------------------------------------------------------------"
	logfile=`ls /var/log/ | grep -E 'secure-.*'| tail -n 1`
	cat /var/log/${logfile} | tail -n 10
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# Files permission for about syslog and audit"
	echo "#----------------------------------------------------------------------------"
	ls -l /var/log/messages
	ls -l /var/log/secure
	ls -l /var/log/audit/audit.log
	ls -l /etc/rsyslog.conf
	ls -l /etc/syslog.conf
	ls -l /etc/audit/auditd.conf
	echo

	echo "#----------------------------------------------------------------------------"
	echo "# Configuration parameter of audit record"
	echo "#----------------------------------------------------------------------------"
	cat /etc/audit/auditd.conf | grep max_log_file | grep  -v ^#
	cat /etc/audit/auditd.conf | grep num_logs | grep  -v ^#
	#Max_log_file=5(日志文件大小)
	#Max_log_file_action=ROTATE(循环日志文件)
	#num_logs=4(旧文件数量)
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# Show all running service"
	echo "#----------------------------------------------------------------------------"
	case $DISTRO_NUMBER in
        7)
			systemctl list-unit-files --type=service | grep enabled;;      		
        *)    
			service --status-all | grep running;;        		
    esac
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# System patch info"
	echo "#----------------------------------------------------------------------------"
	rpm -qa --last | grep patch
	echo

	echo "#----------------------------------------------------------------------------"
	echo "# PermitRootLogin parameter status of ssh"
	echo "#----------------------------------------------------------------------------"
	cat /etc/ssh/sshd_config | grep Root
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# IP address permit in hosts.allow and hosts.deny"
	echo "#----------------------------------------------------------------------------"
	echo "[more /etc/hosts.allow:]"
	cat /etc/hosts.allow | grep -v ^#
	echo "[more /etc/hosts.deny :]"
	cat /etc/hosts.deny | grep -v ^#
	echo

	echo "#----------------------------------------------------------------------------"
	echo "# Check /etc/securetty about tty login number"
	echo "#----------------------------------------------------------------------------"
	for tty in `cat /etc/securetty `; do
		ttylist+="$tty,"
	done
	echo ${ttylist%?}
	echo

	echo "#----------------------------------------------------------------------------"
	echo "# Checking iptables status"
	echo "#----------------------------------------------------------------------------"
	iptables -L -n
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# System resource limit for single user"
	echo "#----------------------------------------------------------------------------"
	echo "<domain> <type> <item> <value>"
	cat /etc/security/limits.conf | grep -v ^# 
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# System resource used status"
	echo "#----------------------------------------------------------------------------"
	# 磁盘使用情况
	echo "[disk info:]"
	df -h
	echo
	
	# 内存使用情况
	echo "[Memory info:]"
	free -m
	echo
	
	# 内存使用率
	echo "mem_used_rate = "  `free -m | awk '{if(NR==2){print int($3*100/$2),"%"}}'`
	# CPU使用率
	cpu_used=`top -b -n 1 | head -n 4 | grep "^Cpu(s)" | awk '{print $2}' | cut -d 'u' -f 1`
	echo "cpu_used_rate = " $cpu_used
	echo
	
	echo "#----------------------------------------------------------------------------"
	echo "# MISC"
	echo "#----------------------------------------------------------------------------"
	echo "#System lastlog info:"
	lastlog
	echo
	echo "#crontab info:"
	crontab -l
	echo
	echo "#Process and port state:"
	netstat -pantu
	echo
}


#----------------------------------------------------------------------------
# Oracle database checking(compatible 10g 11g 12c)
#----------------------------------------------------------------------------
oracle_ceping()
{
	echo "#----------------------------------------------------------------------------"
	echo "# Oracle checking"
	echo "#----------------------------------------------------------------------------"
	
	# sql语句路径
	sqlFile=/tmp/tmp_oracle.sql

	# 写入sql语句
	echo "set echo off feedb off timi off pau off trimsp on head on long 2000000 longchunksize 2000000" > ${sqlFile}
	echo "set linesize 150" >> ${sqlFile}
	echo "set pagesize 80" >> ${sqlFile}
	echo "col username format a22" >> ${sqlFile}
	echo "col account_status format a20" >> ${sqlFile}
	echo "col password format a20" >> ${sqlFile}
	echo "col CREATED format a20" >> ${sqlFile}
	echo "col USER_ID, format a10" >> ${sqlFile}
	echo "col profile format a20" >> ${sqlFile}
	echo "col resource_name format a35" >> ${sqlFile}
	echo "col limit format a10" >> ${sqlFile}
	echo "col TYPE format a15" >> ${sqlFile}
	echo "col VALUE format a20" >> ${sqlFile}

	echo "col grantee format a25" >> ${sqlFile}
	echo "col owner format a10" >> ${sqlFile}
	echo "col table_name format a10" >> ${sqlFile}
	echo "col grantor format a10" >> ${sqlFile}
	echo "col privilege format a10" >> ${sqlFile}

	echo "col AUDIT_OPTION format a30" >> ${sqlFile}
	echo "col SUCCESS format a20" >> ${sqlFile}
	echo "col FAILURE format a20" >> ${sqlFile}
	echo "col any_path format a100" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Oracle version info" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select * from v\$version;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # All database instances" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select name from v\$database;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Checking all user status" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select username, CREATED, USER_ID, account_status, profile from dba_users;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Policie Checking of password and attempt login failed" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select profile, resource_name, limit from dba_profiles where resource_type='PASSWORD';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Show all users about granted_role='DBA'" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select grantee from dba_role_privs where granted_role='DBA';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Default users grantee roles about grantee='PUBLIC'" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select granted_role from dba_role_privs where grantee='PUBLIC';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Checking access of data dictionary must boolean=FALSE" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "show parameter O7_DICTIONARY_ACCESSIBILITY;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Audit state" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "show parameter audit;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Important security events covered by audit" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select AUDIT_OPTION, SUCCESS, FAILURE from dba_stmt_audit_opts;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Protecting audit records status" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select grantee, owner, table_name, grantor, privilege from dba_tab_privs where table_name='AUD$';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Protecting audit records status" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select grantee, owner, table_name, grantor, privilege from dba_tab_privs where table_name='AUD$';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Checking login 'IDLE_TIME' value" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select resource_name, limit from dba_profiles where profile='DEFAULT' and resource_type='KERNEL' and resource_name='IDLE_TIME';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Checking single user resource limit status" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select resource_name, limit from dba_profiles where profile='DEFAULT' and resource_type='SESSIONS_PER_USERS';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Checking cpu time limit for a single session" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select resource_name, limit from dba_profiles where profile='DEFAULT' and resource_type='CPU_PER_SESSION';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Show maximum number of connections" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "show parameter processes;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Default account password (11g)" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select * from dba_users_with_defpwd;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Access control function" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select any_path from resource_view where any_path like '/sys/acls/%.xml';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # Remote_os_authent" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select value from v\$parameter where name='remote_os_authent';" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "PROMPT # 'Oracle Label Security' install status" >> ${sqlFile}
	echo "PROMPT #============================================================================#" >> ${sqlFile}
	echo "select username, account_status, profile from dba_users where username='LBACSYS';" >> ${sqlFile}
	echo "select object_type,count(*) from dba_objects where OWNER='LBACSYS' group by object_type;" >> ${sqlFile}
	echo "PROMPT" >> ${sqlFile}

	echo "exit" >> ${sqlFile}

	# 切换oracle账户执行后返回root
	su - oracle << EOF
sqlplus / as sysdba @ ${sqlFile}
exit
EOF
	# 清除临时sql文件
	rm $sqlFile -f
	echo
	echo
}

main_ceping()
{	
	output_file_banner
	get_system_version
	get_database_version	
	
	if [ "CentOS"==${DISTRO} ] || [ "RedHat"==${DISTRO} ]; then
		redhat_or_centos_ceping
	fi
		
	if [ "Oracle"==${ORACLE} ]; then
		oracle_ceping
	fi
		
}

main_ceping