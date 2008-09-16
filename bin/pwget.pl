#!/usr/bin/perl
# -*- mode: perl; -*-
#
#  pwget -- batch download files possibly with configuration file
#
#  File id
#
#       Copyright (C) 1996-2009 Jari Aalto
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
#	along with program; see the file COPYING. If not
#	visit <http://www.gnu.org/copyleft/gpl.html>
#
#   Introduction
#
#       Please start this perl script with options
#
#           --help      to get the help page
#
#   Description
#
#       If you retrieve latest versions of certain program blocks
#       periodically, this is the Perl script for you. Run from cron job
#       or once a week to upload newest versions of files around the net.
#
#       _Note:_ This is simple file by file copier and does not offer
#       any date comparing or recursive features like found from C-program
#       wget(1).

use strict;
use 5.004;

#       A U T O L O A D
#
#       The => operator quotes only words, and File::Basename is not
#       Perl "word"

use autouse 'Carp'          => qw( croak carp cluck confess );
use autouse 'Text::Tabs'    => qw( expand                   );
use autouse 'Pod::Text'     => qw( pod2text                 );
use autouse 'Pod::Html'     => qw( pod2html                 );
use autouse 'File::Copy'    => qw( copy move                );
use autouse 'File::Path'    => qw( mkpath rmtree            );

#   Standard perl modules

use Cwd;
use Env;
use English;
use File::Basename;
use Getopt::Long;

IMPORT:
{
    use Env;
    use vars qw
    (
        $PATH
        $HOME
        $TEMP
        $TEMPDIR
        $SHELL
    );
}

#   Modules from CPAN

use LWP::UserAgent;
use Net::FTP;

    use vars qw ( $VERSION );

    #   This is for use of Makefile.PL and ExtUtils::MakeMaker
    #   So that it puts the tardist number in format YYYY.MMDD
    #   The REAL version number is defined later

    #   The following variable is updated by developer's Emacs setup
    #   whenever this file is saved

    $VERSION = '2008.0916.1138';

# ****************************************************************************
#
#   DESCRIPTION
#
#       Set global variables for the program
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Initialize ()
{
    use vars qw
    (
        $PROGNAME
        $LIB
        $CONTACT
        $URL
        $WIN32
        $CYGWIN_PERL
    );

    $LIB        = basename $PROGRAM_NAME;
    $PROGNAME   = $LIB;

    $CONTACT     = "";
    $URL         = "http://freshmeat.net/projects/perl-webget";

    $WIN32    = 1   if  $OSNAME =~ /win32/i;

    if ( $OSNAME =~ /cygwin/i )
    {
        # We need to know if this perl is Cygwin native perl?

        use vars qw( %Config );
        eval "use Config";

        $EVAL_ERROR  and die "$EVAL_ERROR";

        if (  $main::Config{osname} =~ /cygwin/i )
        {
            $CYGWIN_PERL = 1;
        }
    }

    $OUTPUT_AUTOFLUSH = 1;

    #   This variable holds the current tag line being used.

    use vars qw( $CURRENT_TAG_LINE );
}

# ***************************************************************** &help ****
#
#   DESCRIPTION
#
#       Print help and exit.
#
#   INPUT PARAMETERS
#
#       $msg    [optional] Reason why function was called.
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

=pod

=head1 NAME

pwget - Perl Web URL fetch program

=head1 SYNOPSIS

    pwget http://example.com/ [URL ...]
    pwget --config $HOME/config/pwget.conf --Tag linux --Tag emacs ..
    pwget --verbose --overwrite http://example.com/
    pwget --verbose --overwrite --Output ~/dir/ http://example.com/
    pwget --new --overwrite http://example.com/kit-1.1.tar.gz

=head1 OPTIONS

=head2 General options

=over 4

=item B<-C|--Create-paths>

Create paths that do not exist in C<lcd:> directives.

By default, any LCD directive to non-existing directory will interrupt
program. With this option, local directories are created as needed making
it possible to re-create the exact structure as it is in configuration
file.

=item B<--config FILE>

This option can be given multiple times. All configurations are read.

Read URLs from configuration file. If no configuration file is given, file
pointed by environment variable is read. See ENVIRONMENT.

The configuration file layout is envlained in section CONFIGURATION FILE

=item B<--chdir DIRECTORY>

Do a chdir() to DIRECTORY before any URL download starts. This is
like doing:

    cd DIRECTORY
    pwget http://example.com/index.html

=item B<--extract -e>

Unpack any files after retrieving them. The command to unpack typical
archive files are defined in a program. Make sure these programs are
along path. Win32 users are encouraged to install the Cygwin utilities
where these programs come standard. Refer to section SEE ALSO.

  .tar => tar
  .tgz => tar + gzip
  .gz  => gzip
  .bz2 => bzip2
  .zip => unzip

=item B<-F|--Firewall FIREWALL>

Use FIREWALL when accessing files via ftp:// protocol.

=item B<-m|--mirror SITE>

If URL points to Sourcefoge download area, use mirror SITE for downloading.
Alternatively the full full URL can include the mirror information. And
example:

    --mirror kent ... http://prdownloads.sourceforge.net/foo/foo-1.0.0.tar.gz

=item B<-n|--new>

Get newest file. This applies to datafiles, which do not have extension
.asp or .html. When new releases are announced, the version
number in filename usually tells which is the current one so getting
harcoded file with:

    pwget -o -v http://example.com/dir/program-1.3.tar.gz

is not usually practical from automation point of view. Adding
B<--new> option to the command line causes double pass: a) the whole
http://example.com/dir/ is examined for all files and b) files
matching approximately filename program-1.3.tar.gz are examined,
heuristically sorted and file with latest version number is retrieved.

=item B<--no-lcd>

Ignore C<lcd:> directives in configuration file.

In the configuration file, any C<lcd:> directives are obeyed as they
are seen. But if you do want to retrieve URL to your current
directory, be sure to supply this option. Otherwise the file will end
to the directory pointer by C<lcd:>.

=item B<--no-save>

Ignore C<save:> directives in configuration file. If the URLs have
C<save:> options, they are ignored during fetch. You usually want to
combine B<--no-lcd> with B<--no-save>

=item B<--no-extract>

Ignore C<x:> directives in configuration file.

=item B<-O|--Output DIR>

Before retrieving any files, chdir to DIR.

=item B<-o|--overwrite>

Allow overwriting existing files when retrieving URLs.
Combine this with B<--skip-version> if you periodically update files.

=item B<--Proxy PROXY>

Use PROXY server for HTTP. (See B<--Firewall> for FTP.). The port number is
optional in the call:

    --Proxy example.com.proxy.com
    --Proxy http://example.com.proxy.com
    --Proxy example.com.proxy.com:8080
    --Proxy example.com.proxy.com:8080/

=item B<-p|--prefix PREFIX>

Add PREFIX to all retrieved files.

=item B<-P|--Postfix POSTFIX >

Add POSTFIX to all retrieved files.

=item B<-D|--prefix-date>

Add iso8601 ":YYYY-MM-DD" prefix to all retrived files.
This is added before possible B<--prefix-www> or B<--prefix>.

=item B<-W|--prefix-www>

Usually the files are stored with the same name as in the URL dir, but
if you retrieve files that have identical names you can store each
page separately so that the file name is prefixed by the site name.

    http://example.com/page.html    --> example.com::page.html
    http://example2.com/page.html   --> example2.com::page.html

=item B<-r|--regexp REGEXP>

Retrieve URLs matching REGEXP from configuration file. This cancels
B<--Tag> options in the command line.

=item B<-R|--Regexp REGEXP>

Retrieve file matching at the destination URL site. This is like "Connect
to the URL and get all files matching REGEXP". Here all gzip compressed
files are found form HTTP server directory:

    pwget -v -R "\.gz" http://example.com/archive/

=item B<-A|--Regexp-content REGEXP>

Analyze the content of the file and match REGEXP. Only if the regexp
matches the file content, then download file. This option will make
downloads slow, because the file is read into memory as a single line
and then a match is searched against the content.

For example to download Emacs lisp file (.el) written by Mr. Foo in
case insesiteve manner:

    pwget -v -R '\.el$' -A "(?i)Author: Mr. Foo" \
      http://www.emacswiki.org/elisp/index.html

=item B<--stdout>

Retrieve URL and write to stdout.

=item B<--skip-version>

Do not download files that have version number and which already exists on
disk. Suppose you have these files and you use option B<--skip-version>:

    kit.tar.gz
    file-1.1.tar.gz

Only file.txt is retrieved, because file-1.1.tar.gz contains version number
and the file has not changed since last retrieval. The idea is, that in
every release the number in in distribution increases, but there may be
distributions which do not contain version number. In regular intervals
you may want to load those kits again, but skip versioned files. In short:
This option does not make much sense without additional option B<--new>

If you want to reload versioned file again, add option B<--overwrite>.

=item B<-T|--Tag NAME [NAME] ...>

Search tag NAME from the config file and download only entries defined
under that tag. Refer to B<--config FILE> option description. You can give
Multiple B<--Tag> switches. Combining this option with B<--regexp>
does not make sense and the concequencies are undefined.

=back

=head2 Miscellaneous options

=over 4

=item B<-d|--debug [LEVEL]>

Turn on debug with positive LEVEL number. Zero means no debug.
This option turns on B<--verbose> too.

=item B<-h|--help>

Print help page in text.

=item B<--help-html>

Print help page in HTML.

=item B<--help-man>

Print help page in Unix manual page format. You want to feed this output to
c<nroff -man> in order to read it.

Print help page.

=item B<-s|--selftest>

Run some internal tests. For maintainer or developer only.

=item B<-t|--test>

Run in test mode.

=item B<-v|--verbose [NUMBER]>

Print verbose messages.

=item B<-V|--Version>

Print version information.

=back

=head1 README

Automate periodic downloads of files and packages.

=head2 Wget and this program

At this point you may wonder, where would you need this perl program when
wget(1) C-program has been the standard for ages. Well, 1) Perl is cross
platform and more easily extendable 2) You can record file download
criterias to configuration files and use perl regular epxressions to select
downloads 3) the program can anlyze web-pages and "search" for the download
only links as instructed 4) last but not least, it can track newest
packages whose name has changed since last downlaod. There is heuristics to
determine the newest file or package according to file name skeleton
defined in configuration.

This program does not replace pwget(1) because it does not offer as many
options as wget, like recursive downloads. Use wget for ad hoc downloads
and this utility for files that you monitor periodically.

=head2 Short introduction

This small utility makes it possible to keep a list of URLs in a
configuration file and periodically retrieve those pages or files with
simple commands. This utility is best suited for small batch jobs to
download e.g. most recent versions of software files. If you use an URL
that is already on disk, be sure to supply option B<--overwrite> to allow
overwriting existing files.

While you can run this program from command line to retrieve individual
files, program has been designed to use separate configuration file via
B<--config> option. In the configuration file you can control the
downloading with separate directives like C<save:> which tells to save the
file under different name. The simplest way to retreive the latest version
of a kit from FTP site is:

    pwget --new --overwite --verbose \
       http://www.example.com/kit-1.00.tar.gz

Do not worry about the filename "kit-1.00.tar.gz". The latest version, say,
kit-3.08.tar.gz will be retrieved. The option B<--new> instructs to find
newer version than the provided URL.

If the URL ends to slash, then directory list at the remote machine
is stored to file:

    !path!000root-file

The content of this file can be either index.html or the directory listing
depending on the used http or ftp protocol.

=head1 EXAMPLES

Get files from site:

    pwget http://www.example.com/dir/package.tar.gz ..

Get all mailing list archive files that match "gz":

    pwget -R gz  http://example.com/mailing-list/archive/download/

Read a directory and store it to filename YYYY-MM-DD::!dir!000root-file.

    pwget --prefix-date --overwrite --verbose http://www.example.com/dir/

To update newest version of the kit, but only if there is none at disk
already. The B<--new> option instructs to find newer packages and the
filename is only used as a skeleton for files to look for:

    pwget --overwrite --skip-version --new --verbose \
        ftp://ftp.example.com/dir/packet-1.23.tar.gz

To overwrite file and add a date prefix to the file name:

    pwget --prefix-date --overwrite --verbose \
       http://www.example.com/file.pl

    --> YYYY-MM-DD::file.pl

To add date and WWW site prefix to the filenames:

    pwget --prefix-date --prefix-www --overwrite --verbose \
       http://www.example.com/file.pl

    --> YYYY-MM-DD::www.example.com::file.pl

Get all updated files under default cnfiguration file's tag KITS:

    pwget --verbose --overwrite --skip-version --new --Tag kits
    pwget -v -o -s -n -T kits

Get files as they read in the configuration file to the current directory,
ignoring any C<lcd:> and C<save:> directives:

    pwget --config $HOME/config/pwget.conf /
        --no-lcd --no-save --overwrite --verbose \
        http://www.example.com/file.pl

To check configuration file, run the program with non-matching regexp and
it parses the file and checks the C<lcd:> directives on the way:

    pwget -v -r dummy-regexp

    -->

    pwget.DirectiveLcd: LCD [$EUSR/directory ...]
    is not a directory at /users/foo/bin/pwget line 889.


=head1 CONFIGURATION FILE

=head2 Comments

The configuration file is NOT Perl code. Comments start with hash character
(#).

=head2 Variables

At this point, variable expansions happen only in B<lcd:>. Do not try
to use them anywhere else, like in URLs.

Path variables for B<lcd:> are defined using following notation, spaces are
not allowed in VALUE part (no directory names with spaces). Varaible names
are case sensitive. Variables substitute environment variabales with the
same name. Environment variables are immediately available.


    VARIABLE = /home/my/dir         # define variable
    VARIABLE = $dir/some/file       # Use previously defined variable
    FTP      = $HOME/ftp            # Use environment variable

The right hand can refer to previously defined variables or existing
environment variables. Repeat, this is not Perl code although it may
look like one, but just an allowed syntax in the configuration file. Notice
that there is dollar to the right hand> when variable is referred, but no
dollar to the left hand side when variable is defined. Here is example
of a possible configuration file contant. The tags are hierarchically
ordered without a limit.

Warning: remember to use different variables names in separate
include files. All variables are global.

=head2 Include files

It is possible to include more configuration files with statement

    INCLUDE <path-to-file-name>

Variable expansions are possible in the file name. There is no limit how
many or how deep include structure is used. Every file is included only
once, so it is safe to to have multiple includes to the same file.
Every include is read, so put the most importat override includes last:

    INCLUDE <etc/pwget.conf>             # Global
    INCLUDE <$HOME/config/pwget.conf>    # HOME overrides it

A special C<THIS> tag means relative path of the current include file,
which makes it possible to include several files form the same
directory where a initial include file resides

    # Start of config at /etc/pwget.conf

    # THIS = /etc, current location
    include <THIS/pwget-others.conf>

    # Refers to directory where current user is: the pwd
    include <pwget-others.conf>

    # end

=head2 Configuraton file example

The configuration file can contain many <directoves:>, where
each directive end to a colon. The usage of each directory is best explained
by examining the configuration file below and reading the commentary
near each directive.

    #   $HOME/config/pwget.conf F- Perl pwget configuration file

    ROOT   = $HOME                      # define variables
    CONF   = $HOME/config
    UPDATE = $ROOT/updates
    DOWNL  = $ROOT/download

    #   Include more configuration files. It is possible to
    #   split a huge file in pieces and have "linux",
    #   "win32", "debian", "emacs" configurations in separate
    #   and manageable files.

    INCLUDE <$CONF/pwget-other.conf>
    INCLUDE <$CONF/pwget-more.conf>

    tag1: local-copies tag1: local      # multiple names to this category

        lcd:  $UPDATE                   # chdir directive

        #  This is show to user with option --verbose
        print: Notice, this site moved YYYY-MM-DD, update your bookmarks

        file://absolute/dir/file-1.23.tar.gz

    tag1: external

      lcd:  $DOWNL

      tag2: external-http

        http://www.example.com/page.html
        http://www.example.com/page.html save:/dir/dir/page.html

      tag2: external-ftp

        ftp://ftp.com/dir/file.txt.gz save:xx-file.txt.gz login:foo pass:passwd x:

        lcd: $HOME/download-kit

        ftp://ftp.com/dir/kit-1.1.tar.gz new:

      tag2: package-x

        lcd: $DOWNL/package-x

        #  Person announces new files in his homepage, download all
        #  announced files. Unpack everything (x:) and remove any
        #  existing directories (xopt:rm)

        http://example.com/~foo pregexp:\.tar\.gz$ x: xopt:rm

    # End of configuration file pwget.conf

=head1 LIST OF DIRECTIVES IN CONFIGURATION FILE

All the directives must in the same line where the URL is. The programs
scans lines and determines all options given in line for the URL.
Directives can be overriden by command line options.

=over 4

=item B<cnv:CONVERSION>

Currently only B<conv:text> is available.

Convert downloaded page to text. This option always needs either B<save:>
or B<rename:>, because only those directives change filename. Here is
an example:

    http://example.com/dir/file.html cnv:text save:file.txt
    http://example.com/dir/ pregexp:\.html cnv:text rename:s/html/txt/

A B<text:> shorthand directive can be used instead of B<cnv:text>.

=item B<cregexp:REGEXP>

Download file only if the content matches REGEXP. This is same as option
B<--Regexp-content>. In this example directory listing Emacs lisp packages
(.el) are downloaded but only if their content indicates that the Author is
Mr. Foo:

    http://example.com/index.html cregexp:(?i)author:.*Foo pregexp:\.el$

=item B<lcd:DIRECTORY>

Set local download directory to DIRECTORY (chdir to it). Any environment
variables are substituted in path name. If this tag is found, it replaces
setting of B<--Output>. If path is not a directory, terminate with error.
See also B<--Create-paths> and B<--no-lcd>.

=item B<login:LOGIN-NAME>

Ftp login name. Default value is "anonymous".

=item B<mirror:SITE>

This is relevant to sourceforge, which does not allow direct downloads with
links like http://prdownloads.sourceforge.net/foo/foo-1.0.0.tar.gz Visit
the page and selct the announced mirror that can be seen from the URL
which includes string "use_mirror=site"

An example:

  http://prdownloads.sourceforge.net/foo/foo-1.0.0.tar.gz new: mirror:kent

=item B<new:>

Get newest file. This variable is reset to the value of B<--new> after the
line has been processed. Newest means, that an ls() command is run in the
ftp, and something equivalent in HTTP "ftp directories", and any files that
resemble the filename is examined, sorted and heurestically determined
according to version number of file which one is the latest. For example
files that have version information in YYYYMMDD format will most likely to
be retrieved right.

Time stamps of the files are not checked.

The only requirement is that filename C<must> follow the universal version
numbering standard for released kits:

    FILE-VERSION.extension      # de facto VERSION is defined as [\d.]+

    file-19990101.tar.gz        # ok
    file-1999.0101.tar.gz       # ok
    file-1.2.3.5.tar.gz         # ok

    file1234.txt                # not recognized. Must have "-"
    file-0.23d.tar.gz           # warning ! No letters allowed 0.23d

Files that have some alphabetic version indicator at the end of VERSION
are not handled correctly. Bitch the developer and persuade him to stick
to the de facto standard so that files can be retrieved intelligently.

=item B<overwrite:> B<o:>

Same as turning on B<--overwrite>

=item B<page:>

Download the HTTP page or apply command to it. A simple example, the
contact page name "index.html", "welcome.html" etc. is not known:

   http://example.com/~foo page: save:foo-homepage.html

C<More about> B<page:> C<directive and downloading difficult packages>

B<REMEMBER: All the regular epxression used in the configuration file have
a limitation of keeping together. This means that there must be no space
characters in the regular expressions, because it will terminate reading
the item.> Like if you write

    pregexp:(this regexp )

It must be written:

    pregexp:(this\s+regexp\s)

Read the HTTP url page "as is" and parse page content. You need this
directive if the archive is not stored in HTTP server directory (similar
to ftp dir), but the maintainer has set up a separate HTML page where the
details how to get archive is explained.

In order to find the information from the page, you must also supply
some other directives to guide searching and constructing
the correct file name:

1) A page regexp directive C<pregexp:ARCHIVE-REGEXP> matches the A HREF
filename location in the page.

2) Directive C<file:DOWNLOAD-FILE> tells what is the template to use to
construct the downloadable file (for the C<new:> directive).

3) Directive C<vregexp:VERSION-REGEXP> matches the exact location
in the page from where the version information is extracted. The default
regexp looks for line that says "The latest version ...is.. 1.4.2". The
regexp must return submatch 2 for the version number.

To put all together, an example shows more this in action. The following
example should all be PUT ON ONE LINE, while it has been splitted to
separate lines for legibility. The presented configuration line is
explaind in next paragraphs.

Contact absolute B<page:> at http://www.example.com/package.html and
search A HREF urls in the page that match B<pregexp:>. In addition, do
another scan and search the version number in the page from thw
position that match B<vregexp:> (submatch 2).


After all the pieces have been found, use template B<file:> to
make the retrievable file using the version number found from
B<vregexp:>. The actual download location is combination of
B<page:> and A HREF B<pregexp:> location. Here is the whole "one line"
definition in the configuration file:


    http://www.example.com/~foo/package.html
    page:
    pregexp: package.tar.gz
    vregexp: ((?i)latest.*?version.*?\b([\d][\d.]+).*)
    file: package-1.3.tar.gz
    new:
    x:

Still not clear? Look at this complete HTML page where the above directives
apply:

    <HTML>
    <BODY>

    The latest version of package is <B>2.4.1</B> It can be
    downloaded in several forms:

        <A HREF="download/files/package.tar.gz">Tar file</A>
        <A HREF="download/files/package.zip">ZIP file

    </BODY>
    </HTML>

For this example it is assumed that package.tar.gz is actually a symbolic
link to the latest standard release file package-2.4.1.tar.gz. From this
page the actual download location would have been
http://www.example.com/~foo/download/files/package-2.4.1.tar.gz So why not
simply download package.tar.gz? Because then the program can't decide if
the version at the page is newer than one stored on disk from the previous
download. With version numbers in the file names, it can.

ANOTHER EXAMPLE

It is possible to add B<rename:> directive to change the final name
of the saved file to the above cases. Sometimes people put version number
to "plain" files, that are not archives, like

    file.el-1.1
    file.el-1.2

the .el files are Emacs editor packages files and it would be very
inconvenient for Emacs users to refer to those with any other name than
plain "file.el". To write a complete line to find such files from
a page and save them in plain name, see below. Lines have been broken
for legibility:

    http://example.com/files/
    page:
    pregexp:\.el-\d
    vregexp:(file.el-([\d.]+))
    file:file.el-1.1
    new:
    rename:s/-[\d.]+//

It effectively says "See if there is new version of something that
looks like file.el-1.1 and save it under name file.el by deleting the extra
version number at the end of original filename".

=item B<page:find>

THIS IS NOT FOR FTP directories. Use directive B<regexp:> for FTP.

This is more general instruction than the B<page:> and B<vregexp:>
explained above.

Instruct to download every URL on HTML page matching B<pregexp:RE>. In
typical situation the page maintainer lists his software in the development
page. This example would download every tar.gz file mentined in a page.
Note, that the REGEXP is matched against the A HREF link content, not
the actual text that you see on the page:

    http://www.example.com/index.html page:find pregexp:\.tar.gz$

You can also use additional B<regexp-no:> directive if you want to exclude
files after the B<pregexp:> has matched a link.

    http://www.example.com/index.html page:find pregexp:\.tar.gz$ regexp-no:this-packet

=item B<pass:PASSWORD>

For FTP logins. Default value is C<nobody@example.com>.

=item B<print:MESSAGE>

Print associated message to user requesting matching tag name.
This directive must in separate line inside tag.

    tag1: linux

      print: this download site moved 2002-02-02, check your bookmarks.
      http://new.site.com/dir/file-1.1.tar.gz new:

The C<print:> directive for tag is shown only if user turns on --verbose
mode:

    pwget -v -T linux

=item B<rename:PERL-CODE>

Rename each file using PERL-CODE. The PERL-CODE must be full perl program
with no spaces anywhere. Following variables are available during the
eval() of code:

    $ARG = current file name
    $url = complete url for the file
    The code must return $ARG which is used for file name

For example, if page contains links to .html files that are in fact
text files, following statement would chnage the file extensions:

    http://example.com/dir/ page:find pregexp:\.html rename:s/html/txt/

You can also call function C<MonthToNumber($string)> if the filename
contains written month name, like <2005-February.mbox>.The function will
convert the name into number. Many mailing list archives can be donwloaded
cleanly this way.

    #  This will download SA-Exim Mailing list archives:
    http://lists.merlins.org/archives/sa-exim/ pregexp:\.txt$ rename:$ARG=MonthToNumber($ARG)

Here is a more complicated example:

    http://www.contactor.se/~dast/svnusers/mbox.cgi pregexp:mbox.*\d$ rename:my($y,$m)=($url=~/year=(\d+).*month=(\d+)/);$ARG="$y-$m.mbox"

Let's break that one apart. You may spend some time with this example since
the possiblilities are limitless.

    1. Connect to page http://www.contactor.se/~dast/svnusers/mbox.cgi
    2. Search page for URLs matching regexp 'mbox.*\d$'. A found link would
       could be
       http://svn.haxx.se/users/mbox.cgi?year=2004&month=12
    3. The found link is put to $ARG, which can be used to extract suitable
       mailbox name with perl code that is evaluated. The resulting name must
       apear in $ARG. Thus the code effectively extract two items from the
       link to form a mailbox name:

        my ($y, $m) = ( $url =~ /year=(\d+).*month=(\d+)/ )
        $ARG = "$y-$m.mbox"

        => 2004-12.mbox

Just remember, that there B<must> not be any spaces in the code that
follows C<rename:> directive.

=item B<regexp:REGEXP>

Get all files in ftp directory matching regexp. Directive B<save:> is ignored.

=item B<regexp-no:REGEXP>

After the regexp: directive has matched, explude files that match
directive B<regexp-no:>

=item B<Regexp:REGEXP>

This option is for interactive use. Retrieve all files from HTTP or FTP
site which match REGEXP.

=item B<save:LOCAL-FILE-NAME>

Save file under this name to local disk.

=item B<tagN:NAME>

Downloads can be grouped under C<tagN> so that e.g. option B<--Tag1> would
start downloading files from that point on until next C<tag1> is found.
There are currently unlimited number of tag levels: tag1, tag2 and tag3, so
that you can arrange your downlods hierarchially in the configuration file.
For example to download all Linux files rhat you monitor, you would give
option B<--Tag linux>. To download only the NT Emacs latest binary, you
would give option B<--Tag emacs-nt>. Notice that you do not give the
C<level> in the option, program will find it out from the configuration
file after the tag name matches.

The downloading stops at next tag of the C<same level>. That is, tag2 stops
only at next tag2, or when upper level tag is found (tag1) or or until end of
file.

    tag1: linux             # All Linux downlods under this category

        tag2: sunsite    tag2: another-name-for-this-spot

        #   List of files to download from here

        tag2: ftp.funet.fi

        #   List of files to download from here

    tag1: emacs-binary

        tag2: emacs-nt

        tag2: xemacs-nt

        tag2: emacs

        tag2: xemacs

=item B<x:>

Extract (unpack) file after download. See also option B<--unpack> and
B<--no-extract> The archive file, say .tar.gz will be extracted the file in
current download location. (see directive B<lcd:>)

The unpack procedure checks the contents of the archive to see if
the package is correctly formed. The de facto archive format is

    package-N.NN.tar.gz

In the archive, all files are supposed to be stored under the proper
subdirectory with version information:

    package-N.NN/doc/README
    package-N.NN/doc/INSTALL
    package-N.NN/src/Makefile
    package-N.NN/src/some-code.java

C<IMPORTANT:> If the archive does not have a subdirectory for all files, a
subdirectory is created and all items are unpacked under it. The defualt
subdirectory name in constructed from the archive name with currect date
stamp in format:

    package-YYYY.MMDD

If the archive name contains something that looks like a version number,
the created directory will be constructed from it, instead of current date.

    package-1.43.tar.gz    =>  package-1.43

=item B<xx:>

Like directive B<x:> but extract the archive C<as is>, without
checking content of the archive. If you know that it is ok for the archive
not to include any subdirectories, use this option to suppress creation
of an artificial root package-YYYY.MMDD.

=item B<xopt:rm>

This options tells to remove any previous unpack directory.

Sometimes the files in the archive are all read-only and unpacking the
archive second time, after some period of time, would display

    tar: package-3.9.5/.cvsignore: Could not create file: Permission denied
    tar: package-3.9.5/BUGS: Could not create file: Permission denied

This is not a serious error, because the archive was already on disk and
tar did not overwrite previous files. It might be good to inform the
archive maintainer, that the files have wrong permissions. It is customary
to expect that distributed kits have writable flag set for all files.

=back

=head1 ERRORS

Here is list of possible error messages and how to deal with them.
Turning on  B<--debug> will help to understand how program has
interpreted the configuration file or command line options. Pay close
attention to the generated output, because it may reveal that
a regexp for a site is too lose or too tight.

=over 4

=item B<ERROR {URL-HERE} Bad file descriptor>

This is "file not found error". You have written the filename incorrectly.
Double check the configuration file's line.

=back

=head1 ENVIRONMENT

Variable C<PWGET_PL_CFG> can point to the root configuration file in
which you can use B<include> directives to read more configuration files.
The configuration file is read at startup if it exists.

    export PWGET_PL_CFG=$HOME/conf/pwget.conf     # /bin/hash syntax
    setenv PWGET_PL_CFG $HOME/conf/pwget.conf     # /bin/csh syntax

=head1 SEE ALSO

C program wget(1) http://www.ccp14.ac.uk/mirror/wget.htm and
from the the Libwww Perl library you find scripts
lwp-download(1) lwp-mirror(1) lwp-request(1) lwp-rget(1)

Win32 Cygwin unix utilities at http://www.cygwin.com/

=head1 AVAILABILITY

Latest version of this file is at Project homepage at
http://freshmeat.net/projects/perl-webget

=head1 SCRIPT CATEGORIES

CPAN/Administrative
CPAN/Web

=head1 PREREQUISITES

C<LWP::UserAgent>
C<Net::FTP>

=head1 COREQUISITES

C<HTML::Parse>
C<HTML::TextFormat>
C<HTML::FormatText>

These modules are dynamically loaded only if directive B<cnv:text>
is used. Otherwise these modules are not loaded.

C<Crypt::SSLeay>
This module is loaded only if HTTPS scheme is encountered.

=head1 OSNAMES

C<any>

=head1 VERSION

$VERSION

=head1 AUTHOR

Copyright (C) 1996-2009 Jari Aalto. This program is free software; you
can redistribute it and/or modify it under the same terms of Gnu
General Public License v2 or any later version.

=cut

sub Help (;$ $)
{
    my $id   = "$LIB.Help";
    my $msg  = shift;  # optional arg, why are we here...
    my $type = shift;  # optional arg, type

    if ( $type eq -html )
    {
        pod2html $PROGRAM_NAME;
    }
    elsif ( $type eq -man )
    {
        eval "use Pod::Man";
        $EVAL_ERROR  and  die "$id: Cannot generate Man $EVAL_ERROR";

        # Other option: name, section, release
        #
        my %options;
        $options{center} = 'Perl pwget URL fetch utility';

        my $parser = Pod::Man->new(%options);
        $parser->parse_from_file ($PROGRAM_NAME);
    }
    else
    {
        pod2text $PROGRAM_NAME;
    }

    exit 0;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#
#
#   INPUT PARAMETERS
#
#       $path       Path name
#       $type       -win32      convert to win32 path.
#                   -cygwin     convert to cygwin path.
#
#   RETURN VALUES
#
#
#
# ****************************************************************************

sub PathConvert ($;$)
{
    my $id = "$LIB.PathConvertDosToCygwin";

    local $ARG  = shift;
    my    $type = shift;

    my $ret = $ARG;

    if ( /^([a-z]):(.*)/i  and  $type eq -cygwin )
    {
        my $dir  = $1;
        my $path = $2;

        $ret = "/cygdrive/\L$dir\E$path";

        $ret =~ s,\\,/,g;
    }

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Determine OS and convert path to correct Win32 environment.
#       Cygwin perl or to Win32 Activestate perl
#
#   INPUT PARAMETERS
#
#
#
#   RETURN VALUES
#
#
#
# ****************************************************************************

sub PathConvertSmart ($)
{
    my $id     = "$LIB.PathConvertSmart";
    my ($path) = @ARG;

    if ( $CYGWIN_PERL )
    {
        #   In win32, you could define environment variables as
        #   C:\something\like, but that's not understood under cygwin.

        $path = PathConvert $path, -cygwin;
    }

    $path;
}

# ************************************************************** &args *******
#
#   DESCRIPTION
#
#       Read and interpret command line arguments
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub HandleCommandLineArgs ()
{
    # ............................................... local variables ...

    my $id = "$LIB.HandleCommandLineArgs";

    # .......................................... command line options ...

    use vars qw
    (
        $CHECK_NEWEST

        $debug
        $DIR_DATE

        @CFG_FILE
        $CFG_FILE_NEEDED
        $FIREWALL

        $LCD_CREATE

        $MIRROR
        $NO_SAVE
        $NO_LCD
        $NO_EXTRACT

        $OVERWRITE
        $OUT_DIR

        $PREFIX
        $PREFIX_DATE
        $PREFIX_WWW

        $POSTFIX
        $PROXY
        $STDOUT

        $SKIP_VERSION

        $URL_REGEXP
        $EXTRACT
        $SITE_REGEXP
        $CONTENT_REGEXP

        $TAG_REGEXP
        @TAG_LIST
        $verb
        $test

        $PWGET_PL_CFG
    );

    $CFG_FILE_NEEDED = 0;
    $FIREWALL        = "";
    $OVERWRITE       = 0;
    $debug           = -1;

    # .................................................... read args ...

    Getopt::Long::config( qw
    (
        require_order
        no_ignore_case
        no_ignore_case_always
    ));

    my ( $version, $help, $helpHTML, $helpMan, $selfTest, $chdir );

    GetOptions      # Getopt::Long
    (
          "Version"         => \$version

        , "A|Regexp-content=s"  => \$CONTENT_REGEXP
        , "Create-paths"    => \$LCD_CREATE
        , "D|prefix-date"   => \$PREFIX_DATE
        , "Firewall=s"      => \$FIREWALL
        , "Output:s"        => \$OUT_DIR
        , "Postfix:s"       => \$POSTFIX
        , "Proxy=s"         => \$PROXY
        , "R|Regexp=s"      => \$SITE_REGEXP
        , "Tag=s"           => \@TAG_LIST
        , "W|prefix-www"    => \$PREFIX_WWW
        , "chdir=s"         => \$chdir
        , "config:s"        => \@CFG_FILE
        , "debug:i"         => \$debug
        , "extract"         => \$EXTRACT
        , "help-html"       => \$helpHTML
        , "help-man"        => \$helpMan
        , "h|help"          => \$help
        , "mirror=s"        => \$MIRROR
        , "no-extract"      => \$NO_EXTRACT
        , "no-lcd"          => \$NO_LCD
        , "no-save"         => \$NO_SAVE
        , "n|new"           => \$CHECK_NEWEST
        , "overwrite"       => \$OVERWRITE
        , "prefix:s"        => \$PREFIX
        , "regexp=s"        => \$URL_REGEXP
        , "selftest"        => \$selfTest
        , "skip-version"    => \$SKIP_VERSION
        , "stdout"          => \$STDOUT
        , "test"            => \$test
        , "verbose:i"       => \$verb

    );

    $debug = 1          if $debug == 0;
    $debug = 0          if $debug < 0;

    $verb = 1           if $verb == 0;
    $verb = 0           if $verb < 0;

    $verb = 5           if $debug;

    #   set verbose to 1, if debug is on. Set to full verbose if
    #   debug is higher than 2.

    $debug and $verb == 0  and $verb = 1;
    $debug > 2             and $verb = 10;

    $version    and die "$VERSION $PROGNAME $CONTACT $URL\n";
    $helpHTML   and Help( undef, -html );
    $helpMan    and Help( undef, -man );
    $help       and Help();

    $selfTest   and SelfTest();

    $NO_LCD     = 0   unless defined $NO_LCD;
    $NO_SAVE    = 0   unless defined $NO_SAVE;
    $NO_EXTRACT = 0   unless defined $NO_EXTRACT;

    if ( $chdir )
    {
        unless ( chdir $chdir )
        {
            die "$id: CHDIR [$chdir] fail. $ERRNO";
        }
    }

    if ( defined $URL_REGEXP  or  (defined @TAG_LIST and @TAG_LIST) )
    {
        $CFG_FILE_NEEDED = -yes;
    }

    if ( defined $URL_REGEXP  and  @TAG_LIST )
    {
        die "You can't use both --Tag and --regexp options.";
    }

    if ( defined $PROXY )
    {
        $ARG = $PROXY;

        if ( not m,^http://, )
        {
            $debug  and  print "$id: Adding http:// to proxy $PROXY\n";
            $ARG = "http://" . $ARG;
        }

        if ( not m,/$, )
        {
            $debug  and  print "$id: Adding trailing / to proxy $PROXY\n";
            $ARG .= "/";
        }

        $PROXY = $ARG;
        $debug  and  print "$id: PROXY $PROXY\n";
    }

    if ( defined @TAG_LIST )
    {
        #   -s -t -n tag   --> whoopos....


        if ( grep /^-/ , @TAG_LIST )
        {
            die "$id: You have option in TAG_LIST: @TAG_LIST\n";
        }

        $TAG_REGEXP = '\btag(\d+):\s*(\S+)';
    }

    if  (
            not @CFG_FILE
            and ( @TAG_LIST or $URL_REGEXP )
        )
    {

        unless ( defined $PWGET_PL_CFG )
        {
            die "$id: No environment variable PWGET_PL_CFG defined."
                , " Need --config"
                ;
        }

        my $file = PathConvertSmart $PWGET_PL_CFG;

        unless ( -r $file )
        {
            die "$id: PWGET_PL_CFG is not readable [$file]";
        }

        $verb  and  print "$id: Using default config file $file\n";

        push @CFG_FILE, $file;
    }

    $debug  and   @CFG_FILE  and  print "$id: Config file [@CFG_FILE]\n";

    # Do not remove this comment, it is for Emacs font-lock-mode
    # to handle hairy perl fontification right.
    #font-lock * s/*/
}
# ****************************************************************************
#
#   DESCRIPTION
#
#       Convert month names to numbers in string.
#
#   INPUT PARAMETERS
#
#       $str    Like "2005-February.txt"
#
#   RETURN VALUES
#
#       $       Like "2005-02.txt" is no changes.
#
# ****************************************************************************

sub MonthToNumber ($)
{
    local $ARG = shift;

    my %hash =
    (
        'Jan(uary)?'      => '01'
        , 'Feb(ruary)?'   => '02'
        , 'Mar(ch)?'      => '03'
        , 'Apr(il)?'      => '04'
        , 'May'           => '05'
        , 'Jun(e)?'       => '06'
        , 'Jul(y)?'       => '07'
        , 'Aug(ust)?'     => '08'
        , 'Oct(ober)?'    => '09'
        , 'Sep(tember)?'  => '10'
        , 'Nov(ember)?'   => '11'
        , 'Dec(ember)?'   => '12'
    );

    while ( my($re, $month) = each %hash )
    {
        s/$re/$month/i;
    }

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Find out the temporary directory
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       $       temporary directory
#
# ****************************************************************************

sub TempDir ()
{
    my $id         = "$LIB.TempDir";

    local $ARG;

    if ( defined $TEMPDIR  and  -d $TEMPDIR)
    {
        $ARG = $TEMPDIR;
    }
    elsif ( defined $TEMP  and  -d $TEMP)
    {
        $ARG = $TEMP;
    }
    elsif ( -d "/tmp" )
    {
        $ARG = "/tmp";
    }
    elsif ( -d "c:/temp" )
    {
        $ARG = "c:/temp"
    }
    elsif ( -d "$HOME/temp" )
    {
        $verb and
          print "$id: [WARNING] using HOME/tmp, make sure you have disk space";

        $ARG = "$HOME/temp";
    }
    else
    {
        die "$id:  Can't find temporary directory. Please set TEMPDIR."
    }

    if ( $ARG  and not -d  )
    {
        die "$id: Temporary directory found is invalid: [$ARG]";
    }

    s,[\\/]$,,;         # Delete trailing slash
    s,\\,/,g;           # Unix slashes in this Perl code

    $debug  and  print "$id: $ARG\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Remove duplicate entries from list. Empty values are removed too.
#
#   INPUT PARAMETERS
#
#       @list
#
#   RETURN VALUES
#
#       @list
#
# ****************************************************************************

sub ListRemoveDuplicates (@)
{
    my $id   = "$LIB.FilterDuplicates";
    my @list = @ARG;

    $debug  and  print "$id: [@list]\n";

    if ( @list )
    {
        my %hash;
        @hash{ @list }++;

        @list = grep /\S/, keys %hash;

    }

    @list;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return temporary process file
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       $       temporary filename
#
# ****************************************************************************

sub TempFile ()
{
    my $id  = "$LIB.TempFile";

    my $ret = TempDir() . basename($PROGRAM_NAME) . "-" . $PROCESS_ID;

    $debug  and  print "$id: $ret\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Write file to stdout
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Stdout ( $ )
{
    my $id    = "$LIB.Stdout";
    my($file) = @ARG;

    local *FILE;

    unless ( open FILE, "< $file" )
    {
        warn "$id: Can't STDOUT $file $ERRNO";
    }
    else
    {
        print <FILE>;
        close FILE;
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Fix the filename to correct OS version ( win32 /Cygwin / DOS )
#       This is needed when calling external programs that take file arguments.
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       $file   Converted file
#
# ****************************************************************************

sub MakeOSfile ( $ )
{
    my $id      = "$LIB.MakeOSfile";
    local($ARG) = @ARG;

    if ( $WIN32 )
    {
        if ( defined $SHELL  )
        {
            $debug  and  print "$id: SHELL = $SHELL\n";

            if ( $SHELL =~ /sh/i )  # bash.exe
            {
                #       This is Win32/Cygwin, which needs c:/  --> /cygdrive/c/

                if ( /^(.):(.*)/ )  #font s/
                {
                    $ARG = "/cygdrive/$1/$2";
                    s,\\,/,g;
                    s,//,/,g;
                }
            }
        }
        else
        {
            s,/,\\,g;           # Win32 likes backslashes more
        }
    }

    $debug  and  print "$id: $ARG\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return ISO 8601 date YYYY-MM-DD
#
#   INPUT PARAMETERS
#
#       $format     [optional] If "-version", return in format YYYY.MMDD
#
#   RETURN VALUES
#
#       $str        Date string
#
# ****************************************************************************

sub DateYYYY_MM_DD (; $)
{
    my $id       = "$LIB.DateYYYY_MM_DD";
    my ($format) = @ARG;


    my (@time)    = localtime(time);
    my $YY        = 1900 + $time[5];
    my ($DD, $MM) = @time[3,4];
#   my ($mm, $hh) = @time[1,2];

    $debug > 3 and  print "$id: @time\n";

    #   Month(MM) counts from zero

    my $ret;

    if ( defined $format  and  $format eq -version )
    {
        $ret = sprintf "%d.%02d%02d", $YY, $MM + 1, $DD;
    }
    else
    {
        $ret = sprintf "%d-%02d-%02d", $YY, $MM + 1, $DD;
    }

    $debug > 3  and  print "$id: RET $ret\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print variables in hash
#
#   INPUT PARAMETERS
#
#       $name       name of the hash
#       %hash       content of hash
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub PrintHash ( $ % )
{
    my $id             = "$LIB.PrintHash";
    my ($name, %hash ) = @ARG;

    print "$id: hash [$name] contents\n";

    for my $key ( sort keys %hash )
    {
        my $val = $hash{ $key };
        printf "%-20s = %s\n", $key, $val;
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Print download progress
#
#   INPUT PARAMETERS
#
#       $url        Site from where to download
#       $prefix     String to print
#       $index      current count
#       $total      total
#
#   RETURN VALUES
#
#       string      indicator message
#
# ****************************************************************************

{
    my %staticDone;

sub DownloadProgress ($$ $$ $)
{
    my $id  = "$LIB.DownloadProgress";
    my ( $site, $url, $prefix, $index, $total ) = @ARG;

    if ( $verb )
    {
        if ( $total > 1 )
        {
            sprintf $prefix .  " %3d%% (%2d/%d) "
                , int ( $index * 100 / $total )
                , $index
                , $total
                ;
        }
        else
        {
            unless ( exists $staticDone{$site}  )
            {
                $staticDone{$site} = 1;
                $prefix;
            }
        }
    }
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Expand variable by substituting any Environment variables in it.
#
#   INPUT PARAMETERS
#
#       $string     Path information, like $HOME/.example
#       $str        Original line; full string from configuration file.
#
#   RETURN VALUES
#
#       string      Expanded path.
#
# ****************************************************************************

sub ExpandVars ($; $)
{
    my $id         = "$LIB.ExpandVars";
    local $ARG     = shift;
    my   $origline = shift;

    $debug  > 2 and print "$id: input $ARG [$origline]\n";

    return $ARG    unless /\$[a-z]/i;   # nothing to do

    my $orig    = $ARG;

    #   We must substitute environment variables so that the
    #   longest are handled first. An example of the problem using
    #   variable: $FTP_DIR_THIS/here.
    #
    #       FTP_DIR      = one
    #       FTP_DIR_THIS = two
    #
    #       --> one_THIS/here

    my @keys = sort { length $b <=> length $a } keys %ENV;
    my $value;

    for my $key ( @keys )
    {
        next unless $key =~ /[a-z]/i;                 # ignore odd "__" env vars

        $value = $ENV{$key};

        if ( /$key/  and  $value ne "" )              #font s/
        {
            $debug  > 2 and print  "$id $ARG substituting key $key => $value\n";

            s/\$$key/$value/;                         #font s/;
        }
    }

    #   The env variables may contain leading slashes, get rid of them.
    #   Or there may be "doubles"; fix them.
    #
    #   [$ENV = /dir/ ]
    #   $ENV/path   --> /dir//path
    #

    s,//+,/,   unless /(http|ftp):/i;

    $debug  > 2 and print "$id: after loop $orig ==> $ARG\n";

    if ( /\$/ )
    {
        # PrintHash "ENV", %ENV;
        die "$id: [ERROR]. Check environment. Expansion did not "
          , "find variable(s): $orig\n";
    }

    #   Convert to Unix paths

    s,\\,/,g;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Evaluate perl code and return result.
#
#   INPUT PARAMETERS
#
#       $url        text to put variable $url
#       $text       The text to be placed to variable $ARG
#       $code       Perl code to manipulate $ARG
#       $flag       non-empty: Do not return empty values, if the perl
#                   code didn]t set ARG at all, then return original TEXT
#
#   RETURN VALUES
#
#       $text
#
# ****************************************************************************

sub EvalCode ($ $ ; $)
{
    my $id = "$LIB.EvalCode";
    my ($url, $text, $code, $flag ) = @ARG;
    my $ret = $text;

    #   Variable $url is seen to CODE if it wants to use it

    $debug  and  print "$id: ARG $ARG EVAL $code\n";

    return $ret unless $code;

    #  Wrap this inside private block, so that user defined
    #  $code can execute in safe environment. E.g he can
    #  define his own variables and they willnot affect the program
    #  afterwards.

    {
        local $ARG  = $text;
        eval $code;

        if ( $EVAL_ERROR )
        {
            warn "$id: eval-fail ARG [$ARG] CODE [$code] $EVAL_ERROR";
            $ARG = $text;
        }

        if ( not $ARG  and $flag )
        {
            $debug  and  print "$id: ARG [$ARG] is empty [$code]\n";
            $ARG = $text;
        }
        elsif ( $ARG )
        {
            $ret = $ARG;
        }
    }

    $debug   and print "$id: RET $ret\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if HTML::Parse and HTML::FormatText libraries are available
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       0       Error
#       1       Ok, support present
#
# ****************************************************************************

sub IsLibHTML ()
{
    my $id       = "$LIB.IsLibHTML";
    my $error    = 0;
    $EVAL_ERROR  = '';

    local *LoadLib = sub ($)
    {
        my $lib = shift;

        eval "use $lib";

        if ( $EVAL_ERROR )
        {
            warn "$id: $lib not available [$EVAL_ERROR]\n";
            $error++;
        }
    };

    LoadLib( "HTML::Parse");
    LoadLib( "HTML::FormatText");

    return 0 if $error;
    1;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       convert html into ascii
#
#   INPUT PARAMETERS
#
#       @lines
#
#   RETURN VALUES
#
#       @txt
#
# ****************************************************************************

{
    my $staticLibCheck = 0;
    my $staticLibOk    = 0;

sub Html2txt (@)
{
    my $id        = "$LIB.Html2txt";
    my (@list)    = @ARG;


    my @ret       = @list;

    unless ( $staticLibCheck )
    {
        $staticLibOk    = IsLibHTML();
        $staticLibCheck = 1;

        unless ( $staticLibOk )
        {
            warn "$id: No HTML to TEXT conversion available.";
        }
    }

    #   Library was not found, nothing to do

    return unless $staticLibOk;

    if ( not @list )
    {
        $verb  and  print "$id: Empty content";
    }
    elsif ( $staticLibCheck )
    {
        my $formatter = new HTML::FormatText
                        ( leftmargin => 0, rightmargin => 76);

        # my $parser = HTML::Parser->new();
        # $parser->parse( join '', @list );
        # $parser-eof();

        # $HTML::Parse::WARN = 1;

        my $html = parse_html( join '', @list );

        $verb  and  print "$id: Making conversion\n";

        @ret = ( $formatter->format($html) );

        $html->delete();        # mandatory to free memory
    }

    @ret;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return File content
#
#   INPUT PARAMETERS
#
#       $file
#       $join       [optional] If set, then the file is read as one big
#                   string. The value is the first argument in return array.
#
#   RETURN VALUES
#
#       (\@lines, $status)
#
# ****************************************************************************

sub FileRead ( $; $ )
{
    my $id   = "$LIB.FileRead";
    my $file = shift;
    my $join = shift;

    my $status = 0;
    my @ret;
    local *FILE;

    #   Convert path to Unix format

    $file =~ s,\\,/,g;

    if ( $file =~ /^~/ )
    {
        # must expand ~/dir  and ~user/dir contructs with shell

        my $expanded = qx(echo $file);

        $debug and  print "$id: EXPANDED by shell: $file => $expanded\n";

        $file = $expanded;
    }

    unless ( open FILE, "< $file" )
    {
        $status = $ERRNO;
        warn "$id: FILE [$file] $ERRNO";
    }
    else
    {
        if ( $join )
        {
            $ret[0] = join '', <FILE>;
        }
        else
        {
            @ret = <FILE>;
        }

        close FILE;
    }

    $debug  and  print "$id: [$file] status [$status]\n";


    \@ret, $status;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Write File content
#
#   INPUT PARAMETERS
#
#       $file
#       @lines
#
#   RETURN VALUES
#
#       $status     true, ERROR
#
# ****************************************************************************

sub FileWrite ( $ @)
{
    my $id              = "$LIB.FileWrite";
    my ($file, @lines ) = @ARG;

    my $status = 0;

    local *FILE;

    unless ( open FILE, "> $file" )
    {
        $status = $ERRNO;
        warn "$id: FILE [$file] $ERRNO";
    }
    else
    {
        print FILE @lines;
        close FILE;
    }

    $debug  and  print "$id: [$file] status [$status]\n";

    $status;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Convert HTML file to text
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       $status
#
# ****************************************************************************

sub FileHtml2txt ($)
{
    my $id   = "$LIB.FileHtml2txt";
    my $file = shift;

    my( $lineArrRef, $status ) = FileRead $file;

    if ( $status )
    {
        $debug  and  print "$id: Can't convert\n";
    }
    else
    {
        my @text = Html2txt @$lineArrRef;
        $status = FileWrite $file, @text;
    }

    $debug  and  print "$id: [$file] status [$status]\n";

    $status;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#        analyze FILE to match to match content. If content is not found,
#        delete file.
#
#   INPUT PARAMETERS
#
#       $file
#       $regexp     [optional] content match regexp.
#
#   RETURN VALUES
#
#       $status     True if file is okay
#
# ****************************************************************************

sub FileContentAnalyze ($ $)
{
    my $id   = "$LIB.FileContentAnalyze";
    my $file = shift;
    my $re   = shift;

    return -noregexp unless $re;

    my( $lineArrRef, $status ) = FileRead $file, '-join';
    my $ret;

    if ( $status )
    {
        $debug  and  print "$id: Can't Analyze $file\n";
    }
    else
    {
        local $ARG = $$lineArrRef[0];
        my $match  = $MATCH if /$re/;

        if ( $match )
        {
            $ret = -matched;
        }
        else
        {
            unless ( $test )
            {
                $debug > 1 and
                       print "$id: [$re] content not found, deleting $file\n";

                unless ( unlink $file )
                {
                    $verb  and  print "$id: $ERRNO";
                }
            }
        }

        $debug  and  print "$id: [$file] status [$ret] RE [$re]=[$match]\n";
    }

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Append slash to the end. Optionally remove
#
#   INPUT PARAMETERS
#
#       $path           Add slash to path
#       $flag           [optional] Remove slash
#
#   RETURN VALUES
#
#       $path
#
# ****************************************************************************

sub Slash ($; $)
{
    my $id      = "$LIB.Slash";
    local $ARG  = shift;
    my $remove  = shift;

    if ( $remove )
    {
        s,/$,,;
    }
    {
        $ARG .= '/'  unless m,/$,;
    }

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Split url to components. http://some.com/1/2page.html would be seen as
#
#           http  some.com 1/2 page.html
#
#   INPUT PARAMETERS
#
#       $url
#
#   RETURN VALUES
#
#       @list   Component list
#
# ****************************************************************************

sub SplitUrl ($)
{
    my $id     = "$LIB.SplitUrl";
    local $ARG = shift;

    my($protocol, $site, $dir, $file ) = ("") x 4;

    $protocol = lc $1       if m,^([a-z][a-z]+):/,i;
    $site     = lc $1       if m,://?([^/]+),i;
    $dir      = lc $1       if m,://?[^/]+(/.*/),i;
    $file     = lc $1       if m,^.*/(.*),i;

    if ( $file  and  $file !~ /[.]/ )
    {
        $debug  and  print "$id: [WARNING] ambiguous [$ARG], dir or file?\n";

        unless ( $dir )
        {
            $dir  = $file;
            $file = "";
        }
    }

    $debug  and  print "$id:"
            , " PROTOCOL <$protocol>"
            , " SITE <$site>"
            , " DIR <$dir>"
            , " FILE <$file>"
            , "\n"
            ;

    $protocol, $site, $dir, $file;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return basename from URL. This drops the possible
#       filename from the end. The extra file is dtected
#       from the file extension, perriod(.)
#
#       http://some.com/~foo        ok
#       http://some.com/foo         ok treated as directory
#       http://some.com/page.html   nok
#
#   INPUT PARAMETERS
#
#       $base
#
#   RETURN VALUES
#
#       $string     The url will not contain trailing slash
#
# ****************************************************************************

sub BaseUrl ($)
{
    my $id     = "$LIB.BaseUrl";
    local $ARG = shift;

    if ( m,/~[^/]+$, )
    {
        $debug  and  print "$id: ~foo\n";
        # ok
    }
    elsif ( m,^(.*/)([^/]+)$, )
    {
        my ( $base, $rest ) = ( $1, $2 );

        $debug  and  print "$id: [$base] [$rest]\n";

        $ARG = $base   if  $rest =~ /[.]/;
    }

    s,/$,,;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return basename of the archive.
#
#           file.tar,gz         => file
#           file-1.2.tar.gz     => file-1.2
#           file-1_2.tar.gz     => file-1.2
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       $string
#
# ****************************************************************************

sub BaseArchive ($)
{
    my $id     = "$LIB.BaseArchive";
    local $ARG = shift;

    if ( /^(.*-\d+[-_.]\d+[-_.\d]*)/ )
    {
        # delete last trailing - or . or _

        ( $ARG = $1 ) =~ s/[-_.]$//;
    }
    elsif ( /^(.*)\.[a-z].*$/ )
    {
        #   some-archive.bz2 --> some-archive
        #   some-archive.zip --> some-archive
        $ARG = $1;
    }

    s/_/-/g;

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Try to make sense of relative paths when Base is known.
#       This function is very simplistic.
#
#   INPUT PARAMETERS
#
#       $base
#       $relative
#
#   RETURN VALUES
#
#       $path
#
# ****************************************************************************

sub RelativePath ($ $)
{
    my $id     = "$LIB.RelativePath";
    my $base   = shift;
    local $ARG = shift;

    $base = Slash $base;

    my $ret = $base;

    unless ( $ARG )
    {
        $debug  and  print "$id: second arg is empty [$base]";
    }
    else
    {
        if ( m,^/.*, )      # /root/somewhere/file.txt
        {
            my ($proto, $site, $dir, $file) = SplitUrl $base;

            $ret = "$proto://$site$ARG";

        }
        elsif ( m,^\./(.*), )       # ./somewhere/file.txt
        {
            $ret = $base . $1;
        }
        elsif ( m,^[^/\\#?=], )  # this/path/file.txt
        {
            $ret = $base . $ARG;
        }
        else
        {
            chomp;      # make warn display line number, remove \n
            warn "$id:  [ERROR] Can't resolve relative $base + $ARG";
        }
    }

    $debug  and  print "$id: BASE $base ARG $ARG RET $ret\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return decompress command for file.
#
#   INPUT PARAMETERS
#
#       $file
#       $type       -list       return listng command
#                   -extract    return unpack command
#
#   RETURN VALUES
#
#       lines as listed in file
#
# ****************************************************************************

sub FileDeCompressedCmd ($; $)
{
    my $id = "$LIB.FileDeCompressedCmd";

    local $ARG  = shift;
    my    $type = shift;

    $type = '-extract'      unless defined $type;

    my $cmd;
    my $decompress;

    if ( /\.rar$/ )
    {
         die "$id: $ARG Can't handle. No free rar uncompress program exists.";
    }

    if ( $type eq -extract )
    {
        if ( /\.(tar|tgz)/ )
        {
            /\.(gz|tgz)$/i      and  $decompress = "gzip -d -c";
            /\.(bzip|bz2)$/i    and  $decompress = "bzip2 -d -c";

            $cmd = "$decompress $ARG | tar xvf -";
        }
        elsif ( /\.gz$/ )
        {
            $cmd = "gzip -f -d $ARG";
        }
        elsif ( /\.(bz2|bzip)$/ )
        {
            $cmd = "bzip2 -f -d $ARG";
        }
        elsif ( /\.zip$/ )
        {
            $cmd = $decompress = "unzip -o $ARG";
        }
    }
    else
    {
        if ( /tar/ )
        {
            SWITCH:
            {
                /\.(gz|tgz)$/i      and  $decompress = "gzip -d -c", last;
                /\.(bzip|bz2)$/i    and  $decompress = "bzip2 -d -c", last;
            }

            if ( defined $decompress )
            {
                $cmd = "$decompress $ARG | tar tvf -";
            }
            else
            {
                $cmd = "tar tvf $ARG";
            }
        }
        elsif ( /\.zip$/ )
        {
            $cmd = "unzip -l $ARG";
        }
        elsif ( /\.(bzip|bz2)$/ )
        {
            $cmd = "bzip2 - $ARG";
        }
    }

    $debug  and  print "$id:\n\tARG = $ARG\n"
            , "\tTYPE $type\n"
            , "\tRET [$cmd]\n"
            ;

    $cmd;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return decompress file listing
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       \@files     Files from the archive
#       $error      If "-noarchive" , then file is not an archive.
#
# ****************************************************************************

sub FileDeCompressedListing ( $ )
{
    my $id   = "$LIB.FileDeCompressedListing";
    my $file = shift;

    $debug  and  print "$id: BEGIN $file CWD ", cwd(), "\n";

    my ($cmd, @result, $status);

    if ( -f $file )
    {
        $cmd = FileDeCompressedCmd $file, -list ;

        $debug  and  print "$id: running [$cmd] CWD ", cwd(), "\n";

        $ERRNO  = 0;
        @result = qx($cmd) if $cmd;

        if ( $ERRNO )
        {
            $verb  and  print "$id: [WARN] $ERRNO\n";
            $status  = -externalerror;
        }

        $debug  and  print "$id: CMD [$cmd] => \n[@result]\n";
    }
    else
    {
        $verb  and  warn "[ERROR] file not found ", cwd(), "$file";
        $status = -file-not-found;
    }

    my @ret     = ();
    local $ARG;

    if ( $status )
    {
        # Nothing to do here. Error
    }
    elsif  ( $file =~ /tar/ )
    {
        #   Get last elements in the line
        #
        #  ..      0 2000-11-18 16:18 semantic-1.3.2
        #  ..  23688 2000-11-18 16:18 semantic-1.3.2/semantic-bnf.el
        #  ..  50396 2000-11-18 16:18 semantic-1.3.2/semantic.el
        #  ..  36176 2000-11-18 16:18 semantic-1.3.2/semantic-util.el
        #
        # This comment fixes Emacs fontification: m///

        for ( @result )
        {
            my $file = (reverse split)[0];
            chomp $file;

            push @ret,  (reverse split)[0];
        }

        $debug  and  print "$id: TAR [@result]\n";

    }
    elsif ( $file =~ /zip/ )
    {
         #  Length    Date    Time    Name
         #  ------    ----    ----    ----
         #    4971  03-22-00  21:14   1/gnus-ml.el
         #       0  10-03-99  01:33   tmp/1/tpu/
         #  ------                    -------
         #   25036                    8 files

        for ( @result )
        {
            my @split = reverse split;
            chomp $split[0];

            next  unless /^\s+\d+\s/;

            push @ret,  $split[0]    if   @split == 4;
        }

        $debug  and  print "$id: ZIP [@result]\n";
    }
    else
    {
        $debug  and  print "$id: -noarchive $file\n";
        $status = -noarchive;
    }

    $debug  and  print "$id: RET $file status [$status] [@ret]\n";


    \@ret, $status;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Return the subdirectory where the files are in compressed archive.
#       There may not be any directory or there may be several direcotries
#       that do not share one ROOT directory.
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       $dir        The topmost COMMON root directory. If not all files
#                   have common root, return nothing.
#
#       $status     -noarchive      The file was not archive.
#       \@file      reference to file list
#
# ****************************************************************************

sub FileDeCompressedRootDir ( $ )
{
    my $id   = "$LIB.FileDeCompressedRootDir";
    my $file = shift;

    $debug  and  print "$id: BEGIN $file CWD ", cwd(), "\n";

    my ( $fileArrRef, $status ) = FileDeCompressedListing $file;

    #   If there is directory it must be in front of every file

    local $ARG;
    my %seen  = ();
    my @nodir = ();

    for ( @$fileArrRef  )
    {
        if (  m,^([^/]+)/, )
        {
            #   Do not accept "./" directory

            $seen{ $1 } = 1    if $1  ne ".";
        }
        else
        {
            push @nodir, $ARG;
        }
    }

    my @roots  = keys %seen;
    my $ret;

    if ( @roots == 1  and  @nodir == 0 )
    {
        $ret = $roots[0]
    }

    $debug  and  print "$id: RET roots [@roots] no-dirs [@nodir]\n";

    $ret, $status, $fileArrRef ;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       If archive does not have root directory, return the
#       filename which is bet used for archive root dir.
#
#           package.tar.gz --> package-YYYY.MMDD
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       $root       Returned, If archive does not have natural ROOT
#
# ****************************************************************************

sub FileRootDirNeedeed ( $ )
{
    my $id   = "$LIB.FileRootDirNeedeed";
    my $file = shift;

    $debug  and  print "$id: BEGIN $file CWD ", cwd(), "\n";

    my ($root, $status, $fileArrRef) = FileDeCompressedRootDir $file;

    local $ARG;

    if ( $status eq -noarchive )            # Single file.txt.gz, not package
    {
        $debug  and  print "$id: -noarchive $file\n";
        $ARG = '';
    }
    elsif ( @$fileArrRef == 0 )
    {
        $debug  and  print "$id: EMPTY $file\n";
        $ARG = '';
    }
    elsif ( @$fileArrRef == 1 )
    {
        $debug  and  print "$id: SINGLE FILE $file\n";
        $ARG = '';
    }
    elsif ( $root eq '' )
    {
        $ARG      = basename $file;
        my $base  = BaseArchive $ARG;


        #   If there is no numbers left, assume that we got barebones
        #   and not name like "package-1.11". Add date postfix

        unless ( $base =~ /\d/ )
        {
            $base .= "-" . DateYYYY_MM_DD -version ;
        }

        $ARG = $base;
    }

    $debug  and  print "$id: $file --> need dir [$ARG]\n";

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Create root directory if it is necessary in order to unpack
#       the file. If the archive does not contain ROOT, contruct one
#       from the filename and current date.
#
#       If directory was created or it already exists, return full path
#
#   INPUT PARAMETERS
#
#       $file
#       $path       Under this directory the creation
#       $opt        -rm    Delete previous unpack directory
#
#   RETURN VALUES
#
#       $path       If directory was created
#
# ****************************************************************************

sub FileRootDirCreate ( $ $; $ )
{
    my $id   = "$LIB.FileRootDirCreate";
    my ($file, $path, $opt) = @ARG;

    not defined $opt  and  $opt = '';

    $debug  and  print "$id: BEGIN $file PATH $path\n";

    local $ARG = FileRootDirNeedeed $file;

    my $ret = '';

    if ( $ARG )
    {
        $ARG = "$path/$ARG";

        if ( -e )
        {
            $verb  and  print "$id: Unpack dir already exists $ARG\n";

            if ( $opt =~ /rm/i )
            {
                $verb  and  print "$id: deleting old unpack dir\n";

                unless ( rmtree($ARG, $debug) )
                {
                    warn "$id: Could not rmtree() $ARG\n";
                }
            }
        }

        unless ( -e )
        {
            unless ( $test )
            {
                mkpath( $ARG )  or  die "$id: mkdir() fail $ARG $ERRNO";

                $verb  and  warn "$id: [WARNING] archive $file"
                        , " has no root-N.NN directory."
                        , " Report this to archive maintainer. CREATED $ARG"
                        , "\n"
                        ;
            }
        }

        $ret = $ARG;
    }

    $debug  and  print "$id:\n\tFILE $file\n"
        , "\tPATH $path\n"
        , "\tRET --> created [$ret]\n"
        ;

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Unpack list of files recursively (If package contains more
#       archives)
#
#   INPUT PARAMETERS
#
#       \@array     List of files
#       \%hash      Unpack command hash table: REGEXP => COMMAND, where
#                   %s is substituted for filename
#       $check      "-noroot", will not check the archive content
#       $opt        "-rm", will remove any existing unpack dir
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Unpack($ $; $ $);    # must be introdced due to recursion

sub Unpack ($ $; $ $)
{
    my $id = "$LIB.Unpack";
    my ( $filesArray, $cmdHash, $check, $opt ) = @ARG;

    $check = 1   if  not defined $check;
    $check = 0   if  $check eq -noroot;
    $opt   = ''  if  not defined $opt;

    local $ARG;
    my $origCwd = cwd();

    $debug  and  print "$id: entry cwd = $origCwd OPT [$opt]\n";

    my @array = sort { length $b <=> length $a } keys %$cmdHash;
    $debug  and  print "$id: SORTED decode array @array\n";

    for ( @$filesArray )
    {
        $debug  and warn "$id: unpacking $ARG\n";

        if ( -d )
        {
            $verb  and  print "$id: $ARG is directory, skipped.\n";
            next;
        }
        elsif ( not -f )
        {
            $verb and  print "$id: $ARG is not a file (not exist), skipped.\n";
            next;
        }

        #   The filename may look lik test/tar.gz

        my $gocwd = dirname($ARG)  || '.' ;
        chdir $gocwd or  die "$id: [for] Can't chdir [$gocwd] $ERRNO";

        #   Check only archives that do not contains some kind
        #   of numbering for missing ROOT directories.

        my $cwd   = cwd();
        my $chdir = 0;
        my $file  = basename $ARG;
        my $newDir;

        # ............................................ check ...
        # Must contain root directory in archive
        # We check every archive. Regexp \d would have
        # skipped names looking like package-1.34.tar.gz

        if ( $check )  #    and  not /-[\d]/ )    #font s/
        {
            $debug  and  print "##\n";

            $newDir = FileRootDirCreate basename($ARG), $cwd, $opt;

            $debug  and  print "## $newDir\n";

            if ( $newDir )
            {
                $debug  and  print "$id: cd newdir $newDir\n";

                unless ( chdir $newDir )
                {
                    print "$id: [ERROR] chdir $newDir $ERRNO\n";
                    next;
                }

                $file = "../$file";
                $chdir = 1;
            }
        }

        # ........................................... unpack ...

        $debug  and   print ">>\n";

        my $cmd = FileDeCompressedCmd $file;

        $debug  and  print "$id: unpacking CWD ", cwd(), " [$cmd]\n";

        my @response = qx($cmd)  unless $test;

        print "@response\n"   if $verb;

        # ........................................ recursive ...

        for my $entry ( @response )  # Make this recursive
        {
            local $ARG = $entry;
            chomp;

            if ( /\.(bz2|gz|z|zip)$/i )  # s/
            {
                $debug  and  print "$id: >> RESCURSIVE [$ARG]\n";

                Unpack( [ $ARG ], $cmdHash, -noroot, $opt );
            }
        }

        chdir $cwd    if  $chdir;   # Go back to original dir
    }

    $debug  and  print "EXIT chdir $origCwd\n";

    chdir $origCwd  or  die "$id: [exit] Can't chdir [$origCwd] $ERRNO";
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read directory content
#
#   INPUT PARAMETERS
#
#       $path
#
#   RETURN VALUES
#
#       @       list of files
#
# ****************************************************************************

sub DirContent ($)
{
    my $id       = "$LIB.DirContent";
    my ( $path ) = @ARG;

    $debug and warn "$id: $path\n";

    local *DIR;

    unless ( opendir DIR, $path )
    {
        print "$id: can't read $path $ERRNO\n";
        next;
    }

    my @tmp = readdir DIR;
    closedir DIR;

    $debug > 1 and warn "$id: @tmp";

    @tmp;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Scan until valid tag line shows up. Return line if it is under the
#       TAG
#
#   INPUT PARAMETERS
#
#       $line               line content
#       $tag                Tag name to look for
#       $reset              If set, do nothing but reset state variables.
#                           You should call with this if you start a new round.
#
#   RETURN VALUES
#
#       ($LINE, $stop)      The $LINE is non-empty if it belongs to the TAG.
#                           The $stop flag is non-zero if TAG has ended.
#
# ****************************************************************************

{
    my
    (
          $staticTagLevel
        , $staticTagName
        , $staticTagFound
    );

sub TagHandle ($$ ; $)
{
    my $id          = "$LIB.TagHandle";

    local $ARG              = shift;
    my ( $tag , $reset)     = @ARG;

    my $info = ( $verb > 1 || $debug > 1 ) ? 1 : 0;

    # ........................................................ reset ...

    if ( $reset )
    {
        $debug > 1   and  print "$id: RESET\n";
        $staticTagLevel = $staticTagName = $staticTagFound = "";
        return $ARG;
    }

    # ...................................................... tag ...

    my $stop;

    #   The line may have multiple tags and the $1 is number, second
    #   is the tag name. However we can't put them in that order
    #   to the hash, because the number is "key". Use reverse here
    #
    #       tag2: A  tag2: B
    #
    #       2 => A
    #       2 => B
    #       |
    #       The key, only last would be in hash

    my %choices = reverse /$TAG_REGEXP/go;

    if( $info  and  keys %choices > 0   )
    {
        print "$id: TAG CHOICES: ", join( ' ', %choices), "\n"
    }

    unless ( $staticTagFound )
    {
        while ( my($tagN, $tagNbr) = each %choices )
        {
            if ( $info and $tagNbr )
            {
                print "$id: [$tagNbr] '$tagN' eq '$tag'\n";
            }

            if ( $tagNbr  and   $tagN eq $tag )
            {
                $staticTagLevel  = $tagNbr;
                $staticTagName   = $tagN;
                $staticTagFound  = 1;

                $debug > 0 and warn "$id: TAG FOUND [$staticTagName] $ARG\n"
            }
        }

        $ARG = ""  unless $staticTagFound;      # Read until TAG
    }
    else
    {
        #   We're reading lines after the tag was found.
        #   Terminate on next found tag name

        while ( my($tagN, $tagNbr) = each %choices )
        {
            if ( $tagNbr  and  $tagNbr <= $staticTagLevel )
            {
                $info and print "$id: End at [$staticTagName] $ARG\n";
                $stop = 1;
            }
        }
    }

    $debug > 1  and  print "$id: RETURN [$ARG] stop [$stop]\n";

    $ARG, $stop;
}}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Handle Local directory change and die if can't checnge to
#       directory.
#
#   INPUT PARAMETERS
#
#       $dir        Where to chdir
#       $make       [optional] Flag, if allowed to create directory
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub DirectiveLcd (%)
{
    my $id        = "$LIB.DirectiveLcd";
    my %arg       = @ARG;

    my $dir       = $arg{-dir}   or  die "$id: No DIR argument";
    my $mkdir     = $arg{-mkdir} || 0;

    $verb > 2  and  PrintHash "$id: input", %arg;

    my $lcd  = ExpandVars $dir;

    $verb > 2  and  print "$id: LCD original $lcd\n";

    $lcd = PathConvertSmart $lcd;

    $verb > 2  and  print "$id: LCD converted $lcd\n";

    unless ( -d $lcd )
    {
        not $mkdir  and  die "$id: [$dir] => lcd [$lcd] is not a directory";

        $verb  and  warn "$id: Creating directory $lcd";

        mkpath( $lcd, $verb) or die "$id: mkpath $lcd failed $ERRNO";
    }

    $debug > 2      and  print "$id: chdir $lcd\n";
    chdir $lcd      or   die   "$id: chdir $lcd $ERRNO";
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Examine list of files and return the newest file that match FILE
#       the idea is that we divide the filename into 3 parts
#
#           PREFIX VERSION REST
#
#       So that for example filename
#
#           emacs-20.3.5.1-lisp.tar.gz
#
#       is exploded to parts
#
#           emacs -20.3.5.1- lisp.tar.gz
#
#       After this, the VERSION part is examined and all the numbers from
#       it are read and converted to zero filled keys, so that sorting
#       between versions is possible:
#
#           (20 3 5 1) --> "0020.0003.0005.0001"
#
#       A hash table for each file is build according to this version key
#
#           VERSION-KEY => FILE-NAME
#
#       When we finally sort the has by key, we get the latest version number
#       and the associated file.
#
#   INPUT PARAMETERS
#
#       $file       file to use as base.
#       \@files     list of files
#
#   RETURN VALUES
#
#       $file       File that is newest, based on version number.
#
# ****************************************************************************

sub LatestVersion ( $ $ )
{
    my $id                = "$LIB.LatestVersion";
    my ( $file , $array ) = @ARG;

    ! $file  and  die "$id: <file:> argument missing";

    # ................................................ write regexps ...

    #   NN.NN   YYYY-MM-DD
    #   1.2beta23
    #   1.1-beta1
    #   1.1a
    #   file_150b6_en.zip
    #
    #   Difficult names are like4this-1.1.gz
    #
    #   Prevent 1.1.tar.gz --> "1.1.t" with negative lookahead

    my $ext     = '(?!(?i)tar|gz|bzip|bz2|tgz|tbz2|zip|rar|z$)';
    my $add     = '(?:-?(?:alpha|beta)\d*|' . $ext . '[a-z])';
    my $regexp  = '^(.*?[-_]|\D*\d+\D+|\D+)'        # $1
                  . '([-_.\db]*\d'                  # $2
                  . $add
                  . '?)'
                  . '(\S+)'                         # $3
                  ;

    $debug   and
        print "$id: file [$file] REGEXP /$regexp/\n",
            , join("\n", @$array), "\n";

    DUPLICATE_REMOVE:   # Make "local sandbox" for a while (scoping rules)
    {
        my %hash;
        @hash{ @$array } = (1) x @$array;

        @$array = keys %hash;

        $debug   and   print "$id: after duplicate remove "
                           , join("\n", @$array), "\n";
    }

    # .......................................................... sub ...

    my ( %hash, %hash2, $max );

    local *VersionPush = sub ( $ $ )
    {
        my $id       = "$id.VersionPush";
        local $ARG   = shift;       # filename
        my $verStr   = shift;

        my $key      = "";
        my @v        = /(\d+)/g ;

        if ( $verStr =~ /([a-z])$/ )    #   "1.1a"
        {
            #  1.1a  => 1.1.97  use a's ascii code
            #  1.1   => 1.1.0

            push @v, ord $1;    # get character ASCII code
        }

        $debug > 1  and  print "$id: [Version pure] \@v = @v\n";

        #   Sometimes the version number is really unorthodox
        #   like foo-1.020.el.gz When compared with 1.2.3, that
        #   would say:
        #
        #       1.  20
        #       1.  2
        #
        #   And giving false prioroty to "020". The leading
        #   zeroes must be treated as it the number was:
        #
        #       1.  0   20

        LOCALIZE:
        {                            # Use inner block to localize @ver
            my @ver;

            for my $nbr ( @v )
            {
                if ( $nbr =~ /^(0+)(\d+)/ )
                {
                    push @ver, (0) x length $1;
                    push @ver, $2;
                }
                else
                {
                    push @ver, $nbr;
                }
            }

            @v = @ver;
        }

        $debug > 1  and  print "$id: [Version fixed] \@v = @v\n";

        #   Record how many separate digits was found.

        $max = @v           if @v > $max;

        #       fill until 8 version digit elements in array

        push @v, 0          while @v < 8 ;

        for my $version ( @v )
        {
            #   1.0 --> 0001.0000.0000.0000.0000.0000
            $key .= sprintf "%015d.", $version;
        }

        $hash  { $key  } = $ARG;
        $hash2 { $v[0] } = $ARG;
    };

    # .......................................................... sub ...

    local *DebugHash = sub ()
    {
        if ( $debug > 1 )
        {
            while ( my($key, $val) = each %hash )
            {
                printf "$id: HASH1 $key => $val\n";
            }

            while ( my($key, $val) = each %hash2 )
            {
                printf "$id: HASH2 $key => $val\n";
            }
        }
    };

    # .......................................................... sub ...

    local *ParseVersion = sub ($ $ $)
    {
        my $id = "$id.ParseVersion";
        my ($pfx, $post, $ver) = @ARG;
        my $ret;

        #   If date is used as version number:
        #
        #       wemi-199802080907.tar.gz
        #       wemi-19980804.tar.gz
        #       wemi-199901260856.tar.gz
        #       wemi-199901262204.tar.gz
        #
        #   then sort directly by the %hash2, which only contains direct
        #   NUMBER key without prefixed zeroes. For multiple numbers we
        #   sort according to %hash

        my @try;

        if ( $max == 1 )
        {
            @try  = sort { $b <=> $a } keys %hash2;
            %hash = %hash2;
        }
        else
        {
            @try = sort { $b cmp $a } keys %hash;
        }

        if ( $debug )
        {
            print "$id: Sorted choices: $ver $pfx.*$post\n";

            for my $arg ( @try )
            {
                print "\t$hash{$arg}\n";
            }
        }

        #   If SINGLE answer, then use that. Or if we grepped versioned
        #   files, take the sorted one from the beginning

        if ( @try  )
        {
            $ret = $hash{ $try[0] };
        }

        $ret;
    };

    # ........................................... search version [1] ...

    #   APACHE project uses underscores in filenames:
    #   apache_1_3_9_win32.exe

    local $ARG = $file;
    my $ret    = $file;

    if ( /$regexp/o  )
    {
        my $pfx  = $1;
        $pfx =~ s,([][{}+.?*]),\\$1,g;   # Quote special characters.

        #  Examine 150b6, 1.50, 1_15

        my $ver  = '[-_]([-._\db]+ ' . $add . '?)';
        my $post = "$3\$";                  #   Add anchor too

        $debug  and  print "$id: INITIAL PFX: [$pfx] POSTFIX: [$post]\n";

        # .................................................. arrange ...
        # If there are version numbers, then sort all according
        # to version.

        for ( @$array )
        {
            $debug > 1  and  print "$id: FOR [$ARG]\n";

            #   If the filename is like file.txt-1.1, then there is
            #   no point to use $post, because it would reject files
            #   because it requires extension "1$", but file.txt-1.2
            #   has extension "2$"

            unless (  ( ( /\.[a-z]+[^-.]+$/ and /$pfx.*$post/)
                         or /$pfx/ )
                      and  /$regexp/o
                   )
            {
                $debug > 1  and  print "$id: REJECTED\t\t$ARG\n";
                next;
            }

            unless ( /$pfx.*$post/ )
            {
                $debug > 1  and  print "$id: REJECTED, no pfx-postfix\t$ARG\n";
                next;
            }

            unless ( /$regexp/o )
            {
                $debug > 1
                       and print "$id: REJECTED, no regexp match\t$ARG\n";
            }

            my ($BEG, $vver, $END) = ($1, $2, $3);

            $debug > 1  and  print "$id: MATCH: [$BEG] [$vver] [$END]\n";

            VersionPush( $ARG, $vver);
        }

        DebugHash();
        $ret = ParseVersion( $pfx, $post, $ver );

    }
    elsif ( /(.*)-[\d.]+$/ )
    {
        $debug  and  print "$id: plan B, non-standard version-N.NN\n";

        my $pfx  = $1;
        my $ver  = '(-[\d.]+)$';
        my $post = "";

        $debug > 1
               and  print "$id: (B) PFX: [$pfx] POSTFIX: [$post] [$ARG]\n";

        for ( @$array )
        {
            unless ( /($pfx)-$ver/ )
            {
                $debug  and  print "$id: REJECTED\t\t$ARG\n";
                next;
            }

            my ($BEG, $vver) = ($1, $2);

            $debug > 1  and  print "$id: MATCH: [$BEG] [$vver]\n";

            VersionPush( $ARG, $vver);
        }

        DebugHash();
        $ret = ParseVersion( $pfx, $post, $ver );

    }
    elsif ( /^(\D+)[\d.]+[a-h]+[\d.]+(.*)/ )   # WinCvs11b14.zip
    {
        $debug > 1  and  print "$id: plan C, non-standard version-N.NN\n";

        my $pfx  = $1;
        my $ver  = '([\d.]+[a-h]+[\d.]+)';
        my $post = $2;

        $debug > 1
               and  print "$id: (C) PFX: [$pfx] POSTFIX: [$post] [$ARG]\n";

        for ( @$array )
        {
            unless ( /($pfx)$ver$post/ )
            {
                $debug > 1  and  print "$id: REJECTED\t\t$ARG\n";
                next;
            }

            my ($BEG, $vver) = ($1, $2);

            $debug > 1  and  print "$id: MATCH: [$BEG] [$vver] $ARG\n";

            VersionPush( $ARG, $vver);
        }

        DebugHash();
        $ret = ParseVersion( $pfx, $post, $ver );

    }
    elsif ( /^(\D+)[\d.]+/ )   # WinCvs136.zip
    {
        $debug > 1 and  print "$id: plan D, non-standard version-N.NN\n";

        my $pfx  = $1;
        my $ver  = '([\d.]+)';
        my $post = "";

        $debug > 1  and  print "$id: (D) PFX: [$pfx] POSTFIX: [$post]\n";

        for ( @$array )
        {
            unless ( /($pfx)$ver/ )
            {
                $debug > 1 and  print "$id: REJECTED\t\t$ARG\n";
                next;
            }

            my ($BEG, $vver) = ($1, $2);

            $debug > 1 and  print "$id: MATCH: [$BEG] [$vver] $ARG\n";

            VersionPush( $ARG, $vver);
        }

        DebugHash();
        $ret = ParseVersion( $pfx, $post, $ver );

    }
    else
    {
        if ( $verb )
        {
            print  <<EOF;
$id: Unknown version format in filename. Cannot parse according to skeleton [$ARG]
    The most usual reason for this error is, that you have supplied
    <pregexp:> and <new:>. Please examine your URL and try removing <new:>

    Another reason may be that the filename is in format that is not standard
    NAME-VERSION.EXTENSION, like package-1.34.4.tar.gz. In that case please
    contact the developer of the package and let him know about the de facto
    packaging format.
EOF
        }
    }

    $debug  and  warn "$id: RETURN model was:$file --> [$ret]\n";

    if ( $ret eq '' )
    {
        die <<EOF;
$id: Internal error, Run with --debug on to pinpoint the details.

     Cannot find anything suitable for download. This may be due to
     non-matching file regexp: that is, your file-format for <new:> is wrong,
     or <regexp:> is too limiting or <no-regexp:> filtered everything.

     check also that the <new:> file extension looks the same as what
     <pregexp:> found from the page.
     [$CURRENT_TAG_LINE]
EOF
    }

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if file is compressed once. This means that
#       if file is decompressed it would possibly overwrite original file.
#
#           file.txt.gz     => is simple compressed
#           package.tar.gz  => is NOT simple compressed.
#
#   INPUT PARAMETERS
#
#       $   FILENAME
#
#   RETURN VALUES
#
#       $   True value if file is simple compressed
#
# ****************************************************************************

sub FileSimpleCompressed ( $ )
{
    my $id = "FileSimpleCompressed";
    my ($file) = @ARG;

    my @list =
    (
        '.gz'
        , '.bz2'
        , '.Z'
        , '.z'
    );

    my $ret;

    unless ( $file =~ /\.(tar|zip|rar)/ )   # must not be multi-archive format
    {
        my @suffixlist = map { my $f = $ARG; $f =~ s/\./\\./g; $f } @list;

        my ($name,$path,$suffix) = fileparse( $file , @suffixlist);

        $ret = $suffix;

    }

    $debug  and  print "$id: [$file] RET [$ret]\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check If file exists. Checks also the name without compression
#       extension.
#
#   INPUT PARAMETERS
#
#       $       FILENAME
#       $       [optional] UNPACK. If set, then the file will be
#       $       decompressed and the original file under it should be checked.
#               That is, if FILENAME is "file.txt.gz", check also "file.txt"
#
#   RETURN VALUES
#
#       @       List of files that exist on disk
#
# ****************************************************************************

sub FileExists ( $ ; $ )
{
    my $id = "FileExists";
    my ($file, $unpack) = @ARG;

    if ( $file =~ /\?.*=(.+[a-zA-Z])/ )
    {
        #  download.php?file=this.tar.gz

        $debug  and  print "$id: FILE [$file] fixed => [$1]\n";
        $file = $1;
    }

    my @list =
    (
        '.zip'
        , '.rar'
        , '.gz'
        , '.bz2'
        , '.Z'
        , '.z'
    );

    my @suffixlist = map { my $f = $ARG; $f =~ s/\./\\./g; $f } @list;

    my ($name, $path, $suffix) = fileparse( $file , @suffixlist);

    my %ret;                    # hash filters out duplicates

    if ( $suffix )
    {
        my @try = ( $suffix );
        push @try, ''   if $unpack;  # '' => file itself

        for my $try ( @try )            # '' => file itself
        {
            $debug  and  print "$id: trying: [$path] + [$name] + [$try]\n";

            my $file = $path . $name . $try;
            $ret{$file} = 1    if -e $file;
        }
    }
    elsif ( not $unpack  and  -e $file )
    {
        $ret{$file} = 1;
    }

    $debug  and  print "$id: ", cwd(), " [$file] RET [", keys %ret, "]\n";

    keys %ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check Invalid filename characters
#
#   INPUT PARAMETERS
#
#       $       filename
#
#   RETURN VALUES
#
#       $       URL file
#
# ****************************************************************************

sub FileNameFix ( $ )
{
    my $id       = "FileNameFix";
    local ($ARG) = @ARG;

    if ( /\?.+=(.+\.(?:gz|bz2|tar|zip|rar|pak|lhz))/ )
    {
        # download.php?id=file.tar.gz

        $debug  and
            print "$id: A: chararcter [?] - fixing [$ARG] => [$1]\n";

        $ARG = $1;
    }
    elsif ( /^(.*)\?/ )
    {
        # http://cvs.someorg/cgi-bin/viewcvs.cgi/~checkout~/file?rev=HEAD
        # =>  file "file?rev=HEAD"

        $debug  and
            print "$id: B: chararcter [?] - fixing [$ARG] => [$1]\n";

        $ARG = $1;
    }

    $ARG;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Make latest filename with possible version numbers
#
#   INPUT PARAMETERS
#
#       $file       Template, how the file looks like
#       @           Array of possible verion numbers
#
#   RETURN VALUES
#
#       @           Versioned files
#
# ****************************************************************************

sub MakeLatestFiles ( $ @ )
{
    my $id       = "$LIB.MakeLatestFiles";
    local $ARG   = shift;
    my @versions = @ARG;

    my @ret;

    if ( /^(.*?)-([\d.]+[\d])(.*)/ )
    {
        my ( $pre, $middle, $rest ) = ( $1, $2,  $3 );

        $debug  and  print "$id: Exploded [$pre] [$middle] [$rest]\n";

        for my $ver ( @versions )
        {
            my $file = $pre . "-" . $ver . $rest;
            push @ret, $file;
        }
    }
    else
    {
        $verb  and  print "$id:  Can't parse version from FILE $ARG\n";

        #   Suppose that all the files in @versions are versioned
        #
        #   file.txt-1.2  file.txt-1.3   and the model file was
        #   file.txt


        @ret = ( LatestVersion $versions[0], \@versions );
    }

    $debug  and  print "$id: FILE $ARG RET => [@ret]\n";

    @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Selct file or files from LIST. GETFILE and REGEXP are
#       mutually exclusive
#
#   INPUT PARAMETERS
#
#       $regexp     Select files according to regexp.
#       $regexpNo   Files not to match after REGEXP
#
#       $getFile    If newest file is wanted, here is sample.
#                   If this variable is empty; then no newest file is searched.
#
#       @           candidate file list
#
#   RETURN VALUES
#
#       @           List of selected files
#
# ****************************************************************************

sub FileListFilter ( $ $ @)
{
    my $id                          = "$LIB.FileListFilter";
    my ( $regexp, $regexpNo, $getFile, @list ) = @ARG;

    $debug  and  print "$id: INPUT REGEXP [$regexp]"
        , " REGEXPNO [$regexpNo]"
        , " GETFILE  [$getFile]"
        , " LIST     => "
        , join("\n", @list)
        , "\n"
        ;

    # ......................................................... args ...

    local *Filter = sub ( $ @)
    {
        my ($regexpNo, @list) = @ARG;

        my @new = grep ! /$regexpNo/, @list;

        $debug  and  print "$id: [$regexpNo] FILTERED "
                , join(' ', grep /$regexpNo/, @list), "\n"
                ;

        if ( $verb  and  not @new )
        {
            print "$id: [WARNING] regexpNo [$regexpNo] rejected everything\n";
        }

        @list = @new;
    };

    @list = Filter( $regexpNo, @list )  if $regexpNo  and @list;

    if ( $regexp )
    {
        @list = sort grep /$regexp/, @list;
    }

    $debug  and  print "$id: after regexp [@list]\n";

    if ( $getFile )
    {
        my $name = basename $getFile;
        my $file = LatestVersion $name, \@list;

        if ( $verb )
        {
            print "$id: ... Getting latest version: $file DIR: ", cwd(), "\n";
        }

        @list = ( $file );
    }

    @list = Filter( $regexpNo, @list )  if $regexpNo  and @list;

    $debug  and  print "$id: RET [@list]\n";

    @list;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Get file via FTP
#
#   INPUT PARAMETERS
#
#       $site       Dite to connect
#       $path       dir in SITE
#
#       $getFile    File to get
#       $saveFile   File to save on local disk
#       $regexp
#       $regexpNo
#
#       $firewall
#
#       $new        Flag, Should only the newest file retrieved?
#       $stdout     Print to stdout
#
#   RETURN VALUES
#
#       ()      RETURN LIST whose elements are:
#
#       $stat   Error reason or "" => ok
#       @       list of retrieved files
#
# ****************************************************************************

sub UrlFtp ( % )
{
    my $id                = "$LIB.UrlFtp";

    my %arg = @ARG;

    # ......................................................... args ...

    #   check mandatory

    not exists $arg{site}                   and  die "$id: SITE missing";
    not exists $arg{path}                   and  die "$id: PATH missing";
    not exists $arg{getFile}                and  die "$id: FILE missing";
    not exists $arg{saveFile}               and  die "$id: SAVE missing";

    #   Defaults. Note: login 'ftp' is still not known to every
    #   FTP server.

    not $arg{login}     and  $arg{login} = 'anonymous';
    not $arg{pass}      and  $arg{pass}  = 'nobody@example.com';

    #   Read values

    my $url                     = $arg{url};
    my $site                    = $arg{site};
    my $path                    = $arg{path};
    my $getFile                 = $arg{getFile};
    my $saveFile                = $arg{saveFile};
    my $regexp                  = $arg{regexp};
    my $regexpNo                = $arg{regexpNo};
    my $firewall                = $arg{firewall};
    my $login                   = $arg{login};
    my $pass                    = $arg{pass};
    my $new                     = $arg{new}           || 0;
    my $stdout                  = $arg{stdout}        || 0 ;
    my $conversion              = $arg{conversion}    || '';
    my $rename                  = $arg{rename}        || '';
    my $origLine                = $arg{origLine}      || '';
    my $unpack                  = $arg{unpack}        || '';
    my $overwrite               = $arg{overwrite}     || '';

    # ............................................ private functions ...

    my @files;

    local *PUSH = sub ($)
    {
        local ( $ARG ) = @ARG;

        if ( $stdout )
        {
            Stdout $ARG;
        }
        else
        {
            unless ( m,[/\\], )
            {
                $ARG = cwd() . "/" . $ARG ;
            }

            push @files, $ARG   if not $stdout;
        }
    };

    # ............................................ private variables ...

    my $timeout        = 120;
    my $singleTransfer;

    if ( (not defined $regexp  or  $regexp eq '') and ! $new )
    {
        $singleTransfer = 1;
    }

    local $ARG;

    $stdout   and  $saveFile = TempFile();

    if ( $debug )
    {
        print "$id:\n"
            , "\tsingleTransfer: $singleTransfer\n"
            , "\tSITE        : $site\n"
            , "\tPATH        : $path\n"
            , "\tLOGIN       : $login PASS $pass\n"
            , "\tgetFile     : $getFile\n"
            , "\tsaveFile    : $saveFile\n"
            , "\trename      : $rename\n"
            , "\tconversion  : $conversion\n"
            , "\tregexp      : $regexp\n"
            , "\tregexp-no   : $regexpNo\n"
            , "\tfirewall    : $firewall\n"
            , "\tnew         : $new\n"
            , "\tcwd         : ", cwd(), "\n"
            , "\tOVERWRITE   : $overwrite\n"
            , "\tSKIP_VERSION: $SKIP_VERSION\n"
            , "\tstdout      : $stdout\n"
            ;
    }

    $verb  and print
           "$id: Connecting to ftp://$site$getFile --> $saveFile\n";

    $debug and print "$id:\n"
           , "REGEXP: $regexp \n"
           , "LOGIN : $login\n"
           , "PASSWD: $pass\n"
           , "SITE  : $site\n"
           , "PATH  : $path\n"
           ;

    #   One file would be transferred, but it already exists and
    #   we are not allowed to overwrite --> do nothing.

    if ( $singleTransfer  and  -e $saveFile
         and  not $overwrite
         and  not $stdout
       )
    {
        $verb  and  print "$id: [ignored, exists] $saveFile\n";
        return;
    }

    # .................................................. make object ...

    my $ftp;

    if ( $firewall ne '' )
    {
        $ftp = Net::FTP->new
        (
            $site,
            (
                Firewall => $firewall,
                Timeout  => $timeout
            )
        );
    }
    else
    {
        $ftp = Net::FTP->new
        (
            $site, ( Timeout  => $timeout )
        );
    }

    unless ( defined $ftp )
    {
        print "$id: Cannot make route to $site $ERRNO\n";
        return;
    }

    # ........................................................ login ...

    $debug  and print "$id: Login to $site ..\n";

    unless ( $ftp->login($login, $pass) )
    {
        print  "$id: Login failed $login, $pass\n";
        goto QUIT;
    }

    $ftp->binary();

    my $cd = $path;
    $cd = dirname $path     unless $path =~ m,/$, ;

    if ( $cd ne '' )
    {
        unless ( $ftp->cwd($cd) )
        {
            print "$id: Remote cd $cd failed [$path]\n";
            goto QUIT;
        }
    }

    # .......................................................... get ...

    my $stat;

    $ftp->binary();
    $ftp->hash( $verb ? "on" : undef );     # m"

    if ( $singleTransfer )
    {
        $verb  and  print "$id: Getting file... [$getFile]\n";   # m:

        $rename   and  do{$saveFile = EvalCode $url, $saveFile, $rename};

        unless ( $ftp->get($getFile, $saveFile) )
        {
            warn  "$id: ** [ERROR] SingleFile [$getFile] $ERRNO\n"
                  , "\tMaybe you have invalid line? [$origLine]"
                  ;
        }
        else
        {
            PUSH($saveFile);
        }
    }
    else
    {
        my (@list, $i);

        $verb  and print "$id: Getting list of files $site ...\n";

        $i    = 0;

        $debug  and warn "$id: Running ftp dir ls()\n";

        @list = $ftp->ls();
        @list = FileListFilter $regexp, $regexpNo, $getFile, @list;

        $debug  and  warn "$id: List length ", scalar @list, " --> @list\n";

        if ( $verb  and not @list )
        {
            print "$id: No files to download."
                , " Run with debug to investigate the problem.\n"
                ;
        }

        for ( @list )
        {
            $i++;

            my $progress = DownloadProgress $site . $cd, $ARG, "$id: ..."
                           , $i, scalar @list;
            print $progress if $progress;

            my $saveFile = $ARG;
            $saveFile    = TempFile()   if $stdout;

            $rename   and  do{$saveFile = EvalCode $url, $saveFile, $rename};
            $verb     and  print " $ARG [$saveFile]\n";

            unless ( $stdout )
            {
                my $onDisk;
                my $simpleZ = FileSimpleCompressed $saveFile;

                if ( $simpleZ )
                {
                    ($onDisk) = FileExists $saveFile, -forceUnpackCheck;

                    if ( $verb > 1 )
                    {
                        print "$id: Uncompressed file found (use --overwrite)\n";
                    }
                }
                else
                {
                    ($onDisk) = FileExists $saveFile, $unpack;
                }

                $debug and  print "$id: On disk? [$ARG] [save $saveFile] .. "
                    , -e $onDisk ? "[yes]" : "[no]"
                    , cwd()
                    , "\n"
                    ;

                if ( $onDisk )
                {
                    if ( $SKIP_VERSION  and  /-\d[\d.]*\D+/ )
                    {
                        $verb and print "$id: [skip version/already on disk] "
                                  , " $ARG => $onDisk\n";
                        next;
                    }
                    elsif ( not $overwrite )
                    {
                        $verb and print "$id: [no overwrite/already on disk] "
                                  , " $ARG => $onDisk\n";
                        next;
                    }
                }
            }

            unless ( $stat = $ftp->get($saveFile) )
            {
                print "$id: ... ** error $ARG $ERRNO $stat\n";
            }
            else
            {
                PUSH ($saveFile);
            }
        }
    }

    QUIT:
    {
        $ftp->quit() if defined $ftp;
    }

    ($stat, @files);
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Try to find the latest version number from the page.
#       Normally indicated by "The latest version of XXX is N.N.N"
#
#   INPUT PARAMETERS
#
#       $       String, the Url page
#       $       [optional] regexp, what words to lok for
#
#   RETURN VALUES
#
#       %       ver => string, List of versions and text matches
#
# ****************************************************************************

sub UrlHttPageParse ( $ ; $ )
{
    my $id      = "$LIB.UrlHttpPageParse";
    local $ARG  = shift;
    my $regexp  = shift;

    my %hash;

    if ( defined $regexp  and  $regexp ne '' )
    {
        while ( /$regexp/g )
        {
            $hash{$2} = $1   if  $1 and  $2;
        }

        unless ( scalar keys %hash )
        {
            print "$id: [ERROR] version regexp [$regexp] "
                , " didn't find versions. "
                , "Please check or define correct <vregexp:>\n";
        }
    }
    elsif ( 0 and /(latest.*?version.*?\b([\d][\d.]+[\d]).*)/ )
    {
        $debug   and  print "$id: Using DEFAULT page regexp => [$MATCH]\n";
        $hash{$2} = $1;
    }


    $debug  and  print "$id: RET regexp = [$regexp] HASH = ["
        , join ( ' => ', %hash)
        , "]\n"
        ;

    %hash;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Parse all HREFs in the page and return the locations. If there is
#       <BASE> tag, it is always obeyed and not filtered
#
#   INPUT PARAMETERS
#
#       $content    The html page
#       $regexp     [optional] Return only HREFs matching regexp.
#
#   RETURN VALUES
#
#       @urls
#
# ****************************************************************************

sub UrlHttpParseHref ($ ; $)
{
    my $id     = "$LIB.UrlHttpParseHref";
    local $ARG = shift;
    my $regexp = shift;

    $debug > 1 and  print  "$id: regexp [$regexp] ARG [$ARG]\n";

    #   Some HTML pages do not use double quotes
    #
    #       <A HREF=http://example.com>
    #
    #   The strict way is to use double quotes
    #
    #       <A HREF="http://example.com">
    #
    #   URLs do not necessarily stop after HREF
    #
    #       <a href="dir/file.txt" target="_top">

    my (@ret, $base);

    if ( /<\s*BASE\s+href\s*=[\s\"]*([^\">]+)/i )
    {
        $base = $1;
        $base =~ s,/$,,;                    # Remove trailing slash.
        $debug  and  print "$id: BASE $base\n";
    }

    while ( /HREF\s*=[\s\"']*([^\"'>]+)/ig )
    {
        my $file = $1;

        if ( $base  and  $file eq $base )
        {
            next;
        }

        if ( $base   and  $file !~ m,//, )
        {
            $file = "$base/$file";
        }

        if ( $regexp ne ''  and  $file !~ /$regexp/ )
        {
            $debug  and  print "$id:  FILTERED BY REGEXP $file\n";
            next;
        }

        if ( $file =~ /^#/ )
        {
            $debug  and  print "$id:  FILTERED [#] $file\n";
            next;
        }

        if ( $file =~ /^(index)/ )
        {
            $debug  and  print "$id:  FILTERED [index] $file\n";
            next;
        }


        if ( $file =~ m,^\?|/$|mailto, )
        {
            $debug  and  print "$id:  FILTERED OTHER [mailto] $file\n";
            next;
        }

        push @ret, $file;
    }

    $debug  and  print "$id: EXIT. REGEXP = [$regexp] RET =>\n"
                     , join("\n", @ret), "\n";

    @ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       If you connect to http page, that shows directory, this
#       Function tries to parse the HTML and extract the filenames
#
#   INPUT PARAMETERS
#
#       $       String, The Url page
#       $       [optional] boolean, if non-zero, filter out
#               non-interesting files like directories.
#
#   RETURN VALUES
#
#       @       List of files
#
# ****************************************************************************

sub UrlHttpDirParse ( $ ; $ )
{
    my $id      = "$LIB.UrlHttpDirParse";
    local $ARG  = shift;
    my $filter  = shift;

    $debug  and  print "$id: $filter\n";

    my @files;

    if ( /Server:\s+apache/i )
    {
        #   Date: Wed, 16 Feb 2000 16:26:08 GMT
        #   Server: Apache/1.3.11 (Win32)
        #   Connection: close
        #   Content-Type: text/html   m:
        #
        # <IMG SRC="/icons/folder.gif" ALT="[DIR]"> <A HREF="/">
        # <IMG SRC="/icons/image2.gif" ALT="[IMG]"> <A HREF="apache_pb.gif">
        # <IMG SRC="/icons/text.gif" ALT="[TXT]"> <A HREF="index.html.ca">

        #  Anything special to know? No?
    }

    #   Filter out directories and non interesting files
    #
    #   ?N=D ?M=A
    #   manual/

    @files = UrlHttpParseHref $ARG, '' ;

    @files;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Parse list of mirrors from sourceforge's download page.
#
#   INPUT PARAMETERS
#
#       $       HTML
#
#   RETURN VALUES
#
#       %       Hash of hash. Mirrors and their locations
#               MIRROR_NAME => { location, continent }
#
# ****************************************************************************

sub UrlSfMirrorParse ($)
{
    my $id      = "$LIB.UrlSfMirrorParse";
    local($ARG) = @ARG;
    my %hash;

    $debug > 3  and  print "$id: INPUT $ARG\n";

    while ( m,<td>\s*([a-z].*?)</td> \s+
             <td>(.*?)</td> \s+
             .*?use_mirror=([a-z]+)
            ,gsmix
          )
    {
        my( $location, $continent, $mirror) = ($1, $2, $3);

        $debug  > 2 and  print "$id: location [$location] "
                             , "continent [$continent] "
                             , "mirror $mirror\n"
                             ;

        $hash{$mirror} = { location => $location, continent => $continent };
    }

    %hash;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Manipulate URLs as needed for special sites, like sourceforge,
#       which do not accept direct download but always a mirror
#       Like http://prdownloads.sourceforge.net/foo/foo-1.0.0.tar.gz must
#       include parameter like "?use_mirror=kent". Unfortunately, this
#       isn't ye yhe real page. It returns a REFRESH page which contains
#       headers:
#
#           Server: Apache/2.0.51 (Fedora)
#           ...
#           Title: Downloading File: /bogofilter/bogofilter-1.0.0.tar.bz2
#           X-Powered-By: PHP/4.3.10
#           Refresh: 5;URL=http://kent.dl.sourceforge.net/sourceforge/foo..
#
#   INPUT PARAMETERS
#
#       %       hash
#
#   RETURN VALUES
#
#       $       URL which may have been changed
#
# ****************************************************************************

sub UrlHttpManipulate (%)
{
    my $id      = "$LIB.UrlHttpManipulate";
    my %arg     = @ARG;
    my $ua      = $arg{-useragent}  || die "No UA object";;
    my $url     = $arg{-url};
    my $mirror  = $arg{-mirror};

    $debug > 2  and  print "$id: INPUT url [$url]\n";

    if ( $url =~ /^(.*)prdownloads.(sourceforge.*)/
         and  $url !~ /use_mirror/ )
    {
        my ($part1, $part2) = ( $1, $2 );

        $debug > 2 and print "$id: url part1 [$part1] part2 [$part2]\n";

        unless ( $mirror )
        {
            print "$id: Mirror site not defined. Guessing...\n";

            my $request = new HTTP::Request( 'GET' => $url );
            my $obj     = $ua->request( $request );
            my $stat    = $obj->is_success;
            my $str     = $obj->content;

            my %hash = UrlSfMirrorParse($str);
            my @list = keys %hash  if %hash;

            $debug > 2  and  print "$id: mirror hash: "
                                 , join(' ', @list), "\n"
                                 ;

            $mirror  = $list[0] if @list;
            print "$id: Using mirror [$mirror]\n";
        }

        $url = "$part1$mirror.dl.$part2"  if $mirror;
    }

    $debug > 2  and  print "$id: RET url [$url]\n";

    $url;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Check if file is already on disk and do not overwrite if that is
#       not allowed. Check also if there is skip version option active.
#
#   GLOBAL VARIABLES
#
#       $SKIP_VERSION
#
#   INPUT PARAMETERS
#
#       $file
#       $unpack
#
#   RETURN VALUES
#
#       True    if it's ok to download file.
#
# ****************************************************************************

sub UrlHttpFileCheck ( % )
{
    my $id         = "$LIB.UrlHttpFileCheck";
    my %arg       = @ARG;
    my $saveFile  = $arg{savefile};
    my $unpack    = $arg{unpack};
    my $overwrite = $arg{overwrite};

    my $ret;
    my $onDisk;
    my $simpleZ = FileSimpleCompressed $saveFile;

    if ( $simpleZ )
    {
        ($onDisk) = FileExists $saveFile, -forceUnpackCheck;

        if ( $verb > 1 )
        {
            print "$id: Uncompressed file found (use --overwrite)\n";
        }
    }
    else
    {
        ($onDisk) = FileExists $saveFile, $unpack;
    }

    $debug and  print "$id: file on disk? .. "
        , -e($saveFile) ? "[yes]" : "[no]"
        , "\n"
        ;

    if ( $onDisk )
    {
        #   If the filename contains version number
        #   AND skipping is on, then ignore downoad

        if ( $SKIP_VERSION  and  /-\d[\d.]*\D+/ )
        {
            $verb  and  print "$id: [already on disk]"
                        , " $ARG => $onDisk\n";
            $ret = -skipversion
        }
        elsif ( not $overwrite )
        {
            $verb   and print "$id: [no overwrite/already on disk]"
                        , " $ARG => $onDisk\n";
            $ret = -noovrt
        }
    }

    $debug  and  print "$id: RET $ret\n";

    $ret;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Search download ULRs from page.
#
#   INPUT PARAMETERS
#
#       %
#
#   RETURN VALUES
#
#       @list       List of URLs found
#
# ****************************************************************************

sub UrlHttpSearchPage ( % )
{
    my $id  = "$LIB.UrlHttpSearchPage";
    my %arg =  @ARG;

    my $ua              = $arg{useragent}  || die "No UA object";;
    my $url             = $arg{url};
    my $regexpNo        = $arg{regexpno};
    my $baseUrl         = $arg{baseurl};
    my $thisPageRegexp  = $arg{pageregexp};

    my @list;

    my $request = new HTTP::Request( 'GET' => $url );
    my $obj     = $ua->request($request);
    my $stat    = $obj->is_success;

    unless ( $stat )
    {
        print "  ** error: $baseUrl ",  $obj->message, "\n";
    }
    else
    {
        my $content = $obj->content();
        my $head    = $obj->headers_as_string();

        @list     = UrlHttpParseHref $content, $thisPageRegexp;

        if ( $regexpNo )
        {

            $debug > 2  and  print "$id:  filter before [$regexpNo] [@list]\n";
            @list = grep ! /$regexpNo/, @list;
            $debug > 2  and  print "$id:  filter after  [@list]\n";
        }

        # Filter out FRAGMENTs that are not part of the file names:
        #
        # http://localhost/index.html#section1

        local $ARG;
        for ( @list )
        {
            if ( /#.*/ )
            {
                $debug  and  print "$id: filtering out FRAGMENT-SPEC $ARG\n";
                s/#.*//;
            }
        }

        $debug  and  print "$id: -find regexpNo [$regexpNo] @list\n";
    }


    $debug  and  print "$id: ret [@list]\n";

    @list;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Search Newest file form page
#
#   INPUT PARAMETERS
#
#       %
#
#   RETURN VALUES
#
#       @list       List of URLs found
#
# ****************************************************************************

sub UrlHttpSearchNewest ( % )
{
    my $id  = "$LIB.UrlHttpSearchNewest";
    my %arg =  @ARG;

    my $ua              = $arg{useragent}  || die "No UA object";
    my $getPage         = $arg{page};
    my $thisPage        = $arg{flag};
    my $file            = $arg{file};
    my $getFile         = $arg{getfile};
    my $baseUrl         = $arg{baseurl};
    my $versionRegexp   = $arg{versionRE};
    my $thisPageRegexp  = $arg{pageRE};
    my $regexp          = $arg{RE};
    my $regexpNo        = $arg{REno};

    my @list;

    $debug  and print "$id: Getting list of files $getPage ...\n";

    my $request = new HTTP::Request( 'GET' => $getPage );
    my $obj     = $ua->request($request);
    my $stat    = $obj->is_success;

    unless ( $stat )
    {
        print "  ** error: $baseUrl ",  $obj->message, "\n";
    }
    else
    {
        my $content = $obj->content();
        my $head    = $obj->headers_as_string();

        if ( $thisPage )
        {
            $getFile  = $file;

            my %hash  = UrlHttPageParse $content, $versionRegexp;
            my @keys  = keys %hash;
            my @urls  = UrlHttpParseHref $content, $thisPageRegexp;
            my @files;

            #   The filename may contain the version information,
            #   UNLESS this is page search condition.

            if ( $getFile !~ /\d/ )
            {
                #  Nope, this is "download.html" search with
                #  possible "--Regexp SEARCH" option.
                $getFile = $urls[0];
                $file    = $getFile;
            }

            $debug  and print "$id: THISPAGE file [$file] "
                        , "getFile [$getFile] "
                        , "urls [@urls] "
                        , "version urls [@keys]\n";

            if ( @keys )
            {
                $debug  and  print "$id: <page> if-case\n";

                @files = MakeLatestFiles $file, keys %hash ;

                if ( @files == 1 )
                {
                    @list = ( RelativePath dirname($urls[0]), $files[0] );

#                        for my $path ( @urls )
#                        {
#                            push @list, RelativePath
#                                ( dirname($path), $files[0] );
#                        }
#
                }
                else
                {
                    $debug  and  print "$id: Latest files > 1\n";
                    @list = ( LatestVersion $file, [@urls, @files] ) ;

                    # @list > 1  and  $file = '';
                }
            }
            else
            {
                #   Try old fashioned. The filename may contain the
                #   version information,

                $debug  and  print "$id: EXAMINE latest URL model[$file]\n";

                @list = ( LatestVersion $file, \@urls ) ;
                # $file = '';
            }

            $debug  and  print "$id: FILES [@files] URLS [@urls]\n";

            unless ( @urls == 1 )
            {
                warn "$id: Can't parse precise location [@urls] ";

                #  Select from these URLs in the FileListFilter

                @list = @urls;
            }
        }
        else
        {
            $debug  and  print "$id: NOT <page> else\n";
            @list   = UrlHttpDirParse $head . $content, "clean";
            # $file   = '';
        }

        @list = FileListFilter $regexp, $regexpNo, $getFile, @list;
    }

    $debug  and  print "$id: RETURN [@list]";

    @list;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Download files
#
#   INPUT PARAMETERS
#
#       %
#
#   RETURN VALUES
#
#       @list       List of URLs found
#
# ****************************************************************************

sub UrlHttpDownload ( % )
{
    my $id = "$LIB.UrlHttpDownload";
    my %arg = @ARG ;

    my $ua         = $arg{useragent};
    my $list       = $arg{list};
    my $file       = $arg{file};
    my $stdout     = $arg{stdout};
    my $find       = $arg{find};
    my $saveopt    = $arg{saveopt};
    my $baseUrl    = $arg{baseurl};
    my $unpack     = $arg{unpack};
    my $rename     = $arg{rename};
    my $overwrite  = $arg{overwrite};
    my $mirror     = $arg{mirror};

    my $contentRegexp           = $arg{contentre} || '';
    my $errUrlHashRef           = $arg{errhash};
    my $errExplanationHashRef   = $arg{errtext};

    if ( $debug )
    {
        print <<EOF;
$id:
 list          = @$list
 file          = $arg{file}
 stdout        = $arg{stdout}
 find          = $arg{find}
 saveopt       = $arg{saveopt}
 baseUrl       = $arg{baseurl}
 unpack        = $arg{unpack}
 rename        = $arg{rename}
 overwrite     = $arg{overwrite}
 contentRegexp = $arg{contentre}
EOF
    }

    # ............................................ private functions ...

    my @files;

    local *PUSH = sub ($)
    {
        local ( $ARG ) = @ARG;

        if ( $stdout )
        {
            Stdout $ARG;
        }
        else
        {
            unless ( m,[/\\], )
            {
                $ARG = cwd() . "/" . $ARG ;
            }
            push @files, $ARG   if not $stdout;
        }
    };

    # ..................................................... download ...

    my $ret;
    my $i    = 0;
    my @list = sort @$list;

    for ( @list )
    {
        $i++;

        #   sometimes the file includes a version number, which
        #   may be instructed to be removed by user configuration tag.
        #   Respect it. But if there are many files then we do not
        #   have a choice.
        #
        #       save: this-name.txt

        my $saveFile = $file;

        $debug  and  print "$id: SAVEFILE-1 $saveFile\n";

        if ( $stdout )
        {
            $saveFile = TempFile();
        }
        elsif ( @list == 1  and  $saveopt )
        {
            $saveFile = $saveopt;
        }
        elsif ( @list > 1  or $file eq ''  or ($find and not $saveopt) )
        {
             $saveFile = basename $ARG;
        }

        my $relative = $ARG || $baseUrl;

        $debug  and  print "$id: SAVEFILE-2 $saveFile RELATIVE $relative\n";

        if ( $ARG  and  not m,://, )
        {
            #   If the ARG is NOT ABSOLUTE reference ftp:// or http://
            #   Then glue together the base site + relative reference found
            #   from page

            $debug  and  print "$id: glue [$baseUrl] + [$ARG]\n";

            $relative  = RelativePath BaseUrl($baseUrl), $ARG;

            #   The whole URL is now known, strip PATH from savefile.
            $saveFile  = basename  $saveFile;
        }

        unless ( $relative )
        {
            warn "$id: [ERROR] Can't resolve relative $baseUrl + [$ARG]";
            next;
        }

        my $url = $relative;

        if ( $rename )
        {
            $saveFile = EvalCode $url, $saveFile, $rename
        }

        $saveFile = FileNameFix $saveFile;

        unless ( $stdout )
        {
            next if UrlHttpFileCheck savefile  => $saveFile
                                   , unpack    => $unpack
                                   , overwrite => $overwrite
                                   ;
        }

        $url = UrlHttpManipulate -useragent => $ua
                                 , -url     => $url
                                 , -mirror  => $mirror
                                 ;

        my $progress = DownloadProgress $baseUrl, $ARG, "$id: ..."
                                        , $i, scalar @list;


        my $request = new HTTP::Request( 'GET' => $url );
        my $obj     = $ua->request( $request , $saveFile );
        my $stat    = $obj->is_success;

        if ( $debug )
        {
            print "$id: content-type:\n\t", $obj->content_type, "\n"
                , "\tsuccess status ", $stat, "\n"
                , map { $ARG = "\t$ARG\n"  } $obj->headers_as_string
                ;
        }

        # ........................................... file downloaded ...

        if ( $stat )
        {
            PUSH ($saveFile);

            my $contentStatus = FileContentAnalyze $saveFile, $contentRegexp;
            my $err;
            $err = "[no match] " unless $contentStatus;

            if ( (not $contentStatus and $verb > 1)
                 or
                 ($contentStatus and $verb)
               )
            {
                print "$progress ${err}$url => $saveFile\n";
            }

        }
        else
        {
            $verb  and  print "$progress $url => $saveFile\n";

            $errUrlHashRef->{ $url } = $obj->code;

            #  There is new error code, record it.

            if ( not defined $errUrlHashRef->{ $obj->code }  )
            {
                  $errExplanationHashRef->{ $obj->code } = $obj->message;
            }

            $ret = $errUrlHashRef->{ $obj->code };

            print "  ** error: $url ",  $obj->message, "\n";
        }
    }

    $ret, @files;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Get content of URL
#
#   INPUT PARAMETERS
#
#       $url                        The URL pointer
#       $file
#       $regexp
#       $regexpNo
#       $proxy
#       \%errUrlHashRef             Hahs where to store the URL-ERROR_CODE
#       \%errExplanationHashRef     Hash  where to store ERROR_CODE-EXPLANATION
#       $new                        Get never file
#       $stdout                     Write to stdout
#       $versionRegexp              How to find the version number from page
#
#   RETURN VALUES
#
#       ()      RETURN LIST whose elements are
#
#       $stat   Error reason or "" => ok
#       @       list of retrieved files
#
# ****************************************************************************

sub UrlHttp ( % )
{
    my $id = "$LIB.UrlHttp";
    my %arg = @ARG ;

    # .............................................. input arguments ...

    #  check mandatory

    not exists $arg{url}                    and  die "$id: URL missing";
    not exists $arg{file}                   and  die "$id: FILE missing";
    not exists $arg{errUrlHashRef}          and  die "$id: HashRef missing";
    not exists $arg{errExplanationHashRef}  and  die "$id: errHashRef missing";

    #  Read values

    my $url                     = $arg{url};
    my $file                    = $arg{file};
    my $errUrlHashRef           = $arg{errUrlHashRef};
    my $errExplanationHashRef   = $arg{errExplanationHashRef};

    my $proxy                   = $arg{proxy}         || '';
    my $regexp                  = $arg{regexp}        || '';
    my $regexpNo                = $arg{regexpNo}      || '';
    my $new                     = $arg{new}           || 0;
    my $stdout                  = $arg{stdout}        || 0;;
    my $versionRegexp           = $arg{versionRegexp} || '';
    my $thisPage                = $arg{plainPage}     || 0;
    my $thisPageRegexp          = $arg{pageRegexp}    || '';
    my $contentRegexp           = $arg{contentRegexp} || '';
    my $conversion              = $arg{conversion}    || '';
    my $rename                  = $arg{rename}        || '';
    my $saveopt                 = $arg{save}          || '';
    my $unpack                  = $arg{unpack}        || '';
    my $overwrite               = $arg{overwrite}     || '';
    my $mirror                  = $arg{mirror}        || '';

    my $find = $thisPage eq -find ? 1 : 0;

    # ......................................................... code ...

    if ( $debug )
    {
        print "$id:\n"
            , "\tURL       : $url\n"
            , "\tFILE      : $file\n"
            , "\trename    : $rename\n"
            , "\tconversion: $conversion\n"
            , "\tregexp    : $regexp\n"
            , "\tregexp-no : $regexpNo\n"
            , "\tthis page : $thisPage\n"
            , "\tfind      : $find\n"
            , "\tvregexp   : $versionRegexp\n"
            , "\tpregexp   : $thisPageRegexp\n"
            , "\tcregexp   : $contentRegexp\n"
            , "\tproxy     : $proxy\n"
            , "\tnew       : $new\n"
            , "\tstdout    : $stdout\n"
            , "\tcwd       : ", cwd(), "\n"
            , "\toverwrite : $overwrite\n"
    }

    $verb  and  print "$id: $url --> $file\n";

    my $ua = new LWP::UserAgent;

    if ( defined $proxy )
    {
          $debug  and $proxy  and  print "$id: Using PROXY $proxy\n";
          $ua->proxy( "http", "$proxy" );
    }

    my ($baseUrl, $getFile) = ($url,"");

    unless ( $thisPage )
    {
        ($baseUrl, $getFile) = ( $url =~ m,^(.*/)(.*), );
    }

    if (      $getFile eq ''
         and  ($regexp eq '' or $thisPageRegexp eq '')
         and  not $thisPage
       )
    {
          die "$id: [ERROR] invalid URL $url. No file name part found."
            , " Did you forgot to use <page:> or <pregexp:> ?"
            ;
    }

    my @list = ( $getFile );

    if ( $new )        # Directory lookup
    {

        my $getPage = $thisPage ? $url : $baseUrl ;

        @list       = UrlHttpSearchNewest
                            useragent    => $ua
                            , page       => $getPage
                            , flag       => $thisPage
                            , file       => $file
                            , baseurl    => $baseUrl
                            , getfile    => $getFile
                            , versionRE  => $versionRegexp
                            , pageRE     => $thisPageRegexp
                            , RE         => $regexp
                            , REno       => $regexpNo
                            ;
    }
    elsif ( $find )
    {
        @list = UrlHttpSearchPage
                    useragent    => $ua
                    , url        => $url
                    , regexpno   => $regexpNo
                    , baseurl    => $baseUrl
                    , pageregexp => $thisPageRegexp
                    ;
    }

    # ............................................ get list of files ...

    #   Multiple links to the same destination
    @list = ListRemoveDuplicates @list;

    local $ARG;

    $debug   and  print "$id: FILE LIST [@list]\n";
    $verb    and  !@list and  print "$id: No matching files [$regexp]\n";

    if ( @list > 1  and  $file  and  not $new)
    {
        $file = '';
        $debug  and
            print "$id: Clearing FILE: [$file] because many/new"
                  , " files to load. "
                  , "\@list = count, ", scalar @list, ", [@list]\n"
                  ;
    }

    my ($ret, @files) = UrlHttpDownload
                    useragent   => $ua
                    , list      => \@list
                    , file      => $new ? $list[0] : $file
                    , stdout    => $stdout
                    , find      => $find
                    , saveopt   => $saveopt
                    , baseurl   => $baseUrl
                    , unpack    => $unpack
                    , rename    => $rename
                    , errhash   => $errUrlHashRef
                    , contentre => $contentRegexp
                    , errtext   => $errExplanationHashRef
                    , overwrite => $overwrite
                    , mirror    => $mirror
                    ;

    $ret, @files;

}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Copy content of PATH to FILE.
#
#   INPUT PARAMETERS
#
#       $path       From where to read. If this is directory, read files
#                   in directory. If this is file, copy file.
#
#       $file       Where to put resuts.
#       $prefix     [optional] Filename prefix
#       $postfif    [optional] postfix
#
#   RETURN VALUES
#
#       ()      RETURN LIST whose elements are:
#
#       $stat   Error reason or "" => ok
#       @       list of retrieved files
#
#
# ****************************************************************************

sub UrlFile (%)
{
    my $id = "$LIB.UrlFile";
    my %arg           = @ARG;
    my $path          = $arg{path}      || die "$id: Missing arg PATH";
    my $file          = $arg{file}      || die "$id: Missing arg FILE";
    my $prefix        = $arg{prefix}    || '';
    my $postfix       = $arg{postfix}   || '';
    my $overwrite     = $arg{overwrite} || '';

    my ( $stat, @files );

    $debug and warn "$id: PATH $path, FILE $file\n";

    if ( -f $path  and  not -d $path )
    {
        if ( $CHECK_NEWEST )
        {
            my @dir = DirContent dirname( $path );

            if ( @dir )
            {
                my $base = dirname($path);
                $file = LatestVersion basename($path) , \@dir;
                $path = $base . "/" . $file;
            }
            else
            {
                $verb and print "$id: Can't set newest $file";
            }
        }

        $file = $prefix . $file . $postfix;

        $debug and warn "$id: FileCopy $path => $file\n";

        unless ( copy($path, $file)  )
        {
            print "$id: FileCopy $path => $file $ERRNO";
        }
        else
        {
            push @files, $file;
        }
    }
    else
    {
        my @tmp = DirContent $path;

        local *FILE;

        $file =~ s,/,!,g;

        if ( -e $file  and  not $overwrite )
        {
            print "$id: [ignored, exists] $file\n";
            return;
        }

        unless ( open FILE, "> $file" )
        {
            print "$id: can't write $file $ERRNO\n";
            return;
        }

        print FILE join "\n", @tmp;
        close FILE;

        push @files, $file;
    }

    ( $stat, @files );
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Run Some self tests. This is for developer only
#
#   INPUT PARAMETERS
#
#       none
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub TestDriverSfMirror ()
{
        my $id = "$LIB.TestDriverSfMirror";
        $debug = 3 unless $debug;

        my $str = << "EOF";

        <caption>
                Download Mirrors
        </caption>
        <tr>
                <th>
                        Host
                </th>
                <th>
                        Location
                </th>
                <th>
                        Continent
                </th>
                <th>
                        Download
                </th>
        </tr>   <tr class="odd">
                <td><a href="http://www.optusnet.com.au"><img alt="optusnet logo
" border="0" src="http://images.sourceforge.net/prdownloads/optusnet_100x34.gif"
></a></td>
                <td>Sydney, Australia</td>
                <td>Australia</td>
                <td><a href="/bogofilter/bogofilter-1.0.0.tar.bz2?use_mirror=opt
usnet"><b>Download</b></a></td>
        </tr>   <tr >
                <td><a href="http://www.mesh-solutions.com/sf/"><img alt="mesh logo" border="0" src="http://images.sourceforge.net/prdownloads/mesh_100_34_3.gif"></a></td>
                <td>Duesseldorf, Germany</td>
                <td>Europe</td>
                <td><a href="/bogofilter/bogofilter-1.0.0.tar.bz2?use_mirror=mesh"><b>Download</b></a></td>
        </tr>   <tr class="odd">
                <td><a href="http://www.mirrorservice.org/help/introduction.html"><img alt="kent logo" border="0" src="http://images.sourceforge.net/prdownloads/ukms-button-100x34.png"></a></td>
                <td>Kent, UK</td>
                <td>Europe</td>
                <td><a href="/bogofilter/bogofilter-1.0.0.tar.bz2?use_mirror=kent"><b>Download</b></a></td>
        </tr>   <tr >
                <td><a href="http://www.heanet.ie"><img alt="heanet logo" border="0" src="http://images.sourceforge.net/prdownloads/heanet_100x34.gif"></a></td>
                <td>Dublin, Ireland</td>
                <td>Europe</td>
                <td><a href="/bogofilter/bogofilter-1.0.0.tar.bz2?use_mirror=heanet"><b>Download</b></a></td>
        </tr>   <tr class="odd">
                <td><a href="http://www.ovh.com"><img alt="ovh logo" border="0"
src="http://images.sourceforge.net/prdownloads/ovh_100x34.jpg"></a></td>
                <td>Paris, France</td>
                <td>Europe</td>
                <td><a href="/bogofilter/bogofilter-1.0.0.tar.bz2?use_mirror=ovh"><b>Download</b></a></td>
        </tr>   <tr >
                <td><a href="http://www.puzzle.ch/sourceforge.net/"><img alt="puzzle logo" border="0" src="http://images.sourceforge.net/prdownloads/puzzleitc_100x34.gif"></a></td>
                <td>Bern, Switzerland</td>
                <td>Europe</td>
                <td><a href="/bogofilter/bogofilter-1.0.0.tar.bz2?use_mirror=puzzle"><b>Download</b></a></td>

EOF

    print "$id: UrlSfMirrorParse\n";

    UrlSfMirrorParse $str;
}

sub TestDriverSfMirror ()
{
    my $id = "$LIB.TestDriverSfMirror";

    $debug = 6   unless $debug;

    my $ua  = new LWP::UserAgent;
    my $url = "http://prdownloads.sourceforge.net/"
            . "bogofilter/bogofilter-0.9.1.tar.bz2";

    print "$id: url $url\n";

    UrlHttpManipulate -useragent => $ua, -url => $url;
}

sub SelfTest ()
{
    my $id = "$LIB.SelfTest";

    $debug = 1   unless $debug;

    my (@files, $file, $i);
    local $ARG;

    # ............................................................ X ...
    $i++;

    $file = "artist-1.1-beta1.tar.gz",

    print "$id: [$i] LatestVersion ", "." x 40, "\n"  ;

    @files = qw
    (
        mailto:tab@lysator.liu.se
        emacs-shapes.gif
        emacs-shapes.html
        emacs-a.gif
        emacs-a.html
        emacs-rydmap.gif
        emacs-rydmap.html
        COPYING
        artist-1.2.3.tar.gz
        artist.el
        mailto:kj@lysator.liu.se
        mailto:jdoe@example.com
        http://st-www.cs.uiuc.edu/~chai/figlet.html
        artist-1.2.1.tar.gz
        artist-1.2.tar.gz
        artist-1.1.tar.gz
        artist-1.1a.tar.gz
        artist-1.1-beta1.tar.gz
        artist-1.0.tar.gz
        artist-1.0-11.tar.gz
        mailto:tab@lysator.liu.se
    );

    LatestVersion $file, \@files;

    # ............................................................ X ...
    $i++;

    $file = "irchat-900625.tar.gz";

    print "$id: [$i] LatestVersion ", "." x 40, "\n"  ;

    @files = qw
    (
        ./dist/irchat/irchat-20001203.tar.gz
        ./dist/irchat/irchat-19991105.tar.gz
        ./dist/irchat/irchat-980625-2.tar.gz
        ./dist/irchat/irchat-980128.tar.gz
        ./dist/irchat/irchat-971212.tar.gz
        ./dist/irchat/irchat-3.04.tar.gz
        ./dist/irchat/irchat-3.03.tar.gz
        ./dist/irchat/irchat-3.02.tar.gz
        ./dist/irchat/irchat-3.01.tar.gz
        ./dist/irchat/irchat-3.00.tar.gz
    );

    LatestVersion $file, \@files;

    # ............................................................ X ...
    $i++;

    $file = "bogofilter-0.9.1.tar.gz";

    print "$id: [$i] LatestVersion ", "." x 40, "\n"  ;

    @files = qw
    (
        http://freshmeat.net
        http://newsletters.osdn.com
        http://ads.osdn.com/?ad_id=2435&amp;alloc_id=5907&amp;op=click
        http://sourceforge.net
        http://sf.net
        http://sf.net/support/getsupport.php
        /bogofilter/?sort_by=name&sort=desc
        /bogofilter/?sort_by=size
        /bogofilter/?sort_by=date
        /bogofilter/..
        /bogofilter/ANNOUNCE
        /bogofilter/ANNOUNCE-0.94.12
        /bogofilter/Judy-0.0.2-1.i386.rpm
        /bogofilter/Judy-0.04-1.i386.rpm
        /bogofilter/Judy-0.04-1.src.rpm
        /bogofilter/Judy-devel-0.04-1.i386.rpm
        /bogofilter/Judy_trial.0.0.4.src.tar.gz
        /bogofilter/NEWS
        /bogofilter/NEWS-0.10
        /bogofilter/NEWS-0.10.0
        /bogofilter/NEWS-0.11
        /bogofilter/bogofilter-0.10.0-1.i586.rpm
        /bogofilter/bogofilter-0.10.0-1.src.rpm
        /bogofilter/bogofilter-0.10.0.tar.gz
        /bogofilter/bogofilter-0.96.6-1.src.rpm
        /bogofilter/bogofilter-0.96.6.tar.bz2
        /bogofilter/bogofilter-0.96.6.tar.gz
        /bogofilter/bogofilter-1.0.0-1.i586.rpm
        /bogofilter/bogofilter-1.0.0-1.src.rpm
        /bogofilter/bogofilter-1.0.0.tar.bz2
        /bogofilter/bogofilter-1.0.0.tar.gz
        /bogofilter/bogofilter-faq.html
        /bogofilter/bogofilter-static-0.13.1-1.i586.rpm
        /bogofilter/bogofilter-static-0.13.2-1.i586.rpm
        /bogofilter/bogofilter-static-0.13.2.1-1.i586.rpm
    );

    LatestVersion $file, \@files;

    # ............................................................ X ...
    $i++;

    print "$id: [$i] FileDeCompressedCmd ", "." x 40, "\n"  ;

    for ( qw
    (
        1.tar 1.tar.gz 1.tgz
        2.bz2 2.tar.bz2
        3.zip
        3.rar
    ))
    {
        eval { FileDeCompressedCmd $ARG };
        print $EVAL_ERROR  if  $EVAL_ERROR;
    }

    exit;
}

# ****************************************************************************
#
#   DESCRIPTION
#
#
#
#   INPUT PARAMETERS
#
#       \@data      Configuration file content
#
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub Main ($ $)
{
    my $id = "$LIB.Main";

    my ( $TAG_NAME, $data ) = @ARG;

    if ( $TAG_NAME )
    {
        $debug  and  warn "$id: Tag name search [$TAG_NAME]\n";
    }

    #   This is an old relict and not used

    my %EXTRACT_HASH =
    (
          '\.tar\.gz$'  => "gzip -d -c %s | tar xvf -"
        , '\.gz$'       => "gzip -f -d %s"
        , '\.bz2$'      => "bzip2 -f -d %s"
        , '\.tar$'      => "tar xvf %s"
        , '\.tgz$'      => "tar -zxvf %s"               # GNU TAR
        , '\.zip$'      => "unzip %s"
    );

    # ............................................... prepare output ...

    if ( $OUT_DIR )
    {
        $verb           and  print "$id: chdir $OUT_DIR\n";
        chdir $OUT_DIR  or   die   "$id: chdir $OUT_DIR $ERRNO";
    }

    my $date  = DateYYYY_MM_DD();
    my $count = 0;
    my ( %URL_ERROR_HASH , %URL_ERROR_REASON_HASH  );
    my $TagLine;

    local $ARG;

    for ( @$data )
    {
        chomp;
        my $line = $ARG;

        s/^\s*[#].*$//;                         # Kill comments
        next if /^\s*$/;                        # ignore empty lines

        # ............................................ Variable defs ...
        # todo: should be removed, this was for gz = 'command'

        my %variables;
        %variables =  /'(\S+)'\s*=\s*(.*)/g;

        while ( my($var, $val) = each %variables )
        {
            $debug  and  warn "$id:\t\t$var = $val\n";
            $EXTRACT_HASH{ $var } = $val;
        }

        # ............................................... directives ...

        my $LINE = $ARG;        # make a secure copy

        my $new           = $CHECK_NEWEST;
        my $unpack        = $EXTRACT;
        my $overwrite     = $OVERWRITE;
        my $contentRegexp = $CONTENT_REGEXP;
        my $mirror        = $MIRROR;

        $TagLine = $ARG if /tag\d+:/;   # Remember tag name

        my $pass       = ExpandVars($1) if /\bpass:\s*(\S+)/;
        my $login      = $1             if /\blogin:\s*(\S+)/;
        my $regexp     = $1             if /\bregexp:\s*(\S+)/;
        my $regexpNo   = $1             if /\bregexp-no:\s*(\S+)/;
           $new        = 1              if /\bnew:/;
           $unpack     = 1              if /\bx:/;
           $unpack     = -noroot        if /\bxx:/;
        my $xopt       = $1             if /\bxopt:\s*(\S+)/;

        my $lcd        = $1    if /lcd:\s*(\S+)/;
           $overwrite  = 1     if /\bo(verwrite)?:/;
        my $vregexp    = $1    if /\bvregexp:\s*(\S+)/;
        my $fileName   = $1    if /\bfile:\s*(\S+)/;
        my $rename     = $1    if /\brename:\s*(\S+)/;
           $mirror     = $1    if /\bmirror:\s*(\S+)/;

        my $pageRegexp = $1    if /\bpregexp:\s*(\S+)/;
        $contentRegexp = $1    if /\bcregexp:\s*(\S+)/;

        my $conversion = -text if /\btext:/;

        if ( /\bco?nv:\s*(\S+)/ )  # old implementation used tag <cnv:>
        {
            local $ARG = $1;

            if ( /te?xt/i )
            {
                $conversion = -text
            }
            else
            {
                warn "$id: Unknown conversion [$ARG] [$line]";
            }
        }

        my $plainPage;

        if ( /\bpage:/ )
        {
            $plainPage  = 1;

            if ( /\bpage:\s*find/i )
            {
                $plainPage  = -find;
            }
        }

        #   "lcd-ohio" is valid tag name, but "lcd" is our
        #   directive. Accept word names after OUR directives.

        if ( $verb and  not /print:/ and  /(?:^|\s)(:[-a-z]+)\b/ )
        {
            print "$id: [WARNING] directive, leading colon? [$1] $ARG\n";
        }

        if ( $lcd )
        {
            $debug > 2 and  print "$id: LCD $lcd\n";
            DirectiveLcd -dir   => $lcd
                       , -mkdir => $LCD_CREATE   unless $NO_LCD;
        }

        # ................................................... regexp ...

        if ( defined $URL_REGEXP )
        {
            if ( /$URL_REGEXP/o )
            {
                $debug and  warn "$id: REGEXP match [$URL_REGEXP] $ARG\n"
            }
            else
            {
                $debug > 3 and  warn "$id: [regexp ignored] $ARG\n";
                next;
            }
        }

        if ( defined $TAG_REGEXP )
        {
            my $stop;
            ($ARG, $stop) = TagHandle $ARG, $TAG_NAME;
            last  if  $stop;
            next  if  $ARG eq '';
        }

        # ................................................. grab url ...

        $ARG = ExpandVars $ARG  if /\$/  and ! $rename;

        if ( $verb and /(print:\s*)(.+)/ )          # Print user messages
        {
            print "$TagLine: $2\n";
            next;
        }

        m,^\s*((https?|ftp|file):/?(/([^/\s]+)(\S*))),;

        unless ( $1  and  defined $2 )
        {
            if ( /https/ )
            {
                warn "$id: https is not supported, just http://";
            }

            $debug  and  warn "$id: [skipped] not URL: $line [$ARG]\n";
            next;
        }

        # ............................................... components ...

        my $url        = $1;
        my $type       = $2;
        my $path       = $3;
        my $site       = $4;
        my $sitePath   = $5;

        #   Remove leading slash if we log with real username.
        #   The path is usually relative to the directory under LOGIN.
        #
        #   For anonymous, the path is absolute.

        $sitePath =~ s,^/,,     if $login;

        my $origFile = $sitePath;

        if ( $type eq 'https' )
        {
            eval "use Crypt::SSLeay";

            if ( $EVAL_ERROR )
            {
                warn "http needs Crypt::SSLeay.pm [$EVAL_ERROR]";
                next;
            }
        }

        my $file;

        #   The page:find command may instruct to search
        #
        #   http://some.com/~foo
        #   http://some.com/
        #
        #   Do not consider those to contain filename part

        if (
             $plainPage ne -find
             or ( $url !~ m,/$, )
             or ( $url !~ m,/[~][^/]+$, )
           )
        {
            ($file = $url) =~ s,^\s*\S+/,,;

            $file = $fileName               if $fileName ne '';
        }

        if ( /http/  and  $file eq ''   and  not $plainPage )
        {
            $file = $path . "000root-file";
        }

        $debug and print "$id: VARIABLES\n"
            , "\tURL        = $url\n"
            , "\tFILE       = $file\n"
            , "\tFILE_NAME  = $fileName\n"
            , "\tTYPE       = $type\n"
            , "\tPATH       = $path\n"
            , "\tSITE       = $site\n"
            , "\tSITE_PATH  = $sitePath\n"
            , "\tCONVERSION = $conversion\n"
            ;

        my $saveopt;

        if ( $NO_SAVE == 0  and /save:\s*(\S+)/ )
        {
            $saveopt = $1;
            $file    = $1;
        }

        my $postfix = $POSTFIX              if  defined $POSTFIX;
        my $prefix  = $PREFIX               if  defined $PREFIX;

        $prefix  = $site . "::" . $prefix   if  $PREFIX_WWW;
        $prefix  = $date . "::" . $prefix   if  $PREFIX_DATE;

        $file = $prefix . $file . $postfix;

        # .................................................... do-it ...

        $debug and warn "$id: <$type> <$site> <$path> <$url> <$file>\n";

        $ARG   = $type;
        my ($stat, @files);

        # ******************************************************************
        # Set global which is used in error messages or if program must die.

        $CURRENT_TAG_LINE = $line;

        # *******************************************************************

        $verb  and  print "$id: DIRECTORY ", cwd(), "\n";

        if ( /http/ )
        {
            $count++;

            if ( $plainPage eq -find   and  not $pageRegexp )
            {
                die  "$id: no <pregexp:> directive"
                    , " LINE => [$line]"
                    ;
            }

            if ( $pageRegexp  and not $plainPage )
            {
                $debug  and  print "$id: Implicit <page:find> [$line]\n";
                $plainPage = -find;
            }

            if ( ($plainPage ne -find)  and  $pageRegexp  and not $file )
            {

                $debug and print "$id: Expecting [page:find]",
                    , " for non-named download file"
                    , " [$url]"
                    , " LINE => [$line]"
                    ;

                $plainPage = -find;
            }
            elsif ( $plainPage ne -find and $pageRegexp )
            {
                $plainPage = -find;
            }

            if ( $saveopt  and  $pageRegexp   and  $verb > 1 )
            {
                chomp;
                warn  "$id: [WARNING] mixing <save:> and <pregexp:>"
                    , " May give multiple answers. Use absolute filename"
                    , " URL with <save:> LINE => [$line]"
                    ;
            }

            if ( $pageRegexp  and not $plainPage )
            {
                warn "$id: [WARNING] no page: directive [$ARG]\n";
            }

            if ( $pageRegexp  and not $file  and ($plainPage ne -find))
            {
                warn "$id: [WARNING] no file: directive. [$ARG]\n";
            }

            if ( $pageRegexp  and not $file  and ($plainPage ne -find))
            {
                warn "$id: [WARNING] no file: directive. [$ARG]\n";
            }

            ($stat, @files) = UrlHttp
                  url           => $url
                , file          => $file
                , regexp        => $regexp
                , regexpNo      => $regexpNo
                , proxy         => $PROXY
                , errUrlHashRef => \%URL_ERROR_HASH
                , errExplanationHashRef => \%URL_ERROR_REASON_HASH
                , new           => $new
                , stdout        => $STDOUT
                , versionRegexp => $vregexp
                , plainPage     => $plainPage
                , pageRegexp    => $pageRegexp
                , contentRegexp => $contentRegexp
                , conversion    => $conversion
                , rename        => $rename
                , save          => $saveopt
                , origLine      => $line
                , unpack        => $unpack
                , overwrite     => $overwrite
                , mirror        => $mirror
                ;
        }
        elsif ( /ftp/ )
        {
            $count++;

            my ($pproto, $ssite, $ddir, $ffile) = SplitUrl $url;

            if ( $ffile  and  $ffile !~ /[.]/ )
            {
                #   ftp://some.com/dir/dir
                warn "$id: Did you forgot trailing slash? [$line]";
            }

            if ( $regexp )
            {
                #   There can't be serched "file" if regexp is used.
                $origFile = '';
                $file     = '';
                $sitePath = Slash $sitePath;
            }

            if ( $fileName  and  ! $origFile )
            {
                $origFile = $fileName;   # the "new" search.
            }

            if ( $pageRegexp )
            {
                chomp;
                warn  "$id: [WARNING] mixing ftp:// and <pregexp:>"
                    , " Did you mean <regexp:> instead?"
                    , " LINE => [$line]"
                    ;
            }

            #   Directory path given, so reset the file
            $origFile = ''  if  $origFile =~ m,/$,;

            ($stat, @files ) = UrlFtp
                      site       => $site
                    , url        => $url
                    , path       => $sitePath
                    , getFile    => $origFile
                    , saveFile   => $file
                    , regexp     => $regexp
                    , regexpNo   => $regexpNo
                    , firewall   => $FIREWALL
                    , login      => $login
                    , pass       => $pass
                    , new        => $new
                    , stdout     => $STDOUT
                    , conversion => $conversion
                    , rename     => $rename
                    , origLine   => $line
                    , unpack     => $unpack
                    , overwrite => $overwrite
                    ;
        }
        elsif ( /file/ )
        {
            ($stat, @files) = UrlFile path      => $path
                                    , file      => $origFile
                                    , prefix    => $prefix
                                    , postfix   => $postfix
                                    , overwrite => $overwrite
                                    ;
            $count++;
        }

        # .............................................. conversion ...

        if ( $conversion eq -text )
        {
            for my $file ( @files )
            {
                FileHtml2txt $file;
            }
        }
        elsif ( $conversion )
        {
            warn "$id: Unknown conversion [$conversion]";
        }

        # .................................................. &unpack ...

        if ( $unpack  and  not $NO_EXTRACT )
        {
            $debug   and  print "$id: extracting [@files]\n";
            @files   and  Unpack \@files, \%EXTRACT_HASH, $unpack, $xopt;
        }
    }

    if ( not $count  and  $verb)
    {
        $URL_REGEXP
            and printf "$id: No labels matching regexp [%s]\n",
                $URL_REGEXP;

        @TAG_LIST
            and printf "$id: Nothing to do. No tag matching [%s]\n",
                join(' ', @TAG_LIST);

        if ( @CFG_FILE == 0 )
        {
            print "$id: Nothing to do. Use config file or give URL? ",
                  "Did you mean --Tag for [@ARGV]?\n"
                  ;
        }
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Parse VAR = VALUE statements. The values are put to %ENV
#
#   INPUT PARAMETERS
#
#       @lines
#
#   RETURN VALUES
#
#       none
#
# ****************************************************************************

sub ConfigVariableParse (@)
{
    my $id   = "$LIB.ConfigVariableParse";
    my @data = @ARG;

    local $ARG;

    for ( @data )
    {
        s/#.*//;

        next unless /\S/;
        next if /rename:/;  # Skip Perl command line, which may contain '='

        my %variables = /(\S+)\s*=\s*(\S+)/g;

        while ( my($var, $val) = each %variables )
        {
            #   Save values to environment.
            #   Ignore some URLS, that look like variable assignments:
            #   print http://example.com/viewcvs/vc-svn.el?rev=HEAD

            $debug > 2 and  print "$id:[$var] = [$val] [$ARG]\n";

            if ( $var =~ m![?,.&:]!i )
            {
                $debug > 2  and  print "$id: IGNORED. Wasn't a variable\n";
                next;
            }

            $ARG = $val;

            $val = ExpandVars $ARG;

            $debug > 2   and  print "$id: assigning ENV $var => $val\n";

            $ENV{ $var } = $val;
        }
    }
}

# ****************************************************************************
#
#   DESCRIPTION
#
#       Read Configuration file contents. The directive can be in format:
#
#           include <file>          Read from User's current dir
#           include <$HOME/file>    Expand $HOME
#           include </etc/file>     Absolute path
#           include <THIS/file>     Read from same directory where the
#                                   current file with includes reside.
#
#   INPUT PARAMETERS
#
#       $file
#
#   RETURN VALUES
#
#       @lines
#
# ****************************************************************************

sub ConfigRead ( $ );   # Recursive call needs prototyping

{
    my %staticInclude;  # already included files, do not read again
    my $staticPwd;      # Current pwd

sub ConfigRead ( $ )
{
    my $id   = "$LIB.ConfigRead";
    my $file = shift;

    $verb > 2 and  print "$id: Reading config [$file]\n";

    $file = PathConvertSmart $file;

    $verb > 2 and  print "$id: Reading config CONVERSION [$file]\n";

    if ( $debug > 1 )
    {
        print "$id: input FILE $file "
            , ExpandVars($file)
            , " ["
            , join(' ', %staticInclude)
            , "]\n"
            ;
    }

    # .............................................. already included ...
    # In windows c:/dir  is same as C:/DIR

    my $check = $file;
    $check    = lc $file  if $WIN32;

    if ( exists $staticInclude{$check} )
    {
        $debug  and   print "$id: skipped, already included $file\n";
        return;
    }

    # .......................................................... pwd ...

    my $dir = dirname $file;

    $staticPwd = cwd()  unless $staticPwd;      # set inital value

    $debug > 2  and  print "$id: PWD $staticPwd\n";

    if ( -f $file  and  not $dir =~ /^.$|THIS/ )
    {
        my $orig = cwd();

        # Peek where are we going, handles ../../ cases too

        if ( chdir $dir )
        {
            $staticPwd = cwd();     # ok, set "THIS" location
            chdir $orig;            # Back to original directory
        }
    }
    elsif ( $dir eq "THIS" )
    {
        $file = "$staticPwd/" . basename $file;
        $debug  and  print "$id: THIS set to $file\n";
    }

    # .......................................................... read ...

    my ($lineArrRef, $status);

    if ( -f  $file )
    {
        ($lineArrRef, $status) = FileRead $file;
    }
    else
    {
        $status = "File does not exist $file";
    }

    $staticInclude{ $file } = 1;

    if ( $status )
    {
        $verb > 0 and  warn "$id: SKIPPED, Can't include $file";
        return;
    }

    if ( @$lineArrRef )
    {
        ConfigVariableParse @$lineArrRef;

        local $ARG;
        my @lines;

        for my $line ( @$lineArrRef )
        {
            push @lines, $line;

            #   Skip INCLUDE statements that have been commented out.

            $ARG  = $line;

            s/#.*//;

            next unless /[a-z]/i;

            #   include <this>
            #   include <this>
            #   include < this/here >
            #   include < c:/Progrm Files/this/here >

            if ( /include\s+<\s*(.*[^\s]+)\s*>/i )
            {
                my $inc  = $1;

                my $path    = ExpandVars $inc;
                my $already = exists $staticInclude{$path};

                $debug > 1 and
                    print "$id: RECURSIVE INCLUDE [$path] [$inc]"
                    , " already flag [$already]\n";

                unless ( $already )
                {
                    push @lines, ConfigRead $path;

                    $path  = lc $path   if $WIN32;

                    $staticInclude{ $path } = 1;
                }
            }
        }
        @$lineArrRef = @lines;

        $debug > 4  and  print "$id: READ config $file\n@lines\n\n";

    }
    else
    {
        $debug  and  print "$id: Nothing found from $file\n";
    }

    @$lineArrRef;
}}

# }}}
# {{{ more

# ****************************************************************************
#
#   DESCRIPTION
#
#       Start, the start of the program.
#
#   INPUT PARAMETERS
#
#       None
#
#   RETURN VALUES
#
#       None
#
# ****************************************************************************

sub Boot ()
{
    Initialize();
    HandleCommandLineArgs();

    my $id = "$LIB.Start";

    # ......................................................... args ...

    $debug > 2  and  PrintHash "$id: begin ENV", %ENV;

    #   Convert any command line arguments as if they would appear
    #   in configuration file:
    #
    #   --site-regexp gz http://there.at/
    #
    #   --> http://there.at  page: pregexp:gz

    for my $arg ( @ARGV )
    {
        if ( $SITE_REGEXP )
        {
            if ( /ftp/i )
            {
                $arg .= " regexp:$SITE_REGEXP";
            }
            else
            {
                $arg .= " page: pregexp:$SITE_REGEXP";
            }
        }
    }

    my @data;

    if ( $CFG_FILE_NEEDED and  @CFG_FILE )
    {
        for my $arg ( @CFG_FILE )
        {
            my @lines = ConfigRead $arg;
            push @data, @lines;
        }

        if ( $debug > 4 )
        {
            print "$id: CONFIG-FILE-CONTENT-BEGIN\n"
                , @data
                , "$id: CONFIG-FILE-CONTENT-END\n"
                ;
        }
    }

    $debug > 4  and  PrintHash "$id: end ENV", %ENV;

    push @data, @ARGV   if @ARGV;       # Add command line URLs

    if ( @TAG_LIST )
    {
        for my $arg ( @TAG_LIST )
        {
            TagHandle undef, undef, "1-reset";
            Main $arg, \@data;
        }
    }
    else
    {
        Main "", \@data;
    }
}

sub Test ()
{
    my $str = join '', <>;
    $debug  = 1;
    print UrlHttpParseHref $str, "tar.gz";
}

Boot();

# }}}

0;
__END__