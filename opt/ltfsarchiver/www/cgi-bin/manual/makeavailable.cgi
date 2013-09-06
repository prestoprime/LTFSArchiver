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
echo '<b>MakeAvailable management</b>'
echo '<hr><br>'

echo '<a href="activemake.cgi" target=result>Currently available LTO Tapes</a><br>'
echo '<P>'
tape_list=( `$CMD_DB  "select label,poolname from lto_info where ltotype <> 'n/a' order by label;"` )
echo '<FORM action="../MakeAvailable" method="get" target="result" >'
echo '   <input type="hidden" name="Command" value="Mount">'
echo '   <input type="hidden" name="FromGUI" value="true">'
echo '   <table width="60%" border="1">'
echo '      <tr>'
echo '        <td width="20%"><b>Tape Mount<br></td>'
echo '        <td width="70%">'

echo '          <select name="TapeID">'
for ((i=0; i<${#tape_list[@]};i+=3));do
	#	NON deve essere inuse='A' o avere richieste in wait di tipo 'A'
	INUSE=`$CMD_DB" select inuse from lto_info where label='${tape_list[$i]}';" | sed -e 's/^ *//'`
	BOOKED=`$CMD_DB" select count (*) from requests where ltotape='${tape_list[$i]}' and operation='A' and status='wait';" | sed -e 's/^ *//'`
	 if ( [ "$INUSE" != "A" ] && [ $BOOKED == 0 ] ); then
		let "j = i + 2"
		pool=${tape_list[$j]}
		echo "      <option value=\"${tape_list[$i]}\">${tape_list[$i]} - $pool</option>"
	fi
done
echo '          </select>'
echo '        </td>'
echo '        <td><button type="submit">Submit</button></td>'
echo '      </tr>'
echo '   </table>'
echo '</FORM>'
#	Lista dei tape montati come makeaval
tape_mounted=( `mount | grep $LTFSARCHIVER_MNTAVAIL | cut -d ' ' -f 3 | sed -e 's;'$LTFSARCHIVER_MNTAVAIL'/;;' | sort | tr '\n' ' '` )
unset tape_list
for ((j=0;j<${#tape_mounted[@]};j++)); do
	#	verifico su db
	is_mounted_avail=( `$CMD_DB "select poolname, inuse from lto_info where label='${tape_mounted[$j]}';" | tr -d ' ' | tr '|' ' '` )
	#	Se effettivamente inuse=A allora li espongo
	if [ "${is_mounted_avail[1]}" == "A" ]; then
		#	Controllo prima che non ci sia una richiesta di unmount
		u_request=`$CMD_DB "select count(*) from requests where operation='U' and substatus<60 and ltotape='${tape_mounted[$j]}'"`
		[ $u_request == 0 ] && tape_list=( "${tape_list[@]}" "${tape_mounted[$j]}" "${is_mounted_avail[0]}" )
	fi
	
done
#tape_list=( `$CMD_DB  "select t.label,t.poolname  from requests r, lto_info t  where r.ltotape=t.label and t.inuse='A' and r.substatus=60 and r.id=(select max(id) from requests where substatus=60 and ltotape=r.ltotape) order by r.ltotape;"` )
echo '<FORM action="../MakeAvailable" method="get" target="result" >'
echo '   <input type="hidden" name="Command" value="Unmount">'
echo '   <input type="hidden" name="FromGUI" value="true">'
echo '   <table width="60%" border="1">'
echo '      <tr>'
echo '        <td width="20%"><b>Tape UnMount<br></td>'
if [ "${#tape_list[@]}" -eq "0" ];then
	echo '<td width="70%">No tape currently mounted</td>'
else
	echo '        <td width="70%">'
	echo '          <select name="TapeID">'
	for ((i=0; i<${#tape_list[@]};i+=2));do
	        let "j = i + 1"
	        pool=${tape_list[$j]}
	        echo "      <option value=\"${tape_list[$i]}\">${tape_list[$i]} - $pool</option>"
	done
	echo '          </select>'
	echo '        </td>'
fi
echo '        <td><button type="submit">Submit</button></td>'
echo '      </tr>'
echo '   </table>'
echo '</FORM>'


echo '</body>'
echo '</html>'
