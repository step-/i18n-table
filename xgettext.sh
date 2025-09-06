#!/bin/sh

# =============================================================================
# xgettext.sh - xgettext-based extraction tool for i18n_table
# (C)2016-2023, step - https://github.com/step-/i18n-table
# License: GNU GPL3 or MIT
# Version: 20230614
# =============================================================================

usage() {
  cat << 'EOF'
This script runs the `xgettext` command to extract MSGIDs from a shell
file and also extracts MSGIDs from the `gettext -es` block within the
user-defined i18n_table() function. By enabling developers to replace
multiple scattered `gettext` calls with a single `gettext -es` run,
i18n_table.sh can improve script startup speed.

Limitation: Within i18n_table, xgettext.sh can parse double-quoted
strings but not single-quoted or the $'' bash syntax.

Usage: xgettext.sh [OPTIONS] ['--' xgettext_OPTIONS ...] FILE"

OPTIONS:
  --help    Print this message and exit. See also xgettext --help.
  --no-c1   Do not output [c1] lines ([c1] is defined below).
  --no-c2   Do not output [c2] lines ([c2] is defined below).
  --test    Generate a test translation.

The xgettext_OPTIONS environment variable may be used to pass options to
the internal `xgettext` command invocation, defaulting to `-o - -LShell`.

If FILE includes a function named i18n_table then:
[c1] Shell comment lines inside i18n_table will become "#." PO comments
     before their corresponding MSGIDs.
[c2] A "#. i18n_<string>" PO comment will be inserted before the
     MSGID for each shell line that starts with "read i18n_<string>".

If FILE contains an i18n_table function then:
[c1] Shell comment lines inside i18n_table convert to "#." PO comments
     before their MSGIDs.
[c2] A "#. i18n_<identifier>" PO comment is added before the MSGID for
    each shell line starting with "read i18n_<identifier>".

In the `gettext -es` sub-shell, lines ending with "##" are ignored. A block of
ignored lines starts with a line ending with "<<<##" and ends with the first
line ending with ">>>##". Lines inside the block do not need to end with "##".

EOF
}

# Parse options.
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

###########################
#  Standard xgettext run  #
###########################

xgettext ${IENC:+--from-code=$IENC} -L Shell "$@" -o - |
if [ "$opt_test" ]; then
  sed -e 's/\(; charset=\)CHARSET/\1utf-8/' -e 's/^"Language: /&en/'
else
  cat
fi |

# erase the output for "gettext -es", if any
awk '
###awk
/^#:/ { buf = $0 }
/^msgid "-es"$/ { getline; next } # erase this line, the one after and buf, if any
$0 !~ /^#:/ { if(buf) {print buf} ; print; buf = ""
}
###awk'

#######################################
#  Output for case $(gettext -es ...) #
#######################################

gawk -v NO_C1=$opt_no_c1 -v NO_C2=$opt_no_c2 \
  -v NO_LOC=$opt_no_location -v TEST=$opt_test '
###gawk
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
  # escaped shell special characters
  re_msgid_clean_escapes  = @/(\\\\)*\\[$`'\'']/
}

$0 ~ re_gettext_es_start {
  inside_gettext_es = 1
  print "line",NR,"start gettext_es block" > logfile
  next
}

inside_gettext_es && $0 ~ re_gettext_es_end {
  inside_gettext_es = 0
  print "line",NR,"end gettext_es block" > logfile
  delete C1
  nC1 = iC1 = 0
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

  # sometimes the function opening brace is on a separate line
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
    curr_c1_comment = curr_c1_comment "\n" s
    print "comment("s")" > logfile
  }
  else if(match(s, /read[ \t]+i18n_[^ \t]+/)) { # [c2]
    ++nC1
    if (curr_c1_comment != "") {
      C1[nC1] = substr(curr_c1_comment, 2)
      curr_c1_comment = ""
    }
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
  line = clean_up_shell_escapes(line)
  print "emit("location")("line")" > logfile
  print ""
  if(C1[++iC1]) { print C1[iC1] }
  if(C2[++iC2]) { print C2[iC2] }
  if(location) { print location }
  print "msgid "line
  if(TEST) { print "msgstr \"[T]"substr(line, 2) }
  else     { print "msgstr \"\"" }
}

# Remove backslashes used for shell escaping to prevent gettext
# tools from terminating with fatal errors. For instance,
# IN (shell): "Open \${FILE}" => OUT (MSGID) "Open ${FILE}".
function clean_up_shell_escapes(s,   o) {
  while (match(s, re_msgid_clean_escapes)) {
    o = o substr(s, 1, RSTART + RLENGTH - 3) substr(s, RSTART + RLENGTH -1, 1)
    s = substr(s, RSTART + RLENGTH)
  }
  o = o s
  return o
}
###awk
' "$script"

