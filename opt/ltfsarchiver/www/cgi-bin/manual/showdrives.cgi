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
LOADEDTAPE=`$DBACCESS "select ltolabel from lock_table where device='$1'" | tr -d ' '`
if [ -z $LOADEDTAPE ]; then
	OUTSTR='<TR><TD>'$1'</TD><TD align="center"><img src=/ltfsarchiver/images/ok.png></TD><TD><A HREF=lockdev.cgi?lock=y&device='$1'>lock</A></TD><TD>none</TD></TR>'
else
	if [ $LOADEDTAPE == $LTFSARCHIVER_LOCK_LABEL ]; then
		OUTSTR='<TR><TD>'$1'</TD><TD align="center"><img src=/ltfsarchiver/images/lock.gif></TD><TD><A HREF=lockdev.cgi?lock=n&device='$1'>unlock</A></TD><TD>none</TD></TR>'
	else
		ACTIVITY=`$DBACCESS "select inuse from lto_info where label='$LOADEDTAPE'" | tr -d ' '`
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
		ccounter=0
		while [ $ccounter -lt ${#CHANGER_DEVICES[@]} ]; do
			tape_array_name="CHANGER_TAPE_DEV_"$ccounter"[@]"
			temp_array=( ${!tape_array_name} )
			#	Device della libreria
			echo '<TR><TD colspan=4>Library: '${CHANGER_DEVICES[$ccounter]}'</TD></TR>'
			echo '<TR><TD>Device</TD><TD align=center>Status</TD><TD>Action</TD><TD>TapeID</TD></TR>'
			tcounter=0
			while [ $tcounter -lt ${#temp_array[@]} ]; do

				get_dev_status ${temp_array[$tcounter]}
				echo $OUTSTR
				let tcounter+=1
			done
			let ccounter+=1
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
                mcounter=0
                while [ $mcounter -lt ${#MANUAL_TAPE_DEVICES[@]} ]; do
			get_dev_status ${MANUAL_TAPE_DEVICES[$mcounter]}
			echo $OUTSTR
                        let mcounter+=1
                done
		echo '</TABLE>'
        ;;
esac


echo '</font></center></body></html>'
