#  PrestoPRIME  LTFSArchiver
#  Version: 1.3
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
#       Checksum management
#               Commands to be used, test to pe performed, etc-
################################################################################################
#	
CHECKSUMCREATE=${UUID_DATA[2]}
case $CHECKSUMCREATE in
	"MD5"|"MD5_both"|"SHA1"|"SHA1_both")
		#	Determine the checksum method (SHA1 vs MD5)
		CHECKSUMTYPE=`echo $CHECKSUMCREATE | sed -e 's/_/ /' | awk '{print $1}'`
		tmp="CMD_"$CHECKSUMTYPE
		CHECKSUMCMD=${!tmp}
		#	xxx_both -> match test has to be executed
		#	otherwise -> no match test has to be executed
		if [ "`echo $CHECKSUMCREATE | sed -e 's/_/ /' | awk '{print $2}'`" == "both" ]; then
			MATCHTEST="Y"
		else
			MATCHTEST="N"
		fi
	;;
	"FILE")
		#	calculated checksum will be tested against a supplied value
		#	name of the file supplied
		#		exixtence of file and first line syntax have been checked by WriteToLTO API
		CHECKSUMSUPPLIED=`$CMD_DB"select checksumfile from requests where uuid='$WORKING_UUID'" | sed -e 's/^[ \t]*//'`
		#	Determine the checksum method (SHA1 vs MD5)
		CHECKSUMTYPE=`head -1 $CHECKSUMSUPPLIED | sed -e 's/^#//'`
		tmp="CMD_"$CHECKSUMTYPE
		CHECKSUMCMD=${!tmp}
		MATCHTEST="FILE"
		#	Creation of a temp file... FLocat is sedded to recreate the absolute pathname of each file
		case  ${UUID_DATA[0]} in
			"D"|"d")
				grep -v '^#' "$CHECKSUMSUPPLIED" | sed -re '/\*lto/s;\*lto.*:.*:.{36};\*'`dirname "$UUID_DATA_SOURCE"`';' > /tmp/$WORKING_UUID.checksumsupplied.txt
			;;
			"F"|"f")
				grep -v '^#' "$CHECKSUMSUPPLIED" | sed -e 's;\*.*;\*'$UUID_DATA_SOURCE';' > /tmp/$WORKING_UUID.checksumsupplied.txt
			;;
		esac

	;;
	"N")	#	Checksums will not be calculated nor matched
		MATCHTEST="N"
	;;
esac
#	Log of checksum management parms
main_logger 2 "######### Checksum management for taskid: $WORKING_UUID"
main_logger 2 "- CHECKSUMCREATE: $CHECKSUMCREATE"
main_logger 2 "- CHECKSUMTYPE: $CHECKSUMTYPE"
main_logger 2 "- MATCHTEST: $MATCHTEST"
[ $CHECKSUMCREATE == "FILE" ]  && main_logger 2 "- CHECKSUMSUPPLIED: $CHECKSUMSUPPLIED"
main_logger 2 "######################################################################"
}

function manage_checksum()
{
#	On-tape-saved file checksuma -> temp_chsum_saved
main_logger 1 "creating checksum value for saved file: $archfile"
temp_chsum_saved=`$CHECKSUMCMD "$archfile" | cut -d ' ' -f 1`
#	datetime of check... it will be stored
checktime=`date +'%Y-%m-%dT%H:%M:%S'`
#	what about tests and matches?
case $MATCHTEST in
	"N")	#	No further action is required. Creates a Flocat with minimun info set
		main_logger 1 "source file checksum not required"
		#	Scrivo su output
		FLOCATLIST=$FLOCATLIST"\t\t\t"'<FLocat xlink:href="'${SINGLE_FLOCAT}'" size="'$archivedsize'" lastModified="'$archivedlastmod'">'
		FLOCATLIST=$FLOCATLIST"\n\t\t\t\t"'<checksum type="'$CHECKSUMTYPE'" value="'$temp_chsum_saved'"/>'
		MATCH_RESULT="none"
		checkmatchok="Y"
	;;
	"Y")	#	Match test against source. Source checksum calculation -> temp_chsum_source
		main_logger 1 "creating checksum value for source file $sourcefile"
		sourcefile=`echo "$archfile" | sed -e 's;'$TEMP_TARGET';'\`dirname $UUID_DATA_SOURCE\`';'`
		temp_chsum_source=`$CHECKSUMCMD "$sourcefile" | cut -d ' ' -f 1`
		#	Do they match?
		if [ $temp_chsum_saved == $temp_chsum_source ]; then
			#	YES, create a "matching" Flocat
			good_checksum_match
		else
			#	NO, create a "matching" Flocat where file is renamed as ".corrupted"
			bad_checksum_match
		fi
	;;
	"FILE")	#	Look into the supplied checksum list to find the expected value
		#		Beginning with setting filename too be searched
		sourcefile=`echo "$archfile" | sed -e 's;'$TEMP_TARGET';'\`dirname $UUID_DATA_SOURCE\`';'`	#	Path del file sorgente
		main_logger 1 "reading checksum value for source file: $sourcefile"
		#		Gree in to the list...
		temp_chsum_source=`cat /tmp/$WORKING_UUID.checksumsupplied.txt | grep -v "^#" | grep -F "$sourcefile" | cut -d ' ' -f 1`
		#		Log values
		main_logger 2 "SUPPLIED VALUES - FILE: ""$sourcefile"" - Checksum: *$temp_chsum_source*"
		main_logger 2 "CALCULATED VALUES - FILE: ""$archfile"" - Checksum: $temp_chsum_saved"
		#	Maybe a file (new one?) has been archived bat not referenced in the checksum supplied list
		if [ -z $temp_chsum_source ]; then
			#	create a "unverified" Flocat where file is renamed as ".unverified"
			unverified_checksum
		else
			#	Do they match?
			if [ "$temp_chsum_source" == $temp_chsum_saved ]; then
				#	YES, create a "matching" Flocat
				good_checksum_match
			else
				#	NO, create a "matching" Flocat where file is renamed as ".corrupted"
				bad_checksum_match
			fi
		fi
	;;
esac
#	FLocat TAG closing
FLOCATLIST=$FLOCATLIST"\n\t\t\t"'</FLocat>'"\n"
}
######################################################################################################
function good_checksum_match()				
{
#	FLOCATLIST feed
FLOCATLIST=$FLOCATLIST"\t\t\t"'<FLocat xlink:href="'${SINGLE_FLOCAT}'" size="'$archivedsize'" lastModified="'$archivedlastmod'">'
FLOCATLIST=$FLOCATLIST"\n\t\t\t\t"'<checksum type="'$CHECKSUMTYPE'" expectedvalue="'$temp_chsum_source'" value="'$temp_chsum_saved'" lastChecked="'$checktime'" match="true"/>'
MATCH_RESULT="true"
checkmatchok="Y"
}

#----------------------------------------------------------------------------
function bad_checksum_match()
{
mv "$archfile" "$archfile.corrupted"
#	FLOCATLIST feed
FLOCATLIST=$FLOCATLIST"\t\t\t"'<FLocat xlink:href="'${SINGLE_FLOCAT}'.corrupted" size="'$archivedsize'" lastModified="'$archivedlastmod'">'
FLOCATLIST=$FLOCATLIST"\n\t\t\t\t"'<checksum type="'$CHECKSUMTYPE'" expectedvalue="'$temp_chsum_source'" value="'$temp_chsum_saved'" lastChecked="'$checktime'" match="false"/>'
#	Error rising switches
MATCH_RESULT="false"
checkmatchok="N"
MANAGE_STATUS="ERR"
CHECKSUM_PASSED=false
}

#-----------------------------------------------------------
function unverified_checksum()
{
mv "$archfile" "$archfile.unverified"
#	FLOCATLIST feed
FLOCATLIST=$FLOCATLIST"\t\t\t"'<FLocat xlink:href="'${SINGLE_FLOCAT}'.unverified" size="'$archivedsize'" lastModified="'$archivedlastmod'">'
FLOCATLIST=$FLOCATLIST"\n\t\t\t\t"'<checksum type="'$CHECKSUMTYPE'" value="'$temp_chsum_saved'"/>'
#	Warning rising switches
checkmatchok="U"
}
