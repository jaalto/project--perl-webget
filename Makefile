#!/usr/bin/make -f
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
#	General Public License for more details at
#	<http://www.gnu.org/copyleft/gpl.html>.

ifneq (,)
This makefile requires GNU Make.
endif

MAKEDIR = admin/mk

include $(MAKEDIR)/clean.mk
include $(MAKEDIR)/install.mk
include $(MAKEDIR)/manifest.mk
include $(MAKEDIR)/perl.mk
include $(MAKEDIR)/release.mk
include $(MAKEDIR)/vars.mk
include $(MAKEDIR)/www.mk

PACKAGE			= pwget
PL			= $(PACKAGE).pl
BIN			= $(PACKAGE)
PL_SCRIPT		= bin/$(PL)

WWWROOT			= $(shell echo $$(pwd)/..)
INSTALL_OBJS		= $(BIN)
INSTALL_DOC_OBJS	= COPYING README
INSTALL_MAN1_OBJS	= bin/*.1
INSTALL_BIN_S_OBJS	= $(PL_SCRIPT)

all:
	@echo "Nothing to compile. See INSTALL"

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

# Rule: install - Install the software
install: all install-script-bin install-man1 install-doc

test: perl-test

.PHONY: all man doc test

# End of file
