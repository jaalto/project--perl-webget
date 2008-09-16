#!/usr/bin/makefile -f
# -*- makefile -*-
#
#	Copyright (C) 2002-2008 Jari Aalto
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
#	You should have received a copy of the GNU General Public License
#	along with program; see the file COPYING. If not, write to the
#	Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#	Boston, MA 02110-1301, USA.
#
#	Visit <http://www.gnu.org/copyleft/gpl.html>

# Hm, AIX can use 'include', but it would stuck on this
# ifneq (,)
# This makefile requires GNU Make.
# endif

PACKAGE		= mywebget

SRCS_PL		= bin/$(PACKAGE).pl

DOCS		= doc/txt doc/html doc/man
SRCS		= $(SRCS_PL) $(SRCS_SH)
MANS		= $(SRCS_PL:.pl=.1) $(SRCS_SH:.sh=.1)
OBJS		= $(SRCS) Makefile README ChangeLog

MAKE_INCLUDEDIR = etc/makefile

include $(MAKE_INCLUDEDIR)/id.mk
include $(MAKE_INCLUDEDIR)/vars.mk
include $(MAKE_INCLUDEDIR)/cygwin.mk
include $(MAKE_INCLUDEDIR)/unix.mk
include $(MAKE_INCLUDEDIR)/net-sf.mk

# ######################################################## &suffixes ###

.SUFFIXES:
.SUFFIXES: .pl .1

#   Pod generates .x~~ extra files and rm(1) cleans them
#
#   $< = name of the input (full)
#   $@ = name, but only basename part, without suffix
#   D  = macro; Give only directory part
#   F  = macro; Give only file part

.pl.1:
	perl $< --Help-man > doc/man/$(*F).1
	perl $< --Help-html > doc/html/$(*F).html
	perl $< --help > doc/txt/$(*F).txt
	-rm  -f *[~#] *.tmp

doc/man/$(PACKAGE).1: $(SRCS_PL)
	make docs

# ######################################################### &targets ###

clean:
	rm  -f *[~#] *.tmp

# Rule: all - Make and Compile all.
all: perl-fix chmod-x doc

# install: install-log install-etc install-unix
install: install-unix

# Rule: clean - Remove files that can be generated
clean: clean-temp-files

# Rule: distclean - Remove files that can be generated
distclean: clean

# Rule: realclean - Clean everything
realclean: clean-temp-realclean	 clean

$(DOCS):
	$(INSTALL) $(INSTALL_DATA) -d $@

# Rule: docs - Generate or update documentation (force)
docs: $(DOCS) $(MANS)

# Rule: doc - Generate or update documentation
doc: $(DOCS) doc/man/$(PACKAGE).1

test:
	@echo "Nothing to test. Report bugs to <$(EMAIL)>"

# Rule: chmod-x - Make binaries executable
chmod-x:
	chmod +x $(SRCS)

# Rule: perl-fix - Change 1st line in *.pl file to match system perl
perl-fix:
	@export perl=`which perl`;				 \
	if [ "$$perl" ] && [ "$$perl" != "/usr/bin/perl" ]; then \
	    echo "Fixing Perl location to #!$$perl";		 \
	    perl -pe 's/!.*perl/!$$ENV{perl}/ if $$. == 1'	 \
		$(SRCS) > $(SRCS).tmp &&			 \
	    if [ -s $(SRCS).tmp ] ; then			 \
		mv $(SRCS).tmp $(SRCS);				 \
	    fi							 \
	fi

# ######################################################### &release ###

#   Check that program does not have compilation errors
release-check:
	perl -cw $(SRCS_PL)

# these two are Synonyms
release: kit

# Rule: kit - [maintenance] Make a World and Cygwin kits
kit: release-check release-world release-cygwin

# End of file
