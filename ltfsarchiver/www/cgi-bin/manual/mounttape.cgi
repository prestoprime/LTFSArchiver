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

#	MAIN
. $CFGFILE
. `dirname $0`/../common.sh
#	Lista dei tape esterni
PARM=$QUERY_STRING
UUID_LIST=$( get_parameter uuidlist )
UUID_ITEMS=( `echo $UUID_LIST | tr ',' ' '` )
echo 'Content-Type: text/html'
echo ''
echo '<html>'
echo '<head>'
echo '<meta content="text/html; charset=iso-8859-1"'
echo 'http-equiv="Content-Type">'
echo '<title></title>'
echo '</head>'
echo '<body bgcolor="#FFFFCC" link="#000099" vlink="#000099">'
echo '<font size="2" face="Verdana, Arial, Helvetica, sans-serif">'
echo '<body>'
echo 'The following uuids have been sent to ready status:<br><br>'
for ((ELEM=0; ELEM<${#UUID_ITEMS[@]}; ELEM++)); do
	$CMD_DB" update requests set substatus=40, status='starting' where uuid='${UUID_ITEMS[$ELEM]}';" >/dev/null 2>&1
	echo ${UUID_ITEMS[$ELEM]}'<br>'
done
echo '</body></html>'
