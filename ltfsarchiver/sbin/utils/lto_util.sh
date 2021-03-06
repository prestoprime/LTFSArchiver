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

function get_tape_status()
{
#	function called after physical load, I have to be sure that status is "41010000" (unprotected, BOT)
TENTATIVO=0
while [ $TENTATIVO -le 5 ]; do
	TAPESTATUS=( `$CMD_MT -f $1 status |grep -E "General|Density" | sed -e 's/.*code//' -e 's/(no.*//' -e 's/ (de.*//'| sed '/General/s/[^0-9]*//g' |  tr -d ' ' | tr '\n' ' '` )
	main_logger 4 "TAPESTATUS returned values: ${TAPESTATUS[@]}"
	[ $LTFSARCHIVER_DEBUG == 1 ] && $CMD_MT -f $1 status 
	case ${TAPESTATUS[1]} in
		"41010000")
			#	ok, loaded and ready
			TAPE_STATUS_RC=0
			TAPE_STATUS_MSG="ready"
			TENTATIVO=5
			#	let's see density code and try to match with allowed ones
			DENSITY_IDX=0
			if [ -z ${TAPESTATUS[0]} ]; then
				unset TAPE_STATUS_TYPE
			else
				for ((DENSITY_IDX=0;DENSITY_IDX<${#LTO_ALLOWED_CODES[@]};DENSITY_IDX++)); do
					if [ ${TAPESTATUS[0]} == ${LTO_ALLOWED_CODES[$DENSITY_IDX]} ]; then
						TAPE_STATUS_TYPE=${LTO_ALLOWED_TYPES[$DENSITY_IDX]}
						#	Setting watermark (will be used for write batch(es))
						TAPE_WATERMARK=${LTO_WATERMARK[$DENSITY_IDX]}
						DENSITY_IDX=${#LTO_ALLOWED_CODES[@]}
					fi
				done
			fi
			if [ -z $TAPE_STATUS_TYPE ]; then
				TAPE_STATUS_RC=32
				TAPE_STATUS_MSG=" unsupported type (density code: ${TAPESTATUS[0]})"
			fi
			#	test to simulate a wrong density code
			#TAPE_STATUS_RC=32
			#TAPE_STATUS_MSG="fake error"
		;;
		#	Known status...
		"10000")
			TAPE_STATUS_RC=1
			TAPE_STATUS_MSG=" positioning"
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
		#	Other status...
		*)
			TAPE_STATUS_RC=16
			TAPE_STATUS_MSG=" unknown status: ${TAPESTATUS[1]}"
		;;
	esac
	sleep 1
	let TENTATIVO+=1
done
}
