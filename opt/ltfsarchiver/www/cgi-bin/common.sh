function get_parameter()
{
echo $PARM | tr '&' '\n' | grep "^$1=" | sed 's/.*=//' | sed 's/\\//'
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
echo 'Content-Type: text/plain'
echo ''
echo -e $message
}

function output_json_common
{
echo 'content-type: application/json'
echo ''
echo $message
}


function getinfo_common()
{
ANSWERS=( `$DBACCESS" select operation, status, substatus from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
if [ -z "$ANSWERS" ] ; then
        message="400\t$taskid doesn't exist"
else
        ANSWERS=( ${ANSWERS[@]} "$( substatus_descr ${ANSWERS[2]} )" )
        case $command in
                "GetStatus")
			case ${ANSWERS[2]} in
				60|99)
					message="200\tCompleted"
				;;
				50)	#	Running... se e' una write o una restore devo calcolare percentuale completamento
					case ${ANSWERS[0]} in
						"W")
							ST_DATA=( `$DBACCESS" select sourcefile, sourcesize, device from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
							TARGETN=/mnt/ltfs`basename ${ST_DATA[2]}`/$taskid/`basename ${ST_DATA[0]}`
							TARGETS=`du -ksm $TARGETN | awk '{ print $1 }'`
							#donebyte=`stat --printf '%s\n' ${response[1]}"/*" |  awk '{ SUM += $1} END { print SUM}'`
							#TARGETS=`echo "$donebyte/1048576" | bc`
							if [ -z $TARGETS ]; then
								perc=0
							else
								let perc=( $TARGETS * 100 / ${ST_DATA[1]})
							fi
							message="200\t${ANSWERS[1]}\tp=$perc"
						;;
						"R")
							ST_DATA=( `$DBACCESS" select sourcefile, destfile, device from requests where uuid='$taskid'" | tr -d ' ' | tr '|' ' '` )
							SOURCEN=/mnt/ltfs`basename ${ST_DATA[2]}`/`echo ${ST_DATA[0]} | sed -e 's/.*://'`
							SOURCES=`du -ksm $SOURCEN | awk '{ print $1 }'` 2>/dev/null
							TARGETS=`du -ksm ${ST_DATA[1]} | awk '{ print $1 }'` 2>/dev/null
							if [ -z $TARGETS ]; then
								perc=0
							else
								let perc=( $TARGETS * 100 / $SOURCES)
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
							message=$message"\t$LTFSARCHIVER_MNTAVAIL"/"`$DBACCESS" select ltotape from requests where uuid='$taskid'" | tr -d ' '`"
						;;
						"W")	#	Per Archive devo aggiungere i
					esac
                                ;;
                                99)
                                        message="500\tFailure\t`$DBACCESS" select errordescription from requests where uuid='$taskid'" | tr '|' ' '`"
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
response=( `$DBACCESS "SELECT substatus, operation FROM requests WHERE uuid = '$taskid' AND operation in $1;" | tr -d ' ' | tr '|' ' ' ` )
if [ -z "$response" ]; then
	message="400\t$taskid doesn't exist or it's not of the requested type"
else
	case ${response[0]} in
		0)	#	cancello senza problemi
			CANDELETE="Y"
		;;
		10)	#	e archive deprenoto lo spazio, poi cancello
			if [ ${response[0]} == "W" ]; then
				TAPE2UNBOOK=( `$DBACCESS "SELECT ltotape,sourcesize FROM requests WHERE uuid = '$taskid'" | tr -d ' ' | tr '|' ' ' ` )
				$DBACCESS "UPDATE lto_info set booked=booked-${TAPE2UNBOOK[1]} WHERE label='${TAPE2UNBOOK[0]}';" > /dev/null 2>&1
			fi
			CANDELETE="Y"
		;;
		*)
			message="400\t$taskid is not in deletable status"
			CANDELETE="N"
		;;
	esac
	if [ $CANDELETE == "Y" ]; then
		$DBACCESS "delete from requests WHERE uuid='$taskid';" > /dev/null 2>&1
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
response=( `$DBACCESS "SELECT substatus, operation FROM requests WHERE uuid = '$taskid' AND operation in $1;" | tr -d ' ' | tr '|' ' ' ` )
if [ -z "$response" ]; then
	message="400\t$taskid doesn't exist or it's not of the requested type"
else
	case ${response[0]} in
		99)
			$DBACCESS "update requests set status='wait',substatus=0,ltolibrary='NONE',device='n/a',errordescription='NULL',errorcode=NULL,manager='$LTFSARCHIVER_MODE' WHERE uuid = '$taskid';" > /dev/null 2>&1
			if [ $? == 0 ]; then
				message="200\t$taskid requeued"
			else
				message="500\t$taskid requeue failed"
			fi
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
