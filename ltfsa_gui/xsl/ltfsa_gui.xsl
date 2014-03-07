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

-->

<xsl:stylesheet version="1.0" 
	xmlns:xlink="http://www.w3.org/1999/xlink" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" indent="yes" omit-xml-declaration="yes"/>


<xsl:template match="/LTFSArchiver">
<html>
	<head>
		<link href="/ltfsa_gui/css/1.css" type="text/css" rel="stylesheet"/>
	</head>
  <body>
	<div>
	<h3>LTFSArchiver</h3>
	<xsl:if test="@ltfsaVersion">
		<small>version<xsl:value-of select="@ltfsaVersion"/></small>
	</xsl:if>
	</div>
	<div style="clear:both">
	<xsl:apply-templates select="ReceivedRequest"/>
	<xsl:apply-templates select="Response"/>
	</div>
	<div style="clear:both">
	<xsl:apply-templates select="Output"/>
	</div>
  </body>
</html>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="ReceivedRequest|Request">
	<div style="float:left">
		<h4><xsl:value-of select="@service"/></h4>
		<small><xsl:value-of select="@time"/></small>
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
	<xsl:value-of select="@name"/>=<xsl:value-of select="@value"/><br/>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Result">
	<small><xsl:value-of select="@exit_string"/><br/></small>
	<xsl:apply-templates/>
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
	<div style="float:left"><p><xsl:value-of select="@device"/>
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
<xsl:template match="Task">
	<div style="clear:both">
	<h5><xsl:value-of select="@id"/> - <xsl:value-of select="@status"/></h5>
	<p>
	<xsl:if test="@substatus"><xsl:value-of select="@substatus"/></xsl:if>
	<xsl:if test="@timestart"><br/>start: <xsl:value-of select="@timestart"/></xsl:if>
	<xsl:if test="@timeend"><br/>end: <xsl:value-of select="@timeend"/></xsl:if>
	<xsl:if test="@percentage"> (<xsl:value-of select="@percentage"/>%)</xsl:if>
	<xsl:if test="@tapeid"><br/>tape: <xsl:value-of select="@tapeid"/></xsl:if>
	</p>
	<xsl:apply-templates/>
	<!-- forms on this task if applicable 
					<xsd:enumeration value="starting"/>
					<xsd:enumeration value="running"/> -->
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<xsl:element name="input">
			<xsl:attribute name="name">TaskID</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute>
		</xsl:element>
		<xsl:choose>
		<xsl:when test="@status='completed'">
			<input type="submit" value="GetResult"/>
			<input type="hidden" name="service" value="GetResult"/>
		</xsl:when>
		<xsl:when test="@status='fallout'">
			<input type="submit" value="Resubmit"/>
			<input type="hidden" name="service" value="ResubmitTask"/>
		</xsl:when>
		<xsl:when test="@status='waiting'">
			<input type="submit" value="Cancel"/>
			<input type="hidden" name="service" value="CancelTask"/>
		</xsl:when> <xsl:otherwise>
			<input type="submit" value="Update"/>
			<input type="hidden" name="service" value="GetStatus"/>
		</xsl:otherwise>
		</xsl:choose>
	</form>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Pool">
	<div style="clear:both">
	<h5><xsl:value-of select="@poolName"/></h5>
	<p>
	<xsl:if test="@numTapes"><xsl:value-of select="@numTapes"/> tapes <br/></xsl:if>
	<xsl:if test="@totalFreeMB"><xsl:value-of select="@totalFreeMB"/>MB free</xsl:if>
	<xsl:if test="@totalSizeMB">out of <xsl:value-of select="@totalSizeMB"/>MB total<br/></xsl:if>
	<xsl:if test="@minimumFreeMB">Minimum Free<xsl:value-of select="@minimumFreeMB"/>MB<br/></xsl:if>
	<xsl:if test="@maximumFreeMB">Maximum Free<xsl:value-of select="@maximumFreeMB"/>MB<br/></xsl:if>
	</p>	
	<!-- Form on pool basis -->
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<xsl:element name="input">
			<xsl:attribute name="name">PoolName</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@poolName"/></xsl:attribute>
		</xsl:element>
		<input type="submit" value="AddTape"/>
		<input type="hidden" name="service" value="AddTape"/>
		<input type="text" name="TapeID" size="5"/><br/>
		Format: No<input type="radio" name="Format" value="N" checked="yes"/>
		Yes<input type="radio" name="Format" value="Y"/>
		Force<input type="radio" name="Format" value="F"/>
	</form>
	<!-- Looking for Tape information -->
	<xsl:apply-templates/>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="Tape">
	<div style="clear:both">
	<h5><xsl:value-of select="@tapeID"/> - <xsl:value-of select="@ltotype"/></h5>
	<p>
	<xsl:value-of select="@freeMB"/>MB free out of  <xsl:value-of select="@sizeMB"/>MB total<br/>
	<xsl:choose><xsl:when test="@writeEnable='false'">Write protected.<br/></xsl:when>
		<xsl:otherwise>Write enabled.<br/></xsl:otherwise></xsl:choose>
	<xsl:if test="@status">Status: <xsl:value-of select="@status"/><br/></xsl:if>
	<xsl:if test="@lastModified">Last modified: <xsl:value-of select="@lastModified"/><br/></xsl:if>
	</p>	
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
			<div style="float:left">
				<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
					<xsl:element name="input">
						<xsl:attribute name="name">TapeID</xsl:attribute>
						<xsl:attribute name="type">hidden</xsl:attribute>
						<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
					</xsl:element>
					<input type="submit" value="List"/>
					<input type="hidden" name="service" value="ListTape"/>
				</form>
			</div>
			<div style="float:left">
				<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
					<xsl:element name="input">
						<xsl:attribute name="name">TapeID</xsl:attribute>
						<xsl:attribute name="type">hidden</xsl:attribute>
						<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
					</xsl:element>
					<input type="submit" value="MakeAvailable"/>
					<input type="hidden" name="service" value="MakeAvailableMount"/>
				</form>
			</div>
			<div style="float:left">
				<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
					<xsl:element name="input">
						<xsl:attribute name="name">TapeID</xsl:attribute>
						<xsl:attribute name="type">hidden</xsl:attribute>
						<xsl:attribute name="value"><xsl:value-of select="@tapeID"/></xsl:attribute>
					</xsl:element>
					<input type="submit" value="Withdraw"/>
					<input type="hidden" name="service" value="WithdrawTape"/>
				</form>
			</div>
		</xsl:otherwise>
	</xsl:choose>
	</div>
</xsl:template>
<!-- ***************************************** -->
<xsl:template match="ManualLoad">
	<div style="clear:both">
	<h5>Please load tape: <xsl:value-of select="@tapeID"/> on device: <xsl:value-of select="@device"/></h5>
	<p><xsl:value-of select="@taskID"/></p>
	<form action="/cgi-bin/ltfsa_gui/ltfsarequest" method="get" target="ltfsa_gui_results">
		<xsl:element name="input">
			<xsl:attribute name="name">TaskID</xsl:attribute>
			<xsl:attribute name="type">hidden</xsl:attribute>
			<xsl:attribute name="value"><xsl:value-of select="@taskID"/></xsl:attribute>
		</xsl:element>
		<input type="submit" value="Enter when done"/>
		<input type="hidden" name="service" value="ManualLoadConfirm"/>
	</form>
	</div>
</xsl:template>
<!-- ************************************************************-->

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
