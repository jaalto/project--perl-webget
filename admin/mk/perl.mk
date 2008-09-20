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
#	Visit <http://www.gnu.org/copyleft/gpl.html>.

# Rule: perl-fix - Change 1st line in *.pl file to match system perl
perl-shebang-fix:
	@export perl=`which perl`;				 \
	if [ "$$perl" ] && [ "$$perl" != "/usr/bin/perl" ]; then \
	    echo "Fixing Perl location to #!$$perl";		 \
	    perl -pe 's/!.*perl/!$$ENV{perl}/ if $$. == 1'	 \
		$(SRC) > $(SRC).tmp &&				 \
	    if [ -s $(SRC).tmp ] ; then				 \
		mv $(SRC).tmp $(SRC);				 \
	    fi							 \
	fi

# Rule perl-test: Test PL_SCRIPT for compile errors
perl-test:
	perl -cw $(PL_SCRIPT)

.PHONY: perl-fix perl-test

# End of file
