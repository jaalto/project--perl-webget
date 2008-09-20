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

# Rule: manifest: Make list of files in this project into file MANIFEST
# Rule: manifest: files matching regexps in MANIFEST.SKIP are skipped.
manifest:
	rm -f MANIFEST
	LC_ALL=C $(PERL) -MExtUtils::Manifest=mkmanifest -e 'mkmanifest()'

# Rule: manifest-check: checks if MANIFEST files really do exist.
manifest-check:
	LC_ALL=C $(PERL) -MExtUtils::Manifest=manicheck -e \
	     'exit 1 if manicheck()';

.PHONY: manifest manifest-check

# End of file
