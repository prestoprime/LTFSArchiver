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

#-----------------------------------------------------------------------
#	DEVICES CONFIG
#	popola le variabili (array) con la cfg di librerie e nastri
#	Se chiamata da ltfsarchiver stampa a video
#	Se chiamata da tape_agent no
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
#	scrive a log la stringa passatai $2, se loglevel >= a $1
function main_logger ()
{
if [ $LTFSARCHIVER_LOGLEVEL -ge $1 ]; then
	echo `date +%Y-%m-%d_%T`" -> "`echo $@ | sed -e 's/^'$1'//'` >> $MAIN_LOG_FILE
fi
if [ $LTFSARCHIVER_DEBUG == 1 ]; then
	echo $@
fi
}
function get_longop()
{
case $1 in
        "U")
                LONGOP="UNMAKEAVALABLE"
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
esac
}
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
#	tenta mount ltfs e restituisc errore
#	$1	device
#	$2	label nastro
#	$3	Mount mode 
#	$4	Mount point
#	$5	checklabel
function mount_ltfs ()
{
#	GID e UID
MOUNTUID=`id -u $LTFSARCHIVER_USER`
MOUNTGID=`id -g $LTFSARCHIVER_USER`
#	Log temporaneo (messaggistica LTFS)
TEMPLOG="/tmp/`basename $1`.tmp"
#       Se non esiste lo creo
[ -d $4 ] || mkdir $4
#	RIcerca backend
for ((BIDX=0;BIDX<${#CONF_BACKENDS[@]};BIDX+=2)); do
	if [ ${CONF_BACKENDS[$BIDX]} == $1 ]; then
		TAPE_BACKEND=${CONF_BACKENDS[$BIDX+1]}
	fi
done
#	Eseguo mount
$CMD_LTFS -o devname=$1 -o $3 -o sync_type=$LTFSARCHIVER_LTFSSYNC  -o tape_backend=$TAPE_BACKEND -o uid=$MOUNTUID -o gid=$MOUNTGID  $4 2> $TEMPLOG
LTFSRC=$?
if [ $LTFSRC == 0 ]; then
	#	Se ho richiesto mount in rw devo verificare che non sia stato forzato ro per "troppopieno"
	if  [ $3 == "rw" ]; then
		TROPPOPIENO=`grep -c "LTFS20022I" $TEMPLOG`
		if [ $TROPPOPIENO -gt 0 ]; then
			#	loggo evento
			main_logger 2 "`grep 'LTFS20022I' $TEMPLOG`"
			#	forzo a zero il freespace
			main_logger 0 "Tape $2 has reached its max capabilty... marking it as full"
			$CMD_DB" update lto_info set free=0,booked=0 where label='$2';" >/dev/null 2>&1
			LTFS_RC=4
			umount $4
		else
			main_logger 1 "ltfs mount completed: `grep 'LTFS11031I' $TEMPLOG`"
			LTFS_RC=0
		fi
	else
		main_logger 1 "ltfs mount completed: `grep 'LTFS11031I' $TEMPLOG`"
		#	Controllo label (Archive / Restore / Makeavailable)
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
	#	loggo intera messaggistica ltfs
	IFS=$'\n'
	for RIGA in `cat $TEMPLOG`; do
		main_logger 0 "$RIGA"
	done
	unset IFS
	#	loggo il fail
	main_logger 0 "Tape $2 has some FS problemi:... marking it as unusable"
	#	forzo a zero il free space (label=$2) per non usarlo in futuro
	$CMD_DB" update lto_info set free=0,booked=0 where label='$2';" >/dev/null 2>&1
fi
[ -f $TEMPLOG ] && rm -f $TEMPLOG
}

function fallout_uuid ()
{
utime=`date '+%Y-%m-%d %H:%M:%S'`
#	il substatus di fallout e' solitamente 99
#	Ma se vado in fallout PRIMA della prenotazione dello spazio, lo passo a 9, in modo da poterlo cancellare
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
		FALLOUTSTRING="bad_request"
	;;
	110)
		Description="Mismatch found between checksum file and file system (filename(s) differs)"
		FALLOUTSTATUS=19
		FALLOUTSTRING="bad_request"
	;;
	111)
		Description="Some file didn not pass checksum verification"
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
	501)
		Description="Error while formatting LTO"
	;;
	502)
		Description="Error while mounting ltfs"
	;;
	601)
		Description="Internal label not matching with requested LTO"
	;;
	901)
		Description="Unexpected error while looking for device containing made available tape"
	;;
	*)
		Description="Error unknown: $2"
	;;
esac
$CMD_DB" update requests set status='"$FALLOUTSTRING"', substatus=$FALLOUTSTATUS, endtime='$utime', errorcode=$2, errordescription='$Description' where uuid='$1';" >/dev/null 2>&1
}
function update_uuid_status ()
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
function substatus_descr()
{
case $1 in
	0)
		echo "Waiting to be loaded"
	;;
	4)
		echo "Running pre-archiving checksumx "
	;;
	6)
		echo "Archive precheck passed, waiting to be dispatched"
	;;
	10)
		echo "Dispatched, waiting for tape device"
	;;
	20)
		echo "Dispatched, waiting for tape loading"
	;;
	30)
		echo "Tape being loaded o positioning"
	;;
	40)
		echo "Tape loaded and ready"
	;;
	50)
		echo "Running - data copying"
	;;
	55)
		echo "Runningi - post data processing"
	;;
	60)
		echo "Completed"
	;;
	99)
		echo "Fallout"
	;;
	*)
	;;
esac
}
#-----------------------------------------------------------------------
#	GET_FORMAT_RULES
#	restitusce l'eventuale stringa con le regole spazio/estensioni per format
function get_format_rules
{
#	Opzioni baee (nessuna)
MKLTFS_RULES=""
#	ci sono regole?
#	Se manca quella sulla dimensione non considero nemmeno quelle sulle estensioni:
#	LTFS11157E Cannot specify a name rule without a size rule
if ! [ -z $LTFSARCHIVER_RULESIZE ]; then
#	Regola su size
	MKLTFS_RULES="-r size=$LTFSARCHIVER_RULESIZE"
	#	Regole su estensioni
	if [ ${#LTFSARCHIVER_RULEEXTS[@]} -gt 0 ]; then
		MKLTFS_RULES=$MKLTFS_RULES"/"
		for ((EXTIDX=0;EXTIDX<${#LTFSARCHIVER_RULEEXTS[@]};EXTIDX++)); do
		        [ $EXTIDX == 0 ] &&  MKLTFS_RULES=$MKLTFS_RULES"name="
		        MKLTFS_RULES=$MKLTFS_RULES'*.'${LTFSARCHIVER_RULEEXTS[$EXTIDX]}
		        [ $EXTIDX -lt `echo ${#LTFSARCHIVER_RULEEXTS[@]} -1 | bc` ] &&  MKLTFS_RULES=$MKLTFS_RULES':'
		done
	fi
fi
#	Ammesso override? PER ORA NO
#( [ $LTFSARCHIVER_RULEOVER == "Y" ] || [ $LTFSARCHIVER_RULEOVER == "y" ] ) ||  MKLTFS_RULES=$MKLTFS_RULES" -o"
MKLTFS_RULES=$MKLTFS_RULES" -o"
echo $MKLTFS_RULES
}
#-----------------------------------------------------------------------
#	GET_RSYNC_RULES
#	restitusce l'eventuale stringa con le regole spazio/estensioni per rsync
function get_rsync_rules
{
#       Opzioni baee (nessuna)
RSYNC_RULES=""
#       Regola per spai
if ! [ -z $LTFSARCHIVER_RULESIZE ]; then
	RSYNC_RULES=$RSYNC_RULES' --temp-dir /tmp --max-size='$LTFSARCHIVER_RULESIZE
fi
#       Regole su estensioni
if [ ${#LTFSARCHIVER_RULEEXTS[@]} -gt 0 ]; then
	RSYNC_RULES=$RSYNC_RULES" --include '*/'"
	for ((EXTIDX=0;EXTIDX<${#LTFSARCHIVER_RULEEXTS[@]};EXTIDX++)); do
		RSYNC_RULES=$RSYNC_RULES" --include='*${LTFSARCHIVER_RULEEXTS[$EXTIDX]}'"
	done
	RSYNC_RULES=$RSYNC_RULES" --exclude='*'"
fi
echo $RSYNC_RULES
}
