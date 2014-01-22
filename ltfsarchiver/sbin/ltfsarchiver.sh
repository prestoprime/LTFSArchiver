#!/bin/bash
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

#       1.0.0 
#=================================================================================================
#	This function trys to assign needed resource (tape and device) to the supplied task
#	When the task type is "archive", it tries at first to a tape with enough free space
#	Otherwise, the tape is already know and it only has to chech "if and where"
#	Incoming parms:
#	-	Task id(not uuid)
#	-	Operation type (both short and long)
function dispatch_or_fall()
{
nowtime=`date '+%Y-%m-%d %H:%M:%S'`
$CMD_DB "update requests set starttime='$nowtime' where id=$3;" >/dev/null 2>&1
case $1 in
	#	List/AddTape/RestoreFromLTO/MakeavailableMount/Checksum
	"L"|"Z"|"F"|"C"|"R"|"A"|"V")
		#	get from requests:uuid,tape,manage (library/manual) and feed an array
		DATA=( `$CMD_DB "select uuid,ltotape,manager from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
		main_logger 0 "Dispatching $2 request for tape ${DATA[1]} (uuid: ${DATA[0]})"
		#	if NOT "manual only" tries to locate the tape.
		if ! [ ${DATA[2]} == "M" ]; then
			find_tape ${DATA[1]}
			case $FINDTP_RC in
				0|1)	#	found in library: manager is set to "C" and library in which it has been found is stored
					main_logger 1 "Tape  ${DATA[1]} found in library $CHANGER_DEVICE_N"
					update_uuid_status ${DATA[0]} 10 "C"  $CHANGER_DEVICE_N
				;;
				*)	#	NOT found in library: if allowed, manager is set to "M", otherwise it fails
					main_logger 0 "Tape  ${DATA[1]} not found in any library"
					if [ ${DATA[2]} == "C" ]; then
						fallout_uuid ${DATA[0]} 201
						create_fallout_report ${DATA[0]} $1
					else
						update_uuid_status ${DATA[0]} 10 "M" "NONE"
					fi
				;;
			esac
		#		if mode ="M", then no search is performed, manager is set to "M"
		else
			main_logger 0 "Running in Manual mode... Tape ${DATA[1]} not searched"
			update_uuid_status ${DATA[0]} 10 "M" 
		fi
	;;
	#	MakeavailableUnmount	
	"U")
		#	get from requests uuid and tape and feed an array
		UMNT_DATA=( `$CMD_DB "select uuid,ltotape from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
		UMNT_LABEL=${UMNT_DATA[1]}
		main_logger 0 "Dispatching $2 request (uuid: ${UMNT_DATA[0]})"
		#	look into lock_table to find on which device is loade
		UMNT_DEVICE=`$CMD_DB "select device from lock_table where ltolabel='$UMNT_LABEL'" | tr -d ' ' | tr '|' ' '`
		#	Is the device manually or library managed?
		unset WHERE
		DEV_IDX=0
		while ( [ $DEV_IDX -lt ${#CONF_MANUAL_TAPEDEV[@]} ] && [ -z $WHERE ] ) ; do
			if  [ ${CONF_MANUAL_TAPEDEV[$DEV_IDX]} == $UMNT_DEVICE ]; then
				WHERE="M"
				LTOLIB="NONE"
				DEV_IDX=${#CONF_MANUAL_TAPEDEV[@]}
			fi
			let DEV_IDX+=1
		done
		DEV_IDX=0
		while ( [ $DEV_IDX -lt ${#ARRAY_MAP[@]} ] && [ -z $WHERE ] ) ; do
			if  [ ${ARRAY_MAP[$DEV_IDX]} == $UMNT_DEVICE ]; then
				WHERE="C"
				LTOLIB=${ARRAY_MAP[$DEV_IDX+1]}
				DEV_IDX=${#ARRAY_MAP[@]}
			fi
			let DEV_IDX+=3
		done
		#	if WHERE in empty something is wrong... fallout task
		#	otherwise update task assigning device and library (if any), then forward again assigning device (redundant, but needed by update to 20)
		if [ -z $WHERE ]; then
			main_logger 0 "Requested unmount for tape $UMNT_LABEL failed... uuid ${UMNT_DATA[0]}) sent to fallout"
			fallout_uuid ${UMNT_DATA[0]} 901
			create_fallout_report ${DATA[0]} $1
		else
			update_uuid_status ${UMNT_DATA[0]} 10 $WHERE $LTOLIB
			#	So gia' quale debba essere il device, quindi assegno e avanzo a 20
			main_logger 1 "$UMNT_LABEL found on device $UMNT_DEVICE" 
			update_uuid_status ${UMNT_DATA[0]} 20 $UMNT_DEVICE
		fi
	;;
	#	WriteToLTO
	"W")	#	get item to archive and calculate needed space
		ITEM_TO_ARCH=`$CMD_DB "select sourcefile from requests where id='$3';"  | sed -e 's/^[ \t]*//'`
		#	Check if exists (maybe it has beeen deleted after archive request submission)
		if ( [ -d "$ITEM_TO_ARCH" ] ||  [ -f "$ITEM_TO_ARCH" ] ); then
			#	Space needed in MB
			mbsize=`du -ksm "$ITEM_TO_ARCH" | awk '{ print $1 }'`
			#	Space needed in bytes
			bytesize=`find "$ITEM_TO_ARCH" -type f -printf '%s\n' | awk 'BEGIN{sum=0}{sum+=$1}END{printf "%.0f\n", sum}'`
			#	Save space on request table
			$CMD_DB" update requests set sourcesize=$mbsize,sourcebytes=$bytesize where id='$3';" >/dev/null 2>&1
			#	get from request uuid, poolname, manager, size and feed ana array
			DATA=( `$CMD_DB "select uuid,poolname,manager,sourcesize from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
			main_logger 0 "Dispatching $2 request using PoolName ${DATA[1]} (uuid: ${DATA[0]})"
			#	Check global free space for pool
			for ((POOLINDEX=0; POOLINDEX<${#POOLNAMES[@]}; POOLINDEX++)); do
			        if [ ${POOLNAMES[$POOLINDEX]} == ${DATA[1]} ]; then
			                #       Oops, not enough space on pool: fallout
	                		if [ ${AVALSPACES[$POOLINDEX]} -lt ${DATA[3]} ]; then
			                        main_logger 0 "Pool ${DATA[1]} has not enough space (${DATA[3]} MB needed, ${AVALSPACES[$POOLINDEX]} MB available)... uuid=${DATA[0]} sent to fallout"
			                        fallout_uuid ${DATA[0]} 101
						create_fallout_report ${DATA[0]} $1
					else
						#	Cerco LTO con spazio sufficiente (passo POOLNAME SOURCESIZE MANAGER e UUID)
						#	look for a tape with enough space (get_canditape returns ASSIGNED_TAPE array)
						get_canditape ${DATA[1]} ${DATA[3]} ${DATA[2]} ${DATA[0]}
						#	if first element is "false" no tape has been found... fallout
						#	otherwise it returns TRUE LABEL M|C LIBRARY_INDEX (-1) if external
						if [ ${ASSIGNED_TAPE[0]} == "false" ]; then
							fallout_uuid ${DATA[0]} ${ASSIGNED_TAPE[1]}
							create_fallout_report ${DATA[0]} $1
						else
							#	add needed space to booked value for selected tape
							$CMD_DB" update lto_info set booked=booked+'${DATA[3]}' where label='${ASSIGNED_TAPE[1]}'" >/dev/null 2>&1
							bkpltoinfo
							#	assignes selected tape to task
							$CMD_DB" update requests set ltotape='${ASSIGNED_TAPE[1]}' where uuid='${DATA[0]}'" >/dev/null 2>&1
							#	forward status setting manager and (if any) library
							update_uuid_status ${DATA[0]} 10 ${ASSIGNED_TAPE[2]} ${ASSIGNED_TAPE[3]}
			                        	main_logger 1 "Data will be archived on Tape ${ASSIGNED_TAPE[1]}"
						fi
			                fi
				fi
			done
		else
			#	Bad news... item has been deleted befor archiving
			temp=`$CMD_DB "select uuid from requests where id=$3" | tr -d ' ' `
			main_logger 0 "Item to archive ($ITEM_TO_ARCH) was not found. uuid $temp sent to fallout"
			fallout_uuid $temp 108
			create_fallout_report $temp $1
		fi
	;;
esac
}
#=================================================================================================
#========== funzione che riceve in input  POOLNAME SPAZIORICHIESTO MODALITA
#	Tries to find a tape with enough free space
#	Incoming parms:
#	-	Poolname
#	-	Needes pace (MB)
#	-	manager (M|B|C)
#	if mixed mode (B), the search will advantage "internal" tapes (if any)
#	when a valid tape is found, an array with  (TRUE LABEL [M|C] ARRAY_INDEX_OF_LIBRARY is returned
#	Otherwise an array containing (FALSE FALLOUTCODE) is returned
function get_canditape ()
{
unset ASSIGNED_TAPE
unset LOCATION
#	List ALL tapes from that pool having a sufficient free space (booked space is considered as used) , ordered from lower value
CANDIDATES=( `$CMD_DB "select label,(free - booked) as notbooked from lto_info where poolname='$1' and (free - booked) > $2 order by notbooked, label" | 
cut -d '|' -f 1 | grep -v "^$" | sed -e 's/^\ *//' -e 's/\ *$//' | tr '\n' ' '` )
main_logger 3 "Found ${#CANDIDATES[@]} candidate(s): ${CANDIDATES[@]}"
#	If the array is empty no tape is available, so assignes a fallout code end exits
if [ ${#CANDIDATES[@]} == 0 ]; then
	main_logger 0 "No tape belonging to pool $1 has enough space available... uuid=$4 sent to fallout"
	ASSIGNED_TAPE=( "false" "102" )
else
	#	Let's suppose that tape is an external one
	LOCATION="M"
	LIBRARY="NONE"
	case $3 in
		#	Manual/Both:	Tries to locate tape into library. If found, overrides LOCATION and LIBRARY
		"M"|"B")
			if [ $3 == "B" ]; then
				find_tape ${CANDIDATES[0]}
				if ( [ $FINDTP_RC == 0 ] || [ $FINDTP_RC == 1 ] ); then
					main_logger 1 "Candidate tape  ${CANDIDATES[0]} found in library $CHANGER_DEVICE_N"
					LOCATION="C"
					LIBRARY=$CHANGER_DEVICE_N
				fi
			fi
			ASSIGNED_TAPE=( "true" "${CANDIDATES[0]}" "$LOCATION" "$LIBRARY")
		;;
		#	Changer only:	Tries to locate tape into library. If found, overrides LOCATION and LIBRARY
		#		Otherwise loops into the list to find a tape into library. if none is found, fallout
		"C")		#       Se lavoro in Changer: devo verificare che sia in libreria
			ASSIGNED_TAPE=( "false" "103" )
			for ((CANDIDATE_IDX=0; CANDIDATE_IDX<${#CANDIDATES[@]}; CANDIDATE_IDX++)); do
				find_tape ${CANDIDATES[$CANDIDATE_IDX]}
				if ( $FINDTP_RC == 0 ] || [ $FINDTP_RC == 1 ] ); then
					main_logger 1 "Tape  ${CANDIDATES[$CANDIDATE_IDX]} found in library $CHANGER_DEVICE_N"
					ASSIGNED_TAPE=( "true" "$CANDIDATE_IDX" "C" "$CHANGER_DEVICE_N")
					#	foce loop exit
					CANDIDATE_IDX=${#CANDIDATES[@]}
				else
					main_logger 1 "Tape  ${CANDIDATES[$CANDIDATE_IDX]} not found in any library; looking for next one"
				fi
			done
		;;
	esac
fi
}

#================================================================================================
#========== Tries to find a free device, according to the location of the LABEL tape
#	incoming parms:
#	-	Label
#	-	NONE (external) or changer devname
#	If a free device is found, it device name is returned in FREE_DEV variable
#	Otherwise, NONE is returned
function get_candidev ()
{
#	Pessimistic start... no device available
FREE_DEV="NONE"
#	Library or external?
case $2 in
	"NONE")	#	External
		main_logger 1 "looking for external device for tape $1"
		main_logger 4 "${CONF_MANUAL_TAPEDEV[@]}"
		#	each external tape is searche in lock_table... if not locked it is assigned
		for((idx=0; idx<${#CONF_MANUAL_TAPEDEV[@]}; idx++)); do
			if [ `$CMD_DB "select count(*) from lock_table where device='${CONF_MANUAL_TAPEDEV[$idx]}';" | tr -d ' ' | tr '|' ' '` == 0 ] ; then
				FREE_DEV=${CONF_MANUAL_TAPEDEV[$idx]}
				#	force loop exit
				idx=${#CONF_MANUAL_TAPEDEV[@]}
			fi
		done
	;;
	*)	#	Library
		main_logger 4 "looking for internal device for tape $1 (library $2)"
		main_logger 4 "${ARRAY_MAP[@]}"
		#	eache tape (if managed by the supplied library) is searched into lock_table...
		for ((idx=0; idx<${#ARRAY_MAP[@]}; idx+=3)); do
			#	it must be managed by the library supplied
			if [ ${ARRAY_MAP[$idx+1]} ==  $2 ]; then
				#	If it is free, a further check with mtx is done to verify that the associated DTE is non used by some other tape/task
				if [ `$CMD_DB "select count(*) from lock_table where device='${ARRAY_MAP[$idx]}';" | tr -d ' ' | tr '|' ' '` == 0 ] ; then
					#	get DTE id from devname
					convert_dev_to_dte ${ARRAY_MAP[$idx]}
					main_logger 4 "convert_dev_to_dte ${ARRAY_MAP[$idx]} returned: $DTE_SLOT"
					#	get status (it should be empty)
					DTE_STATUS=( $( status_dte $2 $DTE_SLOT ) )
					main_logger 4 "DTE_STATUS returned value: $DTE_STATUS"
					case ${DTE_STATUS[0]} in
						"empty")
							#	OK, assign it to task
							FREE_DEV=${ARRAY_MAP[$idx]}
							#	exit from loop
							idx=${#ARRAY_MAP[@]}
						;;
						"full")
							#	OOPS, someone is already using that device...
							#	mark it as unusable
							main_logger 0 "Oops! Found a stranger tape (${DTE_STATUS[1]})into ${ARRAY_MAP[$idx]} device (changer: $2 - DTE: $DTE_SLOT)"
							#	Touch a file that will be removed (if device will be found empty) by a further run
							echo ${DTE_STATUS[1]}> /tmp/ltfsarchiver.`basename ${ARRAY_MAP[$idx]}`.lock
							
						;;
					esac
				fi
			fi
		done
	;;

esac
}
#-----------------------------------------------------------------------------------------------------------
#=================================================================================================
#	MAIN MAIN MAIN
#	Initializazion and checks
CFG_FILE=`dirname $0`/../conf/ltfsarchiver.conf
#	Use to debug (ltfsarchiver.sh BREAKAT)
BREAK=$1
if [ -f $CFG_FILE ]; then
	. $CFG_FILE
	#	include common functions
	. $LTFSARCHIVER_HOME/sbin/common.sh
	MAIN_LOG_FILE=$LTFSARCHIVER_LOGDIR/ltfsarchiver.`date +%Y%m%d`.log
	MAIN_LOG_ERR=$LTFSARCHIVER_LOGDIR/ltfsarchiver.`date +%Y%m%d`.err
	[ -d $LTFSARCHIVER_LOGDIR ] || mkdir -p $LTFSARCHIVER_LOGDIR
	STARTMSG="------------> Starting "
	#	Check if postgresql is running
	service postgresql status >/dev/null 2>&1
	PSQL_RUN=$?
	if [ $PSQL_RUN -gt 0 ]; then
		main_logger 0 "Postgresql inattivo..."
		exit 3
	fi
	#	check/create base mount poit for MakeavailableMount tasks
	[ -d $LTFSARCHIVER_MNTAVAIL ] || mkdir -p $LTFSARCHIVER_MNTAVAIL
	#	Get operation mode
	case $LTFSARCHIVER_MODE in
		"M")
			STARTMSG=$STARTMSG" in manual mode"
		;;
		"B")
			STARTMSG=$STARTMSG" in mixed mode"
		;;
		"C")
			STARTMSG=$STARTMSG" in changer mode"
		;;
		*)
			main_logger 0 "Invalid run mode specified: $LTFSARCHIVER_MODE"
			exit 3
		;;
	esac
	main_logger 0 "$STARTMSG"
	#	include tape library functions
	case $HW_CHANGER_TYPE in
       		"MSL")
		       	. $LTFSARCHIVER_HOME/sbin/utils/msl_util.sh
			main_logger 4 "MediaChanger type: $HW_CHANGER_TYPE"
	       	;;
	       	*)
			main_logger 0 "MediaChanger type unknown: $HW_CHANGER_TYPE"
		       	exit 3
	       	;;
	       esac
	#	include tape functions
	case $HW_TAPE_TYPE in
		"LTO")
			. $LTFSARCHIVER_HOME/sbin/utils/lto_util.sh
			main_logger 4 "Tapedrive type: $HW_TAPE_TYPE"
		;;
		*)
			main_logger 0 "Tapedrive type unknown: $HW_TAPE_TYPE"
		exit 3
	;;
	esac
	#	include move functions
	. $LTFSARCHIVER_HOME/sbin/utils/mediamove.sh
	#	Touch lockfile
	touch /tmp/ltfsarchiver.main.$$.lock
	#	check/creates directory to store lto_info table backup
	[ -d $LTFSARCHIVER_HOME/poolbkp ] || mkdir -m 777 $LTFSARCHIVER_HOME/poolbkp
	#	check ltfs rules syntax
	if [ -z $LTFSARCHIVER_RULESIZE ]; then
        	main_logger 1 "LTFS is running without sizerule"
	else
	        CAPITALRULE=`echo $LTFSARCHIVER_RULESIZE | tr '[a-z]' '[A-Z]'`
		#	Sizerule must be in the form [0-9]*[A-Z]: 5M - 2G -250K
	        case $CAPITALRULE in
	                [0-9]*[A-Z]*)
	                        FORMAT_OK="Y"
	                        SIZETYPE=`echo $CAPITALRULE | tr -d [0-9]`
	                        if [ ${#SIZETYPE} -gt 1 ]; then
	                                FORMAT_OK="N"
	                        else
	                                case $SIZETYPE in
	                                        "M"|"K"|"G")
	                                                FORMAT_OK="Y"
	                                        ;;
	                                        *)
	                                                FORMAT_OK="N"
	                                        ;;
	                                esac
	                        fi
	                ;;
	                *)
	                        FORMAT_OK="N"
	                ;;
	        esac
	        SIZEVAL=`echo $CAPITALRULE | tr -d [A-Z]`
	        [ $SIZEVAL == 0 ] &&  FORMAT_OK="N"
	        if [ $FORMAT_OK == "N" ]; then
	                main_logger 0 "Bad LTFSARCHIVER_RULESIZE value: $LTFSARCHIVER_RULESIZE. It should be [0-9]*[K|M|G], with numeric part greater than zero"
			exit 3
	        fi
	fi
else
	echo "missing cfg file"
	exit 1
fi
#
#=================================================================================================
#	STEP 0	-	Load device configuration
devices_config 1 	# 	$1 = causes cfg printout

#=================================================================================================
#       STEP 1  -	If a tapedev was previously marked as "used by someone but it's not me"
#	a check is done and (if tape is found empty) the lock file removed
main_logger 1 "------------------------------------->>>    STEP 1 - Checking locked devices"
for ((idx=0; idx<${#ARRAY_MAP[@]} ;idx+=3)); do
        if [ -e /tmp/ltfsarchiver.`basename ${ARRAY_MAP[$idx]}`.lock ]; then
		convert_dev_to_dte ${ARRAY_MAP[$idx]}
		DTE_STATUS=( $( status_dte ${ARRAY_MAP[$idx+1]} $DTE_SLOT ) )
		[ ${DTE_STATUS[0]} == "empty" ] && rm /tmp/ltfsarchiver.`basename ${ARRAY_MAP[$idx]}`.lock
	fi
done

#=================================================================================================
#	STEP 2	-	Running precheck for WriteToLTO with Checksum=FILE option
main_logger 3 "------------------------------------->>>    STEP 2 - Checksum pre-check"
PRECHECKUUID=( `$CMD_DB "select uuid from requests where operation='W' and substatus=0 and checksum='FILE'" | tr '\n' ' '` )
for ((PRECHECKCOUNT=0; PRECHECKCOUNT<${#PRECHECKUUID[@]}; PRECHECKCOUNT++)); do
	#	substatus is set to 4 while precheck is run
	update_uuid_status ${PRECHECKUUID[$PRECHECKCOUNT]} 4
	main_logger 0 "Prechek scheduled for uuid=${PRECHECKUUID[@]}"
	#	start of precheck script (status wiill go to 6=good or 99=failing by script
	PRECHECKCOMMAND=`dirname $0`"/archive_precheck ${PRECHECKUUID[$PRECHECKCOUNT]}"
	$PRECHECKCOMMAND 2>$LTFSARCHIVER_LOGDIR/archive_precheck`date +%s`.err &
done

#=================================================================================================
#	STEP 3	-	Reporting poolnames and their amount of free space
main_logger 3 "------------------------------------->>>    STEP 3 - ARRAYS AND SPACES"
main_logger 3 "========== Listing available pools and free spaces =============="
POOLNAMES=( `$CMD_DB "select distinct poolname from lto_info" | tr '\n' ' '` )
for ((POOLINDEX=0; POOLINDEX<${#POOLNAMES[@]}; POOLINDEX++)); do
	AVALSPACE=`$CMD_DB "select sum(free - booked) from lto_info where poolname='${POOLNAMES[$POOLINDEX]}'"`
	AVALSPACES=( "${AVALSPACES[@]}" $AVALSPACE )
	main_logger 1 "Pool ${POOLNAMES[$POOLINDEX]} has ${AVALSPACES[$POOLINDEX]} free MB"
done
#=================================================================================================
#	STEP 4	-	Tries to dispatch instances in waiting status
#		NB: substatus=6 is the one assigned to a successful archive precheck batch
main_logger 3 "------------------------------------->>>    STEP 6 - INSTANCES DISPATCHING"
main_logger 3 "================================================================="
main_logger 0 "================= Looking for new requests ======================"
#	Tries to dispatch List/MakeavailableUnmount/AddTape(ZCF)/RestoreFromLto/makeAvailableMount/WriteToLTO/Checksum
for SHORTOP in L U Z F C R A W V; do
	get_longop $SHORTOP
	PENDING_RQST=( `$CMD_DB "select id from requests where operation='$SHORTOP' and (substatus=0 or substatus=6) order by id" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	main_logger 0 "- Looking for new $LONGOP requests... found:  ${#PENDING_RQST[@]}"
	for ((RQST_NUMBER=0; RQST_NUMBER<${#PENDING_RQST[@]}; RQST_NUMBER++)); do
		#	Dispatchit or fallout
		dispatch_or_fall $SHORTOP $LONGOP ${PENDING_RQST[$RQST_NUMBER]}
	done
done
#	trap EXIT
[ "$BREAK" == 1 ] && exit
#=================================================================================================
#	FASE 5	-	Exec MakeavailableUnmout
main_logger 3 "------------------------------------->>>    STEP 5 - SATISFYING UNMAKE AVAILABLE"
get_longop "U"
#	get uuids from request and feed an array
REQUESTED_UUIDS=( `$CMD_DB "select uuid from requests where operation='U' and substatus=20;" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
for ((RQST_IDX=0; RQST_IDX<${#REQUESTED_UUIDS[@]}; RQST_IDX++)) do
	#	forward status to runninf
	update_uuid_status  ${OPERATION_UUIDS[$RQST_IDX]} 50
	#	get info: label, library, tapedevice and manager from requests table
	REQUESTED_UMNT=( `$CMD_DB "select ltotape, ltolibrary, device, manager from requests where uuid='${REQUESTED_UUIDS[$RQST_IDX]}';" | tr -d ' ' | tr '|' ' '` )
	main_logger 0 "Starting $LONGOP for tape ${REQUESTED_UMNT[0]} (uuid: ${REQUESTED_UUIDS[$RQST_IDX]})"
	#	label -> mount point
	MOUNT_POINT=$LTFSARCHIVER_MNTAVAIL/${REQUESTED_UMNT[0]}
	#	Check if it's actually mountd
	MOUNTED=`mount | grep -c $MOUNT_POINT`
	#	if NOT mounted, mount_rc is set to 0
	#	otherwise unmount and trap exit code
	if [ $MOUNTED == 0 ]; then
		UMOUNT_RC=0
	else
		#	Smonto mount point
		umount $MOUNT_POINT
		UMOUNT_RC=$?
	fi
	main_logger 4 "UMOUNT_RC returned value: $UMOUNT_RC"
	#	If exitcode is 0, then eject or unload (if unload, the UNLOAD_RC is retorned from unload command
	#	Otherwise (maybe someone is still using tape?) a new attempt will be made later (status and substatus of task are untouched)
	if [ $UMOUNT_RC == 0 ]; then
		main_logger 1 "FS unmounted"
		if [ ${REQUESTED_UMNT[3]} == "M" ]; then
			$CMD_MT -f ${REQUESTED_UMNT[2]} eject
			UNLOAD_RC=$?
		else
			unload_tape ${REQUESTED_UMNT[1]} ${REQUESTED_UMNT[2]}
		fi
		#	IF unload/eject wen fine
		if [ $UNLOAD_RC == 0 ]; then
			[ ${REQUESTED_UMNT[3]} == "M" ] && main_logger 2 "Tape ejected"
			[ ${REQUESTED_UMNT[3]} == "C" ] && main_logger 2 "Tape successfully moved to repository slot"
			#       free device
			$CMD_DB" delete from lock_table where device='${REQUESTED_UMNT[2]}'" > /dev/null 2>&1
			#       free tape
			$CMD_DB" update lto_info set inuse=NULL where label='${REQUESTED_UMNT[0]}'" > /dev/null 2>&1
			bkpltoinfo
			#	forward task to completed status
			update_uuid_status ${REQUESTED_UUIDS[$RQST_IDX]} 60
			main_logger 0 "${REQUESTED_UUIDS[$RQST_IDX]} succesfully completed"
			#	clean mount point
			[ -d $MOUNT_POINT ] && rmdir $MOUNT_POINT
			create_success_report ${REQUESTED_UUIDS[$RQST_IDX]} "U"
		else
			#	OOPS, something went wrong while eject/unload... fallout
			main_logger 0 "CRITICAL ERROR while unloading tape ${REQUESTED_UMNT[0]}"
			if [ ${REQUESTED_UMNT[3]} == "M" ]; then
				fallout_uuid ${REQUESTED_UUIDS[$RQST_IDX]} 403
				create_fallout_report ${REQUESTED_UUIDS[$RQST_IDX]} "U"
			fi
		fi
	else
		main_logger 0 "Tape ${REQUESTED_UMNT[0]} is still in use. I'll try later"
	fi
done
#	trap EXIT
[ "$BREAK" == 2 ] && exit

#=================================================================================================
#	STEP 6	-	Lock/unlock tape devices
main_logger 3 "------------------------------------->>>    STEP 6 - LOCK/UNLOCK DEVICES"
for SHORTOP in K J; do		#	Look for lock/unlock device requests
	get_longop $SHORTOP
	main_logger 1 "======== Looking for devices to be used for $LONGOP requests"
	#	get info: uuid, device and feed an array
	DEV_LOCKS=( `$CMD_DB "select uuid, device from requests where operation='"$SHORTOP"' and substatus=0" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	main_logger 4 "${#DEV_LOCKS[@]}"
	for ((k=0;k<${#DEV_LOCKS[@]};k+=2)); do
		utime=`date '+%Y-%m-%d %H:%M:%S'`
		$CMD_DB "update requests set starttime='$utime' where uuid='${DEV_LOCKS[$k]}';" >/dev/null 2>&1
		#	Act accorting to requested operation
		case $SHORTOP in
			"K")	#	LOCK
				INUSE=`$CMD_DB "select ltolabel from lock_table where device='"${DEV_LOCKS[$k+1]}"';" | tr -d ' '`
				#	if the device is not in use 
				if [ -z $INUSE ]; then
					#	LOCK
					$CMD_DB" insert into lock_table (device,ltolabel) VALUES('${DEV_LOCKS[$k+1]}','$LTFSARCHIVER_LOCK_LABEL');" >/dev/null 2>&1
					#	trap insert error 
					if [ $? == 0 ];then
						#	Success
						update_uuid_status ${DEV_LOCKS[$k]} 60
						create_success_report ${DEV_LOCKS[$k]} "K"
					else
						#	Failure
						fallout_uuid ${DEV_LOCKS[$k]} 701
						create_fallout_report ${DEV_LOCKS[$k]} "K"
					fi
				else
					#	Will try later
					main_logger 0 "Device ${DEV_LOCKS[$k+1]} is in use; lock will be tryed again later"
				fi
			;;
			"J")	#	UNLOCK
				INUSE=`$CMD_DB "select ltolabel from lock_table where device='"${DEV_LOCKS[$k+1]}"';" | tr -d ' '`
				#	if the label found into lock_table is the "special one"
				if [ "$INUSE" == $LTFSARCHIVER_LOCK_LABEL ]; then
					#	UNLOCK
					#	trap delete error 
					$CMD_DB" delete from lock_table where device='"${DEV_LOCKS[$k+1]}"';" >/dev/null 2>&1
					if [ $? == 0 ];then
						#	Success
						update_uuid_status ${DEV_LOCKS[$k]} 60
						create_success_report ${DEV_LOCKS[$k]} "K"
					else
						#	Failure
						fallout_uuid ${DEV_LOCKS[$k]} 701
						create_fallout_report ${DEV_LOCKS[$k]} "K"
					fi
				else
					main_logger 0 "Device ${DEV_LOCKS[$k+1]} was already unlocked..."
					#	Success
					update_uuid_status ${DEV_LOCKS[$k]} 60
					create_success_report ${DEV_LOCKS[$k]} "K"
				fi	
			;;
		esac
	done
done
#=================================================================================================
#	STEP 7	-	Tries to assign a device to dispatched tasks
main_logger 3 "------------------------------------->>>    STEP 7 - TAPE DEVICE ASSIGN"
#	No more than a certain number (LTFSARCHIVER_MAXAVAIL) of Makeavailable task can be active at the same time
#	if the maximum number has been reached, no task of this type will be satisfied
ACTIVE_MA=`$CMD_DB "select count(*) from lto_info where inuse='A';" | tr -d ' '`
if [ $ACTIVE_MA -ge $LTFSARCHIVER_MAXAVAIL ]; then
	main_logger 0 "Maximum running Makeavailable instances ($LTFSARCHIVER_MAXAVAIL) has been reached"
	TYPE_TO_PROCESS="C Z F R W L V"
else
	TYPE_TO_PROCESS="C Z F R W A L V"
fi
#	Loop on task types
for SHORTOP in $TYPE_TO_PROCESS; do
	get_longop $SHORTOP
	main_logger 1 "======== Looking for devices to be used for $LONGOP requests"
	#	For each type of task, get an array with distinct tapes that are requested
	REQUESTED_TAPES=( `$CMD_DB "select ltotape, min(id),ltolibrary from requests where operation='$SHORTOP' and substatus=10 group by ltotape,ltolibrary order by min(id)" \
		| tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	#	For each tape found into array, check if it is already in use
	#	If not, try to find a free tapedevice to be assigned to task
	for ((IDX_TAPE=0; IDX_TAPE<${#REQUESTED_TAPES[@]}; IDX_TAPE+=3)); do
		#	Verifico che il tape non sia gia' in uso
		if [ -z `$CMD_DB "select inuse from lto_info where label='${REQUESTED_TAPES[$IDX_TAPE]}';" | tr -d ' ' | tr '|' ' '` ]; then
			main_logger 1 "Looking for a free tape devices for tape:  ${REQUESTED_TAPES[$IDX_TAPE]}"
			#	CALL get_candidev function and analyze answer
			get_candidev ${REQUESTED_TAPES[$IDX_TAPE]} ${REQUESTED_TAPES[$IDX_TAPE+2]}
			#	If "NONE" is returned means that there no tapedevice available for the requested tape/library
			#	otherwise:
			#	1) select all task of the current type and needing that tape
			#	2) updates them assigning the free tapevices and forwarding status to 20
			#	3) locks the device
			#	4) locks the tape
			if [ $FREE_DEV == "NONE" ]; then
				main_logger 0 "All candidate drives for tape ${REQUESTED_TAPES[$IDX_TAPE]} are in use... requeued"
			else
				UUIDS=( `$CMD_DB "select uuid from requests where ltotape='${REQUESTED_TAPES[$IDX_TAPE]}' and substatus=10 and operation='$SHORTOP';" | tr -d ' ' | tr '\n' ' '` )
				for ((idx=0; idx<${#UUIDS[@]}; idx++)); do
					main_logger 1 "${UUIDS[$idx]} will use device $FREE_DEV"
					#	update status and tapedv assignment
					update_uuid_status ${UUIDS[$idx]} 20 $FREE_DEV
					#	device an tape lock
					if [ $idx == 0 ]; then
						$CMD_DB" insert into lock_table (device,ltolabel) VALUES('$FREE_DEV','${REQUESTED_TAPES[$IDX_TAPE]}')" >/dev/null 2>&1
						$CMD_DB" update lto_info set inuse='$SHORTOP' where label='${REQUESTED_TAPES[$IDX_TAPE]}';" >/dev/null 2>&1
						bkpltoinfo
					fi
				done
			fi
		else
			main_logger 0 " $LONGOP Requests involving tape ${REQUESTED_TAPES[$IDX_TAPE]} requeued: tape already in use"
		fi
	done
done
#	TRAP exit
[ "$BREAK" == 3 ] && exit
#=================================================================================================
#	STEP 8	-	Starting tape agent to run task with resurce assigned
main_logger 3 "------------------------------------->>>    STEP 8 - STARTING TAPE AGENTS"
for SHORTOP in C Z F R W A L V; do
	get_longop $SHORTOP
	#	Get info about first waiting task of that type (substatus=20 if library - substatus=40 for external)
	REQUESTED_AGENTS=( `$CMD_DB "select ltotape, min(id),manager from requests where operation='$SHORTOP' and ((substatus=20 and manager='C') or (substatus=40 and manager='M'))  group by ltotape,manager order by min(id)" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	for ((AGENT_IDX=0; AGENT_IDX<${#REQUESTED_AGENTS[@]}; AGENT_IDX+=3)); do
		#	List of similar tasks
		UUIDS=( `$CMD_DB "select uuid from requests where ltotape='${REQUESTED_AGENTS[$AGENT_IDX]}' and operation='$SHORTOP' and ((substatus=20 and manager='C') or (substatus=40 and manager='M')) order by id;" | tr -d ' ' | tr '\n' ' '` )
		#	forward library task to substatus=30 (will be sent to 40 by tape agent itself)
		if [ ${REQUESTED_AGENTS[$AGENT_IDX+2]} == "C" ]; then
			for ((UUIDto30=0; UUIDto30<${#UUIDS[@]}; UUIDto30++)); do
				update_uuid_status ${UUIDS[$UUIDto30]} 30
			done
		fi
		#	start tape agent passing to it the taskid list
		main_logger 0 "Starting agent for uuid "${UUIDS[@]}
		TAPEAGENTCOMMAND=`dirname $0`"/tape_agent ${UUIDS[@]}"
		$TAPEAGENTCOMMAND 2>$LTFSARCHIVER_LOGDIR/tape_agent_`date +%s`.err &
		sleep 1
	done
done

main_logger 0 "============= All done... ======================================="
rm /tmp/ltfsarchiver.main.$$.lock
exit
