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
		DATA=( `$CMD_DB "select uuid,ltotape,manager from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
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
			update_uuid_status ${DATA[0]} 10 "M" "NONE"
		fi
	;;
	"U")
		UMNT_DATA=( `$CMD_DB "select uuid,ltotape from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
		UMNT_LABEL=${UMNT_DATA[1]}
		main_logger 0 "Dispatching $2 request (uuid: ${UMNT_DATA[0]})"
		#	Dove e' montata?
		UMNT_DEVICE=`$CMD_DB "select device from lock_table where ltolabel='$UMNT_LABEL'" | tr -d ' ' | tr '|' ' '`
		#	Il device e' esterno o interno?
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
		ITEM_TO_ARCH=`$CMD_DB "select sourcefile from requests where id='$3';"  | sed -e 's/^[ \t]*//'`
		if ( [ -d "$ITEM_TO_ARCH" ] ||  [ -f "$ITEM_TO_ARCH" ] ); then
			#	Calcolo spazi e store dei valori sul db
			mbsize=`du -ksm "$ITEM_TO_ARCH" | awk '{ print $1 }'`
			#bytesize=`du -ksb "$ITEM_TO_ARCH" | awk '{ print $1 }'`
			bytesize=`find "$ITEM_TO_ARCH" -type f -printf '%s\n' | awk 'BEGIN{sum=0}{sum+=$1}END{printf "%.0f\n", sum}'`
			$CMD_DB" update requests set sourcesize=$mbsize,sourcebytes=$bytesize where id='$3';" >/dev/null 2>&1
			DATA=( `$CMD_DB "select uuid,poolname,manager,sourcesize from requests where id=$3" | tr -d ' ' | tr '|' ' '` )
			main_logger 0 "Dispatching $2 request using PoolName ${DATA[1]} (uuid: ${DATA[0]})"
			#	Ricerca spazio globale su pool
			for ((POOLINDEX=0; POOLINDEX<${#POOLNAMES[@]}; POOLINDEX++)); do
			        if [ ${POOLNAMES[$POOLINDEX]} == ${DATA[1]} ]; then
			                #       Se lo spazio e' insufficiente
	                		if [ ${AVALSPACES[$POOLINDEX]} -lt ${DATA[3]} ]; then
			                        main_logger 0 "Pool ${DATA[1]} has not enough space (${DATA[3]} MB needed, ${AVALSPACES[$POOLINDEX]} MB available)... uuid=${DATA[0]} sent to fallout"
			                        fallout_uuid ${DATA[0]} 101
					else
						#	Cerco LTO con spazio sufficiente (passo POOLNAME SOURCESIZE MANAGER e UUID)
						get_canditape ${DATA[1]} ${DATA[3]} ${DATA[2]} ${DATA[0]}
						#	Se l'array di ritorno contiene FALSE in prima posizione mando in fallout come da codice ritornato
						if [ ${ASSIGNED_TAPE[0]} == "false" ]; then
							fallout_uuid ${DATA[0]} ${ASSIGNED_TAPE[1]}
						else
							#	Prenoto spazio
							$CMD_DB" update lto_info set booked=booked+'${DATA[3]}' where label='${ASSIGNED_TAPE[1]}'" >/dev/null 2>&1
							bkpltoinfo
							#	Assegno tape
							$CMD_DB" update requests set ltotape='${ASSIGNED_TAPE[1]}' where uuid='${DATA[0]}'" >/dev/null 2>&1
							#	Update substato
							update_uuid_status ${DATA[0]} 10 ${ASSIGNED_TAPE[2]} ${ASSIGNED_TAPE[3]}
			                        	main_logger 1 "Data will be archived on Tape ${ASSIGNED_TAPE[1]}"
						fi
			                fi
				fi
			done
		else
			temp=`$CMD_DB "select uuid from requests where id=$3" | tr -d ' ' `
			main_logger 0 "Item to archive ($ITEM_TO_ARCH) was not found. uuid $temp sent to fallout"
			fallout_uuid $temp 108
		fi
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
CANDIDATES=( `$CMD_DB "select label,(free - booked) as notbooked from lto_info where poolname='$1' and (free - booked) > $2 order by notbooked, label" | 
cut -d '|' -f 1 | grep -v "^$" | sed -e 's/^\ *//' -e 's/\ *$//' | tr '\n' ' '` )
main_logger 3 "Found ${#CANDIDATES[@]} candidate(s): ${CANDIDATES[@]}"
if [ ${#CANDIDATES[@]} == 0 ]; then
	main_logger 0 "No tape belonging to pool $1 has enough space available... uuid=$4 sent to fallout"
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
			for ((CANDIDATE_IDX=0; CANDIDATE_IDX<${#CANDIDATES[@]}; CANDIDATE_IDX++)); do
				find_tape ${CANDIDATES[$CANDIDATE_IDX]}
				if ( $FINDTP_RC == 0 ] || [ $FINDTP_RC == 1 ] ); then
					main_logger 1 "Tape  ${CANDIDATES[$CANDIDATE_IDX]} found in library $CHANGER_DEVICE_N"
					ASSIGNED_TAPE=( "true" "$CANDIDATE_IDX" "C" "$CHANGER_DEVICE_N")
					#	Forzo uscita da ciclo retituedndi
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
function get_candidev ()
#========== funzione che riceve in input  LABEL id libreria (-1 se Manuale)
#	restituisce il devicename  o NONE nella variabile "FREE_DEV"
{
FREE_DEV="NONE"
case $2 in
	"NONE")
		main_logger 1 "looking for external device for tape $1"
		main_logger 4 "${CONF_MANUAL_TAPEDEV[@]}"
		#	Spazzolo l'array dei device interni
		for((idx=0; idx<${#CONF_MANUAL_TAPEDEV[@]}; idx++)); do
			if [ `$CMD_DB "select count(*) from lock_table where device='${CONF_MANUAL_TAPEDEV[$idx]}';" | tr -d ' ' | tr '|' ' '` == 0 ] ; then
				FREE_DEV=${CONF_MANUAL_TAPEDEV[$idx]}
				#	forzo uscita
				idx=${#CONF_MANUAL_TAPEDEV[@]}
			fi
		done
	;;
	*)
		main_logger 4 "looking for internal device for tape $1 (library $2)"
		main_logger 4 "${ARRAY_MAP[@]}"
		#	Spazzolo l'array dei device interni
		for ((idx=0; idx<${#ARRAY_MAP[@]}; idx+=3)); do
			#	considerando solo quelli della libreria indicata
			if [ ${ARRAY_MAP[$idx+1]} ==  $2 ]; then
				#	Se e' libera testo che non sia in realta' occupata da un tape "non ltfsarchiver"
				if [ `$CMD_DB "select count(*) from lock_table where device='${ARRAY_MAP[$idx]}';" | tr -d ' ' | tr '|' ' '` == 0 ] ; then
					#	chiamo rimappature device
					convert_dev_to_dte ${ARRAY_MAP[$idx]}
					main_logger 4 "convert_dev_to_dte ${ARRAY_MAP[$idx]} returned: $DTE_SLOT"
					#	mi faccio restiruire lo sattaus (empy/full)
					DTE_STATUS=( $( status_dte $2 $DTE_SLOT ) )
					main_logger 4 "DTE_STATUS returned value: $DTE_STATUS"
					case ${DTE_STATUS[0]} in
						"empty")
							#	OK, la posso usare
							FREE_DEV=${ARRAY_MAP[$idx]}
							#	forzo uscita
							idx=${#ARRAY_MAP[@]}
						;;
						"full")
							#	NO, non la posso usare... segnalo a log
							main_logger 0 "Oops! Found a stranger tape (${DTE_STATUS[1]})into ${ARRAY_MAP[$idx]} device (changer: $2 - DTE: $DTE_SLOT)"
							#	Tocco un file di lock (non metto a lock_table, o ci vorra' un unlock da interfaccia
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
#	Inizializzazione
CFG_FILE=`dirname $0`/../conf/ltfsarchiver.conf
if [ -f $CFG_FILE ]; then
	. $CFG_FILE
	#	funzioni comuni
	. $LTFSARCHIVER_HOME/sbin/common.sh
	MAIN_LOG_FILE=$LTFSARCHIVER_LOGDIR/ltfsarchiver.`date +%Y%m%d`.log
	MAIN_LOG_ERR=$LTFSARCHIVER_LOGDIR/ltfsarchiver.`date +%Y%m%d`.err
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
	#	valori ammessi per LTFSARCHIVER_CHECKSOUT
	if [ -z $LTFSARCHIVER_CHECKSOUT ]; then
		main_logger 0 "LTFSARCHIVER_CHECKSOUT is empty. Shecksum saving disabled"
	else
		LTFSARCHIVER_CHECKSOUT=`echo $LTFSARCHIVER_CHECKSOUT | tr [A-Z] [a-z]`
		case $LTFSARCHIVER_CHECKSOUT in
			"txt"|"xml"|"json")
				main_logger 4 "LTFSARCHIVER_CHECKSOUT: $LTFSARCHIVER_CHECKSOUT"
			;;
			*)
				main_logger 0 "Invalid LTFSARCHIVER_CHECKSOUT value supplied: $LTFSARCHIVER_CHECKSOUT"
			       	exit 3

			;;
		esac
	fi
	#	funzioni per libreria
	#	controllo solo se diverso da MANUAL
	if [ $LTFSARCHIVER_MODE != "M" ]; then
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
	fi
	#	funzioni per tape
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
	#	funzioni movimento nastri
	if [ $LTFSARCHIVER_MODE != "M" ]; then
		. $LTFSARCHIVER_HOME/sbin/utils/mediamove.sh
	fi
	#	Touch del file di lock
	touch /tmp/ltfsarchiver.main.$$.lock
	#	Directory per JSON files
	[ -d $LTFSARCHIVER_HOME/reportfiles ] || mkdir $LTFSARCHIVER_HOME/reportfiles
	#	Controllo validita' regola "size" per ltfs
	if [ -z $LTFSARCHIVER_RULESIZE ]; then
        	main_logger 1 "LTFS is running without sizerule"
	else
	        CAPITALRULE=`echo $LTFSARCHIVER_RULESIZE | tr '[a-z]' '[A-Z]'`
	        #l_A=${#A}
	        #       La stringa deve essere nella form [0-9]*[A-Z]: 5M - 2G -250K
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
#	log cleaning
find $LTFSARCHIVER_LOGDIR -type f -mtime +7 -exec rm -f {} \;

#
#=================================================================================================
#	FASE 0	-	Cfg librerie e nastri
#	e' su una libreria esterna (common) per essere chamata anche da tape angent
devices_config 1 	# 	$1 = 1 fa stampare output

#=================================================================================================
#       Fase 0  -       Check/Unlock dei device che risultavano avere un nastro "straniero" montato
main_logger 1 "------------------------------------->>>    STEP 0 - Checking locked devices"
for ((idx=0; idx<${#ARRAY_MAP[@]} ;idx+=3)); do
        if [ -e /tmp/ltfsarchiver.`basename ${ARRAY_MAP[$idx]}`.lock ]; then
		convert_dev_to_dte ${ARRAY_MAP[$idx]}
		DTE_STATUS=( $( status_dte ${ARRAY_MAP[$idx+1]} $DTE_SLOT ) )
		[ ${DTE_STATUS[0]} == "empty" ] && rm /tmp/ltfsarchiver.`basename ${ARRAY_MAP[$idx]}`.lock
	fi
done

#=================================================================================================
#	FASE 1	-	Richieste Write con pre-controllo dei checksu forniti da file
main_logger 3 "------------------------------------->>>    STEP 1 - Checksum pre-check"
PRECHECKUUID=( `$CMD_DB "select uuid from requests where substatus=0 and checksum='FILE'" | tr '\n' ' '` )
for ((PRECHECKCOUNT=0; PRECHECKCOUNT<${#PRECHECKUUID[@]}; PRECHECKCOUNT++)); do
#	passo substatus a 4 per evitare che il dispatcher ne tenga conto
	update_uuid_status ${PRECHECKUUID[$PRECHECKCOUNT]} 4
	main_logger 0 "Prechek scheduled for uuid=${PRECHECKUUID[@]}"
	#	Chiamo lo script di archive_precheck su quella uuid (se ok, sara' lui a passare substatus a 6 (se ok) o 99 (se failed)
	PRECHECKCOMMAND=`dirname $0`"/archive_precheck ${PRECHECKUUID[$PRECHECKCOUNT]}"
	$PRECHECKCOMMAND 2>$LTFSARCHIVER_LOGDIR/archive_precheck`date +%s`.err &
done

#=================================================================================================
#	FASE 2	-	Array con nomi e spazi disponibili dei vari pool
main_logger 3 "------------------------------------->>>    STEP 2 - ARRAYS AND SPACES"
main_logger 3 "========== Listing available pools and free spaces =============="
POOLNAMES=( `$CMD_DB "select distinct poolname from lto_info" | tr '\n' ' '` )
for ((POOLINDEX=0; POOLINDEX<${#POOLNAMES[@]}; POOLINDEX++)); do
	AVALSPACE=`$CMD_DB "select sum(free - booked) from lto_info where poolname='${POOLNAMES[$POOLINDEX]}'"`
	AVALSPACES=( "${AVALSPACES[@]}" $AVALSPACE )
	main_logger 1 "Pool ${POOLNAMES[$POOLINDEX]} has ${AVALSPACES[$POOLINDEX]} free MB"
done
#=================================================================================================
#	FASE 4	-	Lista uuid richieste ancora da assegnare ed assegnazione (o fallout)
#		NB: in substatus=6 ci possono essere solo le write con checksum=file e che hanno passato il test
#		    in substatus=6 ci possono essere solo le write con checksum=file e che hanno passato il test
main_logger 3 "------------------------------------->>>    STEP 4 - INSTANCES DISPATCHING"
main_logger 3 "================================================================="
main_logger 0 "================= Looking for new requests ======================"
for SHORTOP in U Z F C R A W; do
	get_longop $SHORTOP
	PENDING_RQST=( `$CMD_DB "select id from requests where operation='$SHORTOP' and (substatus=0 or substatus=6) order by id" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	main_logger 0 "- Looking for new $LONGOP requests... found:  ${#PENDING_RQST[@]}"
	for ((RQST_NUMBER=0; RQST_NUMBER<${#PENDING_RQST[@]}; RQST_NUMBER++)); do
		#	Chiamo la funzione di dispatch
		dispatch_or_fall $SHORTOP $LONGOP ${PENDING_RQST[$RQST_NUMBER]}
	done
done
#=================================================================================================
#	FASE 5	-	Esecuzione immediata degli unmake available
main_logger 3 "------------------------------------->>>    STEP 5 - SATISFYING UNMAKE AVAILABLE"
get_longop "U"
REQUESTED_UUIDS=( `$CMD_DB "select uuid from requests where operation='U' and substatus=20;" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
for ((RQST_IDX=0; RQST_IDX<${#REQUESTED_UUIDS[@]}; RQST_IDX++)) do
	update_uuid_status  ${OPERATION_UUIDS[$RQST_IDX]} 50
	REQUESTED_UMNT=( `$CMD_DB "select ltotape, ltolibrary, device, manager from requests where uuid='${REQUESTED_UUIDS[$RQST_IDX]}';" | tr -d ' ' | tr '|' ' '` )
	main_logger 0 "Starting $LONGOP for tape ${REQUESTED_UMNT[0]} (uuid: ${REQUESTED_UUIDS[$RQST_IDX]})"
	#	ricavo mount point
	MOUNT_POINT=$LTFSARCHIVER_MNTAVAIL/${REQUESTED_UMNT[0]}
	#	E' montato?
	MOUNTED=`mount | grep -c $MOUNT_POINT`
	#	Se non lo e' setto direttamente RC a zero, viceversa chiamo umount e trappo RC
	if [ $MOUNTED == 0 ]; then
		UMOUNT_RC=0
	else
		#	Smonto mount point
		umount $MOUNT_POINT
		UMOUNT_RC=$?
	fi
	main_logger 4 "UMOUNT_RC returned value: $UMOUNT_RC"
	if [ $UMOUNT_RC == 0 ]; then
		main_logger 1 "FS unmounted"
		if [ ${REQUESTED_UMNT[3]} == "M" ]; then
			$CMD_MT -f ${REQUESTED_UMNT[2]} eject
			UNLOAD_RC=$?
		else
			#       passo a dismount libreria e device
			unload_tape ${REQUESTED_UMNT[1]} ${REQUESTED_UMNT[2]}
		fi
		if [ $UNLOAD_RC == 0 ]; then
			[ ${REQUESTED_UMNT[3]} == "M" ] && main_logger 2 "Tape ejected"
			[ ${REQUESTED_UMNT[3]} == "C" ] && main_logger 2 "Tape successfully moved to repository slot"
			#       sblocco il device
			$CMD_DB" delete from lock_table where device='${REQUESTED_UMNT[2]}'" > /dev/null 2>&1
			#       sblocco il nastro
			$CMD_DB" update lto_info set inuse=NULL where label='${REQUESTED_UMNT[0]}'" > /dev/null 2>&1
			bkpltoinfo
			update_uuid_status ${REQUESTED_UUIDS[$RQST_IDX]} 60
			main_logger 0 "${REQUESTED_UUIDS[$RQST_IDX]} succesfully completed"
			#	Rimuovo mount point
			[ -d $MOUNT_POINT ] && rmdir $MOUNT_POINT
		else
			main_logger 0 "CRITICAL ERROR while unloading tape ${REQUESTED_UMNT[0]}"
			[ ${REQUESTED_UMNT[3]} == "M" ] && fallout_uuid ${REQUESTED_UUIDS[$RQST_IDX]} 403
		fi
	else
		main_logger 0 "Tape ${REQUESTED_UMNT[0]} is still in use. I'll try later"
	fi
done
#	Uscita su richiesta
[ "$1" == 1 ] && exit
#=================================================================================================
#	FASE 6	-	Disponibilita' tapedevice
main_logger 3 "------------------------------------->>>    STEP 6 - TAPE DEVICE ASSIGN"
ACTIVE_MA=`$CMD_DB "select count(*) from lto_info where inuse='A';" | tr -d ' '`
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
	REQUESTED_TAPES=( `$CMD_DB "select ltotape, min(id),ltolibrary from requests where operation='$SHORTOP' and substatus=10 group by ltotape,ltolibrary order by min(id)" \
		| tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	for ((IDX_TAPE=0; IDX_TAPE<${#REQUESTED_TAPES[@]}; IDX_TAPE+=3)); do
		#	Verifico che il tape non sia gia' in uso
		if [ -z `$CMD_DB "select inuse from lto_info where label='${REQUESTED_TAPES[$IDX_TAPE]}';" | tr -d ' ' | tr '|' ' '` ]; then
			main_logger 1 "Looking for a free tape devices for tape:  ${REQUESTED_TAPES[$IDX_TAPE]}"
			#	Cerco un device libero in base al manager (C o M)
			get_candidev ${REQUESTED_TAPES[$IDX_TAPE]} ${REQUESTED_TAPES[$IDX_TAPE+2]}
			#	Se trovo "NONE" non ci sono device liberi. Viceversa faccio forward a 20 inserendo device
			#		di tutte le istanze di quel tipo associate a quel tape
			if [ $FREE_DEV == "NONE" ]; then
				main_logger 0 "All candidate drives for tape ${REQUESTED_TAPES[$IDX_TAPE]} are in use... requeued"
			else
				UUIDS=( `$CMD_DB "select uuid from requests where ltotape='${REQUESTED_TAPES[$IDX_TAPE]}' and substatus=10 and operation='$SHORTOP';" | tr -d ' ' | tr '\n' ' '` )
				for ((idx=0; idx<${#UUIDS[@]}; idx++)); do
					main_logger 1 "${UUIDS[$idx]} will use device $FREE_DEV"
					#	update status con assegnazione
					update_uuid_status ${UUIDS[$idx]} 20 $FREE_DEV
					#	Lock del device e del nastro (basta farlo per la prima uid della lista)
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
#	Uscita su richiesta
[ "$1" == 2 ] && exit
#=================================================================================================
#	FASE 7	-	Avvio dei tape agent sulle istanze in substato 20 (se da libreria) e 40 (se esterni)
main_logger 3 "------------------------------------->>>    STEP 7 - STARTING TAPE AGENTS"
for SHORTOP in C Z F R W A; do
	get_longop $SHORTOP
	#	Prima istanza in coda di quel tipo
	REQUESTED_AGENTS=( `$CMD_DB "select ltotape, min(id),manager from requests where operation='$SHORTOP' and ((substatus=20 and manager='C') or (substatus=40 and manager='M'))  group by ltotape,manager order by min(id)" | tr -d ' ' | tr '\n' ' ' | tr '|' ' '` )
	for ((AGENT_IDX=0; AGENT_IDX<${#REQUESTED_AGENTS[@]}; AGENT_IDX+=3)); do
		#	Lista delle uuid dello stesso tipo
		UUIDS=( `$CMD_DB "select uuid from requests where ltotape='${REQUESTED_AGENTS[$AGENT_IDX]}' and operation='$SHORTOP' and ((substatus=20 and manager='C') or (substatus=40 and manager='M')) order by id;" | tr -d ' ' | tr '\n' ' '` )
		#	per quelli via changer passo lo stato a 30 (in caso partisse un altro giro non li beccherebbe piu')
		if [ ${REQUESTED_AGENTS[$AGENT_IDX+2]} == "C" ]; then
			for ((UUIDto30=0; UUIDto30<${#UUIDS[@]}; UUIDto30++)); do
				update_uuid_status ${UUIDS[$UUIDto30]} 30
			done
		fi
		#	Lancio agent con la lista delle uuid
		main_logger 0 "Starting agent for uuid "${UUIDS[@]}
		TAPEAGENTCOMMAND=`dirname $0`"/tape_agent ${UUIDS[@]}"
		$TAPEAGENTCOMMAND 2>$LTFSARCHIVER_LOGDIR/tape_agent_`date +%s`.err &
		sleep 1
	done
done


main_logger 0 "============= All done... ======================================="


rm /tmp/ltfsarchiver.main.$$.lock
exit
