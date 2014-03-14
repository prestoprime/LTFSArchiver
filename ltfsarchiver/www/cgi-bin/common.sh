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
function get_parameter()
{
echo $PARM | tr '&' '\n' | grep -m 1 "^$1=" | sed -e 's/.*=//' -e 's/\\//' -e 's/%20/ /g'
}

#	il nome del parametro e' case unsensitive
function get_parameter_nu()
{
echo $PARM | tr '&' '\n' | grep -i "^$1=" | sed 's/.*=//' | sed 's/\\//'
}

#	il nome del parametro e' case unsensitive, cosi' come il valore ritornato
function get_parameter_au()
{
echo $PARM | tr '&' '\n' | tr '[A-Z]' '[a-z]' | grep -i "^$1=" | sed 's/.*=//' | sed 's/\\//'
}
function get_supplied_parameters()
{
PARMSUPPLIED=( `echo $PARM | tr '&' '\n' | sed -e 's/=.*//' | tr '\n' ' '`)
#	Ce ne sono di nonvalidi
LOCALVALIDPARMS=( `echo ${VALIDPARMS} | tr '|' ' '` )
for ((x=0;x<${#PARMSUPPLIED[@]};x++)); do
	valid="f"
	for ((y=0;y<${#LOCALVALIDPARMS[@]};y++)); do
		if [ ${PARMSUPPLIED[$x]} == ${LOCALVALIDPARMS[$y]} ]; then
			valid="t"
			#	forzo uscita ciclo
			y=${#LOCALVALIDPARMS[@]}
		fi
	done
	if [ $valid == "f" ]; then
		BADPARMS=$BADPARMS" "${PARMSUPPLIED[$x]}
	fi
done
if [ -z "$BADPARMS" ]; then
	unset BADPARMS
else
	BADPARMS="Bad parameter(s) supplied: $BADPARMS"
fi
}
function check_alphanum()
{
checked=true
length=${#1}
if [ $length -gt $2 ] ;then
	checked=false
fi
case $1 in
	#-* ) echo "not ok : start with hyphen";exit ;;
	#*- ) echo "not ok : end with hyphen";exit ;;
	*[^a-zA-Z0-9-_]* )
	checked=false
	;;
esac
echo $checked
}

function normalize_output
{
output=`echo $output | tr '[A-Z]' '[a-z]'`
case $output in
	"xml"|"json")
	;;
	*)
		PARM=`echo $PARM | tr '&' '\n' | sed -e '/^Output=/d' | tr '\n' '&' | sed -e 's/\&$//'`
		unset output
	;;
esac
}

function send_output
{
case  $output in
	"xml"|"html")
		write_xml_cgi_output
	;;
	"json")
		tempfile=/tmp/`uuidgen`.xml
		write_xml_cgi_output | tail -n +3 > $tempfile
		echo 'content-type: application/json'
		echo ''
		python $LTFSARCHIVER_HOME/sbin/jsonfy.py $tempfile
		[ -f $tempfile ] && rm -f $tempfile
	;;
esac
}
function crea_xml_answer()
{
case $exitcode in
	"200")
		XMLANSWER='<Response timenow="'`date +'%Y-%m-%dT%H:%M:%S'`'" exit_string="success" exit_code="'$exitcode'"/>'
	;;
	"400"|"404")
		XMLANSWER='<Response timenow="'`date +'%Y-%m-%dT%H:%M:%S'`'" exit_string="bad_request" exit_code="'$exitcode'">'"$message"'</Response>'
	;;
	"500")
		XMLANSWER='<Response timenow="'`date +'%Y-%m-%dT%H:%M:%S'`'" exit_string="failure" exit_code="'$exitcode'">'"$message"'</Response>'
	;;
	*)
		XMLANSWER='<Response timenow="'`date +'%Y-%m-%dT%H:%M:%S'`'" exit_string="OOPS" exit_code="'$exitcode'">'"$message"'</Response>'
	;;
esac
}

function crea_xml_output()
{
XMLOUTPUT="\t"'<Output>'"\n"
XMLOUTPUT=$XMLOUTPUT"\t\t"'<Task'
XMLOUTPUT=$XMLOUTPUT' id="'$taskid'"'
XMLOUTPUT=$XMLOUTPUT' status="waiting"'
XMLOUTPUT=$XMLOUTPUT'/>'"\n"
XMLOUTPUT=$XMLOUTPUT"\t"'</Output>'
}
#------------------------------------
function cercatape ()
{
trovato=`$CMD_DB" select count (*) from lto_info where label='$1';" | sed -e 's/^ *//'`
}

function write_xml_cgi_output()
{
#	Split della Query string per riportare parametri e valori
echo 'Content-Type: text/xml'
echo ''
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<LTFSArchiver '$LTFSARCHIVER_NAMESPACE'>'
COUPLES=( `echo $PARM | tr '&' ' ' ` )
#	La prte RECEIVEDREQUEST la monto direttamente qui
echo -e "\t"'<ReceivedRequest service="'$command'" time="'$RECEIVEDTIME'">'
#	per ognuna delle coppie PARAMETRO=VALORE
#	verifico se ètato passato un valore  assignmet=VALORE oppure NO(e lo script l'ha messa a default
for ((p=0;p<${#COUPLES[@]};p++)); do
	VALUES=( `echo ${COUPLES[$p]} | tr '=' ' '` )
	isdefval="true"
	for ((q=0;q<${#PARMSUPPLIED[@]};q++)); do
		[ "${VALUES[0]}" == ${PARMSUPPLIED[$q]} ] && isdefval="false"
	done
	echo -e "\t\t"'<Parameter name="'${VALUES[0]}'" value="'${VALUES[1]}'" assignedByDefault="'$isdefval'"/>'
done
#	Chiudeo a prte RECEIVEDREQUEST
echo -e "\t"'</ReceivedRequest>'
#	Butto fuori la parte RESPONSE
echo -e "\t"$XMLANSWER
#	se c'e' butto fuori la parte OUTPUT
[ -z "$XMLOUTPUT" ] || echo -e "$XMLOUTPUT"
#	Chiudo il tutto
echo '</LTFSArchiver>'
}

function substatus_descr()
{
case $1 in
	0)
		echo "Waiting to be dispatched"
	;;
	10)
		echo "Dispatched, waiting for tape or device availability"
	;;
	20)
		echo "Dispatched, waiting for tape transferring from/to device"
	;;
	30)
		echo "Tape being loaded o positioning"
	;;
	40)
		echo "Tape loaded and ready"
	;;
	50)
		echo "Running"
	;;
	55)
		echo "Performing checks"
	;;
	19|60)
		echo "Completed"
	;;
	99)
		echo "Fallout"
	;;
	*)
	;;
esac
}
function get_service()
{
case $1 in
	"A")
		echo "MakeAvailableMount"
	;;
	"U")
		echo "MakeAvailableUnmount"
	;;
	"F"|"Z"|"C")
		echo "AddTape"
	;;
	"R")
		echo "RestoreFromLTO"
	;;
	"W")
		echo "WriteToLTO"
	;;
	"D")
		echo "WithdrawTape"
	;;
	"K")
		echo "LockDevice"
	;;
	"J")
		echo "UnlockDevice"
	;;
	"L")
		echo "ListTape"
	;;
	"V")
		echo "Checksum"
	;;
esac
}

function get_time_value()
{
echo `$CMD_DB" select $1 from requests where uuid='"$2"';" | sed -e 's/^ *//' -e 's/ *$//' -e 's/ /T/' -e 's/\+.*//'`
}

function bkpltoinfo()
{
$CMD_DB "copy lto_info to STDOUT;" > $LTFSARCHIVER_HOME/poolbkp/lto_info.`date '+%s'`
}

function PercentDone()
{
case ${DATA[0]} in
	"W")
		ST_FILE=`$CMD_DB" select sourcefile from requests where uuid='$taskid'" | sed -e 's/^ *//' -e 's/ *$//'`
		ST_DATA=( `$CMD_DB" select sourcebytes, device, datatype from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
		case ${ST_DATA[2]} in		#Tipologia Directory o File
			"D")
				RSYNCFILE=/tmp/$taskid.rsync.txt
				if ! [ -f $RSYNCFILE ]; then
					perc=0
				else
					donebyte=`awk '{print $4}' $RSYNCFILE | sed -e "s/^'//" | sed -e 's/|.*//' \
						| awk 'BEGIN{sum=0}{sum+=$1}END{printf "%.0f\n", sum}'`
					if [ $donebyte -ge ${ST_DATA[0]} ]; then
						perc=100
					else
						perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[0]}" | bc`
					fi
				fi
			;;
			"F")
				TARGETN=/mnt/ltfs`basename ${ST_DATA[1]}`/temp.$taskid/`basename "${ST_FILE}"`
				if [ -f $TARGETN ]; then
					donebyte=`stat --printf '%s\n' $TARGETN`
				else
					donebyte=0
				fi
				perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[0]}" | bc`
			;;
		esac
	;;
	"R")
		ST_FILE=`$CMD_DB" select destfile from requests where uuid='$taskid'" | sed -e 's/^ *//' -e 's/ *$//'`
		ST_DATA=`$CMD_DB" select sourcebytes from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '`
		donebyte=`du --apparent-size -ksb "${ST_FILE}" | awk '{ print $1 }'` 2>/dev/null
		if [ -z $donebyte ]; then
			perc=0
		else
			if [ $donebyte -ge ${ST_DATA} ]; then
				perc=100
			else
				perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA}" | bc`
			fi
		fi
	;;
esac
}
function task_details()
{

DATA=( `$CMD_DB "select operation,status,substatus from requests where uuid='"$taskid"';" | tr -d ' ' | tr '|' ' '` )
if [ -z $DATA ]; then
	XMLANSWER='<Response timenow="'`date +'%Y-%m-%dT%H:%M:%S'`'" exit_string="Not found" exit_code="404">TaskID not found</Response>'
	exitcode="400"
	result="bad_request"
	message="TaskID $taskid not found"
	unset taskid
else
	unset XMLOUTPUT
	#	RISPOSTA
	XMLANSWER='<Response timenow="'`date +'%Y-%m-%dT%H:%M:%S'`'" exit_string="Success" exit_code="200"/>'
	exitcode="200"
	result="success"
	
	#	Ricerca dei parametri passati al task
	case ${DATA[0]} in
		"F"|"Z"|"C")
			#	Poolname, label e opzione format
			OPTIONS=( `$CMD_DB "select poolname,ltotape,operation from requests where uuid='"$taskid"';" | tr -d ' ' | tr '|' ' ' ` )
			OPTANDVAL=( "PoolName=${OPTIONS[0]}" "TapeID=${OPTIONS[1]}" "Format=${OPTIONS[2]}" )
		;;
		"A"|"U")
			#	Label
			OPTIONS=( `$CMD_DB "select ltotape from requests where uuid='"$taskid"';" ` )
			OPTANDVAL=( "TapeID=${OPTIONS[0]}" )
		;;
		"W")
			#	Poolname, source, md5  (checksumfile)
			OPTIONS=( `$CMD_DB "select poolname,sourcefile,checksum,checksumfile from requests where uuid='"$taskid"';" | sed -e 's/ *| */|/g' -e 's/ /\%20/g' | tr '|' ' ' `)		
			case ${OPTIONS[2]} in
				"FILE")
					OPTANDVAL=( "PoolName=${OPTIONS[0]}" "FileName=${OPTIONS[1]}" "Checksum=${OPTIONS[2]}" "ChecksumFile=${OPTIONS[3]}" )
				;;
				*)
					OPTANDVAL=( "PoolName=${OPTIONS[0]}" "FileName=${OPTIONS[1]}" "Checksum=${OPTIONS[2]}" )
				;;
			esac
		;;
		"R")
			OPTIONS=( `$CMD_DB "select sourcefile,destfile from requests where uuid='"$taskid"';" | sed -e 's/ *| */|/g' -e 's/ /\%20/g' | tr '|' ' ' `)		
			OPTANDVAL=( "FileName=${OPTIONS[0]}" "DestPath=${OPTIONS[1]}" )
		;;
		"D")
			OPTIONS=( `$CMD_DB "select poolname,ltotape from requests where uuid='"$taskid"';" | tr -d ' ' | tr '|' ' ' ` )
			OPTANDVAL=( "PoolName=${OPTIONS[0]}" "TapeID=${OPTIONS[1]}" )
		;;
		"K")
			OPTIONS=( `$CMD_DB "select device from requests where uuid='"$taskid"';" | tr -d ' ' | tr '|' ' ' ` )
			OPTANDVAL=( "TapeDevice=${OPTIONS[0]}" )
		;;
		"L")
			OPTIONS=( `$CMD_DB "select ltotape from requests where uuid='"$taskid"';" | tr -d ' ' | tr '|' ' ' ` )
			OPTANDVAL=( "TapeID=${OPTIONS[0]}" )
		;;
		"V")
			OPTIONS=( `$CMD_DB "select sourcefile,checksum,checksumfile from requests where uuid='"$taskid"';" | tr -d ' ' | tr '|' ' ' ` )
			case ${OPTIONS[1]} in
				"FILE")
					OPTANDVAL=( "FileName=${OPTIONS[0]}" "Checksum=${OPTIONS[1]}" "ChecksumFile=${OPTIONS[2]}" )
				;;
				*)
					OPTANDVAL=( "FileName=${OPTIONS[0]}" "Checksum=${OPTIONS[1]}" )
				;;
			esac
		;;
	esac
	report_command=$( get_service ${DATA[0]} )
	showperc=false
	showeta=false
	case ${DATA[2]} in
		9|19|60|99)
			report_status="completed"
			showsubstatus=false
			showstarttime=true
			showendtime=true
		;;
		0|10)
			report_status=${DATA[1]}
			showsubstatus=false
			showstarttime=false
			showendtime=false
		;;
		*)
			report_status=${DATA[1]}
			showsubstatus=true
			showstarttime=true
			showendtime=false
			#
			report_substatus=$( substatus_descr ${DATA[2]} )
			#	if running... per Write  o Restore devo calcolare percentuale
			if [ ${DATA[2]} == 50 ]; then
				if ( [ ${DATA[0]} == "W" ] || [  ${DATA[0]} == "R" ] ); then
					PercentDone
					showperc=true
				fi
			fi
		;;
	esac
	#	OUTPUT open
	[ $1 == "single" ] && XMLOUTPUT="\t"'<Output>'"\n"
	XMLOUTPUT=$XMLOUTPUT"\t\t"'<Task'
	XMLOUTPUT=$XMLOUTPUT' id="'$taskid'"'
	XMLOUTPUT=$XMLOUTPUT' status="'$report_status'"'
	$showsubstatus && XMLOUTPUT=$XMLOUTPUT' substatus="'$report_substatus'"'
	$showperc && XMLOUTPUT=$XMLOUTPUT' percentage="'$perc'"'
	$showstarttime && XMLOUTPUT=$XMLOUTPUT' timestart="'$( get_time_value starttime $taskid)'"'
	$showendtime && XMLOUTPUT=$XMLOUTPUT' timeend="'$( get_time_value endtime $taskid)'"'
	XMLOUTPUT=$XMLOUTPUT'>'"\n"
	reqtime=$( get_time_value callingtime $taskid )
	XMLOUTPUT=$XMLOUTPUT"\t\t\t"'<Request time="'$reqtime'" service="'$report_command'">'"\n"
	for ((ov=0;ov<${#OPTANDVAL[@]};ov++)); do
		OV=( `echo ${OPTANDVAL[$ov]} | tr '=' ' ' ` )
		#	Per il parametro Format di AddTape devo rimappare l'opzione
		if [ ${OV[0]} == "Format" ]; then
			case ${OV[1]} in
				"C")
					OV[1]="N"
				;;
				"F")
					OV[1]="Y"
				;;
				"Z")
					OV[1]="F"
				;;
			esac
		fi
		XMLOUTPUT=$XMLOUTPUT"\t\t\t\t"'<Parameter name="'${OV[0]}'" value="'` echo ${OV[1]} | sed -e 's/\%20/ /g'`'"/>'"\n"
	done
	XMLOUTPUT=$XMLOUTPUT"\t\t\t"'</Request>'"\n"
	XMLOUTPUT=$XMLOUTPUT"\t\t"'</Task>'"\n"
	[ $1 == "single" ] && XMLOUTPUT=$XMLOUTPUT"\t"'</Output>'
fi
}

function devices_list()
{
#	Crea una lista "a coppie" tape/libreria o tape/ext
unset TAPE_LIST
case $LTFSARCHIVER_MODE in
        "C"|"B")
                for ((ccounter=0; ccounter<${#CONF_CHANGER_DEVICES[@]}; ccounter++)); do
                        tape_array_name="CONF_CHANGER_TAPEDEV_"$ccounter"[@]"
                        temp_array=( ${!tape_array_name} )
                        for ((tcounter=0; tcounter< ${#temp_array[@]}; tcounter++)); do
                                TAPE_LIST=( "${TAPE_LIST[@]}" "${temp_array[$tcounter]}" "${CONF_CHANGER_DEVICES[$ccounter]}" )
                        done
                done
        ;;
esac
case $LTFSARCHIVER_MODE in
        "M"|"B")
		TAPE_LIST=( "${TAPE_LIST[@]}" "${CONF_MANUAL_TAPEDEV[@]}" "ext" )
        ;;
esac
}
#-----------------------------------------------------------------------
function validate_uuid()
{
if [[ $1 =~ [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12} ]]; then
	echo true
else
	echo false
fi

}

