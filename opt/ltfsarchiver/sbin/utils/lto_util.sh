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

function get_tape_status()
{
TENTATIVO=0
while [ $TENTATIVO -le 5 ]; do
	TAPESTATUS=( `$MT_CMD -f $1 status |grep -E "General|Density" | sed -e 's/.*code//' -e 's/(no.*//' -e 's/ (de.*//'| sed '/General/s/[^0-9]*//g' |  tr -d ' ' | tr '\n' ' '` )
	main_logger 4 "TAPESTATUS returned value: $TAPESTATUS"
	[ $LTFSARCHIVER_DEBUG == 1 ] && $MT_CMD -f $1 status 
	case ${TAPESTATUS[1]} in
		"41010000")
			#	ok
			TAPE_STATUS_RC=0
			TAPE_STATUS_MSG="ready"
			TENTATIVO=5
			#	se OK, leggo density code
			DENSITY_IDX=0
			if [ -z ${TAPESTATUS[0]} ]; then
				unset TAPE_STATUS_TYPE
			else
				while [ $DENSITY_IDX -lt ${#LTO_ALLOWED_CODES[@]} ]; do
					if [ ${TAPESTATUS[0]} == ${LTO_ALLOWED_CODES[$DENSITY_IDX]} ]; then
						TAPE_STATUS_TYPE=${LTO_ALLOWED_TYPES[$DENSITY_IDX]}
						TAPE_WATERMARK=${LTO_WATERMARK[$DENSITY_IDX]}
						DENSITY_IDX=${#LTO_ALLOWED_CODES[@]}
					fi
				done
			fi
			if [ -z $TAPE_STATUS_TYPE ]; then
				TAPE_STATUS_RC=32
				TAPE_STATUS_MSG=" unsupported type (density code: ${TAPESTATUS[0]})"
			fi
			#	test per simulare errore
			#TAPE_STATUS_RC=32
			#TAPE_STATUS_MSG="fake error"
		;;
		"10000")
			TAPE_STATUS_RC=1
			TAPE_STATUS_MSG=" positiong"
		;;
		"45010000")
			TAPE_STATUS_RC=2
			TAPE_STATUS_MSG=" protected"
		;;
		"50000")
			TAPE_STATUS_RC=4
			TAPE_STATUS_MSG=" missing"
		;;
		"4010000")
			TAPE_STATUS_RC=8
			TAPE_STATUS_MSG=" protected - ejecting"
		;;
		*)
			TAPE_STATUS_RC=16
			TAPE_STATUS_MSG=" unknown status: ${TAPESTATUS[1]}"
		;;
	esac
	sleep 1
	let TENTATIVO+=1
done
}
