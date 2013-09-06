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
echo '<CENTER>'
echo '<b>Tape management</b>'
echo '<hr><br>'
echo '<a href="list_pools.cgi" target=result>List Pools</a><br>'
echo '<P>'

# List tapes
pool_list=( `$CMD_DB  "select distinct(poolname) from lto_info order by poolname;"` )
echo '<FORM action="../QueryKnownTapes" method="get" target="result">'
echo '   <table width="60%" border="1">'
echo '      <tr>'
echo '        <td width="10%" rowspan=2><b>List Tapes</td>'
echo '        <td width="80%" align="center">Pool</td>'
echo '        <td></td>'
echo '      </tr>'
echo '      <tr>'
echo '        <td align="center"><select name="PoolName">'
echo "               <option value=\"\">all</option>"
for ((i=0; i<${#pool_list[@]};i++));do
	echo "      <option value=\"${pool_list[$i]}\">${pool_list[$i]}</option>"
done
echo '        </select>'
echo '        </td>'
echo '        <td><button type="submit">Submit</button></td>'
echo '      </tr>'
echo '   </table>'
echo '</FORM>'
echo '<P>'


# Add a Tape to a pool
echo '<FORM action="../TapeManager" method="get" target="result" name="addform">'
echo '   <input type="hidden" name="Command" value="Add">'
echo '   <input type="hidden" name="FromGUI" value="true">'
echo '   <table width="60%" border=1>'
echo '      <tr>'
echo '        <td width="10%" rowspan=2><b>Add Tape<br></td>'
echo '        <td>TapeId</td>'
echo '        <td onclick="toggle()">Pool</td>'
echo '        <td colspan=3>Format option</td>'
echo '        <td></td>'
echo '      </tr>'
echo '      <tr>'
echo '        <td><input name="TapeID" type="text" size=8></td>'
echo '        <td><div id="poolcombo" style="display: inline">'
echo '            <select id="selpool" name="PoolName">'
for ((i=0; i<${#pool_list[@]};i++));do
        echo "          <option value=\"${pool_list[$i]}\">${pool_list[$i]}</option>"
done
echo '            </select>'
echo '            </div>'
echo '            <div id="pooltext" style="display: none">'
echo '               <input id="inpool" name="PoolName_fake" type="text" size=8 >'
echo '            </div>'
echo '        </td>'
echo '        <td>'
echo '         <input type="radio" name="Format" value="N" checked>No</input>'
echo '        </td>'
echo '        <td>'
echo '         <input type="radio" name="Format" value="Y">Yes</input>'
echo '        </td>'
echo '        <td>'
echo '         <input type="radio" name="Format" value="F">Force</input>'
echo '        </td>'
echo "        <td><input type=\"button\" value=\"Submit\" onClick=\"submit_refresh('addform');\"></td>"
echo '      </tr>'
echo '   </table>'
echo '</FORM>'



##  Remove tape from pool (Withdraw)
tape_list=( `$CMD_DB  "select label,poolname from lto_info where ltotype <> 'n/a' order by label;"` )
echo '<FORM action="../TapeManager" method="get" target="result" name="removeform">'
echo '   <input type="hidden" name="Command" value="Withdraw">'
echo '   <input type="hidden" name="FromGUI" value="true">'
echo '   <table width="60%" border="1">'
echo '      <tr>'
echo '        <td width="10%" rowspan=2><b>Remove Tape<br></td>'
echo '        <td width="80%" align="center">TapeID-Pool</td>'
echo '        <td></td>'
echo '      </tr>'
echo '      <tr>'
echo '        <td align="center">'
echo '          <select name="TapeID">'
for ((i=0; i<${#tape_list[@]};i+=3));do
	let "j = i + 2"
	pool=${tape_list[$j]}
        echo "      <option value=\"${tape_list[$i]}\">${tape_list[$i]} - $pool</option>"
done
echo '          </select>'
echo '        </td>'
echo "        <td><input type=\"button\" value=\"Submit\" onClick=\"submit_refresh('removeform');\"></td>"
echo '      </tr>'
echo '   </table>'
echo '</FORM>'
echo '</CENTER>'

echo '</html>'
