#!/bin/bash
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

#       1.0.0 
#=================================================================================================
function dispatch_or_fall()
#========== funzione che riceve in input un array di richieste ed assegna le risorse
#	in caso di archive deve prima trovare la cassetta con spazio sufficiente
#	in caso di restore / format / check deve solo verificare se e dove si trova
#	$1 uuid
#	$2 tipo operazione (short)
#	$3 tipo operazione (long)
{
case $1 in
	"Z"|"F"|"C"|"R"|"A")	#	Metto nell'array DATA: uuid,label e modalita' operativa	
		DATA=( `$DBACCESS "select uuid,ltotape,manager from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
		main_logger 0 "Dispatching $2 request for tape ${DATA[1]} (uuid: ${DATA[0]})"
		#	Se la gestione prevede l'uso del robot provo a localizzare la cassetta, altrimenti assegno direttamente a manuale
		if ! [ ${DATA[2]} == "M" ]; then
			find_tape ${DATA[1]}
			case $FINDTP_RC in
				0|1)	#	trovata in librerie
					main_logger 1 "Tape  ${DATA[1]} found in library $CHANGER_DEVICE_N"
					#	assegno alla gestione robotizzata, indicando quale libreria lo contiene
					update_uuid_status ${DATA[0]} 10 "C"  $CHANGER_DEVICE_N
				;;
				*)	#	NON trovata in librerie
					main_logger 0 "Tape  ${DATA[1]} not found in any library"
					#	Se e' in configurazione changer only, vado in fallout, altrimenti assegno a manuale
					if [ ${DATA[2]} == "C" ]; then
						fallout_uuid ${DATA[0]} 201
					else
						update_uuid_status ${DATA[0]} 10 "M" "NONE"
					fi
				;;
			esac
		else
			main_logger 0 "Running in Manual mode... Tape ${DATA[1]} not searched"
			update_uuid_status ${DATA[0]} 10 "M" 
		fi
	;;
	"U")
		UMNT_DATA=( `$DBACCESS "select uuid,ltotape from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
		UMNT_LABEL=${UMNT_DATA[1]}
		main_logger 0 "Dispatching $2 request (uuid: ${UMNT_DATA[0]})"
		#	Dove e' montata?
		UMNT_DEVICE=`$DBACCESS "select device from lock_table where ltolabel='$UMNT_LABEL'" | tr -d ' ' | tr '|' ' '`
		#	Il device e' esterno o interno?
		DEV_IDX=0
		unset WHERE
		while ( [ $DEV_IDX -lt ${#MANUAL_TAPE_DEVICES[@]} ] && [ -z $WHERE ] ) ; do
			if  [ ${MANUAL_TAPE_DEVICES[$DEV_IDX]} == $UMNT_DEVICE ]; then
				WHERE="M"
				LTOLIB="NONE"
				DEV_IDX=${#MANUAL_TAPE_DEVICES[@]}
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
		#	Se WHERE e null c'e' qualche errore: mando in fallout, viiceversa faccio dispatch a robot o esterno
		if [ -z $WHERE ]; then
			main_logger 0 "Requested unmount for tape $UMNT_LABEL failed... uuid ${UMNT_DATA[0]}) sent to fallout"
			fallout_uuid ${UMNT_DATA[0]} 901
		else
			update_uuid_status ${UMNT_DATA[0]} 10 $WHERE $LTOLIB
			#	So gia' quale debba essere il device, quindi assegno e avanzo a 20
			main_logger 1 "$UMNT_LABEL found on device $UMNT_DEVICE" 
			update_uuid_status ${UMNT_DATA[0]} 20 $UMNT_DEVICE
		fi
	;;
	"W")
		DATA=( `$DBACCESS "select uuid,poolname,manager,sourcesize from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
		main_logger 0 "Dispatching $2 request using PoolName ${DATA[1]} (uuid: ${DATA[0]})"
		#	Ricerca spazio globale su pool
		POOLINDEX=0
		while [ $POOLINDEX -lt ${#POOLNAMES[@]} ]; do
		        if [ ${POOLNAMES[$POOLINDEX]} == ${DATA[1]} ]; then
		                #       Se lo spazio e' insufficiente
                		if [ ${AVALSPACES[$POOLINDEX]} -lt ${DATA[3]} ]; then
		                        main_logger 0 "Pool ${DATA[1]} has not enough space (${DATA[3]} MB needed, ${AVALSPACES[$POOLINDEX]} MB available)... uuid=${DATA[0]} sent to fallout"
		                        fallout_uuid ${DATA[0]} 101
				else
					#	Cerco LTO con spazio sufficiente 
					get_canditape ${DATA[1]} ${DATA[3]} ${DATA[2]}
					#	Se l'array di ritorno contiene FALSE in prima posizione mando in fallout come da codice ritornato
					if [ ${ASSIGNED_TAPE[0]} == "false" ]; then
						fallout_uuid ${DATA[0]} $ASSIGNED_TAPE[1]
					else
						#	Prenoto spazio
						$DBACCESS" update lto_info set booked=booked+'${DATA[3]}' where label='${ASSIGNED_TAPE[1]}'" >/dev/null 2>&1
						#	Assegno tape
						$DBACCESS" update requests set ltotape='${ASSIGNED_TAPE[1]}' where uuid='${DATA[0]}'" >/dev/null 2>&1
						#	Update substato
						update_uuid_status ${DATA[0]} 10 ${ASSIGNED_TAPE[2]} ${ASSIGNED_TAPE[3]}
		                        	main_logger 1 "Data will be archived on Tape ${ASSIGNED_TAPE[1]}"
					fi
		                fi
			fi

			let POOLINDEX+=1
		done
	;;
esac
}
#=================================================================================================
function get_canditape ()
#========== funzione che riceve in input  POOLNAME SPAZIORICHIESTO MODALITA
#	Se opera in modalita' mista favorisce interno
#	Se opera in modalita' changer va in fallout
#	Se trova un LTO utilizzabile restituisce  (TRUE LABEL [M|C] e "arrayindex della libreria (-1) se esterno") 
#	Se non trova un LTO utilizzabile restituisce FALSE FALLOUTCODE
{
unset ASSIGNED_TAPE
unset LOCATION
CANDIDATES=( `$DBACCESS "select label,(free - booked) as notbooked from lto_info where poolname='$1' and (free - booked) > $2 order by notbooked" | 
cut -d '|' -f 1 | grep -v "^$" | sed -e 's/^\ *//' -e 's/\ *$//' | tr '\n' ' '` )
main_logger 3 "Found ${#CANDIDATES[@]} candidate(s): ${CANDIDATES[@]}"
if [ ${#CANDIDATES[@]} == 0 ]; then
	main_logger 0 "No tape belonging to pool $POOLNEEDED has enough space available... uuid=${REQUEST_PARMS[0]} sent to fallout"
	ASSIGNED_TAPE=( "false" "102" )
else
	#	Parto dal presupposto che sia esterna
	LOCATION="M"
	LIBRARY="NONE"
	case $3 in
		"M"|"B")	#	Se lavoro in Manuale io Both assegno la prima trovata e via
				#	Se lavoro in Both devo ora verificare se e' in libreria o no
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
		"C")		#       Se lavoro in Changer: devo verificare che sia in libreria
				#	In caso passo alla successiva e via cosi'... se non ne trovo alcuna esco con false
				#	Parto dal presupposto che sia esterna
			ASSIGNED_TAPE=( "false" "103" )
			CANDIDATE_IDX=0
			while [ $CANDIDATE_IDX -lt ${#CANDIDATES[@]} ]; do
				find_tape ${CANDIDATES[$CANDIDATE_IDX]}
				if ( $FINDTP_RC == 0 ] || [ $FINDTP_RC == 1 ] ); then
					main_logger 1 "Tape  ${CANDIDATES[$CANDIDATE_IDX]} found in library $CHANGER_DEVICE_N"
					ASSIGNED_TAPE=( "true" "$CANDIDATE_IDX" "C" "$CHANGER_DEVICE_N")
					#	Forzo uscita da ciclo retituedndi
					CANDIDATE_IDX=${#CANDIDATES[@]}
				else
					main_logger 1 "Tape  ${CANDIDATES[$CANDIDATE_IDX]} not found in any library; looking for next one"
				fi
				let CANDIDATE_IDX+=1
			done
		;;
	esac
fi
}

#================================================================================================
function get_candidev ()
#========== funzione che riceve in input  LABEL id libreria (-1 se Manuale)
#	restituisce il devicename  o NONE nella variabile "FREE_DEV"
{
FREE_DEV="NONE"
idx=0
case $2 in
	"NONE")
		main_logger 1 "looking for external device for tape $1"
		main_logger 4 "${MANUAL_TAPE_DEVICES[@]}"
		#	Spazzolo l'array dei device interni
		while [ $idx -lt  ${#MANUAL_TAPE_DEVICES[@]} ]; do
			if [ `$DBACCESS "select count(*) from lock_table where device='${MANUAL_TAPE_DEVICES[$idx]}';" | tr -d ' ' | tr '|' ' '` == 0 ] ; then
				FREE_DEV=${MANUAL_TAPE_DEVICES[$idx]}
				#	forzo uscita
				idx=${#MANUAL_TAPE_DEVICES[@]}
			fi
			let idx+=1
		done
	;;
	*)
		main_logger 4 "looking for internal device for tape $1 (library $2)"
		main_logger 4 "${ARRAY_MAP[@]}"
		#	Spazzolo l'array dei device interni
		while [ $idx -lt  ${#ARRAY_MAP[@]} ]; do
			#	considerando solo quelli della libreria indicata
			if [ ${ARRAY_MAP[$idx+1]} ==  $2 ]; then
				#	Se e' libera associo
				if [ `$DBACCESS "select count(*) from lock_table where device='${ARRAY_MAP[$idx]}';" | tr -d ' ' | tr '|' ' '` == 0 ] ; then
					FREE_DEV=${ARRAY_MAP[$idx]}
					#	forzo uscita
					idx=${#ARRAY_MAP[@]}
				fi
			fi
			let idx+=3
		done
	;;

esac
}
#-----------------------------------------------------------------------------------------------------------
#=================================================================================================
#	MAIN MAIN MAIN
#	Inizializzazione
CFG_FILE=`dirname $0`/../conf/ltfsarchiver.conf
if [ -f $CFG_FILE ]; then
	. $CFG_FILE
	#	funzioni comuni
	. $LTFSARCHIVER_HOME/sbin/common.sh
	MAIN_LOG_FILE=$LTFSARCHIVER_LOGDIR/ltfsarchiver.`date +%Y%m%d`.log
	[ -d $LTFSARCHIVER_LOGDIR ] || mkdir -p $LTFSARCHIVER_LOGDIR
	STARTMSG="------------> Starting "
	#	POSTGRES STA GIRANDO?
	service postgresql status >/dev/null 2>&1
	PSQL_RUN=$?
	if [ $PSQL_RUN -gt 0 ]; then
		main_logger 0 "Postgresql inattivo..."
		exit 3
	fi
	#	Mount point per makeavailable
	[ -d $LTFSARCHIVER_MNTAVAIL ] || mkdir -p $LTFSARCHIVER_MNTAVAIL
	#	Modalita operativa
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
	#	funzioni per libreria
	#	controllo solo se diverso da MANUAL
	if [ $LTFSARCHIVER_MODE != "M" ]; then
		case $CHANGER_TYPE in
       			"MSL")
			       	. $LTFSARCHIVER_HOME/sbin/utils/msl_util.sh
				main_logger 4 "MediaChanger type: $CHANGER_TYPE"
		       	;;
		       	*)
				main_logger 0 "MediaChanger type unknown: $CHANGER_TYPE"
			       	exit 3
	       		;;
	       	esac
	fi
	#	funzioni per tape
	case $TAPE_TYPE in
		"LTO")
			. $LTFSARCHIVER_HOME/sbin/utils/lto_util.sh
			main_logger 4 "Tapedrive type: $TAPE_TYPE"
		;;
		*)
			main_logger 0 "Tapedrive type unknown: $TAPE_TYPE"
		exit 3
	;;
	esac
	#	funzioni movimento nastri
	if [ $LTFSARCHIVER_MODE != "M" ]; then
		. $LTFSARCHIVER_HOME/sbin/utils/mediamove.sh
	fi
	#	Touch del file di lock
	touch /tmp/ltfsarchiver.main.$$.lock
else
	echo "missing cfg file"
	exit 1
fi
#	log cleaning
find $LTFSARCHIVER_LOGDIR -type f -mtime +7 -exec rm -f {} \;

#
#=================================================================================================
#	FASE 1	-	Cfg librerie e nastri
#	e' su una libreria esterna (common) per essere chamata anche da tape angent
devices_config 1 	# 	$1 = 1 fa stampare output

#=================================================================================================
#	FASE 2	-	Array con nomi e spazi disponibili dei vari pool
main_logger 3 "------------------------------------->>>    STEP 2 - ARRAYS AND SPACES"
main_logger 3 "========== Listing available pools and free spaces =============="
POOLNAMES=( `$DBACCESS "select distinct poolname from lto_info" | tr '\n' ' '` )
POOLINDEX=0
while [ $POOLINDEX -lt ${#POOLNAMES[@]} ]; do
	AVALSPACE=`$DBACCESS "select sum(free - booked) from lto_info where poolname='${POOLNAMES[$POOLINDEX]}'"`
	AVALSPACES=( "${AVALSPACES[@]}" $AVALSPACE )
	main_logger 1 "Pool ${POOLNAMES[$POOLINDEX]} has ${AVALSPACES[$POOLINDEX]} free MB"
	let POOLINDEX+=1
done
#=================================================================================================
#	FASE 3	-	Lista uuid richieste ancora da assegnare ed assegnazione (o fallout)
main_logger 3 "------------------------------------->>>    STEP 3 - INSTANCES DISPATCHING"
main_logger 3 "================================================================="
main_logger 0 "================= Looking for new requests ======================"
for SHORTOP in U Z F C R A W; do
	get_longop $SHORTOP
	PENDING_RQST=( `$DBACCESS "select id from requests where operation='$SHORTOP' and substatus=0 order by id" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	main_logger 0 "- Looking for new $LONGOP requests... found:  ${#PENDING_RQST[@]}"
	RQST_NUMBER=0
	while [ $RQST_NUMBER -lt ${#PENDING_RQST[@]} ]; do
		#	Chiamo la funzione di dispatch
		dispatch_or_fall $SHORTOP $LONGOP ${PENDING_RQST[$RQST_NUMBER]}
		let RQST_NUMBER+=1
	done
done
#=================================================================================================
#	FASE 4	-	Esecuzione immediata degli unmake available
main_logger 3 "------------------------------------->>>    STEP 4 - SATISFYING UNMAKE AVAILABLE"
get_longop "U"
REQUESTED_UUIDS=( `$DBACCESS "select uuid from requests where operation='U' and substatus=20;" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
RQST_IDX=0
while [ $RQST_IDX -lt ${#REQUESTED_UUIDS[@]} ]; do
	update_uuid_status  ${OPERATION_UUIDS[$RQST_IDX]} 50
	REQUESTED_UMNT=( `$DBACCESS "select ltotape, ltolibrary, device, manager from requests where uuid='${REQUESTED_UUIDS[$RQST_IDX]}';" | tr -d ' ' | tr '|' ' '` )
	main_logger 0 "Starting $LONGOP for tape ${OPERATION_UUIDS[$RQST_IDX]}"
	#	ricavo mount point
	MOUNT_POINT=$LTFSARCHIVER_MNTAVAIL/${REQUESTED_UMNT[0]}
	#       E' montato?
	MOUNTED=`mount | grep -c $MOUNT_POINT`
	#       Se non lo e' setto direttamente RC a zero, viceversa chiamo umount e trappo RC
	if [ $MOUNTED == 0 ]; then
		UMOUNT_RC=0
	else
		#       Smonto mount point
		umount $MOUNT_POINT
		UMOUNT_RC=$?
	fi
	main_logger 4 "UMOUNT_RC returned value: $UMOUNT_RC"
	if [ $UMOUNT_RC == 0 ]; then
		main_logger 1 "FS unmounted"
		if [ ${REQUESTED_UMNT[3]} == "M" ]; then
			$MT_CMD -f ${REQUESTED_UMNT[2]} eject
			UNLOAD_RC=$?
		else
			#       passo a dismount libreria e device
			unload_tape ${REQUESTED_UMNT[1]} ${REQUESTED_UMNT[2]}
		fi
		if [ $UNLOAD_RC == 0 ]; then
			[ ${REQUESTED_UMNT[3]} == "M" ] && main_logger 2 "Tape ejected"
			[ ${REQUESTED_UMNT[3]} == "C" ] && main_logger 2 "Tape successfully moved to repository slot"
			#       sblocco il device
			$DBACCESS" delete from lock_table where device='${REQUESTED_UMNT[2]}'" > /dev/null 2>&1
			#       sblocco il nastro
			$DBACCESS" update lto_info set inuse=NULL where label='${REQUESTED_UMNT[0]}'" > /dev/null 2>&1
			update_uuid_status ${REQUESTED_UUIDS[0]} 60
			main_logger 0 "${REQUESTED_UUIDS[0]} succesfully completed"
			#	Rimuovo mount point
			[ -d $MOUNT_POINT ] && rmdir $MOUNT_POINT
		else
			main_logger 0 "CRITICAL ERROR while unloading tape ${REQUESTED_UMNT[0]}"
			[ ${REQUESTED_UMNT[3]} == "M" ] && fallout_uuid ${REQUESTED_UUIDS[$RQST_IDX]} 403
		fi
	else
		main_logger 0 "Tape ${REQUESTED_UMNT[0]} is still in use. I'll try later"
	fi
	let RQST_IDX+=1
done
#	Uscita su richiesta
[ "$1" == 1 ] && exit
#=================================================================================================
#	FASE 5	-	Disponibilita' tapedevice
main_logger 3 "------------------------------------->>>    STEP 5 - TAPE DEVICE ASSIGN"
ACTIVE_MA=`$DBACCESS "select count(*) from lto_info where inuse='A';" | tr -d ' '`
if [ $ACTIVE_MA -ge $LTFSARCHIVER_MAXAVAIL ]; then
	main_logger 0 "Maximum running Makeavailable instances ($LTFSARCHIVER_MAXAVAIL) has been reached"
	TYPE_TO_PROCESS="C Z F R W"
else
	TYPE_TO_PROCESS="C Z F R W A"
fi

#for SHORTOP in C Z F R W A; do
for SHORTOP in $TYPE_TO_PROCESS; do
	get_longop $SHORTOP
	main_logger 1 "======== Looking for tapes to be used for $LONGOP requests"
	#	Per ogni tipo di operazione cerco i distinct tape da usare
	REQUESTED_TAPES=( `$DBACCESS "select ltotape, min(id),ltolibrary from requests where operation='$SHORTOP' and substatus=10 group by ltotape,ltolibrary order by min(id)" \
		| tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	IDX_TAPE=0
	while [ $IDX_TAPE -lt ${#REQUESTED_TAPES[@]} ]; do
		#	Verifico che il tape non sia gia' in uso
		if [ -z `$DBACCESS "select inuse from lto_info where label='${REQUESTED_TAPES[$IDX_TAPE]}';" | tr -d ' ' | tr '|' ' '` ]; then
			main_logger 1 "Looking for a free tape devices for tape:  ${REQUESTED_TAPES[$IDX_TAPE]}"
			#	Cerco un device libero in base al manager (C o M)
			get_candidev ${REQUESTED_TAPES[$IDX_TAPE]} ${REQUESTED_TAPES[$IDX_TAPE+2]}
			#	Se trovo "NONE" non ci sono device liberi. Viceversa faccio forward a 20 inserendo device
			#		di tutte le istanze di quel tipo associate a quel tape
			if [ $FREE_DEV == "NONE" ]; then
				main_logger 0 "All candidate drives for tape ${REQUESTED_TAPES[$IDX_TAPE]} are in use... requeued"
			else
				UUIDS=( `$DBACCESS "select uuid from requests where ltotape='${REQUESTED_TAPES[$IDX_TAPE]}' and substatus=10 and operation='$SHORTOP';" | tr -d ' ' | tr '\n' ' '` )
				idx=0
				while [ $idx -lt ${#UUIDS[@]} ]; do
					main_logger 1 "${UUIDS[$idx]} will use device $FREE_DEV"
					#	update status con assegnazione
					update_uuid_status ${UUIDS[$idx]} 20 $FREE_DEV
					#	Lock del device e del nastro (basta farlo per la prima uid della lista)
					if [ $idx == 0 ]; then
						$DBACCESS" insert into lock_table (device,ltolabel) VALUES('$FREE_DEV','${REQUESTED_TAPES[$IDX_TAPE]}')" >/dev/null 2>&1
						$DBACCESS" update lto_info set inuse='$SHORTOP' where label='${REQUESTED_TAPES[$IDX_TAPE]}';" >/dev/null 2>&1
					fi
					let idx+=1
				done
			fi
		else
			main_logger 0 " $LONGOP Requests involving tape ${REQUESTED_TAPES[$IDX_TAPE]} requeued: tape already in use"
		fi
		let IDX_TAPE+=3
	done
done
#	Uscita su richiesta
[ "$1" == 2 ] && exit
#=================================================================================================
#	FASE 6	-	Avvio dei tape agent sulle istanze in substato 20 (se da libreria) e 40 (se esterni)
main_logger 3 "------------------------------------->>>    STEP 6 - STARTING TAPE AGENTS"
for SHORTOP in C Z F R W A; do
	get_longop $SHORTOP
	#	Prima istanza in coda di quel tipo
	REQUESTED_AGENTS=( `$DBACCESS "select ltotape, min(id),manager from requests where operation='$SHORTOP' and ((substatus=20 and manager='C') or (substatus=40 and manager='M'))  group by ltotape,manager order by min(id)" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	AGENT_IDX=0
	while [ $AGENT_IDX -lt ${#REQUESTED_AGENTS[@]} ]; do
		#	Lista delle uuid dello stesso tipo
		UUIDS=( `$DBACCESS "select uuid from requests where ltotape='${REQUESTED_AGENTS[$AGENT_IDX]}' and operation='$SHORTOP' and ((substatus=20 and manager='C') or (substatus=40 and manager='M'));" \
			 | tr -d ' ' | tr '\n' ' '` )
		#	per quelli via changer passo lo stato a 30 (in caso partisse un altro giro non li beccherebbe piu')
		if [ ${REQUESTED_AGENTS[$AGENT_IDX+2]} == "C" ]; then
			UUIDto30=0
			while [ $UUIDto30 -lt ${#UUIDS[@]} ]; do
				update_uuid_status ${UUIDS[$UUIDto30]} 30
				let UUIDto30+=1
			done
		fi
		#	Lancio agent con la lista delle uuid
		main_logger 0 "Starting agent for uuid "${UUIDS[@]}
		TAPEAGENTCOMMAND=`dirname $0`"/tape_agent ${UUIDS[@]}"
		$TAPEAGENTCOMMAND 2>$LTFSARCHIVER_LOGDIR/tape_agent_`date +%s`.err &
		sleep 1
		let AGENT_IDX+=3
	done
done


main_logger 0 "============= All done... ======================================="


rm /tmp/ltfsarchiver.main.$$.lock
exit
