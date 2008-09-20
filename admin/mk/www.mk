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

# Rule: www - copy web pages to $(WWWROOT)/<basename PWD>-www
# Rule: www - All *.html file from doc/ are copied.
www:
	name=$$(basename $$(pwd)); \
	to=$(WWWROOT)/$$name-www; \
	echo "Copying to $$to"; \
	cd doc && find . -type f -name "*.html" | \
	rsync $${test:+"--dry-run"} \
	  --files-from=- \
	  --update \
	  --progress \
	  --verbose \
	  -r \
	  . \
	  $$to/

.PHONY: www

# End of file
