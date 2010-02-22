#!/usr/bin/make -f
#
#   Copyright information
#
#	Copyright (C) 2002-2010 Jari Aalto
#
#   License
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program. If not, see <http://www.gnu.org/licenses/>.

ifneq (,)
This makefile requires GNU Make.
endif

PACKAGE		= pwget
DESTDIR		=
prefix		= /usr/local
exec_prefix	= $(prefix)
man_prefix	= $(prefix)/share
mandir		= $(man_prefix)/man
bindir		= $(exec_prefix)/bin
sharedir	= $(prefix)/share

BINDIR		= $(DESTDIR)$(bindir)
DOCDIR		= $(DESTDIR)$(sharedir)/doc
LOCALEDIR	= $(DESTDIR)$(sharedir)/locale
SHAREDIR	= $(DESTDIR)$(sharedir)/$(PACKAGE)
LIBDIR		= $(DESTDIR)$(prefix)/lib/$(PACKAGE)
SBINDIR		= $(DESTDIR)$(exec_prefix)/sbin
ETCDIR		= $(DESTDIR)/etc/$(PACKAGE)

# 1 = regular, 5 = conf, 6 = games, 8 = daemons
MANDIR		= $(DESTDIR)$(mandir)
MANDIR1		= $(MANDIR)/man1
MANDIR5		= $(MANDIR)/man5
MANDIR6		= $(MANDIR)/man6
MANDIR8		= $(MANDIR)/man8

INSTALL_OBJS_BIN   = bin/$(PACKAGE)
INSTALL_OBJS_DOC   = README COPYING doc/
INSTALL_OBJS_MAN   = bin/*.1

TAR		= tar
TAR_OPT_NO	= --exclude='.build'	 \
		  --exclude='.sinst'	 \
		  --exclude='.inst'	 \
		  --exclude='tmp'	 \
		  --exclude='*.bak'	 \
		  --exclude='*[~\#]'	 \
		  --exclude='.\#*'	 \
		  --exclude='CVS'	 \
		  --exclude='.svn'	 \
		  --exclude='.git'	 \
		  --exclude='.bzr'	 \
		  --exclude='*.tar*'	 \
		  --exclude='*.tgz'

INSTALL		= /usr/bin/install
INSTALL_BIN	= $(INSTALL) -m 755
INSTALL_DATA	= $(INSTALL) -m 644
INSTALL_SUID	= $(INSTALL) -m 4755

BIN		= $(PACKAGE)
PL_SCRIPT 	= bin/$(BIN).pl

INSTALL_OBJS		= $(BIN)
INSTALL_DOC_OBJS	= COPYING README
INSTALL_MAN1_OBJS	= bin/*.1
INSTALL_BIN_S_OBJS	= $(PL_SCRIPT)

all:
	@echo "Nothing to compile. See INSTALL"

clean:
	# clean
	-rm -f *[#~] *.\#*
	*.x~~ pod*.tmp

distclean: clean

realclean: clean

bin/$(PACKAGE).1: $(PL_SCRIPT)
	$(PERL) $< --help-man > $<
	@-rm -f *.x~~ pod*.tmp

doc/manual/$(PACKAGE).html: $(PL_SCRIPT)
	$(PERL) $< --help-html > $<
	@-rm -f *.x~~ pod*.tmp

doc/manual/$(PACKAGE).txt: $(PL_SCRIPT)
	$(PERL) $< --help > $<
	@-rm -f *.x~~ pod*.tmp

doc/conversion/index.html: doc/conversion/index.txt
	perl -S t2html.pl --Auto-detect --Out --print-url $<

# Rule: man - Generate or update manual pages documentation
man: bin/$(PACKAGE).1 doc/manual/$(PACKAGE).html  doc/manual/$(PACKAGE).txt

# Rule: doc - Generate or update all documentation
doc: man doc/conversion/index.html

perl-test:
	# perl-test - Check syntax
	perl -cw $(PL_SCRIPT)

test: perl-test

install-bin:
	# install-bin - Install programs
	$(INSTALL_BIN) -d $(BINDIR)
	for f in $(INSTALL_OBJS_bin); \
	do \
		dest=$$(basename $$f | sed -e 's/.pl//' -e 's/.py//' ); \
		$(INSTALL_BIN) $$f $(BINDIR)/$$dest; \
	done

install-doc:
	# Rule install-doc - Install documentation
	$(INSTALL_BIN) -d $(DOCDIR)
	$(INSTALL_DATA) $(INSTALL_DOC_OBJS) $(DOCDIR)
	$(TAR) -C doc $(TAR_OPT_NO) --create --file=- .  | \
	$(TAR) -C $(DOCDIR) --extract --file=-

install-man:
	# install-man - Install manual pages
	$(INSTALL_BIN) -d $(MANDIR1)
	$(INSTALL_DATA) $(INSTALL_OBJS_MAN) $(MANDIR1)

install: install-bin install-man install-doc

# Rule install-test - for Maintainer only
install-test:
	rm -rf tmp
	make DESTDIR=`pwd`/tmp prefix=/usr install
	find tmp | sort

test: perl-test install-test

.PHONY: clean distclean realclean
.PHONY: install install-bin install-man
.PHONY: all man doc test install-test perl-test

# End of file
