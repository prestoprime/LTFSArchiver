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
echo '<hr>'
echo '<CENTER><b>Pending jobs</CENTER>'
echo '<a href="requestlist.cgi?all" target=work>All types</a><br>'
echo '<a href="requestlist.cgi?archive" target=work>Archive</a><br>'
echo '<a href="requestlist.cgi?restore" target=work>Restore</a><br>'
echo '<a href="requestlist.cgi?makeaval" target=work>Make available</a><br>'
echo '<a href="requestlist.cgi?format" target=work>Format</a><br>'
echo '<a href="requestlist.cgi?checkspace" target=work>Check space</a><br>'
}
. $CFGFILE
VERSION=$LTFSARCHIVER_VERSION
TEMP=$HTTP_USERID
echo 'Content-Type: text/html'
echo ''
echo '<html>'
echo '<head>'
echo '<meta content="text/html; charset=iso-8859-1"'
echo 'http-equiv="Content-Type">'
echo '<title></title>'

echo "<script>
function submit_refresh(formname)
{
   // Allows to submit the form and to refresh the page after a while (combo field are filled again with new values)
   document.forms[formname].submit();
   setTimeout('document.location.reload()',300)
}
</script>"

echo "<style TYPE=\"text/css\">"
echo " body{font-style:normal;font-family:\"Verdana\";font-size:0.875em;}"
echo " td{font-style:normal;font-family:\"Verdana, Arial, Helvetica, sans-serif\";font-size:0.875em;text-align:center;}"
echo " input {height: 20px;}"
echo " select {height: 20px;}"
echo "</style>"


echo '</head>'
echo '<body bgcolor="#FFFFCC" link="#000099" vlink="#000099">'
echo '<hr>'
echo "<CENTER>LTFSArchiver - Ver. $VERSION"
echo '<BR>'
#echo 'Welcome, '$TEMP'<br><br>'
echo 'Welcome, '$REMOTE_USER'<br><br>'
echo "Menu ("
case $LTFSARCHIVER_MODE in
	"C"|"c")
		echo "Changer mode)"
	;;
	"M"|"m")
		echo "Manual mode)"
	;;
	"B"|"b")
		echo "Mixed mode)"
	;;
esac
echo '</CENTER>'

message=`service ltfsarchiver status`
errorcode="$?"
if [ "$errorcode" -ne "0" ];then
	echo '<hr>'
	echo '<CENTER><b>'
	echo '<pre title="Please start the service: service ltfsarchiver start via command line !!" style="background-color:red;font-size:1.2em;text-decoration: blink">'
	echo '  ltfsarchiver daemon is DOWN !  </pre>'
	echo '</CENTER>'
fi

if [ "$LTFSARCHIVER_MODE" != "C" -a "$LTFSARCHIVER_MODE" != "c" ];then
	show_pending_menu
fi

echo '<hr>'
echo '<CENTER><b>Active jobs</CENTER>'
echo '<a href="frameactivelist.cgi?all" target=work>All types</a><br>'
echo '<a href="frameactivelist.cgi?archive" target=work>Archive</a><br>'
echo '<a href="frameactivelist.cgi?restore" target=work>Restore</a><br>'
echo '<a href="frameactivelist.cgi?makeaval" target=work>Make available</a><br>'
echo '<a href="frameactivelist.cgi?format" target=work>Format</a><br>'
echo '<a href="frameactivelist.cgi?checkspace" target=work>Check Space</a><br>'

echo '<hr>'


echo '<CENTER><b>Tape management</b></CENTER>'
echo '<br>'
echo '<A HREF="../../frametapemanager.html" target=work>Pools and tapes</A>'

echo '<br>'

# Make Tapes Available
echo '<A HREF="../../framemakeavailable.html" target=work>Makeavailable manager</A>'

# Device Monitoring
echo '<P>'
echo '<hr>'
echo '<CENTER><b>Device monitoring</b></CENTER>'
echo '<P>'
echo '<a href="showdrives.cgi" target=work>Tape devices status</a><br>'
echo '</body>'
echo '</html>'
