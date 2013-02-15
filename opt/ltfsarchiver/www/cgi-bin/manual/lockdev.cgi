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

PARM=$QUERY_STRING
action=$( get_parameter lock )
device=$( get_parameter device )
case $action in
	"y")
		ACT_MSG=" locked"
		$DBACCESS" insert into lock_table (device,ltolabel) VALUES('$device','$LTFSARCHIVER_LOCK_LABEL');" >/dev/null 2>&1
	;;
	"n")
		ACT_MSG=" unlocked"
		$DBACCESS" delete from lock_table where device='$device';" >/dev/null 2>&1
	;;
esac
EXEC_RC=$?
#	Output
echo 'Content-Type: text/html'
echo 'Pragma: nocache'
echo 'Cache-Control: no-cache, must-revalidate, no-store'
echo ''
echo '<html>'
echo '<META HTTP-EQUIV="refresh" CONTENT="5;URL=showdrives.cgi">'
echo '<body bgcolor="#FFFFCC" link="#000099" vlink="#000099"><center>'
echo '<font size="+2" face="Verdana, Arial, Helvetica, sans-serif">'
case $EXEC_RC in
	0)
		echo 'Tape device '$device' has been successfully '$ACT_MSG
	;;
	*)
		echo 'Error occurred: tape device '$device' has not been '$ACT_MSG
	;;
esac
echo '</font>'
echo '<font face="Verdana, Arial, Helvetica, sans-serif">'
echo '<br><br>you will be soon redirected to the previos page, click <A HREF=showdrives.cgi>here</A> to go back now'
echo '</center></body></html>'
