#!/usr/bin/makefile -f
# -*- makefile -*-
#
#	Copyright (C) 2002-2009 Jari Aalto
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

DOCDIR		= manual
PACKAGE		= pwget
PL		= ../bin/$(PACKAGE).pl

INSTALL		= install
INSTALL_BIN	= $(INSTALL) -m 755
INSTALL_DATA	= $(INSTALL) -m 644
INSTALL_SUID	= $(INSTALL) -m 4755

all: doc

# Rule: clena - delete temporary files
clean:
	rm  -f *[~#] *.tmp

$(DOCDIR)/$(PACKAGE).html: $(PL)
	perl $< help --help-html > $(DOCDIR)/$(PACKAGE).html
	@-rm -f *.x~~ pod*.tmp

$(DOCDIR)/$(PACKAGE).txt: $(PL)
	perl $< --help > $(DOCDIR)/$(PACKAGE).txt
	@-rm -f *.x~~ pod*.tmp

# Rule: doc - Generate or update documentation
doc: $(DOCDIR)/$(PACKAGE).html $(DOCDIR)/$(PACKAGE).txt

man:

# End of file
