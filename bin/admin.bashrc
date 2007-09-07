# .......................................................................
#
#   $Id: admin.bashrc,v 1.7 2004/04/05 10:23:25 jaalto Exp $
#
#   These bash functions will help uploading files to Sourceforge project.
#   You need:
#
#       Unix        (Unix)  http://www.fsf.org/directory/bash.html
#                   (Win32) http://www.cygwin.com/
#       Perl 5.4+   (Unix)  http://www.perl.org
#                   (Win32) http://www.ativestate.com
#       t2html.pl   Perl program to convert text -> HTML
#                   http://www.cpan.org/modules/by-authors/id/J/JA/JARIAALTO/
#
#
#   This file is of interest only for the Admin or Co-Developer of
#   project.
#
#       http://sourceforge.net/projects/perl-webget
#       http://perl-webget.sourceforge.net/
#
#   Include this file to your $HOME/.bashrc and make the necessary
#   modifications:
#
#       SF_PERL_WEBGET_USER=<sourceforge-login-name>
#       SF_PERL_WEBGET_USER_NAME="FirstName LastName"
#       SF_PERL_WEBGET_EMAIL=<email address>
#       SF_PERL_WEBGET_ROOT=~/cvs-projects/perl-webget
#       SF_PERL_WEBGET_HTML_TARGET=http://perl-webget.sourceforge.net/
#
#       source ~/sforge/devel/perl-webget/bin/admin.bashrc
#
# .......................................................................

function sfperlwebgetinit ()
{
    local id="sfperlwebgetinit"

    local url=http://perl-webget.sourceforge.net/

    SF_PERL_WEBGET_HTML_TARGET=${SF_PERL_WEBGET_HTML_TARGET:-$url}
    SF_PERL_WEBGET_KWD=${SF_PERL_WEBGET_KWD:-"\
Perl, HTML, CSS2, conversion, webget"}
    SF_PERL_WEBGET_DESC=${SF_PERL_WEBGET_DESC:-"Perl webget converter"}
    SF_PERL_WEBGET_TITLE=${SF_PERL_WEBGET_TITLE:-"$SF_PERL_WEBGET_DESC"}
    SF_PERL_WEBGET_ROOT=${SF_PERL_WEBGET_ROOT:-""}


    if [ "$SF_PERL_WEBGET_USER" = "" ]; then
       echo "$id: Identity SF_PERL_WEBGET_USER unknown."
    fi


    if [ "$SF_PERL_WEBGET_USER_NAME" = "" ]; then
       echo "$id: Identity SF_PERL_WEBGET_USER_NAME unknown."
    fi

    if [ "$SF_PERL_WEBGET_EMAIL" = "" ]; then
       echo "$id: Address SF_PERL_WEBGET_EMAIL unknown."
    fi
}



function sfperlwebgetdate ()
{
    date "+%Y.%m%d"
}

function sfperlwebgetfilesize ()
{
    #   put line into array ( .. )

    local line
    line=($(ls -l "$1"))

    #   Read 4th element from array
    #   -rw-r--r--    1 root     None         4989 Aug  5 23:37 file

    echo ${line[4]}
}

function sfperlwebget_ask ()
{
    #   Ask question from user. RETURN answer is "no".

    local msg="$1"
    local answer
    local junk

    echo "$msg" >&2
    read -e answer junk

    case $answer in
        Y|y|yes)    return 0 ;;
        *)          return 1 ;;
    esac
}


function sfperlwebgetscp ()
{
    local id="sfperlwebgetscp"

    #   To upload file to project, call from shell prompt
    #
    #       bash$ sfperlwebgetscp <FILE>

    local sfuser=$SF_PERL_WEBGET_USER
    local sfproject=p/pe/perl-webget

    if [ "$SF_PERL_WEBGET_USER" = "" ]; then
        echo "$id: identity SF_PERL_WEBGET_USER unknown, can't scp files."
        return
    fi

    scp $* $sfuser@shell.sourceforge.net:/home/groups/$sfproject/htdocs/
}


function sfperlwebgetcmd ()
{
    #   To send command to the host. This lists the htdocs directory
    #
    #       bash$ sfperlwebgetcmd ls

    local sfuser=$SF_PERL_WEBGET_USER
    local sfproject=p/pe/perl-webget
    local dir=/home/groups/$sfproject/htdocs/

    if [ "$SF_PERL_WEBGET_USER" = "" ]; then
        echo "sfperlwebgetcmd: SF_PERL_WEBGET_USER unknown, can't scp files."
        return
    fi

    ssh $sfuser@shell.sourceforge.net "cd $dir; $*"
}



function sfperlwebgethtml ()
{
    local id="sfperlwebgethtml"

    #   To generate HTML documentation located in /doc directory, call
    #
    #       bash$ sfperlwebgethtml <FILE.txt>
    #
    #   To generate Frame based documentation
    #
    #        bash$ sfperlwebgethtml <FILE.txt> --html-frame
    #
    #   For simple page, like README.txt
    #
    #        bash$ sfperlwebgethtml <FILE.txt> --as-is


    local input="$1"

    if [ "$input" = "" ]; then
        echo "Usage:   $id FILE [html-options]"
        return
    fi

    if [ ! -f "$input" ]; then
        echo "$id: No file found [$input]"
        return
    fi



    local opt

    if [ "$2" != "" ]; then
        opt="$2"
    fi

    echo "$id: Htmlizing $file $opt $size"

    perl -S t2html.pl                                               \
          $opt                                                      \
          --button-top "$SF_PERL_WEBGET_HTML_TARGET"                \
          --title  "$SF_PERL_WEBGET_TITLE"                          \
          --author "$SF_PERL_WEBGET_USER_NAME"                      \
          --email  "$SF_PERL_WEBGET_EMAIL"                          \
          --meta-keywords "$SF_PERL_WEBGET_KWD"                     \
          --meta-description "$SF_PERL_WEBGET_DESC"                 \
          --name-uniq                                               \
          --Out                                                     \
          $input

    if [ -d "../../html/"  ]; then
        mv *.html ../../html/
    elif [ -d "../html/"  ]; then
        mv *.html ../html/
    else
        echo "$id: Can't move generated HTML to ../html/"
    fi


}


function sfperlwebgethtmlall ()
{
    local id="sfperlwebgethtmlall"

    #   loop all *.txt files and generate HTML
    #   If filesize if bigger than 15K, generate Framed HTML page.

    local dir=$SF_PERL_WEBGET_ROOT/doc/tips

    (
        cd $dir || return
        echo "Source dir:" $(pwd)

        for file in *.txt;
        do
             local size=$(sfpmdocfilesize $file)

             if [ $size -gt 15000 ]; then
               opt=--html-frame
             fi

             sfpmdochtml $file $opt

         done
    )

}

function sfperlwebgetdoc ()
{
    local id=sfperlwebgetdoc

    #   Generate documentation.

    local dir=$SF_PERL_WEBGET_ROOT

    if [ ! -d "$dir" ]; then
       echo "$id: invalid SF_PERL_WEBGET_ROOT"
       return
    fi

    cd $dir/bin

    local base
    local out

    for file in *.pl
    do
        base=${file%%.*}
        out=$base.1
        echo "$id: Making $out"
        perl $file --help-man  > $out

        out=../doc/html/$base.html
        echo "$id: Making $out"

        perl $file --help-html > $out

    done

    #   The Perl POD maker leaves behind .x~~ files. Delete them

    for file in *~
    do
        rm $file
    done

    echo "$id: Documentation updated."
}

function sfperlwebget_release_check ()
{
    #   Remind that that everything has been prepared
    #   Before doing release

    if sfperlwebget_ask 'Run cvs -nq up (y/N)?'
    then
        echo "Running..."
        ( cd $SF_PERL_WEBGET_ROOT && cvs -nq up )
    fi


    if sfperlwebget_ask '[sfperlwebgetdoc] Generate manuals (y/N)?'
    then
        echo "Running..."
        sfperlwebgetdoc
    fi

}


function sfperlwebget_release ()
{
    local id="sfperlwebget_release"

    local dir=/tmp

    if [ ! -d $dir ]; then
        echo "$id: Can't make release. No directory [$dir]"
        return
    fi

    if [ ! -d "$SF_PERL_WEBGET_ROOT" ]; then
        echo "$id: No SF_PERL_WEBGET_ROOT [$SF_PERL_WEBGET_ROOT]"
        return
    fi

    sfperlwebget_release_check

    local opt=-9
    local cmd=gzip
    local ext1=.tar
    local ext2=.gz

    local base=perl-webget
    local ver=$(sfperlwebgetdate)
    local tar="$base-$ver$ext1"
    local file="$base-$ver$ext1$ext2"

    if [ -f $dir/$file ]; then
        echo "$id: Removing old archive $dir/$file"
        rm $dir/$file
    fi


    (

        local todir=$base-$ver
        local tmp=$dir/$todir

        if [ -d $tmp ]; then
            echo "$id: Removing old archive directory $tmp"
            rm -rf $tmp
        fi

        cp -r $SF_PERL_WEBGET_ROOT $dir/$todir

        cd $dir

        find $todir -type f                     \
            \( -name "*[#~]*"                   \
               -o -name ".*[#~]"                \
               -o -name ".#*"                   \
               -o -name "*elc"                  \
               -o -name "*tar"                  \
               -o -name "*gz"                   \
               -o -name "*bz2"                  \
               -o -name .cvsignore              \
            \) -prune                           \
            -o -type d \( -name CVS \) -prune   \
            -o -type f -print                   \
            | xargs tar cvf $dir/$tar

        echo "$id: Running $cmd $opt $dir/$tar"

        $cmd $opt $dir/$tar

        echo "$id: Made release $dir/$file"
        ls -l $dir/$file
    )

    echo "$id: Call ncftpput upload.sourceforge.net /incoming $dir/$file"

}

sfperlwebgetinit                       # Run initializer


export SF_PERL_WEBGET_HTML_TARGET
export SF_PERL_WEBGET_KWD
export SF_PERL_WEBGET_DESC
export SF_PERL_WEBGET_TITLE
export SF_PERL_WEBGET_ROOT


# End of file
