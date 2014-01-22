#!/bin/bash
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

################################################################################
# Script starts here
. $CFGFILE
. `dirname $0`/common.sh
command=`basename $0`
PARM=$QUERY_STRING
RECEIVEDTIME=`date +'%Y-%m-%dT%H:%M:%S'`
VALIDPARMS="TaskID|FromGUI"
XSLFILE="$LTFSARCHIVER_HOME/stylesheets/extrchksum.xsl"
LOOKFORCHK=false
get_supplied_parameters
taskid=$( get_parameter TaskID )
guicall=$( get_parameter FromGUI )
callingtime=`date '+%Y-%m-%d %H:%M:%S'`
if [ -z $output ]; then
	output=`echo $LTFSARCHIVER_OUTPUT | tr '[A-Z]' ' [a-z]'`
	PARM=$PARM'&Output='$output
fi
[ -z $guicall ] && guicall=false
if ! [ -z "$BADPARMS" ]; then
	exitcode="400"; message="${BADPARMS}"
else
	if [ -z $taskid ] ; then
		exitcode="400"; message='TaskID not supplied'
	else
		CHKREQ=( `$CMD_DB "select operation,checksum from requests where uuid='$taskid';" | tr -d ' ' | tr '|' ' '` )
		if [ -z "$CHKREQ" ]; then
			exitcode="400"; message="Task not found"
		else
			case ${CHKREQ[0]} in
				"W")
					case ${CHKREQ[1]} in
						"SHA1"|"SHA1_both"|"MD5"|"MD5_both")
							LOOKFORCHK=true
						;;
						*)
							exitcode="400"; message="Checksum not created"
						;;
						esac
				;;
				*)
					exitcode="400"; message="Not an archive task"
				;;
			esac
		fi
	fi
fi
if $LOOKFORCHK; then
	echo 'Content-Type: text/plain'
	echo ''
	tmpout=/tmp/`uuidgen`.xml
	wget "http://10.58.78.165/ltfsarchiver/cgi-bin/GetResult?TaskID=$taskid" -O $tmpout
	$CMD_XSL $XSLFILE $tmpout 3>/dev/null | tr -d '\t' | sed -e 's/^ *//' -e '/^$/d'
	[ -f $tmpout ] && rm $tmpout
else
	crea_xml_answer
	#       Output
	send_output
fi
