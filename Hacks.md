# Hacks

## Creating a TSV table of i18n variable names / MSGIDs

```sh
xgettext.sh ./your-script-filename |
awk -v OFS="\t" '/^$/,/^msgstr / {
	if ($0 ~ /^#:/) { c2 = c2 " " $0 }
	else if ($0 ~ /^#./) { c1 = c1 " " $0 }
	else if ($0 ~ /^msgid /) { id = $0 }
	else if (id) {
		sub(/msgid /, "", id)
		gsub(/^ |#. /, "", c1)
		gsub(/^ |#: /, "", c2)
		print c1 ? c1 : "gettext", id, c2
		c1 = c2 = id = ""
	}
} ' # | cat -T | less
```

## Tilde shorthand for Unicode no-break space U+00A0

I like to _see_ no-break spaces (NS) in my `i18n` strings to avoid mistaking NS
for a regular space. So I write a tilde where I want a no-break space then
substitute back with `sed` as shown below.  Of course, you could change tilde
and no-break space to another pair of characters for your own convenience.

File: example.sh

```sh
export TEXTDOMAIN=example

i18n_table() { #{{{1
	{
# NOTE: at run time, tilde ~ in MSGSTR is replaced by no-break space (U+00A0) throughout.
# To include literal tildes start your MSGSTR with "!~".

# i18n_label_no_break displays an unbreakable "label no break"
read i18n_label_no_break

# i18n_wiggling_line displays as "~~~"
read i18n_wiggling_line
	} << EOF
$(gettext -es -- \
"label~no~break\n" \
"!~~~~\n" \
| ##
# replace tilde with no-break space; start MSGSTR with "!~" to escape ##
sed '2,$s/^ //; /^!~/{s/..//; b}; s/~/ /g' # <<< \u00A0 ##
)
EOF
}

i18n_table
printf "(%s)\n" "$i18n_label_no_break" "$i18n_wiggling_line" | xxd
```

Output―when no message catalog (`example.mo`) is present:

```
00000000: 286c 6162 656c c2a0 6e6f c2a0 6272 6561  (label..no..brea
00000010: 6b29 0a28 7e7e 7e29 0a                   k).(~~~).
```

Note that each line of the `sed` filter ends with two hashes `#`.  This
instructs `xgettext.sh` to ignore that line, which otherwise would be
interpreted as a malformed MSGID and trigger an error.

Don't let this contrived example fool you into thinking that the replacement
applies to the MSGID.  It really applies to the MSGSTR (the translation), so translators can include literal tildes in their translation.  To see what I mean we need to create a `.po` file for `example.sh`, translate it into a `.mo` file and run the test again within the translation domain:

```
1# ./xgettext.sh example.sh > example.po
example.sh: lines 7-10: warning: non-contiguous "read i18n_..." commands
```

Edited example.po―showing just the relevant MSGID/MSGTR pairs:

```
#: example.sh:9
#. i18n_label_no_break
#: example.sh:15
msgid "label~no~break\n"
msgstr "label~could break\n"
# above msgstr has a no-break space and a regular space

#: example.sh:12
#. i18n_wiggling_line
#: example.sh:16
msgid "!~~~~\n"
msgstr "!~~~~ ~~~ ~~~\n"
```

Create the translation catalog:

```sh
1# msgfmt example.po
1# echo $LANG
en_US.UTF-8
1# mkdir -p ./textdomain/en/LC_MESSAGES
1# mv messages.mo ./textdomain/en/LC_MESSAGES/example.mo
```

Run the example again―this time with `example.mo` applied:

```sh
1# TEXTDOMAINDIR=./textdomain sh ./example.sh
```

Translated output:

```
i18n-table 1# TEXTDOMAINDIR=$PWD/textdomain sh ./example.sh
00000000: 286c 6162 656c c2a0 636f 756c 6420 6272  (label..could br
00000010: 6561 6b29 0a28 7e7e 7e20 7e7e 7e20 7e7e  eak).(~~~ ~~~ ~~
00000020: 7e29 0a                                  ~).
```
