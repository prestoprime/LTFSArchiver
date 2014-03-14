<!--
#
#  Authors: L. Boch
#
#  Copyright (C) 2013-2014 RAI - Radiotelevisione Italiana <cr_segreteria@rai.it>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#to be removed
<div style="clear:both" class="divbluesmall">
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<input type="submit" value="AddTape" class="formbutton"/>
		<input type="hidden" name="service" value="AddTape"/>
		<br/><br/>Tape
		<input type="text" name="TapeID" size="5" value="null"/>
		Pool 
		<input type="text" name="PoolName" size="5" value="null"/>
		<br/>Format: No<input type="radio" name="Format" value="N" checked="yes"/>
		Yes<input type="radio" name="Format" value="Y"/>
		Force<input type="radio" name="Format" value="F"/>
	</form>
</div>
-->

<xsl:stylesheet version="1.0" 
	xmlns:xlink="http://www.w3.org/1999/xlink" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" indent="yes" omit-xml-declaration="yes"/>


<xsl:template match="/LTFSArchiver">
	<xsl:choose>
		<xsl:when test="ReceivedRequest/@service='ManualLoadQuery'">
			<html id='ltfsa_gui_MLQ'>
				<head>
					<link href="/ltfsa_gui/css/1.css" type="text/css" rel="stylesheet"/>
					<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.3.0/jquery.min.js"></script>
					<script>
						var auto_refresh = setInterval(
						function ()
						{
						   $('#ltfsa_gui_MLQ').load('/cgi-bin/ltfsa_gui/ltfsarequest?service=ManualLoadQuery');
						}, 10000); // refresh every 10000 milliseconds
					</script>
				</head>
			<body>
			<div  class="divbluesmall">
				<h3>LTFSArchiver Manual Operator Interface</h3>
				<xsl:if test="@ltfsaVersion">
					<small>version<xsl:value-of select="@ltfsaVersion"/></small>
				</xsl:if>
				<p><xsl:value-of select="Response/@timenow"/> - <xsl:value-of select="Response/@exit_string"/></p>
				<xsl:variable name="nummlq"><xsl:value-of select="count(Output/ManualLoad)"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="$nummlq > 0">
						<xsl:apply-templates select="Output/ManualLoad"/>
					</xsl:when>
					<xsl:otherwise>
						<h4>Nothing to do</h4>
					</xsl:otherwise>
				</xsl:choose>
			</div>
		   	</body>
			</html>
		</xsl:when>
		<xsl:otherwise>
			<html>
				<head> <link href="/ltfsa_gui/css/1.css" type="text/css" rel="stylesheet"/> </head>
  			<body>
			<div class="divbluesmall">
			<h3>LTFSArchiver</h3>
			<xsl:if test="@ltfsaVersion">
				<small>version<xsl:value-of select="@ltfsaVersion"/></small>
			</xsl:if>
			</div>
			<!--div style="clear:both"></div-->
			<div style="clear:both;" class="divbluesmall">
				<p>
				<b><xsl:value-of select="ReceivedRequest/@service"/><xsl:text> </xsl:text></b>
				<small>requested on <xsl:value-of select="ReceivedRequest/@time"/>, served at <xsl:value-of select="Response/@timenow"/> with exit </small><b> <xsl:value-of select="Response/@exit_string"/></b> <xsl:text> </xsl:text><xsl:value-of select="Response/text()"/>
				</p><p>
				Parameters:<br/> <xsl:apply-templates select="ReceivedRequest/Parameter"/>
				</p>
			</div>
			<!--xsl:apply-templates select="ReceivedRequest"/>
			<xsl:apply-templates select="Response"/-->
			<div style="clear:both"></div>
			<xsl:apply-templates select="Output"/>
		   	</body>
			</html>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="ReceivedRequest|Request">
	<div style="float:right" class="divbluesmall">
		<p><block style="color:#660000;font-weight:bold"><xsl:value-of select="@service"/><xsl:text> </xsl:text></block>
		<small><xsl:text> </xsl:text><xsl:value-of select="@time"/></small>
		</p>
		<xsl:apply-templates select="Parameter"/>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Response">
	<div style="float:left">
		<small><xsl:value-of select="@timenow"/>: <xsl:value-of select="@exit_string"/></small>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Output">
	<xsl:apply-templates/>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Parameter">
	<xsl:if test="@name != 'Output'"><xsl:value-of select="@name"/>=<xsl:value-of select="@value"/><br/></xsl:if>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Result">
	<div style="clear:both" class="divbluesmall">
	<small><xsl:value-of select="@exit_string"/><br/></small>
	<xsl:apply-templates/>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Report">
	<div style="float:left"><h4>Report</h4><xsl:value-of select="./text()"/></div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="FLocat">
	<div style="clear:both"><h4><xsl:value-of select="@xlink:href"/></h4>
		<xsl:if test="@size"><small><xsl:value-of select="@size"/> bytes<br/></small></xsl:if>
		<xsl:if test="@lastModified"><small>last modified: <xsl:value-of select="@lastModified"/><br/></small></xsl:if>
		<xsl:apply-templates/>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Mount">
	<div class="divbluesmall"><p><xsl:value-of select="@device"/>
	<xsl:if test="@path">: <xsl:value-of select="@path"/></xsl:if>
	<xsl:if test="@readonly='true'"> (ro)</xsl:if>
	</p>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="checksum">
	<div style="clear:both">
	<h5><xsl:value-of select="@value"/><xsl:if test="@match='true'"> OKAY</xsl:if></h5>
	<p><xsl:value-of select="@type"/><xsl:if test="@lastChecked">, checked on <xsl:value-of select="@lastChecked"/></xsl:if><br/> 
	<xsl:if test="@match='false'"><b>ALERT</b>, expected <xsl:value-of select="@expectedvalue"/>.</xsl:if>
	</p>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Library">
	<div style="clear:both" class="divbluesmall">
	<h4>Library: <xsl:value-of select="@device"/></h4>
	<xsl:if test="@use">use=<xsl:value-of select="@device"/></xsl:if>
	<xsl:apply-templates/>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Drive">
	<div style="clear:both" class="divbluesmall">
	<xsl:if test="not(@tapeID)">
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<xsl:element name="input">
			<xsl:attribute name="name">Device</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@device"/></xsl:attribute>
		</xsl:element>
		<xsl:choose>
			<xsl:when test="@use='false'">
				<input type="submit" value="Unlock" class="formbutton"/>
				<input type="hidden" name="service" value="UnlockDevice"/>
			</xsl:when>
			<xsl:otherwise>
				<input type="submit" value="Lock" class="formbutton"/>
				<input type="hidden" name="service" value="LockDevice"/>
			</xsl:otherwise>
		</xsl:choose>
	</form>
	</xsl:if>
	<h4>Drive: <xsl:value-of select="@device"/></h4>
	<xsl:if test="@tapeID">In use with tape: <xsl:value-of select="@tapeID"/></xsl:if>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Task">
	<div style="clear:both" class="divbluesmall">
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<xsl:element name="input">
			<xsl:attribute name="name">TaskID</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute>
		</xsl:element>
		<xsl:choose>
		<xsl:when test="@status='completed'">
			<input type="submit" value="GetResult" class="formbutton"/>
			<input type="hidden" name="service" value="GetResult"/>
		</xsl:when>
		<xsl:when test="@status='fallout'">
			<input type="submit" value="Resubmit" class="formbutton"/>
			<input type="hidden" name="service" value="ResubmitTask"/>
		</xsl:when>
		<xsl:when test="@status='waiting'">
			<input type="submit" value="Cancel" class="formbutton"/>
			<input type="hidden" name="service" value="CancelTask"/>
		</xsl:when> <xsl:otherwise>
			<input type="submit" value="Update" class="formbutton"/>
			<input type="hidden" name="service" value="GetStatus"/>
		</xsl:otherwise>
		</xsl:choose>
	</form>
	<xsl:if test="@status='waiting'">
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<xsl:element name="input">
			<xsl:attribute name="name">TaskID</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute>
		</xsl:element>
		<input type="submit" value="Update" class="formbutton"/>
		<input type="hidden" name="service" value="GetStatus"/>
	</form>
	</xsl:if>
	<xsl:apply-templates/>
	<h5><xsl:value-of select="@id"/> - <xsl:value-of select="@status"/></h5>
	<p>
	<xsl:if test="@substatus"><xsl:value-of select="@substatus"/></xsl:if>
	<xsl:if test="@timestart"><br/>start: <xsl:value-of select="@timestart"/></xsl:if>
	<xsl:if test="@timeend"><br/>end: <xsl:value-of select="@timeend"/></xsl:if>
	<xsl:if test="@percentage"> (<xsl:value-of select="@percentage"/>%)</xsl:if>
	<xsl:if test="@tapeid"><br/>tape: <xsl:value-of select="@tapeid"/></xsl:if>
	<xsl:for-each select="Request/Parameter">
		<br/>
	</xsl:for-each>
	</p>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Pool">
	<div style="clear:both" class="divbluesmall">
	<!-- Form on pool basis -->
	<div style="float:right;width:50%" class="divbluesmall">
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<input type="submit" value="AddTape" class="formbutton"/>
		<xsl:element name="input">
			<xsl:attribute name="name">PoolName</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@poolName"/></xsl:attribute>
		</xsl:element>
		<br/><br/>Tape
		<input type="text" name="TapeID" size="10" value="null"/>
		<br/>Format: No<input type="radio" name="Format" value="N" checked="yes"/>
		Yes<input type="radio" name="Format" value="Y"/>
		Force<input type="radio" name="Format" value="F"/>
		<input type="hidden" name="service" value="AddTape"/>
	</form>
	</div>
	<h4>Pool: <xsl:value-of select="@poolName"/></h4>
	<p style="float:left">
	<xsl:if test="@numTapes"><xsl:value-of select="@numTapes"/> tapes <br/></xsl:if>
	<xsl:if test="@totalFreeMB"><xsl:value-of select="@totalFreeMB"/> MB free</xsl:if>
	<xsl:if test="@totalSizeMB"> out of <xsl:value-of select="@totalSizeMB"/>MB total<br/></xsl:if>
	<xsl:if test="@minimumFreeMB">Minimum Free <xsl:value-of select="@minimumFreeMB"/>MB<br/></xsl:if>
	<xsl:if test="@maximumFreeMB">Maximum Free <xsl:value-of select="@maximumFreeMB"/>MB<br/></xsl:if>
	<br/><br/>
	</p>	
	<!-- Looking for Tape information -->
	<xsl:apply-templates/>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Tape">
	<div style="clear:both" class="divbluesmall">
	<h5><xsl:value-of select="@tapeID"/> - <xsl:value-of select="@ltotype"/></h5>
	<xsl:variable name="nummp"><xsl:value-of select="count(MountPending)"/></xsl:variable>
	<xsl:choose>
		<xsl:when test="$nummp > 0 or Mount">
			<xsl:if test="$nummp >0">
<p>Mount pending for tasks: (<xsl:for-each select="MountPending"><xsl:value-of select="@taskID"/>, </xsl:for-each>)</p>
			</xsl:if>
			<!-- looking for mount -->
			<xsl:apply-templates/>
		</xsl:when>
		<xsl:otherwise>	
			<!-- Form on Tape basis: List, MakeAvailableMount, Withdraw -->
				<form style="float:right" action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
					<xsl:element name="input">
						<xsl:attribute name="name">TapeID</xsl:attribute>
						<xsl:attribute name="type">hidden</xsl:attribute>
						<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
					</xsl:element>
					<input type="submit" value="List" class="formbutton"/>
					<input type="hidden" name="service" value="ListTape"/>
				</form>
				<form style="float:right" action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
					<xsl:element name="input">
						<xsl:attribute name="name">TapeID</xsl:attribute>
						<xsl:attribute name="type">hidden</xsl:attribute>
						<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
					</xsl:element>
					<input type="submit" value="MakeAvailable" class="formbutton"/>
					<input type="hidden" name="service" value="MakeAvailableMount"/>
				</form>
				<form style="float:right" action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
					<xsl:element name="input">
						<xsl:attribute name="name">TapeID</xsl:attribute>
						<xsl:attribute name="type">hidden</xsl:attribute>
						<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
					</xsl:element>
					<input type="submit" value="Withdraw" class="formbutton"/>
					<input type="hidden" name="service" value="WithdrawTape"/>
				</form>
		</xsl:otherwise>
	</xsl:choose>
	<p style="font-weight:bold">
	<xsl:value-of select="@freeMB"/>MB free out of  <xsl:value-of select="@sizeMB"/>MB total<br/>
	</p>	
	<p>
	<xsl:choose><xsl:when test="@writeEnable='false'">Write protected</xsl:when>
		<xsl:otherwise>Write enabled</xsl:otherwise>  </xsl:choose> 
	<xsl:if test="@status"> / <xsl:value-of select="@status"/> </xsl:if>
	<xsl:if test="@lastModified"> / Last modified: <xsl:value-of select="@lastModified"/><br/></xsl:if>
	</p>	
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="ManualLoad">
	<div style="clear:both" class="divbluesmall">
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_main">
		<xsl:element name="input">
			<xsl:attribute name="name">TapeID</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
		</xsl:element>
		<xsl:element name="input">
			<xsl:attribute name="name">Device</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@device"/></xsl:attribute>
		</xsl:element>
		<input type="submit" value="Confirm" class="formbutton"/>
		<input type="hidden" name="service" value="ManualLoadConfirm"/>
		<p style="clear:both;float:right">Done Okay<input type="radio" name="Error" value="null" checked="yes"/>
		Tape Not Found<input type="radio" name="Error" value="TapeNotFound"/>
		Device Error<input type="radio" name="Error" value="DeviceError"/>
		</p>
	</form>
	<h4>Please load tape: <xsl:value-of select="@tapeID"/> on device: <xsl:value-of select="@device"/></h4>
	<p><xsl:value-of select="@taskID"/><br/></p>
	</div>
</xsl:template>
<!-- ************************************************************-->

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
