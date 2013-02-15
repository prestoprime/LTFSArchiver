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
QUERYG="select id, uuid, status, substatus, ltotape, device, manager  from requests where operation='$TYPECODE' and substatus < 60 order by id"
case $TYPECODE in
	"W")	#	Archive
		TYPE="Archive"
	;;
	"R")
		TYPE="Restore"
	;;
	"A")
		TYPE="Make available"
	;;
	"F")
		TYPE="STD Format"
	;;
	"Z")
		TYPE="FORCE Format"
	;;
	"C")
		TYPE="CheckSpace"
	;;
esac
NOACTIVE="No active requests found"
UUID_PND=( `$DBACCESS "$QUERYG" | tr -d ' ' | tr '|' ' ' | tr '\n' ' '` )
if [ -z $UUID_PND ]; then
	echo '<TR><TD colspan=6>'
	echo $TYPE": "$NOACTIVE
	echo '</TD></TR>'
else
	echo '<TR><TD colspan=6>'
	echo 'Active '$TYPE' requests'
	echo '</TD></TR>'
	PND_IDX=0
	#	Per ognuno degli lto richiesti inserisco riga in table
	while [ $PND_IDX -lt ${#UUID_PND[@]} ]; do
		case ${UUID_PND[$PND_IDX+6]} in
			"C")
				MODE=" (Int)"
			;;
			"M")
				MODE=" (Ext)"
			;;
		esac
		case ${UUID_PND[$PND_IDX+3]} in
			0)
				COMMENT="Waiting to be dispatched"
			;;
			10)
				COMMENT="Dispatched, waiting for tape device"
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
			60)
				COMMENT="Completed"
			;;
			99)
				COMMENT="Fallout"
			;;
		esac
		echo '<TR>'
		echo '<TD>'${UUID_PND[$PND_IDX]}'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+1]}'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+2]}'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+4]}$MODE'</TD>'
		echo '<TD>'${UUID_PND[$PND_IDX+5]}'</TD>'
		echo '<TD>'$COMMENT'</TD>'
		echo '</TR>'
		let PND_IDX+=7
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
echo '<TABLE style="width: 90%; text-align: center;" border="1" cellpadding="2" cellspacing="2">'
echo '<TR>'
echo '<TD>ID</TD>'
echo '<TD>UUID</TD>'
echo '<TD>Status</TD>'
echo '<TD>Tape</TD>'
echo '<TD>Device</TD>'
echo '<TD>Note</TD>'
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
echo '</body></html>'
