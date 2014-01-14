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
echo 'Content-Type: text/html'
echo ''
echo '<html>'
echo '<head>'
echo '<meta content="text/html; charset=iso-8859-1"'
echo 'http-equiv="Content-Type">'
echo '<title></title>'

echo "<script>
function toggle()
{
   // This hides one and reveal the other input field
   var tmp = document.getElementById('poolcombo').style.display;
   document.getElementById('poolcombo').style.display = document.getElementById('pooltext').style.display;
   document.getElementById('pooltext').style.display = tmp; 
   // This allows to send just one valid PoolName attribute to the POST
   //alert(document.getElementById('selpool').getAttribute('name'));
   //alert(document.getElementById('inpool').getAttribute('name'));
   if ( document.getElementById('inpool').getAttribute('name') == 'PoolName_fake' ){
	document.getElementById('inpool').setAttribute('name','PoolName');
	document.getElementById('selpool').setAttribute('name','PoolName_fake');
   }
   else{
	document.getElementById('inpool').setAttribute('name','PoolName_fake');
	document.getElementById('selpool').setAttribute('name','PoolName');
   }
}

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
#echo '<font size="2" face="Verdana, Arial, Helvetica, sans-serif">'
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
echo '<a href="activelist.cgi?all" target=work>All types</a><br>'
echo '<a href="activelist.cgi?archive" target=work>Archive</a><br>'
echo '<a href="activelist.cgi?restore" target=work>Restore</a><br>'
echo '<a href="activelist.cgi?makeaval" target=work>Make available</a><br>'
echo '<a href="activelist.cgi?format" target=work>Format</a><br>'
echo '<a href="activelist.cgi?checkspace" target=work>Check Space</a><br>'

echo '<hr>'
echo '<CENTER><b>Tape management</CENTER>'
echo '<a href="list_pools.cgi" target=work>List Pools</a><br>'
echo '<P>'

# List tapes
pool_list=( `$DBACCESS  "select distinct(poolname) from lto_info order by poolname;"` )
echo '<FORM action="../QueryKnownTapes" method="get" target="work">'
echo '   <table width="100%" border="1">'
echo '      <tr>'
echo '        <td width="10%" rowspan=2><b>List Tapes</td>'
echo '        <td width="80%" align="center">Pool</td>'
echo '        <td></td>'
echo '      </tr>'
echo '      <tr>'
echo '        <td align="center"><select name="PoolName">'
echo "               <option value=\"\">all</option>"
i=0
while [ "$i" -lt "${#pool_list[@]}" ];do
	echo "      <option value=\"${pool_list[$i]}\">${pool_list[$i]}</option>"
	let i+=1
done
echo '        </select>'
echo '        </td>'
echo '        <td><button type="submit">Submit</button></td>'
echo '      </tr>'
echo '   </table>'
echo '</FORM>'
echo '<P>'


# Add a Tape to a pool
echo '<FORM action="../TapeManager" method="get" target="work" name="addform">'
echo '   <input type="hidden" name="Command" value="Add">'
echo '   <input type="hidden" name="LTOType" value="LTO5">'
echo '   <table width="100%" border=1>'
echo '      <tr>'
echo '        <td width="10%" rowspan=2><b>Add Tape<br></td>'
echo '        <td>TapeId</td>'
echo '        <td onclick="toggle()">Pool</td>'
echo '        <td colspan=2>Format Y/N</td>'
echo '        <td></td>'
echo '      </tr>'
echo '      <tr>'
echo '        <td><input name="TapeID" type="text" size=8></td>'
echo '        <td><div id="poolcombo" style="display: inline">'
echo '            <select id="selpool" name="PoolName">'
i=0
while [ "$i" -lt "${#pool_list[@]}" ];do
        echo "          <option value=\"${pool_list[$i]}\">${pool_list[$i]}</option>"
        let i+=1
done
echo '            </select>'
echo '            </div>'
echo '            <div id="pooltext" style="display: none">'
#echo '               <input id="inpool" type="text" name="PoolName" size=8 >'
echo '               <input id="inpool" name="PoolName_fake" type="text" size=8 >'
echo '            </div>'
echo '        </td>'
echo '        <td>'
echo '         <input type="radio" name="Format" value="Y" checked>Yes</input>'
echo '        </td>'
echo '        <td>'
echo '         <input type="radio" name="Format" value="N">No</input>'
echo '        </td>'
#echo '      <td><button type="submit">Submit</button></td>'
echo "        <td><input type=\"button\" value=\"Submit\" onClick=\"submit_refresh('addform');\"></td>"
echo '      </tr>'
echo '   </table>'
echo '</FORM>'



##  Remove tape from pool (Withdraw)
tape_list=( `$DBACCESS  "select label,poolname from lto_info where ltotype <> 'n/a' order by label;"` )
echo '<FORM action="../TapeManager" method="get" target="work" name="removeform">'
echo '   <input type="hidden" name="Command" value="Withdraw">'
echo '   <table width="100%" border="1">'
echo '      <tr>'
echo '        <td width="10%" rowspan=2><b>Remove Tape<br></td>'
echo '        <td width="80%" align="center">TapeID-Pool</td>'
echo '        <td></td>'
echo '      </tr>'
echo '      <tr>'
echo '        <td align="center">'
echo '          <select name="TapeID">'
i=0
while [ "$i" -lt "${#tape_list[@]}" ];do
	let "j = i + 2"
	pool=${tape_list[$j]}
        echo "      <option value=\"${tape_list[$i]}\">${tape_list[$i]} - $pool</option>"
        let i+=3
done
echo '          </select>'
echo '        </td>'
#echo '        <td><button type="submit">Submit</button></td>'
echo "        <td><input type=\"button\" value=\"Submit\" onClick=\"submit_refresh('removeform');\"></td>"
echo '      </tr>'
echo '   </table>'
echo '</FORM>'


# Make Tapes Available
echo '<P>'
echo '<hr>'
echo '<CENTER><b>Make Tape Available</CENTER>'
echo '<P>'
echo '<a href="activemake.cgi" target=work>Currently available LTO Tapes</a><br>'
echo '<FORM action="../MakeAvailable" method="get" target="work" >'
echo '   <input type="hidden" name="Command" value="Mount">'
echo '   <table width="100%" border="1">'
echo '      <tr>'
echo '        <td width="20%"><b>Tape Mount<br></td>'
echo '        <td width="70%">'

echo '          <select name="TapeID">'
i=0
while [ "$i" -lt "${#tape_list[@]}" ];do
        let "j = i + 2"
        pool=${tape_list[$j]}
        echo "      <option value=\"${tape_list[$i]}\">${tape_list[$i]} - $pool</option>"
        let i+=3
done
echo '          </select>'
echo '        </td>'
echo '        <td><button type="submit">Submit</button></td>'
echo '      </tr>'
echo '   </table>'
echo '</FORM>'

tape_list=( `$DBACCESS  "select t.label,t.poolname  from requests r, lto_info t  where r.ltotape=t.label and t.inuse='A' and substatus=60 and  r.id=(select max(id) from requests where ltotape=r.ltotape) order by r.ltotape;"` )
echo '<FORM action="../MakeAvailable" method="get" target="work" >'
echo '   <input type="hidden" name="Command" value="Unmount">'
echo '   <table width="100%" border="1">'
echo '      <tr>'
echo '        <td width="20%"><b>Tape UnMount<br></td>'
if [ "${#tape_list[@]}" -eq "0" ];then
	echo '<td width="70%">No tape currently mounted</td>'
else
	echo '        <td width="70%">'
	echo '          <select name="TapeID">'
	i=0
	while [ "$i" -lt "${#tape_list[@]}" ];do
	        let "j = i + 2"
	        pool=${tape_list[$j]}
	        echo "      <option value=\"${tape_list[$i]}\">${tape_list[$i]} - $pool</option>"
	        let i+=3
	done
	echo '          </select>'
	echo '        </td>'
fi
echo '        <td><button type="submit">Submit</button></td>'
echo '      </tr>'
echo '   </table>'
echo '</FORM>'


# Device Monitoring
echo '<P>'
echo '<hr>'
echo '<CENTER><b>Device monitoring</CENTER>'
echo '<P>'
echo '<a href="showdrives.cgi" target=work>Tape devices status</a><br>'
echo '</body>'
echo '</html>'
