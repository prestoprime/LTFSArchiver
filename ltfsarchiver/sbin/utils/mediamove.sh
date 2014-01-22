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

#-------------------------------------------------------------------------------
#	Load/Unload functions for tapelibrary(ies)
function load_tape()
{
#	Incoming parms:
#		$1 tapelibrary devicename
#		$2 ltodrive devicename
#		$3 tapelabel to be loaded
#	step1: determine the DTE id of the ltodriver
#		issued only if library is NON "NONE"
#		If library is "NONE" the tape is supposed to be manually loaded
if [ $1 == "NONE" ]; then
	LOAD_RC=0
else
	main_logger 3 "converting dev id $2 in DTE id"
	convert_dev_to_dte $2
	#	tape location
	SRC_SLOT=$( locate_tape $1 $3 )
	if [ -z $SRC_SLOT ]; then
		main_logger 0 "Oops: $3 was not found"
		main_logger 0 "Instances will be sent to fallout"
		FALLOUT_CODE=301
		LOAD_RC=99
		LOAD_OK="N"
	else
		main_logger 2 "OK, $3 was found into slot n. $SRC_SLOT... loading"
		$CMD_MTX -f $1 load $SRC_SLOT $DTE_SLOT >>$MAIN_LOG_ERR 2>&1
		LOAD_RC=$?
		main_logger 4 "LOAD_RC returned value: $LOAD_RC"
	fi
fi
#	If the tape is loaded...check status
if [ $LOAD_RC == 0 ]; then
	main_logger 2 "$3 loaded succesfully"
	get_tape_status $2
	main_logger 4 "TAPE_STATUS_RC returned value: $TAPE_STATUS_RC"
	#	if OK status is returned go on, otherwise unload and give up
	if [ $TAPE_STATUS_RC == 0 ]; then
		LOAD_OK="Y"
	else
		main_logger 0 "Tape status error after load: RC=$TAPE_STATUS_RC (Tape is $TAPE_STATUS_MSG)... following instances will be sent to fallout"	
		FALLOUT_CODE=306
		#	EJECT o unload according to driver type (external or internal)
		if [ $1 == "NONE" ]; then
			#	EJECT only
			$CMD_MT -f $2 eject
			if [ $? != 0 ]; then
				main_logger 0 "CRITICAL ERROR while ejecting $3"
				FALLOUT_CODE=303
			fi
			LOAD_OK="N"
		else
			#	UNLOAD
			$CMD_MTX -f $1 unload $SRC_SLOT $DTE_SLOT >>$MAIN_LOG_ERR 2>&1
			if [ $? != 0 ]; then
				main_logger 0 "CRITICAL ERROR while returning $3 to storage slot $SRC_SLOT"
				FALLOUT_CODE=305 #	(303 & 304)
			fi
			LOAD_OK="N"
		fi
	fi
else
	#	Failure of unload command has to be fired only if the tape was internal
	if [ $1 != "NONE" ]; then
		main_logger 0 "Error while moving tape to DTE... following instances will be sent to fallout"
		LOAD_OK="N"
		FALLOUT_CODE=302
	fi
fi
}

function unload_tape()
{
#	Incoming parms:
#		$1 tapelibrary devicename
#		$2 ltodrive devicename
#	some mtx command is already running? If so, wait
while [ -f $LTFSARCHIVER_LOGDIR/mtx.lock ]; do
	main_logger 1 "waiting for mtx availability"
	sleep 1
done
#	My turn to execute mtx. I put a lock
touch $LTFSARCHIVER_LOGDIR/mtx.lock
#	Determining DTE # from device
convert_dev_to_dte $2
#	Destination slot (the first free one)
TRG_SLOT=$( locate_slot $1 )
#	It shoulb be at least one, but if not...
if [ -z $TRG_SLOT ]; then
	UNLOAD_RC=16
	UNLOAD_ERROR="Unable to find a free slot to move the tape"
else
	#	Looping on unload command for a maximum of 5 times
	for ((attempt=1; attempt<6; attempt++)); do
		$CMD_MTX -f $1 unload $TRG_SLOT $DTE_SLOT >>$MAIN_LOG_ERR 2>&1
		UNLOAD_RC=$?
		main_logger 4 "unload attempt $attempt: UNLOAD_RC returned value: $UNLOAD_RC"
		if [ $UNLOAD_RC != 0 ]; then
			UNLOAD_ERROR="Error while unloading from device $2: RC=$UNLOAD_RC (attempt n. $attempt)"
			main_logger 0 "$UNLOAD_ERROR"
			sleep `echo "$attempt * 5" | bc`
			
		else
			attempt=6
		fi
	done
fi
#	ok, lock removing
rm -f $LTFSARCHIVER_LOGDIR/mtx.lock
}
