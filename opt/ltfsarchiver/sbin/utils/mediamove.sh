#  PrestoPRIME  LTFSArchiver
#  Version: 0.9 Beta
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
#	Funzioni di mount e dismount nastri
function load_tape()
{
#	Mi arrivano:
#		$1 devicename della libreria
#		$2 devicename del driver
#		$3 label del nastro da montare
#	remap del tapedevice su numero di DTE
if [ $1 == "NONE" ]; then	#	se la libreria e' NONE significa che e' un tape esterno... metto a Yes l'ok alla movimentazione
	LOAD_RC=0
else
	main_logger 3 "converting dev id $2 in DTE id"
	convert_dev_to_dte $2
	#	localizzo il tape 
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
#	A mano o con robot, DOVREBBE essere stato inserito... 
if [ $LOAD_RC == 0 ]; then
	main_logger 2 "$3 loaded succesfully"
	#	controllo status
	get_tape_status $2
	main_logger 4 "TAPE_STATUS_RC returned value: $TAPE_STATUS_RC"
	#	Se ritorna OK,
	#	altrimenti smonto e mando in fallout
	if [ $TAPE_STATUS_RC == 0 ]; then
		LOAD_OK="Y"
	else
		main_logger 0 "Tape status error after load: RC=$TAPE_STATUS_RC (Tape is $TAPE_STATUS_MSG)... following instances will be sent to fallout"
		FALLOUT_CODE=303
		#	EJECT o unload a seconda che sia interno o esterno
		if [ $1 == "NONE" ]; then
			#	faccio solo eject
			$CMD_MT -f $2 eject
			if [ $? != 0 ]; then
				main_logger 0 "CRITICAL ERROR while ejecting $3"
				FALLOUT_CODE=303
			fi
			LOAD_OK="N"
		else
			#	SMONTO
			$CMD_MTX -f $1 unload $SRC_SLOT $DTE_SLOT >>$MAIN_LOG_ERR 2>&1
			if [ $? != 0 ]; then
				main_logger 0 "CRITICAL ERROR while returning $3 to storage slot $SRC_SLOT"
				FALLOUT_CODE=305 #	(303 & 304)
			fi
			LOAD_OK="N"
		fi
	fi
else
	#	l'errore di movimentazione ha senso solo se a farlo e' stato il robot
	if [ $1 != "NONE" ]; then
		main_logger 0 "Error while moving tape to DTE... following instances will be sent to fallout"
		LOAD_OK="N"
		FALLOUT_CODE=302
	fi
fi
}

function unload_tape()
#	Mi arrivano:
#		$1 devicename della libreria
#		$2 devicename del driver
#	remap del tapedevice su numero di DTE
{
#	finche' esiste un lock aspetto
while [ -f $LTFSARCHIVER_LOGDIR/mtx.lock ]; do
	main_logger 1 "waiting for mtx availability"
	sleep 1
done
#	blocco eventuali altre chiamate fino a che non ho scaricato
touch $LTFSARCHIVER_LOGDIR/mtx.lock
convert_dev_to_dte $2
TRG_SLOT=$( locate_slot $1 )
if [ -z $TRG_SLOT ]; then
	UNLOAD_RC=16
	UNLOAD_ERROR="Unable to find a free slot to move the tape"
else
	for ((attempt=1; attempt<6; attemp++)); do
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
#	rimuovo blocco mtx
rm -f $LTFSARCHIVER_LOGDIR/mtx.lock
}
