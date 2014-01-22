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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.0">
  <xsl:output method="xml" omit-xml-declaration="yes" indent="yes"/>
  <xsl:param name="flocat"/>
  <xsl:strip-space elements="*"/>
  <xsl:template match="/Output/Result">
    <xsl:apply-templates select="FLocat"/>
  </xsl:template>
  <xsl:template match="FLocat">
    <xsl:variable name="flocatfound" select="@xlink:href"/>
    <xsl:if test="$flocatfound = $flocat">
      <xsl:element name="FLocat">
        <xsl:attribute name="xlink:href">
          <xsl:value-of select="@xlink:href"/>
        </xsl:attribute>
        <xsl:variable name="chkfound" select="./checksum"/>
        <xsl:if test="$chkfound">
          <xsl:element name="checksum">
            <xsl:attribute name="type">
              <xsl:value-of select="checksum/@type"/>
            </xsl:attribute>
            <xsl:attribute name="value">
              <xsl:value-of select="checksum/@value"/>
            </xsl:attribute>
          </xsl:element>
        </xsl:if>
      </xsl:element>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
