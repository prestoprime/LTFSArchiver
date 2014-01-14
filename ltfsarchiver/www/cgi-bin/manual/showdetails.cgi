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
. $CFGFILE
. `dirname $0`/../common.sh
echo 'Content-Type: text/html'
echo 'Pragma: nocache'
echo 'Cache-Control: no-cache, must-revalidate, no-store'
echo ''
echo '<html><body bgcolor="#FFFFCC" link="#000099" vlink="#000099"><center>'
echo '<font size="+3" face="Verdana, Arial, Helvetica, sans-serif">'
PARM=$QUERY_STRING
OP_TYPE=$( get_parameter Operation )
OP_UUID=$( get_parameter TaskID )
DATA_RQ=( `$CMD_DB" select callingtime from requests where uuid='$OP_UUID';"` )
DATA_ST=( `$CMD_DB" select starttime from requests where uuid='$OP_UUID';"` )
echo '<font size="+2" face="Verdana, Arial, Helvetica, sans-serif">'
echo 'Instance details<BR><BR>'
echo '<TABLE>'
echo '<TR><TD>Instace TaskID</TD><TD>'$OP_UUID'</TD></TR>'
case $OP_TYPE in
	"W")
		DATA_OP=( `$CMD_DB" select status,datatype,sourcesize from requests where uuid='$OP_UUID';" | tr '|' ' '` ) 
		SOURCE_OP=`$CMD_DB" select sourcefile from requests where uuid='$OP_UUID'"`
		echo '<TR><TD>Item to archive</TD><TD>'"$SOURCE_OP"'</TD></TR>'
		echo '<TR><TD>Item type</TD><TD>'${DATA_OP[1]}'</TD></TR>'
		if  [ -z "${DATA_OP[2]}" ]; then
			echo '<TR><TD>Item size (MB)</TD><TD>n/a</TD></TR>'
		else
			echo '<TR><TD>Item size (MB)</TD><TD>'${DATA_OP[2]}'</TD></TR>'
		fi	
	;;
	"R")
		DATA_OP=( `$CMD_DB" select status,sourcefile,destfile from requests where uuid='$OP_UUID';" | tr '|' ' '` ) 
		echo '<TR><TD>Item to restore</TD><TD>'"${DATA_OP[1]}"'</TD></TR>'
		echo '<TR><TD>Destinatione</TD><TD>'"${DATA_OP[2]}"'</TD></TR>'
	;;
esac
echo '<TR><TD>Request datetime</TD><TD>'${DATA_RQ[@]}'</TD></TR>'
echo '<TR><TD>Start datetime</TD><TD>'${DATA_ST[@]}'</TD></TR>'
echo '<TR><TD>Request status</TD><TD>'${DATA_OP[0]}'</TD></TR>'
echo '</TABLE>'
echo '</font></center></body></html>'
