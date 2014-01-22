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
#	Script that actually archive data (included by archive_file)
function exec_archive()
{
#	rsync log options
LOGOPT=" --log-file=/tmp/$WORKING_UUID.rsync.txt --log-file-format='%b|%f'"
#LOGOPT=" --log-file=/tmp/$WORKING_UUID.rsync.txt --log-file-format='%b|%f' --progress"
#	Script starts with checksum_passed flag set to true ad rsync exit code to zero
#	CHECKSUM_PASSED will be set to false if a match fails
#	STEPx_RC will be trapped after archive rsync commands
CHECKSUM_PASSED=true
STEP1_RC=0
STEP2_RC=0
#	Start archive process
#	Archive uses a "two-stpes" rsync method
#		First run copies file(s) that match with "index rule" of the LTFS 
#		It is executed only whet item is a directory
if ( [ ${UUID_DATA[0]} == "F" ] || [ ${UUID_DATA[0]} == "f" ] ); then
	main_logger 1 "Rsync 1st step not needed"
else
	main_logger 0 "Starting rsync for uuid=$WORKING_UUID - phase 1"
	main_logger 1 "Phase 1 rsync command: $CMD_RSYNC $UUID_DATA_SOURCE $TEMP_TARGET $( get_rsync_rules ) $LOGOPT"
	bash -c "$CMD_RSYNC \"$UUID_DATA_SOURCE\" $TEMP_TARGET $( get_rsync_rules ) $LOGOPT > /tmp/$WORKING_UUID.copylist 2>&1"
	STEP1_RC=$?
fi
#		Second (or only) run copies remaining file(s) or the only file to be archived
if [ $STEP1_RC == 0 ]; then
	main_logger 1 "Rsync 1st step OK"
	main_logger 1 "Phase 2 rsync command: $CMD_RSYNC $UUID_DATA_SOURCE $TEMP_TARGET $LOGOPT"
	main_logger 0 "Starting rsync for uuid=$WORKING_UUID - phase 2"
	bash -c "$CMD_RSYNC \"$UUID_DATA_SOURCE\" $TEMP_TARGET $LOGOPT >> /tmp/$WORKING_UUID.copylist 2>&1"
	STEP2_RC=$?
	#	IF archive was succesfully completed
	if [ $STEP2_RC == 0 ]; then
		#	forward status to 55 (post archive operations)
		cat /tmp/$WORKING_UUID.copylist >>$MAIN_LOG_FILE
		update_uuid_status $WORKING_UUID 55
		main_logger 1 "Rsync 2nd step OK"
		main_logger 1 "Generating flocat list"
		main_logger 4 "a) filelist (find)"
		#	work on rsync log to extract the list of copied files
		#		awk '!x[$0]++' (good tricK!) suppress redundant lines
		grep "`echo "$UUID_DATA_SOURCE" | sed -e 's/^\/*//'`" /tmp/$WORKING_UUID.rsync.txt | \
		awk '{for(i=4;i<=NF;++i) printf $i" "; printf "\n"}' | sed -e 's/^[0-9]*|//' -e "s;^;/;" | \
		sed -e "s;`dirname "$UUID_DATA_SOURCE"`;$TEMP_TARGET;" -e 's/[ \t]*$//' -e "s/'//g" |  awk '!x[$0]++'> /tmp/$WORKING_UUID.md5.list
		#	Count archived files 
		NUMLINES=`wc -l /tmp/$WORKING_UUID.md5.list | awk '{print $1}'`
		main_logger 4 "b) loop start"
		#	unsts variable that will keep FLocat's
		unset FLOCATLIST
		#Setto IFS su newliney
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		#	Raed each line of the filelist to get information about file...
		for ((LINE_IDX=1; LINE_IDX<=$NUMLINES; LINE_IDX+=1));do
		        archfile=( `head -$LINE_IDX /tmp/$WORKING_UUID.md5.list | tail -1` )
			#	Creation of the FLocat string
			SINGLE_FLOCAT=`echo "${archfile}" | sed -e 's;'$TEMP_TARGET/\`basename "${UUID_DATA_SOURCE}"\`';'$FLOCAT';'`
			#	If the item is a directory, it's size is zero and checksum has not too be computed
			#	If the item is a file, size and lastmod are read and put into FLocat
			if [ -d "${archfile}" ]; then		#	
				FLOCATLIST=$FLOCATLIST"\t\t\t"'<FLocat xlink:href="'${SINGLE_FLOCAT}'" size="0"/>'"\n"
			else
				archivedsize=`du -ksb "${archfile}" | awk '{print $1}'`
				archivedlastmod=`stat "${archfile}" -c %y | sed -e 's/\..*//' | tr ' ' 'T'`
				#	If non checksum is neede, a "simple <Flocat> is generated
				#	Otherwise, requested checksum operation and <Flocat> creation) is performed
				if [ $CHECKSUMCREATE == "N" ]; then
					FLOCATLIST=$FLOCATLIST"\t\t\t"'<FLocat xlink:href="'${SINGLE_FLOCAT}'" size="'$archivedsize'" lastModified="'$archivedlastmod'"/>'"\n"
				else
					MANAGE_STATUS="OK"
					main_logger 4 "calling manage_checksum"
					manage_checksum
				fi
			fi
		done
		#	restore IFS value
		IFS=$SAVEIFS
		#	remove temporary lists
		rm -f /tmp/$WORKING_UUID.md5.list
		rm -f /tmp/$WORKING_UUID.rsync.txt
	else
		#	RSYNC Step2 failed -> fallout task (copylist is appended to log)
		cat /tmp/$WORKING_UUID.copylist >>$MAIN_LOG_FILE
		main_logger 0 "Rsync 2nd step error: $STEP1_RC"
		#	lo valorizzo comunque per evitare errori a bc
	fi
else
	#	RSYNC Step1 failed -> fallout task (copylist is appended to log)
	cat /tmp/$WORKING_UUID.copylist >>$MAIN_LOG_FILE
	main_logger 0 "Rsync 1st step error: $STEP1_RC"
fi
#	Global RC
COPY_RC=`echo "$STEP1_RC + $STEP2_RC" | bc`
#	remove copylist file (a copy is stored into logfile)
[ -f  /tmp/$WORKING_UUID.copylist ] && rm /tmp/$WORKING_UUID.copylist
#	if created, remove temporary copy of checksumfile supplied
[ -f /tmp/$WORKING_UUID.checksumsupplied.txt ] && rm -f /tmp/$WORKING_UUID.checksumsupplied.txt
}
#	Function that requeue a task
function requeue_uuid
{
$CMD_DB "update requests set status='wait',substatus=0,ltolibrary='NONE',device='n/a',errordescription=NULL,errorcode=NULL,manager='$LTFSARCHIVER_MODE',ltotape='n/a' WHERE uuid = '$WORKING_UUID';" \
	> /dev/null 2>&1
}

