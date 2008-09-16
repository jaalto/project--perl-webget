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
#
#   Description
#
#	Make targets to update files to a remote location.

SOURCEFORGE_UPLOAD_HOST = upload.sourceforge.net
SOURCEFORGE_UPLOAD_DIR	= /incoming

SOURCEFORGE_DIR	    = /home/groups/p/pe/perl-webget
SOURCEFORGE_SHELL   = shell.sourceforge.net
SOURCEFORGE_USER    = $(USER)
SOURCEFORGE_SSH_DIR = \
  $(SOURCEFORGE_USER)@$(SOURCEFORGE_SHELL):$(SOURCEFORGE_DIR)

SF_DOC_DIR	    = doc/html
SF_DOC_OBJS	    = `ls $(SF_DOC_DIR)/*.html`

CYGETC_DIR	    = etc/cygwin
CYGETC_UPLOAD_DIR   = $(SOURCEFORGE_SSH_DIR)

# ######################################################### &targets ###

sf-upload-no-root:
	@if [ $(SOURCEFORGE_USER) = "root" ]; then		    \
	    echo "'root' cannot upload files. ";		    \
	    echo "Please call with 'make USER=<sfuser> <target>";   \
	    return 1;						    \
	fi

# Rule: sf-upload-doc - [Maintenence] Sourceforge; Upload documentation
sf-upload-doc: doc sf-upload-no-root
	scp $(SF_DOC_OBJS) $(SOURCEFORGE_SSH_DIR)/htdocs/

sf-upload-release-check:
	@[ -f $(RELEASE_FILE_PATH) ]

# Rule: sf-upload-doc - [Maintenence] Sourceforge; Upload setup.ini
sf-upload-cyg-setup-ini: sf-uload-no-root
	scp $(CYGETC_DIR)/setup.ini $(CYGETC_UPLOAD_DIR)

# Rule: sf-upload-release - [Maintenence] Sourceforge; Upload documentation
sf-upload-release: sf-upload-release-check
	@echo "-- run command --"
	@echo $(FTP)			    \
		$(SOURCEFORGE_UPLOAD_HOST)  \
		$(SOURCEFORGE_UPLOAD_DIR)   \
		$(TAR_FILE_WORLD_LS)

# End of file
