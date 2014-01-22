<?xml version="1.0" encoding="utf-8"?>
<!--
     #  PrestoPRIME  LTFSArchiver
     #  Version: 1.3
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
     ###############################
-->
<xsl:stylesheet version="1.0" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xml="http://www.w3.org/XML/1998/namespace"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
	xmlns:xlink="http://www.w3.org/1999/xlink">

<xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
<xsl:param name="newflocatfile">null</xsl:param>

<xsl:template match="/">
	<xsl:apply-templates select="LTFSArchiver" />
</xsl:template>

<xsl:template match="Result">
  <xsl:copy>
	<xsl:copy-of select="@*"/>
	<xsl:for-each select="FLocat">
		<xsl:variable name="flocat"><xsl:value-of select="@xlink:href"/></xsl:variable>
  		<xsl:copy>
			<xsl:copy-of select="@*"/>
			<xsl:for-each select="document($newflocatfile)//FLocat[@xlink:href=$flocat]">
    				<xsl:apply-templates select="checksum"/>
			</xsl:for-each>
			<xsl:for-each select="checksum">
				<xsl:variable name="ctype"><xsl:value-of select="@type"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="document($newflocatfile)//FLocat[@xlink:href=$flocat]/checksum/@type=$ctype"/>
					<xsl:otherwise>
  						<xsl:copy>
							<xsl:copy-of select="@*"/>
  						</xsl:copy>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
  		</xsl:copy>
	</xsl:for-each>
  </xsl:copy>
</xsl:template>

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
