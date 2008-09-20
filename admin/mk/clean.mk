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

distclean: clean
	rm -rf .build .sinst .inst tmp

clean:
	-find . -type f \
		-name "*[~#]" \
		-o -name ".[~#]*" \
		-o -name " *.tmp" | \
	xargs -n rm

# End of file
