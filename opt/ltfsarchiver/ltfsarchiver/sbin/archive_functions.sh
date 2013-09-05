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
#============================================================================================================================================
#	Archiviazione fisica
function exec_archive()
{
#	Opzioni del logfile di rsync
LOGOPT=" --log-file=/tmp/$WORKING_UUID.rsync.txt --log-file-format='%b|%f'"
#	Parto col flag di checksum passato a vero
#	Se nei confronti questo viene passato a false, alla fine mando in fallout
CHECKSUM_PASSED="Y"
#LOGOPT=" --log-file=/tmp/$WORKING_UUID.rsync.txt --log-file-format='%b|%f' --progress"
#	Archiviazione
STEP1_RC=0
STEP2_RC=0
#	uso rsync e lo faccio in due giri.
#	Nel primo includo i file che rispettano i parametri di dimensione ed estensione dichiarati in cfg
main_logger 1 "Phase 1 rsync command: $CMD_RSYNC $UUID_DATA_SOURCE $TEMP_TARGET $( get_rsync_rules ) $LOGOPT"
main_logger 0 "Starting rsync for uuid=$WORKING_UUID - phase 1"
#	Lo step1 lo eseguo solo per le directory, per i file passo direttamente allo step2
if ( [ ${UUID_DATA[0]} == "F" ] || [ ${UUID_DATA[0]} == "f" ] ); then
	main_logger 1 "Rsync 1st step not needed"
else
	bash -c "$CMD_RSYNC \"$UUID_DATA_SOURCE\" $TEMP_TARGET $( get_rsync_rules ) $LOGOPT > /tmp/$WORKING_UUID.copylist 2>&1"
	STEP1_RC=$?
fi
if [ $STEP1_RC == 0 ]; then
	main_logger 1 "Rsync 1st step OK"
	#	Nel secondo NON metto limitazioni, copiera' il resto
	main_logger 1 "Phase 2 rsync command: $CMD_RSYNC $UUID_DATA_SOURCE $TEMP_TARGET $LOGOPT"
	main_logger 0 "Starting rsync for uuid=$WORKING_UUID - phase 2"
	bash -c "$CMD_RSYNC \"$UUID_DATA_SOURCE\" $TEMP_TARGET $LOGOPT >> /tmp/$WORKING_UUID.copylist 2>&1"
	STEP2_RC=$?
	#	Se tutto ok, inizio a creare json e md5 (se richiesto)
	if [ $STEP2_RC == 0 ]; then
		#	Passo a stato 55 (creazione files e md5)
		cat /tmp/$WORKING_UUID.copylist >>$MAIN_LOG_FILE
		update_uuid_status $WORKING_UUID 55
		main_logger 1 "Rsync 2nd step OK"
		main_logger 1 "Generating flocat list"
		main_logger 4 "a) filelist (find)"
		#	Lista dei file archiviati
		grep "`echo "$UUID_DATA_SOURCE" | sed -e 's/^\///'`" /tmp/$WORKING_UUID.rsync.txt | \
		awk '{for(i=4;i<=NF;++i) printf $i" "; printf "\n"}' | sed -e 's/^[0-9]*|//' -e "s;^;/;" | \
		sed -e "s;`dirname "$UUID_DATA_SOURCE"`;$TEMP_TARGET;" -e 's/[ \t]*$//' -e "s/'//g" > /tmp/$WORKING_UUID.md5.list
		#	Conto le righe da leggere
		NUMLINES=`wc -l /tmp/$WORKING_UUID.md5.list | awk '{print $1}'`
		#	Apertura dei reportfile
		#	TXT
		echo -e "200\tsuccess\t$FLOCAT" > $TxtOutput
		#	XML
		echo -e '<LTFSArchiver jobid="'$WORKING_UUID'" command="'$fileodir'" exitcode="200">' > $XmlOutput
		echo -e "\t"'<message>___MESSAGE___</message>' >> $XmlOutput

		#       JSON
		echo -e '{"jobid":"'$WORKING_UUID'",' > $JsonOutput
		echo -e '"service":"WriteToLTO",'"\n"'"command":"'$fileodir'",'"\n"'"exitcode":"200",' >>$JsonOutput
		echo -e '"message":"___MESSAGE___",' >> $JsonOutput
		echo -e '"FLocats":[' >> $JsonOutput
	
		main_logger 4 "b) loop start"
		#	Setto IFS su newline
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		for ((LINE_IDX=1; LINE_IDX<=$NUMLINES; LINE_IDX+=1));do
		        archfile=( `head -$LINE_IDX /tmp/$WORKING_UUID.md5.list | tail -1` )
			SINGLE_FLOCAT=`echo "$archfile" | sed -e 's;'$TEMP_TARGET/\`basename "${UUID_DATA_SOURCE}"\`';'$FLOCAT';'`
			if ! [ -d "$archfile" ]; then		#	Escludo le directory
				#	report json
				if [ $CHECKSUMCREATE == "none" ]; then
					#	report xml
					echo -e "\t"'<FLocat xlink:href="'$SINGLE_FLOCAT'"/>' >> $XmlOutput
					#	report json
					echo -e '{"Flocat":"'$SINGLE_FLOCAT'"}' >> $JsonOutput
				else
					#	report xml
					echo -e "\t"'<FLocat xlink:href="'$SINGLE_FLOCAT'">' >> $XmlOutput
					#	Scrivo su output json
					echo -e '{"Flocat":"'$SINGLE_FLOCAT'",' >> $JsonOutput
					MANAGE_STATUS="OK"
					main_logger 4 "calling manage_checksum"
					manage_checksum
					#esac
				fi
				#	virgol di continuazione su Json
				[ $LINE_IDX -lt $NUMLINES ] && echo ',' >> $JsonOutput
			fi
		done
		#       Ultima stringa fissa:
		echo ']}' >> $JsonOutput
		echo '</LTFSArchiver>' >> $XmlOutput
		#	riporto a default IFS
		IFS=$SAVEIFS
		#	rimuovo le liste
		rm -f /tmp/$WORKING_UUID.md5.list
		rm -f /tmp/$WORKING_UUID.rsync.txt
	else
		cat /tmp/$WORKING_UUID.copylist >>$MAIN_LOG_FILE
		main_logger 0 "Rsync 2nd step error: $STEP1_RC"
		#	lo valorizzo comunque per evitare errori a bc
	fi
else
	cat /tmp/$WORKING_UUID.copylist >>$MAIN_LOG_FILE
	main_logger 0 "Rsync 1st step error: $STEP1_RC"
fi
#	Ritorno l'exit code complessivo
COPY_RC=`echo "$STEP1_RC + $STEP2_RC" | bc`
#	rimuovo il file di copylist (una copia e' contenuta nel log dell'agent tramite tee
[ -f  /tmp/$WORKING_UUID.copylist ] && rm /tmp/$WORKING_UUID.copylist
#	Rimuovo l'eventuale file usato per i checksum "both"
}
function requeue_uuid
{
$CMD_DB "update requests set status='wait',substatus=0,ltolibrary='NONE',device='n/a',errordescription=NULL,errorcode=NULL,manager='$LTFSARCHIVER_MODE',ltotape='n/a' WHERE uuid = '$WORKING_UUID';" \
	> /dev/null 2>&1
}

