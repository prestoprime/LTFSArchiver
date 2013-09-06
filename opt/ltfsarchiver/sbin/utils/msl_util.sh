#  PrestoPRIME  LTFSArchiver
#  Version: 0.9 Beta
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


#-----------	find_tape: restituisce posizione TAPE_LABEL
#	in $1 ricevo la label del supporto da cercare
#	se lo trovo nel caricatore esco con 0
#	se lo trovo nel drive esco con 1
#	se non lo trovo esco con 8
#	in FOUND restituisco l'id della slot o del driver in cui ho trovato il tape
#	in CHANGER_DEVICE_I restituisco l'indice del mediachanger su cui l'ho trovato
#	in CHANGER_DEVICE_N restituisco il devname del mediachanger su cui l'ho trovato
function find_tape()
{
for ((IDX=0; IDX<${#CONF_CHANGER_DEVICES[@]}; IDX++)); do
	DATA_ANSWER=( `$CMD_MTX -f ${CONF_CHANGER_DEVICES[$IDX]} status | grep $1 | tr ':' ' '` )
	# Non trovato da nessuna parte
	if [ ${#DATA_ANSWER[@]} == 0 ]; then
		FINDTP_RC=8
		FOUND="X"
	else
		#	Dov'e'?
		case ${DATA_ANSWER[0]} in
			"Data")
				#	E' nel driver
				FINDTP_RC=1
				FOUND=${DATA_ANSWER[3]}
			;;
				#	E' in uno slot
			"Storage")
				FINDTP_RC=0
				FOUND=${DATA_ANSWER[2]}
			;;
		esac
		#	Questo e' il media changer che "possiede" il tape
		CHANGER_DEVICE_I=$IDX
		CHANGER_DEVICE_N=${CONF_CHANGER_DEVICES[$IDX]}
		#	forzo uscita da while
		IDX=${#CONF_CHANGER_DEVICES[@]}
	fi
done
}
function locate_tape()
#	in input devnamelibreria label
#	in output slot (o empty)
{
DATA_ANSWER=( `$CMD_MTX -f $1 status | grep $2 | tr ':' ' '` )
if [ ${DATA_ANSWER[0]} == "Storage" ]; then
	echo ${DATA_ANSWER[2]}
fi
}
function locate_slot()
#	in input devnamelibreria
#	in output slot libero (o empty)
{
echo `$CMD_MTX -f  $1 status | grep Storage | grep Empty | head -1 | tr ':' ' ' | awk '{print $3}'`
}

function status_dte()
{
actual_status=( `$CMD_MTX -f $1 status | grep "Data Transfer Element $2:" | cut -d ':' -f 2 | cut -d ' ' -f 1| tr -d ' ' | tr [A-Z] [a-z]` )
[ $actual_status == "full" ] && actual_status=( "${actual_status[@]}"  `$CMD_MTX -f $1 status | grep "Data Transfer Element $2:" |  awk '{print $NF }'` ) 
echo ${actual_status[@]}
}
