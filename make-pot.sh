#!/bin/sh

# =============================================================================
# make-pot.sh - Create a GNU gettext .pot template file involving i18n_table
# Copyright (C)2016-2023 step - https://github.com/step-/i18n-table
# License: GNU GPL3 or MIT
# Version: 20230206
# Depends: GNU gawk, xgettext, xgettext.sh, mdview (only if markdown needed)
# =============================================================================

# Typically, this file resides in my development directory under
# usr/share/doc/{PackageName}/nls
# where {PackageName} is a placeholder for the name of your project


CONFIG=$1 # default ${0%.sh}.cfg

# Read project configuration file {{{1
# Stubs
md_is_to_be_translated() { :; }
list_md_files() { :; }
FPOT= XSRC= XOPT= XTBL= XXGT= XXGTOPT=

[ -z "$CONFIG" ] && CONFIG="${0%.sh}.cfg"
if ! [ -r "$CONFIG" ]; then
  echo >&2 "${0##*/}: error: can't read configuration file '$CONFIG'.
usage: ${0##*/} [config-file (default ${0%.sh}.cfg)]"
  exit 1
fi
. "$CONFIG"

if ! [ -e "$XSRC" ] || [ "$XTBL" -a ! -e "$XTBL" ] || ! [ "$FPOT" ]; then
  echo >&2 "${0##*/}: error: one or more invalid values set for XSRC, XTBL, FPOT."
  exit 1
fi
export IENC OENC XOPT XXGTOPT

mdview=mdview

create_pot_file() # $1-pot-file $2...-xgettext-options {{{1
{
  local f x fpot xopt
  fpot=$1; shift
  rm  -f "$fpot."*tmp

  # -------------------------------------------------------------------
  # Create pot file header
  if ! init_po_file "$fpot.tmp"; then
    ERRORS="${ERRORS}
    init_po_file '$fpot' $*"
    return 1
  fi
  # -------------------------------------------------------------------
  # Append all notes
  insert_notes >> "$fpot.tmp"
  # -------------------------------------------------------------------
  # Append main source file scan
  if ! scan_source_file "$XSRC" "$@" --omit-header >> "$fpot.tmp"; then
    ERRORS="${ERRORS}
    scan_source_file '$XSRC'"
    return 1
  fi
  # -------------------------------------------------------------------
  # Append i18n_table source file scan
  if ! scan_i18n_table_file "$XTBL" --omit-header >> "$fpot.tmp"; then
    ERRORS="${ERRORS}
    scan_i18n_table_file '$XTBL'"
    return 1
  fi
  # -------------------------------------------------------------------
  # Append .md file scans
  unset notes_appended
  while read -r f; do
    ! [ -e "$f" ] || ! md_is_to_be_translated "$f" && continue
    if ! [ "$notes_appended" ]; then
      # Append notes again
      type __notes_on_pot_file >/dev/null 2>&1 &&
        __notes_on_pot_file >> "$fpot.tmp"
      notes_appended=notes_appended
    fi
    scan_md_file "$f" "$fpot.2.tmp"
    # Cumulate unique messages, all comments and all file positions.
    msgcat -t $OENC --no-wrap -o "$fpot.tmp" "$fpot.tmp" "$fpot.2.tmp" 2>> "$fpot.warn.tmp" ||
      ERRORS="${ERRORS}
    msgcat '$f'"
  done <<- EOF
  $(list_md_files)
EOF
  # -------------------------------------------------------------------
  # Output warnings generated by .md file scans - exclude warnings about "...\r..."
  if [ -s "$fpot.warn.tmp" ]; then
    sort -u "$fpot.warn.tmp" |
      while read line; do
        case $line in *"'r' escape"* | *'\r'* ) continue ;; esac
        IFS=:
        set -- $line
        echo "msgcat: $line"
        sed -n -e "$2 p" "$1"
      done >&2
  fi
  # -------------------------------------------------------------------
  # Delete annoyances
  # - path prefix leading to /usr, e.g. <...prefix...>/usr/...
  # - sundry
  sed -e "
    /^#: /{s~ .*/usr/~ /usr/~g}
    /#-#-#-#-#/d
    " "$fpot.tmp" ||
    ERRORS="${ERRORS}
  sed"
  #  s~^#:.*'"$PACKAGE_NAME"'~#: ~

  # In case of errors keep temp files for inspection
  ! [ "$ERRORS" ] && rm  -f "$fpot."*tmp

  return ${ERRORS:+1}
}

scan_source_file() # $1-filepath $2...-xgettext-options {{{1
{
  local f
  f=$1; shift &&
  echo >&2 "scan_source_file $f" &&
  env TZ="$PACKAGE_POT_CREATION_TZ" \
    xgettext ${IENC:+--from-code=$IENC} -L Shell "$@" --no-wrap -o -  \
      --package-name="$PACKAGE_NAME" \
      --package-version="$PACKAGE_VERSION" \
      --msgid-bugs-address="$PACKAGE_POT_BUGS_ADDRESS" \
    "$f" |

    # erase the output for "gettext -es", if any
    awk '#{{{awk
    /^#:/ { buf = $0 }
    /^msgid "-es"$/ { getline; next } # erase this line, the one after and buf, if any
    $0 !~ /^#:/ { if(buf) {print buf} ; print; buf = ""
    } #awk}}}'
}

scan_i18n_table_file() # $1-filepath $2...-xgettext-options {{{1
{
  local f sep
  f=$1; shift &&
  echo >&2 "scan_i18n_table_file $f" &&
  case $XXGTOPT in
    *' '--' '*|--' '*|*' '-- ) : ;; *) sep="--" ;; esac &&
    "$XXGT" $XXGTOPT $sep "$@" --no-wrap "$f"
}

init_po_file() # $1-po(t)-OUTPUT-file $2...-xgettext-options {{{1
{
  local f
  f=$1; shift
  env TZ="$PACKAGE_POT_CREATION_TZ" \
    xgettext "$@" --force-po -C -o "$f" \
      --package-name="$PACKAGE_NAME" \
      --package-version="$PACKAGE_VERSION" \
      --msgid-bugs-address="$PACKAGE_POT_BUGS_ADDRESS" \
    /dev/null &&
  sed -i '
  {
    s~SOME DESCRIPTIVE TITLE~'"$PACKAGE_TITLE"'~
    s~YEAR THE PACKAGE.*$~'"$PACKAGE_COPYRIGHT"'~
    s~FIRST AUTHOR.*$~'"$PACKAGE_FIRST_POT_AUTHOR"'~
    s~Language: ~&'"$PACKAGE_POT_LANGUAGE"'~
    s~=CHARSET~='"$PACKAGE_CHARSET"'~
  }
  $ a "Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\\n"' "$f"
}

insert_notes() # {{{1
{
  local f
  # Opening notes on pot file
  type __notes_on_pot_file >/dev/null 2>&1 &&
    __notes_on_pot_file
  # Call all function names that start with '__notes_on_file' in
  # config file except those that are marked 'excluded'.
  for f in $(gawk -F '[ \t()]' \
    '/^__notes_on_file/ && ! /excluded/ {print $1}' "$CONFIG"); do
    $f
  done
}

insert_notes_on_file() # $1-filepath {{{1
{
  local f x
  f=$1
  echo "
#.
#. ---------------------------------------------------------
#. i18n $f
#. ---------------------------------------------------------
#.
"
  x=__notes_on_file_${f##*/}; x=${x%.*}
  type "$x" >/dev/null 2>&1 && "$x"
}

scan_md_file() # $1-in-filepath $2-out-filepath {{{1
{
  local in out pat
  in=$1 out=$2
  echo >&2 "$in"

  init_po_file "$out" || {
    ERRORS="${ERRORS}
    init_po_file '$in'"; return 1; }

  insert_notes_on_file "$in" >> "$out"

  if [ "$no_location" ]; then
    set -x
    grep -vF "#: $in:" "$out" > "$out".tmp &&
    mv "$out".tmp "$out" || {
    ERRORS="${ERRORS}
   sed '$out'"; return 1; }
  fi
  set +x

  # match xgettext's --no-location option, if configured
  case "$XOPT$XXGTOPT" in *--no-location* ) pat='^\(msgid\|msgstr\) ' ;; * ) pat=.;; esac

  $mdview --po "$in" | grep "$pat" >> "$out" # || {
    #ERRORS="${ERRORS}
    #$mdview '$in'"; return 1; }
  # FIXME[mdview] mdview's stdout_output() doesn't exit(code) at all

  # Always run msguniq on text output by mdview --po
  msguniq -t $OENC --no-wrap -i "$out" -o "$out" || {
    ERRORS="${ERRORS}
   msguniq '$in'"; return 1; }
}

# {{{1}}}

unset ERRORS

create_pot_file "$FPOT" $XOPT > "$FPOT"

if [ "${ERRORS}" ]; then
  echo >&2 "${0##*/}: ERRORS:${ERRORS}"
  exit 1
fi

