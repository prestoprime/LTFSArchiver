#!/usr/bin/env python
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
import sys, xmltodict, json
#	Firts (an unique) argument is the absolute path to XML file
xmlin=str(sys.argv[1])
#	Load whole file
fileHandle = open ( xmlin, 'r' )
xmltext = fileHandle.read()
fileHandle.close()
#	Parse to JSON
jsontext = xmltodict.parse(xmltext)
#	print it to stdout
print json.dumps(jsontext, indent=4, separators=(',', ': '))
