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
#	General Public License for more details at
#	<http://www.gnu.org/copyleft/gpl.html>.

install-doc:
	# Rule install-doc - install documentation
	$(INSTALL_BIN) -d $(DOCDIR)
	$(INSTALL_DATA) $(INSTALL_DOC_OBJS) $(DOCDIR)
	(cd doc && $(TAR) $(TAR_OPT_NO) --create --file=- . ) | \
	(cd $(DOCDIR) && $(TAR) --extract --file=- )

install-man1:
	# Rule install-man1 - install manual page
	$(INSTALL_BIN) -d $(MANDIR1)
	$(INSTALL_BIN) $(INSTALL_MAN1_OBJS) $(MANDIR1)

# Compiled programs need strip "-s" option during install
# Install without filename extention
install-script-bin:
	# Rule install-script-bin - install scripts
	$(INSTALL_BIN) -d $(BINDIR)
	for f in $(INSTALL_BIN_S_OBJS); \
	do \
		dest=$$(basename $$f | sed -e 's/.pl//' -e 's/.py//' ); \
		$(INSTALL_BIN) $$f $(BINDIR)/$$dest; \
	done

# Rule install-test - for Maintainer only
install-test:
	rm -rf tmp
	make DESTDIR=`pwd`/tmp prefix=/. install

.PHONY: install-test

# End of file
