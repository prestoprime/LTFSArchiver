#  PrestoPRIME  LTFSArchiver
#  Version: 1.0 Beta
#  Authors: L. Savio, L. Boch, R. Borgotallo
#
#  Copyritght (C) 2011-2012 RAI – Radiotelevisione Italiana <cr_segreteria@rai.it>
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
#============================================================================================================================================
function checksum_config()
{
################################################################################################
#       Gestione checksum
#               Comandi da usare, file da usare per confronto, etc
################################################################################################
CHECKSUMCREATE=${UUID_DATA[2]}
case $CHECKSUMCREATE in
	"MD5"|"MD5_both"|"SHA1"|"SHA1_both")
		CHECKSUMTYPE=`echo $CHECKSUMCREATE | sed -e 's/_/ /' | awk '{print $1}'`
		tmp="CMD_"$CHECKSUMTYPE
		CHECKSUMCMD=${!tmp}
		#	Devo testare i checksum?
		if [ "`echo $CHECKSUMCREATE | sed -e 's/_/ /' | awk '{print $2}'`" == "both" ]; then
			MATCHTEST="Y"
		else
			MATCHTEST="N"
		fi
	;;
	"FILE")
		#	file di checksumA
		CHECKSUMSUPPLIED=`$CMD_DB"select checksumfile from requests where uuid='$WORKING_UUID'" | sed -e 's/^[ \t]*//'`
		CHECKSUMTYPE=`head -1 $CHECKSUMSUPPLIED | sed -e 's/^#//'`
		tmp="CMD_"$CHECKSUMTYPE
		CHECKSUMCMD=${!tmp}

		MATCHTEST="FILE"

		#	creazione del file temporaneo con i checksum
		case  ${UUID_DATA[0]} in
			"D"|"d")
				grep -v '^#' "$CHECKSUMSUPPLIED" | sed -re '/\*lto/s;\*lto.*:.*:.{36};\*'`dirname "$UUID_DATA_SOURCE"`';' > /tmp/$WORKING_UUID.checksumsupplied.txt
			;;
			"F"|"f")
				grep -v '^#' "$CHECKSUMSUPPLIED" | sed -e 's;\*.*;\*'$UUID_DATA_SOURCE';' > /tmp/$WORKING_UUID.checksumsupplied.txt
			;;
		esac

	;;
	*)      #       Qualsiasi sia il valore impostato a cfg, NON salvo
		CHECKSUMSAVE="N"
		MATCHTEST="N"
	;;
esac
################################################################################################
#       Se checkumcreate e' diverso da false devo anche vedere se devo creare il file
#               conteneente i checksum e che verra' poi copiato sul nastro
################################################################################################
if [ $CHECKSUMCREATE == "none" ]; then
	main_logger 1 "No checksum mode/type requested: report file not to be created"
else
	CHECKSUMSAVE="Y"
	main_logger 1 "Checksum file requested ($CHECKSUMFMT format)"
fi
main_logger 2 "######### Checksum management for taskid: $WORKING_UUID"
main_logger 2 "- CHECKSUMCREATE: $CHECKSUMCREATE"
main_logger 2 "- CHECKSUMTYPE: $CHECKSUMTYPE"
main_logger 2 "- CHECKSUMSAVE: $CHECKSUMSAVE"
main_logger 2 "- CHECKSUMFMT: $CHECKSUMFMT"
main_logger 2 "- MATCHTEST: $MATCHTEST"
main_logger 2 "- CHECKSUMSUPPLIED: $CHECKSUMSUPPLIED"
main_logger 2 "- CHECKSUM_CFG_OK: $CHECKSUM_CFG_OK"
main_logger 2 "######################################################################"
}

function manage_checksum()
{
#	Quello del file salvato lo calcolo comunque
main_logger 1 "creating checksum value for saved file: $archfile"
temp_chsum_saved=`$CHECKSUMCMD "$archfile" | cut -d ' ' -f 1`

case $MATCHTEST in
	"N")
		main_logger 1 "source file checksum not required"
		#	Scrivo su output
		#	xml
		echo -e "\t\t"'<checksum type="'$CHECKSUMTYPE'" value="'$temp_chsum_saved'" />' >> $XmlOutput
		#	json
		echo '"checksum":{"type":"'$CHECKSUMTYPE'","value":"'$temp_chsum_saved'"}}' >>$JsonOutput
		MATCH_RESULT="none"
		checkmatchok="Y"
	;;
	"Y")
		sourcefile=`echo "$archfile" | sed -e 's;'$TEMP_TARGET';'\`dirname $UUID_DATA_SOURCE\`';'`
		main_logger 1 "creating checksum value for source file $sourcefile"
		temp_chsum_source=`$CHECKSUMCMD "$sourcefile" | cut -d ' ' -f 1`
		##############################################################################################################
		##		RANDOM CHECKSUM
		#NUMBER=$[ ( $RANDOM % 3 ) ]
		#[ $NUMBER == 0 ] && temp_chsum_source=$temp_chsum_source"FAKE"
		##		RANDOM CHECKSUM
		##############################################################################################################
		#	match?
		if [ $temp_chsum_saved == $temp_chsum_source ]; then
			good_checksum_match
		else
			#	1) Rinominare il file target in .corrupted
			bad_checksum_match
		fi
	;;
	"FILE")		#	cat inputcfile.txt | grep -v "^#" | sed -re '/\*lto/s;\*lto.*:.*:.{36};\*/var/pippo;' | grep /var/pippo/testdirvuoti/conspazi/lower.txt | cut -d ' ' -f 1
		sourcefile=`echo "$archfile" | sed -e 's;'$TEMP_TARGET';'\`dirname $UUID_DATA_SOURCE\`';'`	#	Path del file sorgente
		main_logger 1 "reading checksum value for source file: $sourcefile"
		#	Devo cercare sul file che mi e' stato passato...
		temp_chsum_source=`cat /tmp/$WORKING_UUID.checksumsupplied.txt | grep -v "^#" | grep -F "$sourcefile" | cut -d ' ' -f 1`
		#SUPPLIEDVALUE=`cat $CHECKSUMSUPPLIED | grep -v "^#" | grep -F "$sourcefile" | cut -d ' ' -f 1`
		main_logger 2 "SUPPLIED VALUES - FILE: ""$sourcefile"" - Checksum: *$temp_chsum_source*"
		main_logger 2 "CALCULATED VALUES - FILE: ""$archfile"" - Checksum: $temp_chsum_saved"
		#	Combinano?
		#	se il valore fornito e' nullo ------>UNVERIFIED
		if [ -z $temp_chsum_source ]; then
			#	1) Rinominare il file target in .unverified
			unverified_checksum
			#	Alzo il flag che a fine lavoro mi fara' mettere il taskid in fallout (sentire prima BOCH)
		else
			if [ "$temp_chsum_source" == $temp_chsum_saved ]; then
				good_checksum_match
			else
				bad_checksum_match
			fi
		fi
	;;
esac
#	chiudo tag FLOCAT su xml
echo -e "\t</FLocat>" >> $XmlOutput
#	Aggiorno file coi checksum
if [ $CHECKSUMSAVE == "Y" ]; then
	#	Eventuale continuazione per JSON
	( [ "$CHECKSUMFMT" == "json" ] && [ $LINE_IDX -lt $NUMLINES ] ) && echo ',' >> $JsonOutput
fi
}
######################################################################################################
function good_checksum_match()				
{

#	json
echo '"checksum":{"type":"'$CHECKSUMTYPE'","expectedvalue":"'$temp_chsum_source'","value":"'$temp_chsum_saved'","match":"true"}}' >> $JsonOutput
#	xml
echo -e "\t\t"'<checksum type="'$CHECKSUMTYPE'" expectedvalue="'$temp_chsum_source'" value="'$temp_chsum_saved'" match="true"/>' >> $XmlOutput
MATCH_RESULT="true"
checkmatchok="Y"
}

#----------------------------------------------------------------------------
function bad_checksum_match()
{
mv "$archfile" "$archfile.corrupted"
#	2) Editare nei file di output il nome del file appendendo .corrupted
sed -e 's;'"$SINGLE_FLOCAT"';'"$SINGLE_FLOCAT.corrupted"';' -i $JsonOutput 
sed -e 's;'"$SINGLE_FLOCAT"';'"$SINGLE_FLOCAT.corrupted"';' -i $XmlOutput
#	json
echo '"checksum":{"type":"'$CHECKSUMTYPE'","expectedvalue":"'$temp_chsum_source'","value":"'$temp_chsum_saved'","match":"false"}}' >> $JsonOutput
#	xml
echo -e "\t\t"'<checksum type="'$CHECKSUMTYPE'" expectedvalue="'$temp_chsum_source'" value="'$temp_chsum_saved'" match="false"/>' >> $XmlOutput
MATCH_RESULT="false"
checkmatchok="N"
#	alzo gravita' a "error"
MANAGE_STATUS="ERR"
#	Alzo il flag che a fine lavoro mi fara' mettere il taskid in fallout
CHECKSUM_PASSED="N"
}

#-----------------------------------------------------------
function unverified_checksum()
{
#	2) Editare nei file di output il nome del file appendendo .unverified
mv "$archfile" "$archfile.unverified"
sed -e 's;'"$SINGLE_FLOCAT"';'"$SINGLE_FLOCAT.unverified"';' -i $JsonOutput 
sed -e 's;'"$SINGLE_FLOCAT"';'"$SINGLE_FLOCAT.unverified"';' -i $XmlOutput
#	json
echo '"checksum":{"type":"'$CHECKSUMTYPE'","expectedvalue":"'$temp_chsum_source'","value":"'$temp_chsum_saved'","match":"true"}}' >> $JsonOutput
#	xml
echo -e "\t\t"'<checksum type="'$CHECKSUMTYPE'" expectedvalue="'$temp_chsum_source'" value="'$temp_chsum_saved'" match="true"/>' >> $XmlOutput
#	4) appendere .unverified al flocat che eventualmente vado a salvare con "salva_checksum"
checkmatchok="U"
}
