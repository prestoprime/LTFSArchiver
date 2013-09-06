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

function sectotime()
{
seconds=$1
hours=$((seconds / 3600))
seconds=$((seconds % 3600))
minutes=$((seconds / 60))
seconds=$((seconds % 60))
#TIME="$hours hour(s) $minutes minute(s) $seconds second(s)"
TIME="$hours:$minutes:$seconds"
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
echo '<TABLE style="width: 90%; text-align: center;" border="1" cellpadding="2" cellspacing="2">'
echo '<TR>'
echo '<TD>ID</TD>'
echo '<TD>UUID</TD>'
echo '<TD>Tape</TD>'
echo '<TD>Device</TD>'
echo '<TD>Mount point</TD>'
echo '<TD>Runtime</TD>'
echo '</TR>'
}

#	MAIN
. $CFGFILE
#	mountpoint attivi
htmlhead
tabletitle "Make available active instances"
ACTMP=( `mount | grep $LTFSARCHIVER_MNTAVAIL | cut -d ' ' -f 3 | tr '\n' ' '` )
if [ -z $ACTMP ]; then
	echo '<TR><TD colspan=6>None</T></TR>'
else
	for ((ACT_IDX=0; ACT_IDX<${#ACTMP[@]}; ACT_IDX++)); do
		LABEL=`basename ${ACTMP[$ACT_IDX]}`
		DATA=( `$CMD_DB "select id,uuid,ltotape,device from requests where id=(select max(id) from requests where operation='A' and status='completed' and ltotape='$LABEL')" | tr -d ' ' | tr '|' ' '` )
		MD=`$CMD_DB "select endtime from requests where uuid='${DATA[1]}'" | sed -e 's/^ *//' -e 's/ *$//'`
		CD=`date --date "$MD" +%s`
		AD=`date +%s`
		sectotime `echo "$AD-$CD" | bc`
		echo '<TR>'
		echo '<TD>'${DATA[0]}'</TD>'
		echo '<TD>'${DATA[1]}'</TD>'
		echo '<TD>'${DATA[2]}'</TD>'
		echo '<TD>'${DATA[3]}'</TD>'
		echo '<TD>'${ACTMP[$ACT_IDX]}'</TD>'
		echo '<TD>'$TIME'</TD>'
		echo '</TR>'
	done
fi
echo '</TABLE>'
echo '</body></html>'
