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

PACKAGE		= pwget
DESTDIR		=
prefix		= /usr/local
exec_prefix	= $(prefix)
man_prefix	= $(prefix)/share
mandir		= $(man_prefix)/man
bindir		= $(exec_prefix)/bin
sharedir	= $(prefix)/share

BINDIR		= $(DESTDIR)$(bindir)
DOCDIR		= $(DESTDIR)$(sharedir/doc
SHAREDIR	= $(DESTDIR)$(prefix)/share/$(PACKAGE)
LIBDIR		= $(DESTDIR)$(prefix)/lib/$(PACKAGE)
SBINDIR		= $(DESTDIR)$(exec_prefix)/sbin
ETCDIR		= $(DESTDIR)/etc/$(PACKAGE)

# 1 = regular, 5 = conf, 6 = games, 8 = daemons
MANDIR		= $(DESTDIR)$(mandir)
MANDIR1		= $(MANDIR)/man1
MANDIR5		= $(MANDIR)/man5
MANDIR6		= $(MANDIR)/man6
MANDIR8		= $(MANDIR)/man8

INSTALL_OBJS_BIN   = $(PACKAGE).pl
INSTALL_OBJS_MAN1  = *.1
INSTALL_OBJS_SHARE =
INSTALL_OBJS_ETC   =

INSTALL		= install
INSTALL_BIN	= $(INSTALL) -m 755
INSTALL_DATA	= $(INSTALL) -m 644
INSTALL_SUID	= $(INSTALL) -m 4755

PL		= ./$(PACKAGE).pl
DOCDIR		= .

all: man

# Rule: clean - delete temporary files
clean:
	rm  -f *[~#] *.tmp


$(PACKAGE).1: $(PL)
	perl $< --help-man > $(DOCDIR)/$(PACKAGE).1
	@-rm -f *.x~~ pod*.tmp

# Rule: doc - Generate or update documentation
doc: $(PACKAGE).1

man: doc

install-man:
	# install-man
	$(INSTALL_BIN) -d $(MANDIR1)
	$(INSTALL_DATA) $(INSTALL_OBJS_MAN1) $(MANDIR1)

install-bin:
	# install-bin
	$(INSTALL_BIN) -d $(BINDIR)
	$(INSTALL_BIN)	  $(INSTALL_OBJS_BIN) $(BINDIR)/$(PACKAGE)

install: all install-bin install-man

.PHONY: clean distclean realclean install install-bin install-man
.PHONY: all man

# End of file
