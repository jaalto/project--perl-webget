#!/usr/bin/make -f
#
#   Copyright information
#
#	Copyright (C) 2002-2009 Jari Aalto
#
#   License
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License as
#	published by the Free Software Foundation; either version 2 of the
#	License, or (at your option) any later version
#
#	This program is distributed in the hope that it will be useful, but
#	WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#	General Public License for more details.
#
#	Visit <http://www.gnu.org/copyleft/gpl.html>

all:
	@echo "Nothing to compile." \
	      "see 'make DFESTDIR= prefix=/usr/local install"

clean:
	$(MAKE) -C bin clean
	$(MAKE) -C doc clean

man:
	$(MAKE) -C bin man

doc: man
	$(MAKE) -C doc all

distclean: clean

realclean: clean

install:
	$(MAKE) -C bin install

.PHONY: clean distclean realclean install

# End of file
