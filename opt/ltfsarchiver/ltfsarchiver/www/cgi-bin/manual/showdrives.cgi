#!/bin/bash

#  PrestoPRIME  LTFSArchiver
#  Version: 1.0 Beta
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

function get_dev_status()
{
LOADEDTAPE=`$CMD_DB "select ltolabel from lock_table where device='$1'" | tr -d ' '`
#	Se risulta libero da lock_table
if [ -z $LOADEDTAPE ]; then
	#	se esiste lock file significa che c'e un nastro "straniero" -> mostro warning e lock
	#	vieceversa significa il device e' realmente libero -> mostro warning e lock
	if [ -e /tmp/ltfsarchiver.`basename $1`.lock ]; then
		imagename="warning.png"
		tapelabel=`cat /tmp/ltfsarchiver.\`basename $1\`.lock`
	else
		imagename="ok.png"
		tapelabel="none"
	fi
	OUTSTR='<TR><TD>'$1'</TD><TD align="center"><img src="/ltfsarchiver/images/'$imagename'"></TD><TD><A HREF=lockdev.cgi?lock=y&device='$1'>lock</A></TD><TD>'$tapelabel'</TD></TR>'
else
	if [ $LOADEDTAPE == $LTFSARCHIVER_LOCK_LABEL ]; then
		OUTSTR='<TR><TD>'$1'</TD><TD align="center"><img src=/ltfsarchiver/images/lock.gif></TD><TD><A HREF=lockdev.cgi?lock=n&device='$1'>unlock</A></TD><TD>none</TD></TR>'
	else
		ACTIVITY=`$CMD_DB "select inuse from lto_info where label='$LOADEDTAPE'" | tr -d ' '`
		case $ACTIVITY in
			"W")
				DESCR="In use by archive"
			;;
			"R")
				DESCR="In use by restore"
			;;
			"A")
				DESCR="In use by makeavailable"
			;;
			"U")
				DESCR="Waiting by unmount"
			;;
			"F"|"Z")
				DESCR="In use by format"
			;;
			"C")
				DESCR="In use by checkspace"
		;;
		esac
		OUTSTR='<TR><TD>'$1'</TD><TD align="center"><img src=/ltfsarchiver/images/lto.jpg></TD><TD>'$DESCR'</TD><TD>'$LOADEDTAPE'</TD></TR>'
	fi
fi
}
. $CFGFILE
echo 'Content-Type: text/html'
echo 'Pragma: nocache'
echo 'Cache-Control: no-cache, must-revalidate, no-store'
echo ''
echo '<html><body bgcolor="#FFFFCC" link="#000099" vlink="#000099"><center>'
echo '<font size="+3" face="Verdana, Arial, Helvetica, sans-serif">'
case $LTFSARCHIVER_MODE in
	"C"|"B")
		echo '<table border=1 cellspacing=0 cellpadding=5>'
		echo '<TR><TD colspan=4 align="center">Library devices</TD></TR>'
		for ((ccounter=0; ccounter<${#CONF_CHANGER_DEVICES[@]}; ccounter++)); do
			tape_array_name="CONF_CHANGER_TAPEDEV_"$ccounter"[@]"
			temp_array=( ${!tape_array_name} )
			#	Device della libreria
			echo '<TR><TD colspan=4>Library: '${CONF_CHANGER_DEVICES[$ccounter]}'</TD></TR>'
			echo '<TR><TD>Device</TD><TD align=center>Status</TD><TD>Action</TD><TD>TapeID</TD></TR>'
			for ((tcounter=0; tcounter<${#temp_array[@]}; tcounter++)); do

				get_dev_status ${temp_array[$tcounter]}
				echo $OUTSTR
			done
		done
		echo '</TABLE>'
	;;
esac
echo '<BR>'
case $LTFSARCHIVER_MODE in
        "M"|"B")
		echo '<table border=1 cellspacing=0 cellpadding=5>'
		echo '<TR><TD colspan=4 align="center">Manual devices</TD></TR>'
		echo '<TR><TD>Device</TD><TD>Status</TD><TD>Action</TD><TD>TapeID</TD></TR>'
                for ((mcounter=0; mcounter<${#CONF_MANUAL_TAPEDEV[@]}; mcounter++)); do
			get_dev_status ${CONF_MANUAL_TAPEDEV[$mcounter]}
			echo $OUTSTR
                done
		echo '</TABLE>'
        ;;
esac


echo '</font></center></body></html>'
