#!/bin/bash

function get_parameter()
{
echo $PARM | tr '&' '\n' | grep "^$1" | sed 's/.*=//' | sed 's/\\//'
}


function data_tape()
{
DATI=( `echo ${SSLOTS[$1]} | tr ':' ' '` )
#DATI[0] tipo (mail o slot)
#DATI[1] ID
#DATI[2] Full o Empty
#DATI[3] label
#	Slot number
if [ ${DATI[0]} == "m" ]; then
	echo '<TD style="background-color: rgb(234, 234 , 0)">'$FONTS${DATI[1]}$FONTE'</TD>'
else
	echo '<TD>'$FONTS${DATI[1]}$FONTE'</TD>'
fi
#	Slot status
echo '<TD>'$FONTS${DATI[2]}$FONTE'</TD>'
#	Label
if [ -z $esinistraDATI[2]} ]; then
	echo '<TD>'$FONTS'N/A'$FONTE'</TD>'
else
	echo '<TD>'$FONTS${DATI[3]}$FONTE'</TD>'
fi
#	riporto lo status del supporto
if ( [ -z ${DATI[3]} ] && [ ${DATI[2]} == "Full" ] ); then
	echo '<TD colspan=2><IMG SRC=/pprime/images/alarm.png border=0></TD>'
else
	report_label 1 ${DATI[3]}
fi
}

function report_label()
{
case $1 in
	1)
		#	cerco poolname e inuse su DB
		TAPE_STAT=( `$CMD_DB"select poolname,inuse from lto_info where label='$2'" | tr -d ' ' | tr '|' ' '` )
		echo '<TD>'$FONTS${TAPE_STAT[0]}$FONTE'</TD>'
		echo '<TD>'$FONTS${TAPE_STAT[1]}$FONTE'</TD>'
	;;
	3)
		echo '<TD colspan=3>'$FONTS'triplo'$FONTE'</TD>'
	;;
esac
}

#	Crea la form per movimentare da slot a drive
function form_drvload()
{
echo '<CENTER>'
unset IFS
echo '<FORM NAME="form1" ACTION="MSL_changer.cgi">'
echo '<INPUT TYPE=HIDDEN NAME="command" VALUE="mounttape">'
echo '<INPUT TYPE=HIDDEN NAME="changer" VALUE="'$CHANGER_ID'">'
echo $FONTS'Selezionare la cassetta da montare'$FONTE
#	cerco le slot piene
FULLSLOTS=( `grep "Storage Element" $TMPFILE | grep Full | grep -v IMPORT | tr ':' ' ' | awk '{ print $3 }'` )
echo '<SELECT NAME="sorgente">'
for FSLOT in ${FULLSLOTS[@]}; do
	echo '<OPTION VALUE="'$FSLOT'">Slot '$FSLOT'</OPTION>'
done
echo '</SELECT>'
echo $FONTS'Selezionare il driver di destinazione'$FONTE
echo '<SELECT NAME="sorgente">'
for ((FREEDRV_IDX=0; FREEDRV_IDX<${#FREE_DRIVER_LIST[@]}; FREEDRV_IDX++)); do
	echo '<OPTION VALUE="'${FREE_DRIVER_LIST[$FREEDRV_IDX]}'">Driver '${FREE_DRIVER_LIST[$FREEDRV_IDX]}'</OPTION>'
done
echo '<INPUT TYPE=SUBMIT VALUE="CONFERMA">'
echo '</FORM>'
echo '</CENTER>'
}

#	Crea la form per movimentare da slot a mail
function form_scarica()
{
unset IFS
echo '<FORM NAME="form1" ACTION="MSL_changer.cgi">'
echo '<INPUT TYPE=HIDDEN NAME="command" VALUE="movetape">'
echo '<INPUT TYPE=HIDDEN NAME="changer" VALUE="'$CHANGER_ID'">'
echo $FONTS'Movimentare verso la mail-slot '${MSDATA[1]}' il nastro attualmente in :'$FONTE
#	cerco le slot piene
FULLSLOTS=( `grep "Storage Element" $TMPFILE | grep Full | grep -v IMPORT | tr ':' ' ' | awk '{ print $3 }'` )
echo '<SELECT NAME="sorgente">'
for FSLOT in ${FULLSLOTS[@]}; do
	echo '<OPTION VALUE="'$FSLOT'">Slot '$FSLOT'</OPTION>'
done
echo '</SELECT>'
echo '<INPUT TYPE=HIDDEN NAME="destinazione" VALUE="'${MSDATA[1]}'">'
echo '<INPUT TYPE=SUBMIT VALUE="CONFERMA">'
echo '</FORM>'
}



#	Crea la form per movimentare da mail a slot
function form_carica()
{
unset IFS
echo '<FORM NAME="form1" ACTION="MSL_changer.cgi">'
echo '<INPUT TYPE=HIDDEN NAME="command" VALUE="movetape">'
echo '<INPUT TYPE=HIDDEN NAME="changer" VALUE="'$CHANGER_ID'">'
echo $FONTS'Movimentare il nastro attualmente nella mail-slot '${MSDATA[1]}' nella locazione:'$FONTE
echo '<INPUT TYPE=HIDDEN NAME="sorgente" VALUE="'${MSDATA[1]}'">'
#	cerco le slot vuote
echo '<SELECT NAME="destinazione">'
EMPTYSLOTS=( `grep "Storage Element" $TMPFILE | grep Empty | grep -v IMPORT | tr ':' ' ' | awk '{ print $3 }'` )
for ESLOT in ${EMPTYSLOTS[@]}; do
	echo '<OPTION VALUE="'$ESLOT'">Slot '$ESLOT'</OPTION>'
done
echo '</SELECT>'
echo '<INPUT TYPE=SUBMIT VALUE="CONFERMA">'
echo '</FORM>'
}




# Script starts here
FONTS='<font size=-1 face="Verdana, Arial, Helvetica, sans-serif">'
FONTE='</font>'
. $CFGFILE
CMD_MTX="/usr/sbin/mtx"
PARM=$QUERY_STRING
ST_TYPE="LABELS"
command=$( get_parameter command )
echo 'Content-Type: text/html'
echo ''
echo '<HTML><BODY bgcolor="#FFFFCC" link="#000099" vlink="#000099">'
case $command in
	"view")
		echo '<CENTER>'
		echo '<TABLE width=30% border=1>'
		echo '<TR><TD>'$FONTS'Device'$FONTE'</TD><TD>'$FONTS'Stato'$FONTE'</TD>'
		echo '<TD>'$FONTS'Cambia stato'$FONTE'</TD><TD>'$FONTS'Manutenzione'$FONTE'</TD><TD>'$FONTS'Inventory'$FONTE'</TD></TR>'
		for ((MC_IDX=0; MC_IDX<${#CONF_CHANGER_DEVICES[@]};MC_IDX++)); do
			MCNAMES=${CONF_CHANGER_DEVICES[$MC_IDX]}
			echo '<TR>'
			echo '<TD>'$FONTS$MCNAMES$FONTE'</TD>'
			#	se esiste il token di "nouse"..
			if [ -f $DLTAPER_HOME/db/`basename $MCNAMES`.nouse ]; then
				NEWSTATE="Online"
				#	ha delle cassette su?
				FDS=`sudo $CMD_MTX -f $MCNAMES status | grep "Data Transfer Element" | cut -d ':' -f 2 | grep -vc "Empty"`
				if [ $FDS == 0 ]; then
					echo '<TD BGCOLOR="#FF6060">'$FONTS'Offline'$FONTE'</TD>'
					LOCK="no"
				else
					echo '<TD BGCOLOR="#FFFF60">'$FONTS'Pending offline'$FONTE'</TD>'
					LOCK="yes"
				fi
				#	cgi per passare online
				echo '<TD>'
				echo '<A HREF=MSL_changer.cgi?command=change&status=ON&changer='$MC_IDX'>'
				echo $FONTS'Online'$FONTE'</A>'
				echo '</TD>'
			else
				NEWSTATE="Offline"
				LOCK="yes"
				echo '<TD BGCOLOR="#60FF60">'$FONTS'Online'$FONTE'</TD>'
				echo '<TD>'
				echo '<A HREF=MSL_changer.cgi?command=change&status=OFF&changer='$MC_IDX'>'
				echo $FONTS'Offline'$FONTE'</A>'
				echo '</TD>'
			fi
			#	Accesso all'amministrazione SOLO SE OFFLINE
			if [ $LOCK == "no" ]; then
				echo '<TD align=center><A HREF='${CHANGER_ADDRESSES[$MC_IDX]}' target=_new>'
				echo '<IMG SRC="/pprime/images/service.gif" border=0></A></TD>'
			else
				echo '<TD align=center><IMG SRC="/pprime/images/lock.gif" border=0></TD>'
			fi
			#	Link per inventory
			echo '<TD align=center><A HREF=MSL_changer.cgi?command=inventory&changer='$MC_IDX'>'
			echo '<IMG SRC="/pprime/images/file.png" border=0></A></TD>'
			echo '</TR>'
		done
		echo '</TABLE>'
		echo '</CENTER>'
	;;
	"inventory")
		CHANGER_ID=$( get_parameter changer )
		CHANGERNAME=${CONF_CHANGER_DEVICES[$CHANGER_ID]}
		#	Creo un file temporaneo con lo status del mediachanger
		TMPFILE=/tmp/`basename $CHANGERNAME`.txt
		sudo $CMD_MTX -f $CHANGERNAME status > $TMPFILE
		#	la mailslot e' attiva?
		MAIL_ACT=`grep Changer $TMPFILE | awk '{ print $8 }'`
		echo '<CENTER>'
		echo '<TABLE border=1 width=70%>'
		echo '<TR><TD colspan=10 align=middle BGCOLOR="#A0A0FF">'$FONTS'Changer: '$CHANGERNAME$FONTE'</TD></TR>'
		echo '<TR><TD colspan=10 align=middle BGCOLOR="#B0B0F0">'$FONTS'Data slot (drivers)'$FONTE'</TD></TR>'
		echo '<TR><TD colspan=2>'$FONTS'ID'$FONTE'</TD><TD colspan=3>'$FONTS'Stato'$FONTE'</TD>'
		echo '<TD colspan=2>'$FONTS'Label'$FONTE'</TD><TD colspan=3>'$FONTS'Pool'$FONTE'</TD></TR>'
		#	DATA_SLOT (LTO)
		IFS=$'\n'
		for DSLOTS in `grep "Data Transfer Element" $TMPFILE | tr ':' ' '`; do
			echo '<TR>'
			IFS=' '
			DATI=( $DSLOTS )
			#	Slot number
			echo '<TD colspan=2>'$FONTS${DATI[3]}$FONTE'</TD>'
			#	Slot status
			echo '<TD colspan=3>'$FONTS${DATI[4]}$FONTE'</TD>'
			#	alimento array DRIVER_FREE_LIST per abilitare o meno il mount manuale
			[ ${DATI[4]} == "Empty" ] && FREE_DRIVER_LIST=( $FREE_DRIVER_LIST "${DATI[3]}" )
			#	Label
			echo '<TD colspan=2>'$FONTS${DATI[11]}$FONTE'</TD>'
			#	riporto lo status del supporto
			report_label 3 ${DATI[11]}
			echo '</TR>'
		done
		echo '<TR><TD colspan=5 align=middle BGCOLOR="#B0B0F0">'$FONTS'Storage slot sinistro'$FONTE'</TD>'
		echo '<TD colspan=5 align=middle BGCOLOR="#B0B0F0">'$FONTS'Storage slot destro'$FONTE'</TD></TR>'
		echo '<TR><TD>'$FONTS'ID'$FONTE'</TD><TD>'$FONTS'Stato'$FONTE'</TD>'
		echo '<TD>'$FONTS'Label'$FONTE'</TD><TD>'$FONTS'Poolname'$FONTE'</TD><TD>'$FONTS'Inuse'$FONTE'</TD>'
		echo '<TD>'$FONTS'ID'$FONTE'</TD><TD>'$FONTS'Stato'$FONTE'</TD>'
		echo '<TD>'$FONTS'Label'$FONTE'</TD><TD>'$FONTS'Poolname'$FONTE'</TD><TD>'$FONTS'Inuse'$FONTE'</TD></TR>'
		#	STRG_SLOT (BAYS)
		#	Array SLOT_NUM:STATUS:LABEL
		IFS=$'\n'
		#	Prima le eventuali slot mail
		if [ $MAIL_ACT -gt 0 ]; then
			SSLOTS=( `grep "Storage Element" $TMPFILE | grep -v Loaded | grep "IMPORT" \
			| tr ':' ' '| awk '{ print "m:"$3":"$5":"$6 }' | sed -e 's/VolumeTag=//g'` )
			#	creo un array per la successiva fase (gestione mailslot)
			MSLOTS=( ${SSLOTS[@]} )
		fi
		#	Poi (comunque) le slot NON mail
		SSLOTS=(  ${SSLOTS[@]} `grep "Storage Element" $TMPFILE | grep -v Loaded | grep -v "IMPORT" \
		| tr ':' ' '| awk '{ print "s:"$3":"$4":"$5 }' | sed -e 's/VolumeTag=//g'` )
		IFS=' '
		#	Numero di righe
		let SLOT_HALF=( ${CONF_CHANGER_SLOTS[$CHANGER_ID]}/2 )
		for ((SLOT_IDX=0; SLOT_IDX<$SLOT_HALF; SLOT_IDX++)); do
			echo '<TR>'
			#	Colonna di sinistra
			IDX_SX=$SLOT_IDX
			data_tape $IDX_SX
			#	Colonna di destra
			let IDX_DX=($SLOT_IDX+$SLOT_HALF)
			data_tape $IDX_DX
			echo '</TR>'
		done
		echo '</TABLE>'
		#		GESTIONE MAILSLOT
		if [ $MAIL_ACT -gt 0 ]; then
			echo '<HR>'
			#	quali sono?
			for ((MS_IDX=0; MS_IDX<${#MSLOTS[@]}; MS_IDX++)); do
				MSDATA=( `echo ${MSLOTS[$MS_IDX]} | tr ':' ' '` )
				#	se la mailslot e' vuota form per spostare un tape nella mailslot
				#	se la mailslot e' piena form per spostare  il tape in una slot
				case ${MSDATA[2]} in
					"Empty")
						form_scarica
					;;
					"Full")
						form_carica
					;;
				esac
			done
		fi	
		echo '</CENTER>'
		#		Form per mount manuale
		#	se ci sono lto liberi...
		if [ ${#FREE_DRIVER_LIST[@]} -gt 0 ]; then
			form_drvload
		fi
	;;
	"change")
		NEWSTATUS=$( get_parameter status )
		CHANGER_ID=$( get_parameter changer )
		CHANGERNAME=${CONF_CHANGER_DEVICES[$CHANGER_ID]}
		LOCKFILE=$DLTAPER_HOME/db/`basename $CHANGERNAME`.nouse
		case $NEWSTATUS in
			"ON")
				[ -f $LOCKFILE ] && rm -f $LOCKFILE
				
			;;
			"OFF")
				[ -f $LOCKFILE ] || touch $LOCKFILE
			;;
		esac
		echo '<CENTER>'
		echo "$FONTS Lo stato del mediachanger $CHANGERNAME e' ora: $NEWSTATUS <BR>"
		echo 'Cliccare <A HREF=MSL_changer.cgi?command=view> qui </A>'
		echo 'per tornare alla pagina di amministrazione dei mediachanger'$FONTE
	;;
	"movetape"|"mounttape")
		FROM=$( get_parameter sorgente )
		TO=$( get_parameter destinazione )
		CHANGER_ID=$( get_parameter changer )
		CHANGERNAME=${CONF_CHANGER_DEVICES[$CHANGER_ID]}
		echo '<CENTER>'
		echo $FONTS
		case $command in
			"movetape")
				echo "Spostamento in corso dalla locazione $FROM alla locazione $TO<BR>"
				echo "Attendere...<BR>"
				sudo $CMD_MTX -f $CHANGERNAME eepos 0 transfer $FROM $TO
			;;
			"mounttape")
				echo "Caricamento in corso dalla locazione $FROM al driver $TO<BR>"
				echo "Attendere...<BR>"
				sudo $CMD_MTX -f $CHANGERNAME load $FROM $TO
			;;
		esac
		MTXRC=$?
		if [ $MTXRC == 0 ]; then
			echo "Operazione conclusa con successo"
		else
			echo "Operazione non riuscita"
		fi
		echo '<HR width=70%>'
		echo 'Cliccare <A HREF=MSL_changer.cgi?command=inventory&changer='$CHANGER_ID'> Qui</A>'" per tornare all'inventory"
		echo $FONTE
	;;
	*)
		echo "NO VALID COMMAND"
	;;
esac

echo '</BODY></HTML>'
exit

