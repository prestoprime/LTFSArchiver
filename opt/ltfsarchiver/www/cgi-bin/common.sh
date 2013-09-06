function get_parameter()
{
echo $PARM | tr '&' '\n' | grep "^$1=" | sed -e 's/.*=//' -e 's/\\//' -e 's/%20/ /g'
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

function output_text_common
{
if [ "$guicall" == "true" ]; then
	echo 'Content-Type: text/html'
	echo 'Pragma: nocache'
	echo 'Cache-Control: no-cache, must-revalidate, no-store'
	echo ''
	echo '<html>'
	echo '<head>'
	echo '<meta content="text/html; charset=iso-8859-1"'
	echo 'http-equiv="Content-Type">'
	echo '<title></title>'
	echo '</head>'
	echo '<body bgcolor="#FFFFCC" link="#000099" vlink="#000099">'
	echo '<font size="2" face="Verdana, Arial, Helvetica, sans-serif">'
	echo '<CENTER>'
	echo '<center><b>'$command' command result:</b><br><br>'
	data=( `echo -e "$message" | tr '\t' ' '` )
	for ((STR=1; STR<${#data[@]}; STR++)); do
	RESULT=$RESULT" "${data[$STR]}
	done
	echo 'message code: '${data[0]}'<br>'
	echo 'result: '$RESULT
	echo '</body>'
	echo '</html>'
else
	echo 'Content-Type: text/plain'
	echo ''
	echo -e $message
fi
}

function output_json_common
{
echo 'content-type: application/json'
echo ''
echo $message
}


function getinfo_common()
{
ANSWERS=( `$CMD_DB" select operation, status, substatus from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
if [ -z "$ANSWERS" ] ; then
        message="400\t$taskid doesn't exist"
else
        ANSWERS=( ${ANSWERS[@]} "$( substatus_descr ${ANSWERS[2]} )" )
        case $command in
                "GetStatus")
			case ${ANSWERS[2]} in
				19|60|99)
					message="200\tCompleted"
				;;
				50)	#	Running... se e' una write o una restore devo calcolare percentuale completamento
					case ${ANSWERS[0]} in
						"W")
							ST_DATA=( `$CMD_DB" select sourcefile, sourcebytes, device, datatype from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
							case ${ST_DATA[3]} in
								"D")
									RSYNCFILE=/tmp/$taskid.rsync.txt
									if ! [ -f $RSYNCFILE ]; then
										perc=0
									else
										donebyte=`awk '{print $4}' $RSYNCFILE | sed -e "s/^'//" | sed -e 's/|.*//' | awk 'BEGIN{sum=0}{sum+=$1}END{printf "%.0f\n", sum}'`
										if [ $donebyte -ge ${ST_DATA[1]} ]; then
											perc=100
										else
											perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[1]}" | bc`
										fi
									fi
								;;
								"F")
									TARGETN=/mnt/ltfs`basename ${ST_DATA[2]}`/temp.$taskid/`basename ${ST_DATA[0]}`
									donebyte=`stat --printf '%s\n' $TARGETN`
									perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[1]}" | bc`
								;;
							esac
							message="200\t${ANSWERS[1]}\tp=$perc"
						;;
						"R")
							ST_DATA=( `$CMD_DB" select destfile, sourcebytes from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
							donebyte=`du --apparent-size -ksb ${ST_DATA[0]} | awk '{ print $1 }'` 2>/dev/null
							if [ -z $donebyte ]; then
								perc=0
							else
								if [ $donebyte -ge ${ST_DATA[1]} ]; then
									perc=100
								else
									perc=`echo "scale=3;$donebyte * 100 / ${ST_DATA[1]}" | bc`
								fi
							fi
							message="200\t${ANSWERS[1]}\tp=$perc"
						;;
						*)
							message="200\t${ANSWERS[1]}"
						;;
					esac
				;;
				*)	
					message="200\t${ANSWERS[1]}\t${ANSWERS[3]}"
				;;
			esac
		;;
                "GetResult")
                        case ${ANSWERS[2]} in
                                60)
                                        message="200\tSuccess"
					#	Per Makeavailable devo aggiungere il path di accesso: i.e.: /mnt/pprime/lto-ltfs/XX04020B
					case ${ANSWERS[0]} in
						"A")	#	Per Makeavailable devo aggiungere il path di accesso: i.e.: /mnt/pprime/lto-ltfs/XX04020B
							message=$message"\t$LTFSARCHIVER_MNTAVAIL"/"`$CMD_DB" select ltotape from requests where uuid='$taskid'" | tr -d ' '`"
						;;
					esac
                                ;;
                                99)
                                        message="500\tFailure\t`$CMD_DB" select errordescription from requests where uuid='$taskid'" | tr '|' ' '`"
                                ;;
                                *)
                                        message="400\tNot completed"
                                ;;
                        esac
                ;;
        esac
fi
}
function cancel_common()
{
response=( `$CMD_DB "SELECT substatus, operation FROM requests WHERE uuid = '$taskid' AND operation in $1;" | tr -d ' ' | tr '|' ' ' ` )
if [ -z "$response" ]; then
	message="400\t$taskid doesn't exist or it's not of the requested type"
else
	case ${response[0]} in
		0)	#	cancello senza problemi
			CANDELETE="Y"
		;;
		10|99)	#	se archive deprenoto lo spazio, poi cancello
			if [ ${response[0]} == "W" ]; then
				TAPE2UNBOOK=( `$CMD_DB "SELECT ltotape,sourcesize FROM requests WHERE uuid = '$taskid'" | tr -d ' ' | tr '|' ' ' ` )
				$CMD_DB "UPDATE lto_info set booked=booked-${TAPE2UNBOOK[1]} WHERE label='${TAPE2UNBOOK[0]}';" > /dev/null 2>&1
			fi
			CANDELETE="Y"
		;;
		9|19)	#	Possibile solo durante dispatching di archive
			#	Autorizzo la cancellazione senza de-prenotare lo spazio
			CANDELETE="Y"
		;;
		*)
			message="400\t$taskid is not in deletable status"
			CANDELETE="N"
		;;
	esac
	if [ $CANDELETE == "Y" ]; then
		$CMD_DB "delete from requests WHERE uuid='$taskid';" > /dev/null 2>&1
		if [ $? == 0 ]; then
			message="200\t$taskid deleted"
		else
			message="500\t$taskid removal failed"
		fi
	fi
fi
}


function requeue_common()
{
response=( `$CMD_DB "SELECT substatus, operation FROM requests WHERE uuid = '$taskid' AND operation in $1;" | tr -d ' ' | tr '|' ' ' ` )
if [ -z "$response" ]; then
	message="400\t$taskid doesn't exist or it's not of the requested type"
else
	case ${response[0]} in
		9|99)
			$CMD_DB "update requests set status='wait',substatus=0,ltolibrary='NONE',device='n/a',errordescription='NULL',errorcode=NULL,manager='$LTFSARCHIVER_MODE' WHERE uuid = '$taskid';" > /dev/null 2>&1
			if [ $? == 0 ]; then
				message="200\t$taskid requeued"
			else
				message="500\t$taskid requeue failed"
			fi
		;;
		19)
			message="400\t$taskid cannot be requeued"
		;;
		*)
			message="400\t$taskid is not in fallout status"
		;;	
	esac
fi
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
function Verify_CheckFile()
{
CHKSMFILE=$( get_parameter ChecksumFile )
if ( ! [ -f $CHKSMFILE ] || [ -z $CHKSMFILE ] ); then
	FILEPASS="N"
	message="400\tInvalid ChecksumFile supplied: $CHKSMFILE"
else
	case `head -1 $CHKSMFILE | sed -e 's/^#//'` in
		"MD5"|"SHA1")
			FILEPASS="Y"
		;;
		*)
			FILEPASS="N"
			message="400\tInvalid checksum type supplied: "`head -1 $CHKSMFILE | sed -e 's/^#//'`
		;;
	esac
fi
}
function bkpltoinfo()
{
$CMD_DB "copy lto_info to STDOUT;" > $LTFSARCHIVER_HOME/poolbkp/lto_info.`date '+%s'`
}

