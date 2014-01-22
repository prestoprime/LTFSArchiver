#!/bin/bash
#  PrestoPRIME  LTFSArchiver 
#  Version: 1.3
#  Authors: L. Savio, L. Boch, R. Borgotallo
#
#  Copyritght (C) 2011-2012 RAI âadiotelevisione Italiana <cr_segreteria@rai.it>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
clear
rp=`dirname $0`
GOODDBVER=2
. $rp/../../conf/ltfsarchiver.conf
outfile=$rp/../../conf/install.log
#	Override of LTFSARCHIVER_HOME
#	Home as retrieved by install scipt location
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
ACTUAL_HOME=`dirname \`dirname $SCRIPTPATH\``
#
#	STEP 0	- OS (Ubuntu or CentOS?)
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
esac
echo "checking for useful commands"
sleep 2
#	Check availability of required commands
#	STEP 1 check psql, mtx, etc
somemissing=false
for command in python bc sg_map psql mtx mt ltfs rsync xmllint xsltproc $WEBSRV; do
	which $command > /dev/null 2>&1
	if [ $? == 0 ]; then
		echo "$command found"
		echo "$command found" >> $outfile
	else
		echo "$command missing"
		echo "$command missing" >> $outfile
		somemissing=true
	fi
done
$somemissing && exit 3
#	Check availability of python required modules
for pythonmod in sys xmltodict json; do
	python -c "import $pythonmod" 2>/dev/null
	if [ $? -gt 0 ]; then
		echo "$pythonmod python module missing"
		echo "$pythonmod python module missing" >> $outfile
		somemissing=true
	fi
done
$somemissing && exit 3
#       Is postgres running?
service postgresql status >/dev/null 2>&1
PSQL_RUN=$?
if [ $PSQL_RUN -gt 0 ]; then
	echo "Postgresql is not running..."
	echo "Postgresql is not running..." >> $outfile
	exit 3
fi

#	STEP 2	system user check/creation
id -g $LTFSARCHIVER_USER >/dev/null 2>&1
if [ $? == 0 ]; then
	echo "system user $LTFSARCHIVER_USER already existing..." >> $outfile
else
	echo "creating system user $LTFSARCHIVER_USER ..."
	useradd $LTFSARCHIVER_USER -p pprime09 >> $outfile 2>&1
fi

#	STEP 3	postgres user check/creation
dbuserexist=`su - postgres -c 'psql template1 -c "\du"' | grep -c $LTFSARCHIVER_USER`
if [ $dbuserexist == 0 ]; then
	echo "creating postgresql user $LTFSARCHIVER_USER ..."
	su - postgres -c "createuser -S -d -R $LTFSARCHIVER_USER" >> $outfile 2>&1 
else
	echo "postgresql user $LTFSARCHIVER_USER already existing..."
	echo "postgresql user $LTFSARCHIVER_USER already existing..." >>$outfile
fi

#	STEP 4	postgres database check/creation
echo "creating ltfsarchiver db..."
cegia=`su - postgres -c 'psql -l' | grep -c ltfsarchiver`
if [ $cegia -gt 0 ]; then
	echo "ltfsarchive db already existing..."
	echo "ltfsarchive db already existing..." >>$outfile
	#	db version check
	DBVER=`psql -U pprime -d ltfsarchiver -t -c "select dbversion from db_info;" | tr -d ' '`
	if [ -z $DBVER ]; then
		echo "unknown db version (surely older than needed one)"
		exit 3
	else
		echo "DB version installed: $DBVER"
		if [ $DBVER == $GOODDBVER ]; then
			echo "Existing DB is up-to-date... skipping creation"
		else
			echo "Existing DB is incompatible with this versio. Please check documentation"
			exit 3
		fi
	fi
else
	su - pprime -c "createdb ltfsarchiver" >> $outfile 2>&1
	echo "initializing ltfsarchiver db..."
	su - pprime -c "psql -U pprime ltfsarchiver -f ${ACTUAL_HOME}/sbin/utils//DB_pprimelto_schema.sql" >> $outfile 2>&1
fi
#	STEP 6	init.d, conf.d and cron.daily
echo "adding ltfsarchiver to automatic started services list (run levels 3 and 5)"
cp -p $rp/../../specific/ltfsarchiver.conf /etc/$WEBSRV/conf.d
cp -p $rp/../../specific/ltfsarchiver.$OS /etc/init.d/ltfsarchiver
cp -p $rp/../../specific/ltfsarchiver.cron.daily /etc/cron.daily/ltfsarchiver
sed -e 's/___CLEANER___/'$CLEANER'/' -i /etc/cron.daily/ltfsarchiver
sed 's;_LTFSARCHIVER_HOME_;'${ACTUAL_HOME}';' -i /etc/$WEBSRV/conf.d/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_HOME_;'${ACTUAL_HOME}';' -i ${ACTUAL_HOME}/conf/ltfsarchiver.conf
sed 's;_LTFSARCHIVER_HOME_;'${ACTUAL_HOME}';' -i /etc/init.d/ltfsarchiver
sed 's;_LTFSARCHIVER_HOME_;'${ACTUAL_HOME}';' -i /etc/cron.daily/ltfsarchiver
case $OS in
	"ubuntu")
		update-rc.d ltfsarchiver start 90 2 3 5 . stop 90 0 1 4 6 .
	;;
	"centos")
		chkconfig --add ltfsarchiver
	;;
esac
[ -d ${ACTUAL_HOME}/reportfiles ] || mkdir ${ACTUAL_HOME}/reportfiles
[ -d ${ACTUAL_HOME}/poolbkp ] || mkdir ${ACTUAL_HOME}/poolbkp
chmod 777 ${ACTUAL_HOME}/reportfiles
chmod 777 ${ACTUAL_HOME}/poolbkp
service $WEBSRV reload
#	STEP 7 (user option): Guess config
echo -n "Would you like run guess_config script [y|N]> "
read answer
echo "You entered: $answer"
case $answer in
        "y"|"Y")
		. $rp/guess_conf.sh
        ;;
        *)
                echo "guess config skipped"
        ;;
esac
