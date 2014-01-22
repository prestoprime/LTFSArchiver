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

#-----------------------------------------------------------------------
#	DEVICES_CONFIG
#	creates arrays containg library and tapedevice config
function devices_config()
{
[ $1 == 1 ] && main_logger 3 "------------------------------------->>>    STEP 0 - CONFIGURATION"
[ $1 == 1 ] && main_logger 4 "========== Listing available tape devices ======================="
case $LTFSARCHIVER_MODE in
	"C"|"B")
		[ $1 == 1 ] && main_logger 3 "Found ${#CONF_CHANGER_DEVICES[@]} librarie(s):  ${CONF_CHANGER_DEVICES[@]}"
		for ((ccounter=0; ccounter<${#CONF_CHANGER_DEVICES[@]}; ccounter++)); do
			[ $1 == 1 ] && main_logger 4 "-----------------------------------------------------------------"
			[ $1 == 1 ] && main_logger 4 "Library $ccounter: ${CONF_CHANGER_DEVICES[$ccounter]}"
			tape_array_name="CONF_CHANGER_TAPEDEV_"$ccounter"[@]"
			temp_array=( ${!tape_array_name} )
			[ $1 == 1 ] && main_logger 3 "Library has ${#temp_array[@]} tape device(s):  ${temp_array[@]}"
			for ((tcounter=0; tcounter< ${#temp_array[@]}; tcounter++)); do
				ARRAY_MAP=("${ARRAY_MAP[@]}" ${temp_array[$tcounter]} ${CONF_CHANGER_DEVICES[$ccounter]} $tcounter)
			done
			LIBRARY_TAPES=( "${LIBRARY_TAPES[@]}" ${temp_array[@]} )
		done
		[ $1 == 1 ] && main_logger 4 "-----------------------------------------------------------------"
		[ $1 == 1 ] && main_logger 3 "Internal tape device(s): ${LIBRARY_TAPES[@]}"
		[ $1 == 1 ] && main_logger 4 "-----------------------------------------------------------------"
		[ $1 == 1 ] && main_logger 4 "tape/changer/dte_id map: ${ARRAY_MAP[@]}"
		[ $1 == 1 ] && main_logger 4 "-----------------------------------------------------------------"
	;;
esac
case $LTFSARCHIVER_MODE in
	"M"|"B")
		[ $1 == 1 ] && main_logger 3 "Listing available manual tape devices"
		[ $1 == 1 ] && main_logger 4 "-----------------------------------------------------------------"
		[ $1 == 1 ] && main_logger 3 "External tape device(s): ${CONF_MANUAL_TAPEDEV[@]}"
	;;
esac
[ $1 == 1 ] && main_logger 3 "================================================================="
}

#-----------------------------------------------------------------------
#	MAIN_LOGGER
#	saves into logfile string $2 (if $1 less or equal logvel)
function main_logger()
{
if [ $LTFSARCHIVER_LOGLEVEL -ge $1 ]; then
	echo `date +%Y-%m-%d_%T`" -> "`echo $@ | sed -e 's/^'$1'//'` >> $MAIN_LOG_FILE
fi
if [ $LTFSARCHIVER_DEBUG == 1 ]; then
	echo $@
fi
}

#-----------------------------------------------------------------------
#	GET_LONGOP
#	simply returns a long operation description
function get_longop()
{
case $1 in
        "K")
                LONGOP="LOCKDEVICE"
        ;;
        "J")
                LONGOP="UNLOCKDEVICE"
        ;;
        "U")
                LONGOP="UNMAKEAVALABLE"
        ;;
        "D")	#	Synchronous, just to keep track of operation
                LONGOP="WITHDRAW"
        ;;
        "F")
                LONGOP="STD-FORMAT"
        ;;
        "Z")
                LONGOP="FORCED-FORMAT"
        ;;
        "C")
                LONGOP="CHECKSPACE"
        ;;
        "R")
                LONGOP="RESTORE"
        ;;
        "A")
                LONGOP="MAKEAVAILABLE"
        ;;
        "W")
                LONGOP="ARCHIVE"
        ;;
        "L")
                LONGOP="LISTTAPE"
        ;;
        "V")
                LONGOP="CHECKSUM"
        ;;
esac
}

#-----------------------------------------------------------------------
#	CONVERT_DEV_TO_DTE
#	given a device name, returns the DTE index which is known by the library
function convert_dev_to_dte()
{
dteidx=0
for ((dteidx=0;dteidx<${#ARRAY_MAP[@]}; dteidx+=3)); do
	if [ ${ARRAY_MAP[$dteidx]} == $1 ]; then
		DTE_SLOT=${ARRAY_MAP[$dteidx+2]}
		dteidx=${#ARRAY_MAP[@]}
	fi
done
}



#e----------------------------------------------------------------------
#	MOUNT_LTFS
#	attemps to ltfs-mount tape, according to received parms:
#	$1	device
#	$2	tape label
#	$3	Mount mode  (ro/rw)
#	$4	Mount point
#	$5	checklabel: tabel null file in root has to be matched with tapelabel (Y/N)?
function mount_ltfs ()
{
#	GID e UID from config
MOUNTUID=`id -u $LTFSARCHIVER_USER`
MOUNTGID=`id -g $LTFSARCHIVER_USER`
#	temporary log for ltfs mount
TEMPLOG="/tmp/`basename $1`.tmp"
#       creates mount point if it doesn't exist
[ -d $4 ] || mkdir $4
#	look for backend to be used (ltotape, ibmtape...)
for ((BIDX=0;BIDX<${#CONF_BACKENDS[@]};BIDX+=2)); do
	if [ ${CONF_BACKENDS[$BIDX]} == $1 ]; then
		TAPE_BACKEND=${CONF_BACKENDS[$BIDX+1]}
	fi
done
#	Trying to mount
$CMD_LTFS -o devname=$1 -o $3 -o sync_type=$LTFSARCHIVER_LTFSSYNC  -o tape_backend=$TAPE_BACKEND -o uid=$MOUNTUID -o gid=$MOUNTGID  $4 2> $TEMPLOG
#	Trap return code
LTFSRC=$?
if [ $LTFSRC == 0 ]; then
	#	Look for "near to full" ro forced mount	even if rw was requested
	if  [ $3 == "rw" ]; then
		TROPPOPIENO=`grep -c "LTFS20022I" $TEMPLOG`
		if [ $TROPPOPIENO -gt 0 ]; then
			#	log event
			main_logger 2 "`grep 'LTFS20022I' $TEMPLOG`"
			#	force free space to zero in lto_info table (the tape will never be selected for further archives)
			main_logger 0 "Tape $2 has reached its max capabilty... marking it as full"
			$CMD_DB" update lto_info set free=0,booked=0 where label='$2';" >/dev/null 2>&1
			bkpltoinfo
			LTFS_RC=4
			umount $4
		else
			main_logger 1 "ltfs mount completed: `grep 'LTFS11031I' $TEMPLOG`"
			LTFS_RC=0
		fi
	else
		main_logger 1 "ltfs mount completed: `grep 'LTFS11031I' $TEMPLOG`"
		#	Check if "labelfile" exists
		if [ $5 == "Y" ]; then
			if [ -e $4/$2 ]; then
				LTFS_RC=0
			else
				main_logger 0 "Label file is missing or differs from expected one"
				LTFS_RC=2
				umount $4
			fi
		fi
	fi
else
	LTFS_RC=8
	main_logger 0 "ltfs mount failed... reason:"
	#	Appending ltfs log to main log
	IFS=$'\n'
	for RIGA in `cat $TEMPLOG`; do
		main_logger 0 "$RIGA"
	done
	unset IFS
	#	failure logging
	main_logger 0 "Tape $2 has some FS problemi:... marking it as unusable"
	#	force free space to zero in lto_info table (the tape will never be selected for further archives)
	$CMD_DB" update lto_info set free=0,booked=0 where label='$2';" >/dev/null 2>&1
	bkpltoinfo
fi
[ -f $TEMPLOG ] && rm -f $TEMPLOG
}

#-----------------------------------------------------------------------
#	FALLOUT_UUID
#	Send an instance into fallout status.
#	According to fallout code, the substatus is set to:
#	99 (restartable=default) 
#	19 (NOT restartable)
#	9 (error occurred bfore the task was sterted)
function fallout_uuid()
{
utime=`date '+%Y-%m-%d %H:%M:%S'`
FALLOUTSTATUS=99
FALLOUTSTRING="fallout"
case $2 in
	101)
		Description="Requested pool has not enough available space"
		FALLOUTSTATUS=9
	;;
	102)
		Description="No tape with enough free space found into requested pool"
		FALLOUTSTATUS=9
	;;
	103)
		Description="No tape with enough free space found into library, drop to external not allowed"
		FALLOUTSTATUS=9
	;;
	104)
		Description="Source file not found"
	;;
	105)
		Description="Source folder not found"
	;;
	106)
		Description="Error while creating ltfs directory"
	;;
	107)
		Description="Error while writing file to ltfs"
	;;
	108)
		Description="Item to archive vanished before dispatching"
		FALLOUTSTATUS=9
	;;
	109)
		Description="Mismatch found between checksum file and file system (number of file(s) differs)"
		FALLOUTSTATUS=19
	;;
	110)
		Description="Mismatch found between checksum file and file system (filename(s) differs)"
		FALLOUTSTATUS=19
	;;
	111)
		Description="Some file didn not pass checksum verification"
		FALLOUTSTATUS=19
	;;
	112)
		Description="Error occurred while computing file(s) checksum"
		FALLOUTSTATUS=19
	;;
	201)
		Description="Tape not found in library"
	;;
	204)
		Description="File or directory not found on tape"
	;;
	205)
		Description="Insufficient free space for restore"
	;;
	206)
		Description="Error while restoring file to disk"
	;;
	207)
		Description="No existing checksum was found"
		FALLOUTSTATUS=19
	;;
	208)
		Description="More than one existing checksum found"
		FALLOUTSTATUS=19
	;;
	301)
		Description="Tape not found in any storage slot"
	;;
	302)
		Description="Tape library error while moving tape to driver"
	;;
	303)
		Description="Bad tape status or density code"
	;;
	304)
		Description="Tape library error while moving tape to slot"
	;;
	305)
		Description="Tape library error while moving tape to slot and error while unloadong it"
	;;
	306)
		Description="Tape device returned an invalid status"
	;;
	501)
		#	looking for specific or general error code into ltfs logfile
		#	LTFS15490E Tape already contains an LTFS volume.  Need -f option to force reformat
		if [ `grep -c ^LTFS15490E $MAIN_LOG_FILE` -gt 0 ]; then
			Description="Tape already contains an LTFS volume"
		else
			Description="Error while formatting LTO"
		fi
		FALLOUTSTATUS=19
	;;
	502)
		Description="Error while mounting ltfs"
	;;
	503)
		Description="AddTape check function failed; maybe tape is not LTFS formatted"
		FALLOUTSTATUS=19
	;;
	601)
		Description="Internal label not matching with requested LTO"
	;;
	701)
		Description="Error occurred while locking device"
	;;
	901)
		Description="Unexpected error while looking for device containing made available tape"
	;;
	*)
		Description="Error unknown: $2"
	;;
esac
$CMD_DB" update requests set status='"$FALLOUTSTRING"', substatus=$FALLOUTSTATUS, endtime='$utime', errorcode=$2, errordescription='$Description', ltotape='n/a' where uuid='$1';" >/dev/null 2>&1
}
function update_uuid_status()
{
utime=`date '+%Y-%m-%d %H:%M:%S'`
case $2 in
	4|6)
		$CMD_DB" update requests set substatus=$2 where uuid='$1';" >/dev/null 2>&1
	;;
	10)
		$CMD_DB" update requests set substatus=10, manager='$3', ltolibrary='$4' where uuid='$1';" >/dev/null 2>&1
	;;
	20)
		$CMD_DB" update requests set substatus=20, device='$3' where uuid='$1';" >/dev/null 2>&1
	;;
	30|40)
		$CMD_DB" update requests set substatus=$2, status='starting' where uuid='$1';" >/dev/null 2>&1
	;;
	50)
		$CMD_DB" update requests set substatus=50, status='running', starttime='$utime' where uuid='$1';" >/dev/null 2>&1
	;;
	55)
		$CMD_DB" update requests set substatus=55 where uuid='$1';" >/dev/null 2>&1
	;;
	60)
		$CMD_DB" update requests set substatus=60, status='completed', endtime='$utime', errorcode=0, errordescription=NULL where uuid='$1';" >/dev/null 2>&1

	;;
esac
}
#-----------------------------------------------------------------------
#	GET_FORMAT_RULES
#	Creates the mkltfs rule (-r parameter) according to config parms:
#	LTFSARCHIVER_RULESIZE
#	LTFSARCHIVER_RULEEXTS()
function get_format_rules()
{
#	base rule=no rule
MKLTFS_RULES=""
#	Are rules to be set?
#	If a size rule is missing, name rule will be ignored even if specified (ltfs design)
#	LTFS11157E Cannot specify a name rule without a size rule
if ! [ -z $LTFSARCHIVER_RULESIZE ]; then
	#       Size based rule
	MKLTFS_RULES="-r size=$LTFSARCHIVER_RULESIZE"
	#       ext based rule(s)
	if [ ${#LTFSARCHIVER_RULEEXTS[@]} -gt 0 ]; then
		MKLTFS_RULES=$MKLTFS_RULES"/"
		for ((EXTIDX=0;EXTIDX<${#LTFSARCHIVER_RULEEXTS[@]};EXTIDX++)); do
		        [ $EXTIDX == 0 ] &&  MKLTFS_RULES=$MKLTFS_RULES"name="
		        MKLTFS_RULES=$MKLTFS_RULES'*.'${LTFSARCHIVER_RULEEXTS[$EXTIDX]}
		        [ $EXTIDX -lt `echo ${#LTFSARCHIVER_RULEEXTS[@]} -1 | bc` ] &&  MKLTFS_RULES=$MKLTFS_RULES':'
		done
	fi
fi
#	Rule override allowed (non now, maybe in the future... please do not activate this line)
#( [ $LTFSARCHIVER_RULEOVER == "Y" ] || [ $LTFSARCHIVER_RULEOVER == "y" ] ) ||  MKLTFS_RULES=$MKLTFS_RULES" -o"
MKLTFS_RULES=$MKLTFS_RULES" -o"
echo $MKLTFS_RULES
}
#-----------------------------------------------------------------------
#	GET_RSYNC_RULES
#	Creates the rsync rule to be used for first rsync step according to config parms:
#	LTFSARCHIVER_RULESIZE
#	LTFSARCHIVER_RULEEXTS()
#	
function get_rsync_rules()
{
#	base rule=no rule
RSYNC_RULES=""
#       Size based rule
if ! [ -z $LTFSARCHIVER_RULESIZE ]; then
	RSYNC_RULES=$RSYNC_RULES' --temp-dir /tmp --max-size='$LTFSARCHIVER_RULESIZE
fi
#       ext based rule(s)
if [ ${#LTFSARCHIVER_RULEEXTS[@]} -gt 0 ]; then
	RSYNC_RULES=$RSYNC_RULES" --include '*/'"
	for ((EXTIDX=0;EXTIDX<${#LTFSARCHIVER_RULEEXTS[@]};EXTIDX++)); do
		RSYNC_RULES=$RSYNC_RULES" --include='*${LTFSARCHIVER_RULEEXTS[$EXTIDX]}'"
	done
	RSYNC_RULES=$RSYNC_RULES" --exclude='*'"
fi
echo $RSYNC_RULES
}

#-----------------------------------------------------------------------
#	BKLTOINFO
#	Creates creates a backup of lto_info table
function bkpltoinfo()
{
$CMD_DB "copy lto_info to STDOUT;" > $LTFSARCHIVER_HOME/poolbkp/lto_info.`date '+%s'`
}

#-----------------------------------------------------------------------
#	GET_SERVICENAME
#	Simply returns the API name when API short code (operation) is given
function get_servicename()
{
case $1 in
	"L")	#	LockDevice
		echo "ListTape"
	;;
	"K")	#	LockDevice
		echo "LockDevice"
	;;
	"A")	#	UnlockDevice
		echo "UnlockDevice"
	;;
	"A")	#	makeAvailablemount
		echo "MakeAvailableMount"
	;;
	"U")	#	makeavailableUnmount
		echo "MakeAvailableUnmount"
	;;
	"W")	#	Writelto
		echo "WriteToLTO"
	;;
	"R")	#	Restore
		echo "RestoreFromLTO"
	;;
	"C"|"F"|"Z")	#	tapeadd-check
		echo "TapeAdd"
	;;
	"D")	#	Restore
		echo "WithdrawTape"
	;;
	"V")	#	Restore
		echo "Checksum"
	;;
esac
}

#-----------------------------------------------------------------------
#	CREATE_FALLOUT_REPORT
#	Creates a fallout xml report according to incoming values:
#	1: failed task id
#	2: operation
function create_fallout_report()
{
FOservice=$( get_servicename $2 )
FOutReport_XML=$LTFSARCHIVER_HOME/reportfiles/$1.xml
DESCRIPTION=`$CMD_DB"select errordescription from requests where uuid='"$1"';" | sed -e 's/^ //'`
echo '<LTFSArchiver '$LTFSARCHIVER_NAMESPACE'>' > $FOutReport_XML
echo -e "\t"'<Output>' >> $FOutReport_XML
echo -e "\t\t"'<Result exit_code="500" exit_string="Failure">' >> $FOutReport_XML
echo -e "\t\t\t"'<Report>Service '$FOservice' reported the following error: '$DESCRIPTION'</Report>' >> $FOutReport_XML
#	FLOCATLIST is a string; if not null it has to be ehoed into report
[ -z "${FLOCATLIST}" ] || echo -e "${FLOCATLIST}" >> $FOutReport_XML
#	FLOCATFILE is an existing file: it has to be appended into report
( ! [ -z $FLOCATFILE ] &&  [ -f ${FLOCATFILE} ] ) && cat ${FLOCATFILE} >> $FOutReport_XML
echo -e "\t\t"'</Result>' >> $FOutReport_XML
echo -e "\t"'</Output>' >> $FOutReport_XML
echo '</LTFSArchiver>' >> $FOutReport_XML
}

#-----------------------------------------------------------------------
#	CREATE_SUCCESS_REPORT
#	Creates a succes xml report according to incoming values:
#	1: failed task id
#	2: operation
function create_success_report()
{
OKservice=$( get_servicename $2 )
OKReport_XML=$LTFSARCHIVER_HOME/reportfiles/$1.xml
echo '<LTFSArchiver '$LTFSARCHIVER_NAMESPACE'>' > $OKReport_XML
echo -e "\t"'<Output>' >> $OKReport_XML
echo -e "\t\t"'<Result exit_code="200" exit_string="Success">' >> $OKReport_XML
#	FLOCATLIST is a string; if not null it has to be ehoed into report
[ -z "${FLOCATLIST}" ] || echo -e "${FLOCATLIST}" >> $OKReport_XML
#	FLOCATFILE is an existing file: it has to be appended into report
( ! [ -z $FLOCATFILE ] &&  [ -f ${FLOCATFILE} ] ) && cat ${FLOCATFILE} >> $OKReport_XML
#	XMLMOUNTOK is the result of a MakeavailableMount success operation
[ -z "${XMLMOUNTOK}" ] || echo -e "${XMLMOUNTOK}" >> $OKReport_XML
echo -e "\t\t"'</Result>' >> $OKReport_XML
echo -e "\t"'</Output>' >> $OKReport_XML
echo '</LTFSArchiver>' >> $OKReport_XML
}

