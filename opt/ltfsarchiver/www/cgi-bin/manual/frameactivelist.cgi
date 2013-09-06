#!/bin/bash
PASSED=$QUERY_STRING
echo 'Content-Type: text/html'
echo ''
echo '<html>'
echo '<head>'
echo '<meta content="text/html; charset=iso-8859-1"'
echo 'http-equiv="Content-Type">'
echo '<title></title>'
echo '<HTML>
<FRAMESET rows="*,30%" border=0>
		<FRAME NAME=action src="activelist.cgi?'$PASSED'">
		<FRAME NAME=result src="../../blank.html">
	</FRAMESET>
</FRAMESET>'
