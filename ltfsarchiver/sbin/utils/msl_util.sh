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


function find_tape()
{
#-----------	find_tape: returns Storage Slot number for given tape
#	incoming parms
#	$1 tabe label
#
#	outgoing
#	Exit code 
#	0=found into a slot (idle)
#	1=found into a driver (active)
#	8=not found
#	FOUND=Storage Slot (EXIT=0) or DTE (EXIT=1)
#	CHANGER_DEVICE_I=Index of labrary
#	CHANGER_DEVICE_N=Devname of library
for ((IDX=0; IDX<${#CONF_CHANGER_DEVICES[@]}; IDX++)); do
	DATA_ANSWER=( `$CMD_MTX -f ${CONF_CHANGER_DEVICES[$IDX]} status | grep $1 | tr ':' ' '` )
	#	Not found
	if [ ${#DATA_ANSWER[@]} == 0 ]; then
		FINDTP_RC=8
		FOUND="X"
	else
		#	Found... where is it?
		case ${DATA_ANSWER[0]} in
			"Data")
				#	Into a driver
				FINDTP_RC=1
				FOUND=${DATA_ANSWER[3]}
			;;
				#	Into a Slot
			"Storage")
				FINDTP_RC=0
				FOUND=${DATA_ANSWER[2]}
			;;
		esac
		#	tapelibrary owning tape
		CHANGER_DEVICE_I=$IDX
		CHANGER_DEVICE_N=${CONF_CHANGER_DEVICES[$IDX]}
		#	break loop
		IDX=${#CONF_CHANGER_DEVICES[@]}
	fi
done
}
function locate_tape()
{
#	in input devnamelibreria label
#	in output slot (o empty)
DATA_ANSWER=( `$CMD_MTX -f $1 status | grep $2 | tr ':' ' '` )
if [ ${DATA_ANSWER[0]} == "Storage" ]; then
	echo ${DATA_ANSWER[2]}
fi
}
function locate_slot()
{
#	Returns the first free sloto in library
#	Incoming parms: library devname
#	Outgoing: slot number (empty if none)
echo `$CMD_MTX -f  $1 status | grep Storage | grep Empty | head -1 | tr ':' ' ' | awk '{print $3}'`
}

function status_dte()
{
#	Simply returns DTE status
#	Incoming parms:
#	$1: Library devname
#	$2: DTE id
#	Outgoing: status
actual_status=( `$CMD_MTX -f $1 status | grep "Data Transfer Element $2:" | cut -d ':' -f 2 | cut -d ' ' -f 1| tr -d ' ' | tr [A-Z] [a-z]` )
[ $actual_status == "full" ] && actual_status=( "${actual_status[@]}"  `$CMD_MTX -f $1 status | grep "Data Transfer Element $2:" |  awk '{print $NF }'` ) 
echo ${actual_status[@]}
}
