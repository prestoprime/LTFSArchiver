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
	<xsl:param name="flocat"/>
	<xsl:param name="chktype"/>
	<xsl:strip-space elements="*"/>
	<xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
	<xsl:template match="//FLocat">
		<xsl:variable name="flocatfound" select="@xlink:href"/>
		<xsl:variable name="chktypefound" select="./checksum/@type"/>
		<xsl:variable name="chkfound" select="./checksum"/>
		<xsl:if test="$chkfound">
			<xsl:if test="$flocat = $flocatfound">
				<xsl:if test="$chktype = $chktypefound">
        				<xsl:value-of select="checksum/@value"/>
				</xsl:if>
			</xsl:if>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>
