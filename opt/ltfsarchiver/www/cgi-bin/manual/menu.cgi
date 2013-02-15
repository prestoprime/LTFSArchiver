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

function show_pending_menu()
{
echo '</CENTER><hr>'
echo '<CENTER>Pending jobs</CENTER>'
echo '<a href="requestlist.cgi?all" target=work>All types</a><br>'
echo '<a href="requestlist.cgi?archive" target=work>Archive</a><br>'
echo '<a href="requestlist.cgi?restore" target=work>Restore</a><br>'
echo '<a href="requestlist.cgi?makeaval" target=work>Make available</a><br>'
echo '<a href="requestlist.cgi?format" target=work>Format</a><br>'
echo '<a href="requestlist.cgi?checkspace" target=work>Check space</a><br>'
}
. $CFGFILE
VERSION=$LTFSARCHIVER
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
echo '<hr>'
echo "<CENTER>LTFSArchiver - Ver. $VERSION"
echo '<BR>'
echo "Menu ("
case $LTFSARCHIVER_MODE in
	"C"|"c")
		echo "Changer mode)"
	;;
	"M"|"m")
		echo "Manual mode)"
		show_pending_menu
	;;
	"B"|"b")
		echo "Mixed mode)"
		show_pending_menu
	;;
esac
echo '</CENTER><hr>'
echo '<CENTER>Active jobs</CENTER>'
echo '<a href="activelist.cgi?all" target=work>All types</a><br>'
echo '<a href="activelist.cgi?archive" target=work>Archive</a><br>'
echo '<a href="activelist.cgi?restore" target=work>Restore</a><br>'
echo '<a href="activelist.cgi?makeaval" target=work>Make available</a><br>'
echo '<a href="activelist.cgi?format" target=work>Format</a><br>'
echo '<a href="activelist.cgi?checkspace" target=work>Check space</a><br>'
echo '<hr>'
echo '<a href="showdrives.cgi" target=work>Tape devices status</a><br>'
echo '<hr>'
echo '<a href="activemake.cgi" target=work>Currently available ltotape</a><br>'
echo '</body>'
echo '</html>'

