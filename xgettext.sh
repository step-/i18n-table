#!/bin/sh

# =============================================================================
# xgettext.sh - xgettext-based extraction tool for i18n_table
# (C)2016-2023, step - https://github.com/step-/i18n-table
# License: GNU GPL3 or MIT
# Version: 20230614
# =============================================================================

# This file runs the standard xgettext command to extract MSGIDs from a shell
# script file.  In addition it extracts MSGIDs from an occurrence of command
# "gettext -es" that is found inside a function named "i18n_table".

# LIMITATION: Currently, this script can parse strings delimited by double
# quotes only.  Single quotes and the `$''` syntax are not supported.
# Contact me if you need this feature for your project.

usage() { # {{{1
  cat << 'EOF'
Motivation:
A single call to 'gettext -es' with multiple arguments is more efficient than
multiple calls to gettext with a single argument. Unfortunately, the standard
xgettext(1) tool can't detect the MSGIDs when the shell command is `$(gettext
-es "msgid1"...)`.  This tool augments xgettext(1) with such capability.

Usage: xgettext.sh [OPTIONS] ['--' xgettext_OPTIONS ...] FILE"

OPTIONS:
  --help    Print this message and exit. See also xgettext --help.
  --no-c1   Don't output [c1] lines.
  --no-c2   Don't output [c2] lines.
  --test    Generate test translation.
xgettext_OPTIONS:
  Any xgettext(1) option.  Default presets: -o - -LShell

If the script includes a function named i18n_table:
[c1] Comment lines within the i18n_table body are reproduced with prefix "#."
[c2] For lines starting with "read i18n_<string>", i18n_<string> is
     prefixed with "#." then output above its corresponding MSGID.

Location information is generated for lines [c0] and [c2] unless
xgettext_OPTIONS includes option --no-location.

Inside the `$(gettext -es ...)` block, a line that ends with "##" is ignored.
A line that ends with "<<<##" marks the start of a block of ignored lines,
which need not end with "##" themselves. The block ends at the next line that
ends with ">>>##".
EOF
}

# Parse options. {{{1
# Option format: -x[=parm] | --opt-x[=parm]
# Short options can't be combined together. Space can't substitute '=' before option value.
unset opt_no_c1 opt_no_c2 opt_no_location
while ! [ "${1#-}" = "$1" ]; do
  case "$1" in
    --RESERVED) # add more here |...|...
      usage
      echo "${0##*/}: : $(gettext 'option needs a value')" >&2
      exit 1 ;;
    --RESERVED=*) =${1#*=} opt_id=${1#*=} ;;
    -h|--help|-h=*|--help=*) usage "$1"; exit ;;
    --no-c1 ) opt_no_c1=1 ;;
    --no-c2 ) opt_no_c2=1 ;;
    --test ) opt_test=1 ;;
    --) shift; break ;;
    -*)
      usage
      echo "${0##*/}: : $(gettext 'unknown option')" >&2
      exit 1 ;;
  esac
  shift
done
case "$*" in *--no-location* ) opt_no_location=1 ;; esac

for a; do script="$a"; done
if ! [ -e "$script" ]; then
  usage >&2
  exit 1
fi

# Standard xgettext run. {{{1
xgettext ${IENC:+--from-code=$IENC} -L Shell "$@" -o - |
if [ "$opt_test" ]; then
  sed -e 's/\(; charset=\)CHARSET/\1utf-8/' -e 's/^"Language: /&en/'
else
  cat
fi |

# erase the output for "gettext -es", if any
awk '#{{{awk
/^#:/ { buf = $0 }
/^msgid "-es"$/ { getline; next } # erase this line, the one after and buf, if any
$0 !~ /^#:/ { if(buf) {print buf} ; print; buf = ""
} #awk}}}'

# Output for case $(gettext -es ...) {{{1
gawk -v NO_C1=$opt_no_c1 -v NO_C2=$opt_no_c2 \
  -v NO_LOC=$opt_no_location -v TEST=$opt_test '#{{{gawk

BEGIN {
  logfile = "/dev/null"
  #logfile = "/dev/stderr"
}

BEGIN {
  re_gettext_es_start     = @/^[ \t]*\$\(gettext -es/
  # includes possible shell comment
  re_gettext_es_end       = @/\)([ \t]*(#.*))?$/
  # allows MSGID to include escaped double quotes, e.g. "abc\"def"
  re_double_quoted_string = @/"(\\.|[^"])*"/
  re_msgid_end            = @/"[ \t]*\\$/
  re_msgid_continuation   = @/\\$/
  re_msgid_ignore_line    = @/##$/
  re_msgid_ignore_blk_on  = @/<<<##$/
  re_msgid_ignore_blk_off = @/>>>##$/
}

$0 ~ re_gettext_es_start {
  inside_gettext_es = 1
  print "line",NR,"start gettext_es block" > logfile
  next
}

inside_gettext_es && $0 ~ re_gettext_es_end {
  inside_gettext_es = 0
  print "line",NR,"end gettext_es block" > logfile
  delete C2
  nC2 = iC2 = 0
  next
}

# deal with line continuation inside gettext -es
inside_gettext_es {
  linenum = NR
  s = $0
  if(s ~ re_msgid_ignore_blk_on) {
    ignoring_block = 1
  }
  else if(s ~ re_msgid_ignore_blk_off) {
    ignoring_block = 0
  }
  if(ignoring_block || s ~ re_msgid_ignore_line) {
    print "=#("s")" > logfile
    next
  }
  else if(s ~ re_msgid_end) {
    print "=1("s")" > logfile
  }
  else if(s ~ re_msgid_continuation) {
    print ">+("s")" > logfile
    s0 = substr(s, 1, length(s) - 1)
    while(0 < (getline s) && s ~ re_msgid_continuation && s !~ re_msgid_end) {
      s0 = s0 substr(s, 1, length(s) - 1)
      print ">++("s0")" > logfile
    }
    s = s0 substr(s, 1, length(s) - 1)
    print "=+("s")" > logfile
  }
}
inside_gettext_es {
  print "got_line("s")" > logfile
  if (nA = patsplit(s, A, re_double_quoted_string)) {
    # each A[i], i=1...nA, is a string with exterior double quotes
    for(i = 1; i <= nA; i++) {
      loc_info = NO_LOC ? "" : ("#: " FILENAME ":" linenum)
      emit_c0(loc_info, A[i])
      loc_info = ""

      # i18n_table usage mandates for MSGID to end with "\n"
      # (otherwise MSGIDs and MSGSTRs get out of sync)
      if (A[i] !~ /"\\n"$|[^\\]\\n"$/) {
        printf "%s: near line %d: ERROR: MSGID does not end with \"\\n\".\n%s\n",
          FILENAME, linenum, A[i] > "/dev/stderr"
        exit 1
      }

      # bail out if a string matches "\n" anywhere else for the reasons above
      if (substr(A[i], 2, length(A[i]) -4) ~ /[^\\]\\n/) {
        printf "%s: near line %d: ERROR: \"\\n\" inside MSGID is not allowed.\n%s\n",
          FILENAME, linenum, A[i] > "/dev/stderr"
        exit 1
      }
    }
  }
  next
}

BEGIN {
  re_i18n_table       = @/^[ \t]*(function)?[ \t]*i18n_table[ \t]*\([ \t]*\)/
  re_read_block_start = @/^[ \t]*\{/
  re_read_block_end   = @/^[ \t]*\}[ \t]*<</
}

$0 ~ re_i18n_table {
  print "line",NR,"start i18n_table" > logfile
  inside_i18n_table = 1

  # some people write the function`s opening brace on a separate line
  if($0 !~ /\{/) {
    while(0 < getline && $0 !~ /^[ \t]*\{/)
      ;
  }
}

inside_i18n_table && $0 ~ /^\}/ {
  print "line",NR,"end i18n_table" > logfile
  inside_i18n_table = 0
  next
}

inside_i18n_table && $0 ~ re_read_block_start {
  print "line",NR,"start read block" > logfile
  inside_read_block = 1
  next
}

inside_read_block && $0 ~ re_read_block_end {
  inside_read_block = 0
  print "line",NR,"end read block" > logfile
  next
}

inside_read_block {
  s = $0
  if(!NO_C1 && match(s, /^[ \t]*#/)) { # [c1]
    sub(/[ \t]*#/, "#.", s)
    print s
    print "comment("s")" > logfile
  }
  else if(match(s, /read[ \t]+i18n_[^ \t]+/)) { # [c2]
    ++nC2
    if(!NO_C2) {
      m = substr(s, RSTART, RLENGTH)
      C2[nC2] = (NO_LOC ? "" : "#: "FILENAME":"NR "\n") "#. " substr(m, index(m, "i"))
      print "C2["nC2"]("C2[nC2]")" > logfile
    }
    # warn about gaps between "read i18n_" lines: these could be due to mispelling "i18n_"
    C2[nC2,"nr"] = NR
    if(nC2 > 1 && C2[nC2, "nr"] - C2[nC2 -1, "nr"] != 1) {
      printf "%s: lines %d-%d: warning: non-contiguous \"read i18n_...\" commands\n",
        FILENAME, C2[nC2 -1, "nr"], C2[nC2, "nr"] > "/dev/stderr"
    }
  }
  next
}

# emit_c0 prints a c0 line as well as any c1 and c2 lines that got accumulated
# before the c0 line; line has exterior double quotes.
function emit_c0(location, line,   i) {
  print "emit("location")("line")" > logfile
  print ""
  if(C2[++iC2]) { print C2[iC2] }
  if(location) { print location }
  print "msgid "line
  if(TEST) { print "msgstr \"[T]"substr(line, 2) }
  else     { print "msgstr \"\"" }
}
#awk}}}
' "$script"
