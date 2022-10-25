# This file is sourced not run
# Version: 20221024 for POSIX shell.

# See README.md for instructions.  This is a sample file.

# --- Early init ----------------------------------------------------------{{{1
## text highlighter
hl1='#fffbc6'

# --- Init localization i18n ----------------------------------------------{{{1

export TEXTDOMAIN=fatdog OUTPUT_CHARSET=UTF-8
# . gettext.sh
hl1s="<span bgcolor='$hl1'>" hl1e="</span>"

# --- Translation table i18n ----------------------------------------------{{{1

# Notes for translators
# ---------------------
# A. Never use \n **inside** your MSGSTR. Swap \r for \n in yad/gtkdialog text.
# B. However, always **end** your MSGSTR with \n.
# C. Replace trailing spaces (U+0020) with no-break spaces (U+00A0).
#
# To create a pot file for this script use xgettext.sh[1] instead of xgettext.
# xgettext.sh augments xgettext with the ability to extract MSGIDs from calls
# to 'gettext -es'.
# [1] https://github.com/step-/i18n-table

i18n_table() {
# Cf. xgettext.sh usage:
# [c1] comment lines found inside this function are reproduced with prefix "#."
# [c2] variable names are reproduced with prefix "#." above their MSGIDs.
	{
read i18n_markup_example
# {EG} = post-process with "eval_gettext"
read i18n_eval_gettext_example # {EG}
read i18n_four_line_continuation_example
# spacer_example includes 5 non-breaking spaces
read i18n_spacer_example
# ANSI escape code
read i18n_ansi_escape_code_example
# https://en.wikipedia.org/wiki/Underscore#Unicode
# combining macron below U+0331
read i18n_macron_below_example
# combining low line U+0332
read i18n_low_line_example
	} << EOF
$(gettext -es -- \
"<b>powered by...</b>\n" \
"Press \${hl1s} <tt>ENTER</tt> \${hl1e} to view location\n" \
"Multiple lines. \
Line 2. \
Last line.\n" \
"5 non-breaking spaces >>     <<\n" \
"\\033[7mANSI reverse video\\033[0m\n" \
"a̱ḇc̱ḏe̱f̱g̱ẖi̱j̱ḵḻm̱ṉo̱p̱q̱ṟs̱ṯu̱v̱w̱x̱y̱ẕ A̱ḆC̱ḎE̱F̱G̱H̱I̱J̱ḴḺM̱ṈO̱P̱Q̱ṞS̱ṮU̱V̱W̱X̱Y̱Ẕ 0̱1̱2̱3̱4̱5̱6̱7̱8̱9̱\n" \
"a̲b̲c̲d̲e̲f̲g̲h̲i̲j̲k̲l̲m̲n̲o̲p̲q̲r̲s̲t̲u̲v̲w̲x̲y̲z̲ A̲B̲C̲D̲E̲F̲G̲H̲I̲J̲K̲L̲M̲N̲O̲P̲Q̲R̲S̲T̲U̲V̲W̲X̲Y̲Z̲ 0̲1̲2̲3̲4̲5̲6̲7̲8̲9̲\n" \
)
EOF
}

## Create table
if ! i18n_table; then
	echo >&2 "${0##*/}: error in i18n_table: possible causes:
- invalid syntax
- missing MSGID"
fi

# {EG} bind envvars of MSGIDs that are marked "{EG}" in i18_table()
# Cf. gettext.sh's eval_gettext
i18n_eval_gettext_example=$(export hl1s hl1e; echo "$i18n_eval_gettext_example" | envsubst "$i18n_eval_gettext_example")

