#!/usr/bin/make -f
#
#	Copyright (C) 1997-2009 Jari Aalto
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

VERSION		= $$(date '+%Y.%m%d')
BUILDDIR	= .build
PACKAGEVER	= $(PACKAGE)-$(VERSION)
RELEASEDIR	= $(BUILDDIR)/$(PACKAGEVER)
RELEASE_FILE	= $(PACKAGEVER).tar.gz
RELEASE_FILE_PATH = $(BUILDDIR)/$(RELEASE_FILE)

# Rule: release-world - [maintenance] Make a world release
dist: manifest-make
	$(INSTALL_BIN) -d $(RELEASEDIR)
	rm -rf $(RELEASEDIR)/*
	$(TAR) $(TAR_OPT_NO) --create --gzip --file=- . | \
	   ( cd $(RELEASEDIR) && $(TAR) --gzip --extract --file=- )
	cd $(BUILDDIR) &&						  \
	   $(TAR) $(TAR_OPT_WORLD) --create --gzip --file=$(RELEASE_FILE) \
	   $(PACKAGEVER)
	@$(TAR) -ztvf $(RELEASE_FILE_PATH) | sort -k 6
	@echo $(RELEASE_FILE_PATH)

.PHONY: dist

# End of file
