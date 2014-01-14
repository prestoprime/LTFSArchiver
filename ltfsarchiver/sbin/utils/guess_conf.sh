#!/bin/bash

#  PrestoPRIME  LTFSArchiver
#  Version: 0.9 Beta
#  Authors: L. Savio, L. Boch, R. Borgotallo
#
#  Copyritght (C) 2011-2012 RAI âadiotelevisione Italiana <cr_segreteria@rai.it>
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

function PrintConf
{
echo $@  >> $PRINTOUT
}
function tape_map_centos ()
{
LTOTAPEID=0
IBMTAPEID=0
for ((GTX=0; GTX<${#GENERIC_TAPE_ARRAY[@]}; GTX++)); do
	VENDOR=`awk 'NR=='''\`echo "${GENERIC_TAPE_ARRAY[$GTX]:7} + 1" | bc\`''' {print $1}' /proc/scsi/sg/device_strs | tr [A-Z] [a-z]`
	case $VENDOR in
		"hp")
			GEN_BACKEND_ARRAY=( "${GEN_BACKEND_ARRAY[@]}" "/dev/st$LTOTAPEID" "ltotape" )
			TEMP_TAPE_MAP=( "${TEMP_TAPE_MAP[@]}" "n" "${GENERIC_TAPE_ARRAY[$GTX]}" "/dev/st$LTOTAPEID" )
			let LTOTAPEID+=1
		;;
		"ibm")
			GEN_BACKEND_ARRAY=( "${GEN_BACKEND_ARRAY[@]}" "/dev/IBMtape$IBMTAPEID" "ibmtape" )
			TEMP_TAPE_MAP=( "${TEMP_TAPE_MAP[@]}" "n" "${GENERIC_TAPE_ARRAY[$GTX]}" "/dev/IBMtape$IBMTAPEID" )
			let IBMTAPEID+=1
			#	Devo incrementare anche il "counter" degli ltotape
			let LTOTAPEID+=1
		;;
	esac
done
}
function tape_map_ubuntu ()
{
TAPEID=0
for ((GTX=0; GTX<${#GENERIC_TAPE_ARRAY[@]}; GTX++)); do
	VENDOR=`awk 'NR=='''\`echo "${GENERIC_TAPE_ARRAY[$GTX]:7} + 1" | bc\`''' {print $1}' /proc/scsi/sg/device_strs | tr [A-Z] [a-z]`
	case $VENDOR in
		"hp")
			GEN_BACKEND_ARRAY=( "${GEN_BACKEND_ARRAY[@]}" "/dev/st$TAPEID" "ltotape" )
			TEMP_TAPE_MAP=( "${TEMP_TAPE_MAP[@]}" "n" "${GENERIC_TAPE_ARRAY[$GTX]}" "/dev/st$TAPEID" )
		;;
		"ibm")
			GEN_BACKEND_ARRAY=( "${GEN_BACKEND_ARRAY[@]}" "/dev/IBMtape$TAPEID" "ibmtape" )
			TEMP_TAPE_MAP=( "${TEMP_TAPE_MAP[@]}" "n" "${GENERIC_TAPE_ARRAY[$GTX]}" "/dev/IBMtape$TAPEID" )
		;;
	esac
	let TAPEID+=1
done
}

clear
#       STEP 0  individuazione OS
unset FFiles
for FFile in `find -P /etc/*-release -type f`; do
	[ -L $FFile ] || FFiles=( ${FFiles[@]} $FFile )
done

OS=$(awk '/DISTRIB_ID=/'  ${FFiles[@]} | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
if [ -z "$OS" ]; then
	OS=$(awk '{print $1}' ${FFiles[@]} | tr '[:upper:]' '[:lower:]')
fi
echo "Operating system: $OS"


# This scripts uses sg_map utility
PRINTOUT=/tmp/guess_conf.out
RUNNING_TMP=/tmp/ltfsarchiver.tmp
RUNNING_CFG=`dirname $0`/../../conf/ltfsarchiver.conf
GUESSED_TMP=/tmp/guessed.tmp
GUESSED_CFG=`dirname $0`/../../`grep "GUESSED_CONF=" $RUNNING_CFG | sed -e 's/.*=//' -e 's/\$LTFSARCHIVER_HOME\///'`
#	Come running prendo guessed.conf se esiste, viceversa prendo ltfsarchiver
[ -f $GUESSED_CFG ] && RUNNING_CFG=$GUESSED_CFG
#
SG_MAP=`which sg_map`
if [ -z $SG_MAP ]; then
	echo "sg_map command not found"
	exit 3
fi
[ -f $PRINTOUT ] && rm -f $PRINTOUT
#################### LOADER(S) CONFIGURATION
#       Array con le librerie
echo "Step 1: Media changers"
GENERIC_LIBRARY_ARRAY=( `$SG_MAP -x | awk '$6==8{print $1}' | tr '\n' ' '` )
echo "Media changer(s) found: ${#GENERIC_LIBRARY_ARRAY[@]}"
if [ ${#GENERIC_LIBRARY_ARRAY[@]} -gt 0 ]; then
	unset GEN_CHANGER_DEVICES
	unset GEN_CHANNGER_SLOTS
	unset GEN_TAPER_SLOTS
	for ((GLX=0; GLS<${#GENERIC_LIBRARY_ARRAY[@]}; GLS++)); do
		VENDOR=`awk 'NR=='''\`echo "${GENERIC_LIBRARY_ARRAY[$GLX]:7} + 1" | bc\`''' {print $1}' /proc/scsi/sg/device_strs | tr [A-Z] [a-z]`
		GEN_CHANGER_DEVICES=( "${GEN_CHANGER_DEVICES[@]}" /dev/sg${GENERIC_LIBRARY_ARRAY[$GLX]:7} )
		#	Driver e slot
		GEN_CHANGER_SLOTS=( "${GEN_CHANGER_SLOTS[@]}" `loaderinfo -f /dev/sg${GENERIC_LIBRARY_ARRAY[$GLX]:7} | grep "Number of Storage Elements:" | awk '{print $NF}'` )
		GEN_CHANGER_TAPES=( "${GEN_CHANGER_TAPES[@]}" `loaderinfo -f /dev/sg${GENERIC_LIBRARY_ARRAY[$GLX]:7} | grep "Number of Data Transfer Elements:" | awk '{print $NF}'` )
		echo "scsi device /dev/sg${GENERIC_LIBRARY_ARRAY[$GLX]:7} appears to be a library"
	done
	#--------- printout
	PrintConf "CONF_CHANGER_DEVICES=( "${GEN_CHANGER_DEVICES[@]}" )"
	PrintConf "CONF_CHANGER_SLOTS=( "${GEN_CHANGER_SLOTS[@]}" )"
	PrintConf "CONF_CHANGER_TAPES=( "${GEN_CHANGER_TAPES[@]}" )"
fi

#################### TAPEDRIVE(S) CONFIGURATION
echo "Step 2: Tape devices"
GENERIC_TAPE_ARRAY=( `$SG_MAP -x | awk '$6==1{print $1}' | tr '\n' ' '` )
echo "Tape device(s) found: ${#GENERIC_TAPE_ARRAY[@]}"
if [ ${#GENERIC_TAPE_ARRAY[@]} -gt 0 ]; then
	unset GEN_BACKEND_ARRAY
	unset TEMP_TAPE_MAP
	case $OS in
		"centos")
			tape_map_ubuntu
			#tape_map_centos
		;;
		"ubuntu")
			tape_map_ubuntu
		;;
	esac
	#--------- printout
	PrintConf "CONF_BACKENDS=( "${GEN_BACKEND_ARRAY[@]}" )"
	########### ACCOPPIAMENTI ##########################################
	echo "Step 3: Changers/Tape associations"
	for ((LIDX=0; LIDX<${#GEN_CHANGER_DEVICES[@]}; LIDX++)); do
		NOME_ARRAY="CONF_CHANGER_TAPEDEV_$LIDX"
		unset TEMP_ARRAY
		#	Tripla (HOST-CHAN-ID) della libreria
		TRIPLA=`$SG_MAP -x | grep ${GEN_CHANGER_DEVICES[$LIDX]} | awk '{print $2"-"$3"-"$4}'`
		#echo $TRIPLA
		#	Cerco dev/sg che abbiano la stessa tripla
		TRIPLE_UGUALI=( `$SG_MAP -x | awk '{print $2"-"$3"-"$4" "$1}' | grep $TRIPLA | grep -v ${GEN_CHANGER_DEVICES[$LIDX]} | sort | awk '{print $2}' | tr '\n' ' '` )
		#TRIPLE_UGUALI=( `$SG_MAP -x | awk '{print $2"-"$3"-"$4" "$1}' | grep $TRIPLA | sort | awk '{print $2}' | tr '\n' ' '` )
		#echo ${TRIPLE_UGUALI[@]}
		unset TEMP_TARRAY
		for ((TIDX=0; TIDX<${#TRIPLE_UGUALI[@]}; TIDX++)); do
			#	Trasformo /dev/sg in /dev/st o /dev/IBMtape
			for ((TEMPIDX=0; TEMPIDX<${#TEMP_TAPE_MAP[@]}; TEMPIDX+=3)); do
				if [ ${TEMP_TAPE_MAP[$TEMPIDX+1]} == ${TRIPLE_UGUALI[$TIDX]} ]; then
					echo "scsi device ${TEMP_TAPE_MAP[$TEMPIDX+2]} appears to be a tape owned by ${GEN_CHANGER_DEVICES[$LIDX]} media changer"
					#	Marco come "trovato" il device in TEMP_TAPE_MAP
					TEMP_TAPE_MAP[$TEMPIDX]="y"
					#	popolo temp_array
					TEMP_TARRAY=( "${TEMP_TARRAY[@]}" "${TEMP_TAPE_MAP[$TEMPIDX+2]}" )
				fi
			done
		done
		#--------- printout
		PrintConf "$NOME_ARRAY=( "${TEMP_TARRAY[@]}" )"
	done

	########### RIMANENTI ##########################################
	echo "Step 4: Standalone tapes"
	unset GEN_MANUAL_TAPES
	for ((TEMPIDX=0; TEMPIDX<${#TEMP_TAPE_MAP[@]}; TEMPIDX+=3)); do
		if [ ${TEMP_TAPE_MAP[$TEMPIDX]} == "n" ]; then
			echo "scsi device ${TEMP_TAPE_MAP[$TEMPIDX+2]} appears to be an external tape"
			#	Marco come "trovato" il device in TEMP_TAPE_MAP
			TEMP_TAPE_MAP[$TEMPIDX]="y"
			#	popolo Array tape seterni
			GEN_MANUAL_TAPES=( "${GEN_MANUAL_TAPES[@]}" "${TEMP_TAPE_MAP[$TEMPIDX+2]}" )
		fi
	done
	PrintConf 'CONF_MANUAL_TAPEDEV=( '"${GEN_MANUAL_TAPES[@]}"' )'
fi
echo "File generated..."
echo ""
echo ""

#	Verifica congruita' tra il mnumero di tape slot e tape_device delle librerie
#		Carico il file di configurazione creato
. $PRINTOUT
NUM_LIB=${#CONF_CHANGER_DEVICES[@]}
for ((j=0;j<$NUM_LIB;j++)); do
	EXPECTED_TAPE=${CONF_CHANGER_TAPES[$j]}
	TAPE_ARRAY_NAME=CONF_CHANGER_TAPEDEV_$j
	temp_array=( ${!TAPE_ARRAY_NAME} )
	if [ $EXPECTED_TAPE -gt ${#temp_array[@]} ]; then
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "WARNING!"
		echo "Media changer ${CONF_CHANGER_DEVICES[$j]} has ${CONF_CHANGER_TAPES[$j]} tape device(s),"
		echo "but the guessed conf script detected ${#temp_array[@]} tape device(s)"
		echo "maybe one of the following device(s) are actually managed by ${CONF_CHANGER_DEVICES[$j]}"
		echo "--> ${CONF_MANUAL_TAPEDEV[@]}"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo ""
		echo "scsi generic/scsi device map follows:"
		for ((TEMPIDX=0; TEMPIDX<${#TEMP_TAPE_MAP[@]}; TEMPIDX+=3)); do
			echo "${TEMP_TAPE_MAP[$TEMPIDX+1]} -> ${TEMP_TAPE_MAP[$TEMPIDX+2]}"
		done
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo ""
	fi
done



#	Estrazione parametri ^conf da running
grep "^CONF" $RUNNING_CFG | sort > $RUNNING_TMP
#	Ordinamento parametri ^conf da temporaneo
sort $PRINTOUT > $GUESSED_TMP
rm -f $PRINTOUT
#	DIFF
diff $RUNNING_TMP $GUESSED_TMP >/dev/null
if [ $? == 0 ]; then
	echo "The guessed conf doesn't differ from running conf"
	echo "--------------------------------------------------"
	echo "-> Running conf"
	cat $RUNNING_TMP
	echo "--------------------------------------------------"
else
	echo "The guessed conf  differs from running conf:"
	echo "--------------------------------------------------"
	echo "-> Running conf"
	cat $RUNNING_TMP
	echo "--------------------------------------------------"
	echo "-> Guessed conf"
	cat $GUESSED_TMP
	echo "--------------------------------------------------"
	echo -n "Please confirm new config or leave unchanged [y|N]> "
	read answer
	echo "You entered: $answer"
	case $answer in
		"y"|"Y")
			echo '#!/bin/bash' > $GUESSED_CFG
			cat $GUESSED_TMP >> $GUESSED_CFG
			chmod 755 $GUESSED_CFG
			echo "New config file saved"
		;;
		*)
			echo "Config file left unchanged"
		;;
	esac
fi
[ -f $GUESSED_TMP ] && rm $GUESSED_TMP
[ -f $RUNNING_TMP ] && rm $RUNNING_TMP
[ -f $PRINTOUT ] && rm $PRINTOUT
