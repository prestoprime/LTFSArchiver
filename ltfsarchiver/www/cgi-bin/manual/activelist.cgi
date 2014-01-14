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

function activelist()
{
TYPECODE=$1
#QUERYG="select id, uuid, status, substatus, ltotape, device, manager  from requests where operation='$TYPECODE' and substatus < 60 order by id"
QUERYG="select id, uuid, status, substatus, ltotape, device, manager  from requests where operation='$TYPECODE' and substatus <> 60 order by id"
case $TYPECODE in
	"W")	#	Archive
		TYPE="Archive"
		APITOCALL="../WriteToLTO"
	;;
	"R")
		TYPE="Restore"
		APITOCALL="../RestoreFromLTO"
	;;
	"A")
		TYPE="Make available"
		APITOCALL="../MakeAvailable"
	;;
	"F")
		TYPE="STD Format"
		APITOCALL="../TapeManager"
	;;
	"Z")
		TYPE="FORCE Format"
		APITOCALL="../TapeManager"
	;;
	"C")
		TYPE="CheckSpace"
		APITOCALL="../TapeManager"
	;;
esac
NOACTIVE="No active requests found"
UUID_PND=( `$CMD_DB "$QUERYG" | tr -d ' ' | tr '|' ' ' | tr '\n' ' '` )
if [ -z $UUID_PND ]; then
	echo '<TR><TD colspan=7>'
	echo $TYPE": "$NOACTIVE
	echo '</TD></TR>'
else
	echo '<TR><TD colspan=7>'
	echo 'Active '$TYPE' requests'
	echo '</TD></TR>'
	#	Per ognuno degli lto richiesti inserisco riga in table
	for ((PND_IDX=0; PND_IDX<${#UUID_PND[@]}; PND_IDX+=7)); do
		case ${UUID_PND[$PND_IDX+6]} in
			"C")
				MODE=" (Int)"
			;;
			"M")
				MODE=" (Ext)"
			;;
		esac
		#	PArto con NO a cancel
		CANDELETE="N"
		CANRESUB="N"
		case ${UUID_PND[$PND_IDX+3]} in
			0)
				COMMENT="Waiting to be dispatched"
				CANDELETE="Y"
			;;
			4)
				COMMENT="Running prearchive checksum checks"
			;;
			6)
				COMMENT="Prearchive checksum verification ok<BR>waiting to be dispatched"
			;;
			10)
				COMMENT="Dispatched, waiting for tape device"
				CANDELETE="Y"
			;;
			20)
				COMMENT="Dispatched, waiting for tape loading"
			;;
			30)
				COMMENT="Tape being loaded o positiong"
			;;
			40)
				COMMENT="Tape loaded and ready"
			;;
			50)
				COMMENT="Running"
			;;
			55)
				COMMENT="Running postarchive checksum verication"
			;;
			60)
				COMMENT="Completed"
			;;
			19)
				COMMENT=`$CMD_DB" select errordescription from requests where uuid='${UUID_PND[$PND_IDX+1]}'"`
				#COMMENT="Failed prearchive checksum verification"
				CANDELETE="Y"
				CANRESUB="N"
			;;
			9|99)
				COMMENT=`$CMD_DB" select errordescription from requests where uuid='${UUID_PND[$PND_IDX+1]}'"`
				CANDELETE="Y"
				case $TYPECODE in 
					"F"|"Z"|"C")
						CANRESUB="N"
					;;
					*)
						CANRESUB="Y"
					;;
				esac
			;;
		esac
		echo '<TR>'
		echo '<TD>'${UUID_PND[$PND_IDX]}'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+1]}'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+2]}'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+4]}$MODE'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+5]}'</TD>'
		if ( [ "$TYPECODE" == "W" ] && [ ${UUID_PND[$PND_IDX+3]} == 50 ] ); then
			ST_DATA=( `$CMD_DB" select sourcefile, sourcebytes, device, datatype from requests where uuid='${UUID_PND[$PND_IDX+1]}'" | tr -d ' ' | tr '|' ' '` )
			case ${ST_DATA[3]} in
				"D")
					RSYNCFILE=/tmp/${UUID_PND[$PND_IDX+1]}.rsync.txt
					if ! [ -f $RSYNCFILE ]; then
						perc=0
					else
						donebyte=`awk '{print $4}' $RSYNCFILE | sed -e "s/^'//" | sed -e 's/|.*//' | awk 'BEGIN{sum=0}{sum+=$1}END{printf "%.0f\n", sum}'`
						#copyingbyte=`lsof | grep /mnt/ltfsst1/temp.${UUID_PND[$PND_IDX+1]} | awk '{print $7}' | awk 'BEGIN{sum=0}{sum+=$1}END{printf "%.0f\n", sum}'`
						if [ -f "/tmp/${UUID_PND[$PND_IDX+1]}.copylist" ]; then
							fileincopy=/mnt/ltfs`basename ${ST_DATA[2]}`/temp.${UUID_PND[$PND_IDX+1]}/`tail -1 /tmp/${UUID_PND[$PND_IDX+1]}.copylist`
							#	10giga.dat -----durante rsync diventa ----------> .10giga.dat.JDTcKG
							tempname=`dirname $fileincopy`"/."`basename $fileincopy`".*"
							copyingbyte=`find $tempname -printf '%s\n'`
						else
							copyingbyte=0
						fi
						let donebyte+=$copyingbyte
						if [ $donebyte -ge ${ST_DATA[1]} ]; then
							perc=100
						else
							perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[1]}" | bc`
						fi
					fi
				;;
				"F")
					TARGETN=/mnt/ltfs`basename ${ST_DATA[2]}`/temp.${UUID_PND[$PND_IDX+1]}/`basename ${ST_DATA[0]}`
					donebyte=`stat --printf '%s\n' $TARGETN`
					perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[1]}" | bc`
				;;
			esac
			case ${UUID_PND[$PND_IDX+3]} in
				50)
					COMMENT=$COMMENT" - copied $perc %"
				;;
				55)
					COMMENT=$COMMENT" - generating FLOCAT(s) or MD5 checkums(s)"
				;;
			esac
		fi
		echo '<TD>'$COMMENT'</TD>'
		echo '<TD>'
		echo '<FORM ACTION='showdetails.cgi' method="get" target="result">'
		echo '   <input type="hidden" name="Operation" value="'$TYPECODE'" value="true">'
		echo '   <input type="hidden" name="TaskID" value="'${UUID_PND[$PND_IDX+1]}'">'
		echo '	<button type="submit">Details</button>'
		echo '</FORM>'
		if [ $CANDELETE == "Y" ]; then
			echo '<BR>'
			echo '<FORM ACTION='$APITOCALL' method="get"  target="result">'
			echo '   <input type="hidden" name="Command" value="Cancel">'
			echo '   <input type="hidden" name="FromGUI" value="true">'
			echo '   <input type="hidden" name="TaskID" value="'${UUID_PND[$PND_IDX+1]}'">'
			echo '	<button type="submit">Cancel</button>'
			echo '</FORM>'
		fi
		if [ $CANRESUB == "Y" ]; then
			echo '<BR>'
			echo '<FORM ACTION='$APITOCALL' method="get"  target="result">'
			echo '   <input type="hidden" name="Command" value="Resubmit">'
			echo '   <input type="hidden" name="FromGUI" value="true">'
			echo '   <input type="hidden" name="TaskID" value="'${UUID_PND[$PND_IDX+1]}'">'
			echo '	<button type="submit">Resubmit</button>'
			echo '</FORM>'
		fi
		echo '</TD>'
		echo '</TR>'
	done
fi
}




function htmlhead()
{
echo 'Content-Type: text/html'
echo 'Pragma: nocache'
echo 'Cache-Control: no-cache, must-revalidate, no-store'
echo ''
echo '<html>'
echo '<head>'
echo '<meta content="text/html; charset=iso-8859-1"'
echo 'http-equiv="Content-Type">'
echo '<title></title>'
echo '</head>'
echo '<body bgcolor="#FFFFCC" link="#000099" vlink="#000099">'
echo '<font size="2" face="Verdana, Arial, Helvetica, sans-serif">'
echo '<hr>'
}
function tabletitle()
{
echo '<B><FONT SIZE=+2><CENTER>'$1'</CENTER></FONT></B>'
echo '<BR><BR>'
echo '<CENTER>'
echo '<TABLE style="width: 80%; text-align: center;" border="1" cellpadding="2" cellspacing="2">'
echo '<TR>'
echo '<TD>ID</TD>'
echo '<TD>UUID</TD>'
echo '<TD>Status</TD>'
echo '<TD>Tape</TD>'
echo '<TD>Device</TD>'
echo '<TD>Note</TD>'
echo '<TD>Action</TD>'
echo '</TR>'
}

#	MAIN
. $CFGFILE
PARM=$QUERY_STRING
[ -z $PARM ] && PARM="all"
htmlhead
case $PARM in
	"all")
		tabletitle "All kind of active list"
		activelist "W"
		activelist "R"
		activelist "A"
		activelist "F"
		activelist "Z"
		activelist "C"
	;;
	"archive")
		tabletitle "Archiving active list"
		activelist "W"
	;;
	"restore")
		tabletitle "Restore active list"
		activelist "R"
	;;
	"makeaval")
		tabletitle "Make available active list"
		activelist "A"
	;;
	"format")
		tabletitle "Format active list"
		activelist "F"
		activelist "Z"
	;;
	"checkspace")
		tabletitle "CheckSpace active list"
		activelist "C"
	;;
esac
echo '</TABLE>'
echo '</CENTER>'
echo '</body></html>'
