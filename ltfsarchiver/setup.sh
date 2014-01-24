#!/bin/bash
function echo_header()
{
clear
echo -e "\t/---------------------------------------------------\\" | tee -a $outfile
echo -e "\t|    LTFSArchiver quick-installer                   |" | tee -a $outfile
echo -e "\t >-------------------------------------------------<" | tee -a $outfile
}
#	input loop for LTFSArchiver base directory
function get_ltfsarchiverhome()
{
unset USER_HOME
GOOD_HOME=false
while ! $GOOD_HOME; do
	GOOD_HOME=true
	echo -e "\n\tPlease supply the base installation directory [$DEFAULT_HOME]" | tee -a $outfile
	echo -e "\t\ta directory named \"ltfsarchiver\" will be created in it" | tee -a $outfile
	read USER_HOME
	[ -z ${USER_HOME} ] && USER_HOME=$DEFAULT_HOME
	if [ $USER_HOME == $SCRIPTDIR ]; then
		echo -e "Base install directory can't be the one you're installig from" | tee -a $outfile
		GOOD_HOME=false
	else
		if [ -d $USER_HOME/ltfsarchiver ]; then
			echo -e "\t$USER_HOME/ltfsarchiver directory already exists..." | tee -a $outfile
			GOOD_HOME=false
		else
			if ! [[ $USER_HOME =~ ^/ ]]; then
				echo -e "\tInstall directory must be supplied in absloute format: /...." | tee -a $outfile
				GOOD_HOME=false
			else
				if ! [ -d $USER_HOME ]; then
					echo -e "\tBasedirectory $USER_HOME must exist" | tee -a $outfile
					GOOD_HOME=false
				else
					if [ -f $USER_HOME ]; then
						echo -e "\t$USER_HOME is an existing file..." | tee -a $outfile
						GOOD_HOME=false
					fi
				fi
			fi
		fi
	fi
done
}
#	input loop for LTFSArchiver user
function get_ltfsarchiveruser()
{
unset USER_USER
GOOD_USER=false
while ! $GOOD_USER; do
	GOOD_USER=true
	echo -e "\n\tPlease supply the LTFSArchiver user name [$DEFAULT_USER]" | tee -a $outfile
	read USER_USER
	[ -z ${USER_USER} ] && USER_USER=$DEFAULT_USER
	if [[ "$USER_USER" =~  [[:alnum:][:punct:]] ]]; then
		id -g $USER_USER >/dev/null 2>&1
		if [ $? == 0 ]; then
		        echo "system user $USER_USER already existing..." >> $outfile
			create_user=false
		else
			get_ltfsarchiverpass
			create_user=true
		fi
	else
		GOOD_USER=false
		echo -e "\t$USER_USER is an invalid user name..." | tee -a $outfile
	fi
done
}
#	input loop for LTFSArchiver password
function get_ltfsarchiverpass()
{
unset USER_PASS
GOOD_PASS=false
while ! $GOOD_PASS; do
	GOOD_PASS=true
	echo -e "\n\tPlease supply the LTFSArchiver password [$DEFAULT_PASS]" | tee -a $outfile
	read USER_PASS
	[ -z ${USER_PASS} ] && USER_PASS=$DEFAULT_USER
	if ! [[ "$USER_PASS" =~  [[:alnum:][:punct:]] ]]; then
		GOOD_PASS=false
		echo -e "\t$USER_PASS is an invalid password..." | tee -a $outfile
	fi
done
}
#	input loop for LTFSArchiver running mode
function get_ltfsarchivermode()
{
unset USER_MODE
GOOD_MODE=false
while ! $GOOD_MODE; do
	echo -e "\n\tPlease supply the LTFSArchiver running mode" | tee -a $outfile
	echo -e "\t(B)oth will use library and external devices" | tee -a $outfile
	echo -e "\t(M)anual will use only external devices" | tee -a $outfile
	echo -e "\t(C)hancger will use only library devices" | tee -a $outfile
	echo -e "\tDefault: [B]"
	read USER_MODE
	USER_MODE=`echo $USER_MODE | tr [a-z] [A-Z]`
	[ -z ${USER_MODE} ] && USER_MODE=$DEFAULT_MODE
	if [[ "$USER_MODE"  =~  [M|C|B] ]]; then
		GOOD_MODE=true
	fi
done
}
#	show/modify parameters loop
function show_selected()
{
echo -e "\n\tAccording to you choices, LTFSArchiver will be configured as follows:" | tee -a $outfile
echo -e "\t1] LTFSARCHIVER_HOME: " $USER_HOME/ltfsarchiver | tee -a $outfile
echo -e "\t2] LTFSARCHIVER_USER: " $USER_USER | tee -a $outfile
#[ $create_user ] || echo -e "\tLTFSARCHIVER_PWD:  " $USER_PASS | tee -a $outfile
case $USER_MODE in
	"M")
		longmode="External devices only"
	;;
	"C")
		longmode="Internal devices only"
	;;
	"B")
		longmode="Both external and internal"
	;;
esac
echo -e "\t3] LTFSARCHIVER_MODE: " $longmode | tee -a $outfile
echo -e "\n\tSelect y/Y to complete installation, N/n to exit or select number of the item you want to change " | tee -a $outfile
read CONFERMA
echo "$conferma" >> $outfile
case $CONFERMA in
	"Y"|"y")
		installatutto="Y"
	;;
	"N"|"n")
		installatutto="N"
	;;
	"1")
		get_ltfsarchiverhome
		installatutto="C"
	;;
	"2")
		get_ltfsarchiveruser
		installatutto="C"
	;;
	"3")
		get_ltfsarchivermode
		installatutto="C"
	;;
	*)
		echo -e "\t$CONFERMA: Invalid answer"
esac
	
}
#	Default values for setup
DEFAULT_HOME="/opt"
DEFAULT_MODE="B"
DEFAULT_USER="pprime"
DEFAULT_PASS="pprime09"
GOOD_DBVER=2
SCRIPTDIR=$( cd "$(dirname "$0")" ; pwd -P )
#outfile=$SCRIPTDIR/LTFSArchiver.install.log
outfile=/tmp/LTFSArchiver.install.log
TAR_FILE="ltfsarchiver-server-1.3.tar"
#	MAIN STARTS HERE
[ -f $outfile ] && mv $outfile $outfile.`stat --printf %Y $outfile`
echo_header
#	Check user: it must be root
if ! [ `whoami` == "root" ];then
	echo -e "\n \n \n \n" | tee -a $outfile
	echo -e "\tSorry... YOU MUST BE ROOT TO RUN LTFSArchiver installer"  | tee -a $outfile
	echo -e "\n \n \n \n"  | tee -a $outfile
	exit 3
fi
#       STEP 1  - determine OS (Ubuntu or CentOS?)
echo -e "\n\t-> Verifiyng OS..."  | tee -a $outfile
knownOS=true
unset FFiles
for FFile in `find -P /etc/*-release -type f`; do
        [ -L $FFile ] || FFiles=( ${FFiles[@]} $FFile )
done
OS=$(awk '/DISTRIB_ID=/'  ${FFiles[@]} | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
if [ -z "$OS" ]; then
    OS=$(awk '{print $1}' ${FFiles[@]} | tr '[:upper:]' '[:lower:]')
fi
case $OS in
        "ubuntu")
                WEBSRV="apache2"
                CLEANER="tmpreaper"
        ;;
        "centos")
                WEBSRV="httpd"
                CLEANER="tmpwatch"
        ;;
	*)
		knownOS=false
	;;	
esac
if ! $knownOS; then
	echo -e "\n \n \n \n"  | tee -a $outfile
	echo -e "\tSorry... unable to determine OS or unknown OS"  | tee -a $outfile
	echo -e "\n \n \n \n"  | tee -a $outfile
	exit 3
else
	echo -e "\t $OS OS found"  | tee -a $outfile
fi
	
#       STEP 2 check psql, mtx, etc
#       Check availability of required commands
echo -e "\n\t-> Verifiyng needed packages and modules..."  | tee -a $outfile
somemissing=false
for command in python bc sg_map psql mtx mt ltfs rsync xmllint xsltproc $WEBSRV; do
	sleep 1
	which $command > /dev/null 2>&1
	if [ $? == 0 ]; then
		echo -e "\t$command found" | tee -a $outfile
	else
		echo -e "\t$command missing" | tee -a $outfile
	somemissing=true
	fi
done
#       Check availability of python required modules
for pythonmod in sys xmltodict json; do
        python -c "import $pythonmod" 2>/dev/null
        if [ $? == 0 ]; then
                echo -e "\t$pythonmod python module found" | tee -a $outfile
	else
                echo "$pythonmod python module missing" | tee -a $outfile
                somemissing=true
        fi
done
if $somemissing; then
	echo -e "\n \n \n \n" | tee -a $outfile
	echo -e "\tSorry... some of needed packages/commands are missing" | tee -a $outfile
	echo -e "\n \n \n \n" | tee -a $outfile
	exit 3
fi
#       STEP 3 - Is postgres running?
echo -e "\n\t-> Checking postgresql..."  | tee -a $outfile
service postgresql status >/dev/null 2>&1
PSQL_RUN=$?
if [ $PSQL_RUN == 0 ]; then
        echo -e "\tPostgresql is running..." | tee -a $outfile
else
        echo -e "\tPostgresql is not running..." | tee -a $outfile
        exit 3
fi
echo -e "\tPreinstallation checks succesfully completed" | tee -a $outfile
echo -e "\tPress ENTER to proceed" | tee -a $outfile
read campavia
echo_header
#	STEP 4 - Getting variables:
#		LTFSARCHIVER_HOME
#		LTFSARCHIVER_USER
#		LTFSARCHIVER_PWD
#		LTFSARCHIVER_MODE
#		
echo -e "\n\tReady to start LTFSArchiver installation" | tee -a $outfile


#		LTFSARCHIVER_HOME
get_ltfsarchiverhome
#		LTFSARCHIVER_USER
get_ltfsarchiveruser
#		LTFSARCHIVER_MODE
get_ltfsarchivermode
installatutto="C"
while [ $installatutto == "C" ]; do
	show_selected
done
if [ $installatutto == "N" ]; then
	echo -e "\tInstallation cancelled... exiting" | tee -a $outfile
	exit
fi

#	OK, lt's go on with last check

#	CHECK IF DB ALREADY EXISXT (and if existing, its version and owner)
#	
echo -e "\n\tChecking for DB existence (and its version, if any)" | tee -a $outfile
DBEXISTS=`su - postgres -c "psql -l" | grep -w ltfsarchive | wc -l`
CONNECT=$?
if [ $CONNECT -gt 0 ]; then
	echo -e "\n\tERROR while trying a connection to postgresql server... exiting" | tee -a $outfile
	exit 3
fi
if [ $DBEXISTS == "1" ]; then
	echo "DBEXISTS: true" >> $outfile
	create_db=false
	#	OWNER
	DBOWNER=`su - postgres -c "psql -l" | grep -w ltfsarchiver | cut -d '|' -f 2 | tr -d ' '`
	echo "DBOWNER: $DBOWNER" >> $outfile
	#	VERSION
	DBVER=`psql -U $DBOWNER -d ltfsarchiver -t -c "select dbversion from db_info;" | tr -d ' '`
	echo "DBVER: $DBVER" >> $outfile
	[ -z "$DBVER" ] && DBVER=0
	if ! [ $DBOWNER == $USER_USER ]; then
		echo -e "\tERROR: ltfsarchiver exists, but its owner is $DBOWNER, not $USER_USER" | tee -a $outfile
		exit 2
	fi
	if ! [ $DBVER -lt  $GOOD_DBVER ]; then
		echo -e "\tERROR: ltfsarchiver exists, but its version id $DBVER, needed >= $GOOD_DBVER" | tee -a $outfile
		exit 2
	fi
else
	echo "DBEXISTS: false" >> $outfile
	create_db=true	
fi

#	COPY PACKAGE... (TAR LEFT for future USE... now ONLY COPY is used
	
echo -e "\n\tCreating $USER_HOME/ltfsarchiver" |  tee -a $outfile
MKD_RC=0
mkdir -m 755 $USER_HOME/ltfsarchiver; let MKD_RC+=$?
mkdir -m 777 $USER_HOME/ltfsarchiver/reportfiles; let MKD_RC+=$?
mkdir -m 777 $USER_HOME/ltfsarchiver/logs; let MKD_RC+=$?
mkdir -m 777 $USER_HOME/ltfsarchiver/poolbkp; let MKD_RC+=$?
if [ $MKD_RC == 0 ]; then
	echo -e "\n\tCopying files to $USER_HOME/ltfsarchiver" |  tee -a $outfile
	cp -pr $SCRIPTDIR/*  $USER_HOME/ltfsarchiver | tee -a $outfile
	if [ $? != 0 ]; then
		echo -e "\tERROR occurred while copying files" | tee -a $outfile
		exit 3
	else
		#	Removes the setup.sh copied script
		rm $USER_HOME/ltfsarchiver/`basename $0`
	fi
else
	echo -e "\tERROR occurred while creating directories" | tee -a $outfile
	exit 3
fi
#	SYSTEM USER CREATION
if $create_user; then
	echo -e "\n\tcreating system user $USER_USER ..." | tee -a $outfile
	useradd $USER_USER -p $USER_PASS >> $outfile 2>&1
	if [ $? == 0 ]; then
		echo -e "\tUser successfully created" | tee -a $outfile
	else
		echo -e "\tERROR occurred while creating user" | tee -a $outfile
		exit 3
	fi		
fi
#	POSTGRES USER CREATION
#	CHECK IF DBUSER ALREADY EXISXT 
PSQLUSEREXISTS=`su - postgres -c 'psql template1 -c "\du"' | grep -c $USER_USER`
if [ $PSQLUSEREXISTS == 0 ]; then
        echo -e "\n\tcreating postgresql user $USER_USER ..." | tee -a $outfile
        su - postgres -c "createuser -S -d -R $USER_USER" >> $outfile 2>&1
	if [ $? == 0 ]; then
		echo -e "\tSuccess"
	else
		echo -e "\tFailed... exiting"
		exit 3
	fi
else
        echo -e "\n\tpostgresql user $USER_USER already existing..." | tee -a $outfile
fi
#	LTFSARCHVER DB CREATION
if $create_db; then
	echo -e "\n\tCreating ltfsarchiver DB" | tee  -a $outfile
	su - $USER_USER -c "createdb ltfsarchiver" 2>&1 |  tee -a $outfile
	if [ $? == 0 ]; then
		echo -e "\tSuccess" |  tee -a $outfile
		echo -e "\tinitializing ltfsarchiver db..." |  tee -a $outfile
		su - $USER_USER -c "psql -U $USER_USER ltfsarchiver -f ${USER_HOME}/ltfsarchiver/sbin/utils/DB_pprimelto_schema.sql" >> $outfile 2>&1
		if [ $? == 0 ]; then
			echo -e "\tSuccess" |  tee -a $outfile
		else
			echo -e "\tFailed... exiting" |  tee -a $outfile
			exit 3
		fi
	else
		echo -e "\tFailed... exiting" |  tee -a $outfile
		exit 3
	fi
fi
#       STEP 6  init.d, conf.d and cron.daily

echo -e "\n\tFinalizing installation" |  tee -a $outfile
echo -e "\tHTTPD conf file..." |  tee -a $outfile
cp -p $USER_HOME/ltfsarchiver/specific/ltfsarchiver.conf /etc/$WEBSRV/conf.d
echo -e "\tinit.d start/stop file..."|  tee -a $outfile
cp -p $USER_HOME/ltfsarchiver/specific/ltfsarchiver.$OS /etc/init.d/ltfsarchiver
echo -e "\tdaily cleaner conf file..."|  tee -a $outfile
cp -p $USER_HOME/ltfsarchiver/specific/ltfsarchiver.cron.daily /etc/cron.daily/ltfsarchiver
echo -e "\tStoring supplied values into conf files..."|  tee -a $outfile
#	Overwrite preconfigured conf file
sed 's;_LTFSARCHIVER_HOME_;'${USER_HOME}'/ltfsarchiver;' -i ${USER_HOME}/ltfsarchiver/conf/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_MODE_;'${USER_MODE}';' -i ${USER_HOME}/ltfsarchiver/conf/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_USER_;'${USER_USER}';' -i ${USER_HOME}/ltfsarchiver/conf/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_GROUP_;'`id -nu $USER_USER`';' -i ${USER_HOME}/ltfsarchiver/conf/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_HOME_;'${USER_HOME}'/ltfsarchiver;' -i /etc/$WEBSRV/conf.d/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_HOME_;'${USER_HOME}'/ltfsarchiver;' -i /etc/init.d/ltfsarchiver
sed 's;_LTFSARCHIVER_HOME_;'${USER_HOME}'/ltfsarchiver;' -i /etc/cron.daily/ltfsarchiver
sed -e 's/___CLEANER___/'$CLEANER'/' -i /etc/cron.daily/ltfsarchiver
echo -e "\tSetting autostart at needed run levels..." |  tee -a $outfile
case $OS in
	"ubuntu")
		update-rc.d ltfsarchiver start 90 2 3 5 . stop 90 0 1 4 6 .
	;;
	"centos")
		chkconfig --add ltfsarchiver
	;;
esac
#	STEP 7 (user option): Guess config
echo -e "\n\tWould you like run guess_config script [y|N]> " |  tee -a $outfile
read answer
echo -e "\tYou entered: $answer" |  tee -a $outfile
case $answer in
	"y"|"Y")
		. $USER_HOME/ltfsarchiver/sbin/utils/guess_conf.sh fromsetup $USER_HOME/ltfsarchiver
	;;
	*)
		echo -e "\n\tguess config skipped" | tee -a $outfile
	;;
esac
echo -e "\n\n\tAll done!" | tee -a $outfile
echo -e "\n\n\tActivity logged in: $outfile"
