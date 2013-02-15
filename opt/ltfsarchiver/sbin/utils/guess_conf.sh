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


# This scripts uses sg_map utility
clear
SG_MAP=`which sg_map`
if [ -z $SG_MAP ]; then
	echo "sg_map command not found"
	exit 3
fi
GUESSED_CONF=`dirname $0`/../../conf/guessed.conf
[ -f /tmp/foundtape.txt ] && rm /tmp/foundtape.txt
touch /tmp/foundtape.txt
echo '#!/bin/bash' > /tmp/guessedconf.txt
#	RICERCA LIBRERIE E TAPE ANNESSI
echo "looking for tape library(ies)"
old_IFS=$IFS      # save the field separator         
IFS=$'\n'
LF=0
BUSYDEVICES=`$SG_MAP -x | grep -iE "/dev/nst|/dev/st" | grep -ci busy`
if [ $BUSYDEVICES -gt 0 ]; then
	echo "Some tape device appear to be busy:"
	$SG_MAP -x | grep -iE "/dev/nst|/dev/st" | grep -i busy
	echo 
	echo "Please wait activity completion ad retry..."
	exit 3
fi
echo "looking for internal tape device(s)"
for line1 in `$SG_MAP -x`; do
	IFS=$' '
	DATA1=( $line1 )
	if [ ${DATA1[5]} == 8 ]; then
		echo "scsi device ${DATA1[0]} appears to be a library"
		CHANGER_DEVICES=( "${CHANGER_DEVICES[@]}" ${DATA1[0]} )
		CHANGER_SLOTS=( "${CHANGER_SLOTS[@]}" `mtx -f ${DATA1[0]} status | grep -i "Storage Element" | grep -civE "import|loaded"` )
		CHANGER_DTE=( "${CHANGER_DTE[@]}" `mtx -f ${DATA1[0]} status | grep -ci "Data Transfer Element"` )
		unset temparray
		IFS=$'\n'
		for line2 in `$SG_MAP -x`; do
			IFS=$' '
			DATA2=( $line2 )
			if ( [ ${DATA2[5]} == 1 ] && [ ${DATA1[1]} == ${DATA2[1]} ] && [ ${DATA1[2]} == ${DATA2[2]} ] && [ ${DATA1[3]} == ${DATA2[3]} ] ); then
				echo "scsi device `echo ${DATA2[6]} | sed -e 's;/nst;/st;;'` appears to be a tape owned by ${DATA1[0]} library"
				temparray=( "${temparray[@]}"  `echo ${DATA2[6]} | sed -e 's;/nst;/st;;'` )
				echo ${DATA2[6]} >> /tmp/foundtape.txt
			fi
		done
		echo "CHANGER_TAPE_DEV_$LF=( ${temparray[@]} )" >> /tmp/guessedconf.txt
		let LF+=1
	fi
done
echo "CHANGER_DEVICES=( ${CHANGER_DEVICES[@]} )" >> /tmp/guessedconf.txt
echo "CHANGER_SLOTS=( ${CHANGER_SLOTS[@]} )" >> /tmp/guessedconf.txt
echo "TAPE_SLOTS=( ${CHANGER_DTE[@]} )" >> /tmp/guessedconf.txt
#	RICERCA TAPE ESTERNI
echo "looking for external tape device(s)"
IFS=$'\n'
unset temparray
for line3 in `$SG_MAP -x`; do
	IFS=$' '
	DATA3=( $line3 )
	if ( [ ${DATA3[5]} == 1 ] && [ `grep -c ${DATA3[6]} /tmp/foundtape.txt` == 0 ] ); then
		echo "scsi device `echo ${DATA3[6]} | sed -e 's;/nst;/st;;'` appears to be an external tape"
		temparray=( "${temparray[@]}"  `echo ${DATA3[6]} | sed -e 's;/nst;/st;;'` )
		echo ${DATA3[6]} >> /tmp/foundtape.txt
	fi
done
echo "MANUAL_TAPE_DEVICES=( ${temparray[@]} )" >> /tmp/guessedconf.txt
[ -f /tmp/foundtape.txt ] && rm /tmp/foundtape.txt
IFS=$old_IFS     # restore default field separator 

echo ""
echo "Guess completed"
echo ""
echo ""
if [ -f $GUESSED_CONF ]; then
	CONF2MATCH=$GUESSED_CONF
else
	CONF2MATCH=`dirname $0`/../../conf/pprimelto.conf
fi
diff /tmp/guessedconf.txt $CONF2MATCH >/dev/null
if [ $? == 0 ]; then
	echo "The guessed conf doesn't differ from running conf:"
	echo "--------------------------------------------------"
	cat /tmp/guessedconf.txt | grep -v bash
	echo "--------------------------------------------------"
	echo "exiting....."
	echo ""
	exit 0
else	
	echo "The guessed conf  differs from running conf:"
	echo "--------------------------------------------------"
	echo "-> Running conf"
	grep -E "^CHANGER_|^TAPE_SLOTS|^MANUAL_TAPE" $GUESSED_CONF
	echo "............................."
	echo "-> Guessed conf"
	grep -E "^CHANGER_|^TAPE_SLOTS|^MANUAL_TAPE" /tmp/guessedconf.txt
	echo "--------------------------------------------------"
fi
echo -n "Please confirm new config or leave unchanged [y|N]> "
read answer
echo "You entered: $answer"
case $answer in
	"y"|"Y")
		cp -p /tmp/guessedconf.txt $GUESSED_CONF
		chmod 755 $GUESSED_CONF
		echo "New config file saved"
	;;
	*)
		echo "Config file left unchanged"
	;;
esac
