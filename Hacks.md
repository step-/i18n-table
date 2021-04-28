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
