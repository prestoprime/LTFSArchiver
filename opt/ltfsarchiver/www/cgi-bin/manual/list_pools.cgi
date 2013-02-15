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
echo '<hr><CENTER>'
}
function tabletitle()
{
echo '<B><FONT SIZE=+2><CENTER>'$1'</CENTER></FONT></B>'
echo '<TABLE style="width: 90%; text-align: center;" border="1" cellpadding="2" cellspacing="2">'
echo '<TR>'
echo '<TD>Pool Name</TD>'
echo '<TD>Num. Tapes</TD>'
echo '</TR>'
}

#	MAIN
. $CFGFILE
htmlhead

$DBACCESS_HTML  "select poolname as \"Pool Name\",count(*) as \"Num. Tapes\" from lto_info group by poolname order by poolname;" | sed -e '/row)/d' -e '/rows)/d'



echo '</TABLE>'
echo '</CENTER>'
echo '</body></html>'
