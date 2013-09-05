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

function actionlist()
{
TYPECODE=$1
QUERY="select min(id), ltotape from requests where operation='$TYPECODE' and manager='M' and substatus=20 group by ltotape order by min(id)"
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
		TYPE="Format"
	;;
	"C")
		TYPE="CheckSpace"
	;;
esac
NOREQ20="no pending mount requests"
UUID_PND=( `$CMD_DB "$QUERY" | tr -d ' ' | tr '|' ' ' | tr '\n' ' '` )
if [ -z $UUID_PND ]; then
	echo '<TR><TD colspan=6>'
	echo $TYPE": "$NOREQ20
	echo '</TD></TR>'
else
	#	Per ognuno degli lto richiesti inserisco riga in table
	for ((PND_IDX=0; PND_IDX<${#UUID_PND[@]}; PND_IDX+=2)); do
		#	quante e quali per quel nastro?
		UUID_FOR_TAPE=( `$CMD_DB "select id,uuid,device from requests where substatus=20 and operation='$TYPECODE' and ltotape='${UUID_PND[$PND_IDX+1]}'" \
			| tr -d ' ' | tr '|' ' ' | tr '\n' ' '` )
		#	Quante	sono per quel tape?
		NUM_FOR_TAPE=`echo "${#UUID_FOR_TAPE[@]} /3" | bc`
		#	LABEL (su tante righe quante sono le uuid
		echo '<TR><TD rowspan='$NUM_FOR_TAPE'>'${UUID_PND[$PND_IDX+1]}'</TD>'
		echo '<TD rowspan='$NUM_FOR_TAPE'>'$TYPE'</TD>'
		#	ID/UUID
		unset UUID_LIST
		for ((UUID_IDX=0; UUID_IDX<${#UUID_FOR_TAPE[@]};UUID_IDX+=3)); do
			UUID_LIST=( ${UUID_LIST[@]} "${UUID_FOR_TAPE[$UUID_IDX+1]}" )
			[ $UUID_IDX == 0 ] || echo '<TR>'
			#	ID
			echo '<TD>'${UUID_FOR_TAPE[$UUID_IDX]}'</TD>'
			#	UUID
			echo '<TD>'${UUID_FOR_TAPE[$UUID_IDX+1]}'</TD>'
			if [ $UUID_IDX == 0 ]; then
				echo '<TD rowspan='$NUM_FOR_TAPE'>'${UUID_FOR_TAPE[$UUID_IDX+2]}'</TD>'
				echo '<TD rowspan='$NUM_FOR_TAPE'><A HREF=mounttape.cgi?uuidlist='`echo ${UUID_LIST[@]} | tr ' ' ','`'>confirm load</A></TD>'
			fi
			echo '</TR>'
		done
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
echo '<TD>Req. tape</TD>'
echo '<TD>Req. type</TD>'
echo '<TD>Req. #</TD>'
echo '<TD>uuid</TD>'
echo '<TD>Assigned dev.</TD>'
echo '<TD>Req. action</TD>'
echo '</TR>'
}

#	MAIN
. $CFGFILE
PARM=$QUERY_STRING
htmlhead
case $PARM in
	"all")
		tabletitle "All type of request list"
		actionlist "W"
		actionlist "R"
		actionlist "A"
		actionlist "F"
		actionlist "C"
	;;
	"archive")
		tabletitle "Archiving request list"
		actionlist "W"
	;;
	"restore")
		tabletitle "Restore request list"
		actionlist "R"
	;;
	"makeaval")
		tabletitle "Make available request list"
		actionlist "A"
	;;
	"format")
		tabletitle "Format request list"
		actionlist "F"
	;;
	"checkspace")
		tabletitle "CheckSpace request list"
		actionlist "C"
	;;
esac
echo '</TABLE>'
echo '</CENTER>'
echo '</body></html>'
