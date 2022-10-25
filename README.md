# i18n-table

Minimal framework to speed up translated shell scripts

* Start a localized script faster with [i18n_table.sh](i18n_table.sh) and [xgettext.sh](xgettext.sh)
* Enable occasional translators
* Better organize translation resources
* Decrease overhead

## Introduction

This is a simple idea: combining multiple runs of the same command into a single run to cut down on process execution overhead.  Instead of running `gettext` many times--one for each localized string--your script can pack all strings together and run `gettext -es` only once.  This reduces start time proportionally to approximately `N * S`, where `N` is the number of `gettext` calls in your original script and `S` is the time it takes to spawn a sub-shell.¹

Another possible benefit is easier engagement with human translators.  By keeping all localized strings in a single file you can give occasional translators just the `i18n_table.sh` file for your script, and tell them to edit it with a text editor.  They don't need more complex translation tools.

If you are dealing with more sophisticated translators who know how to use the "GNU gettext" tools, and expect to be handed a ".pot" file, this project includes
`xgettext.sh`, which will help you create an _annotated_ .pot file from your script.

Some projects known to use these tools:

* SMB-browser² for [fatdog64](http://distro.ibiblio.org/fatdog/web)
* [find-n-run](https://github.com/step-/find-n-run)²
* fatdog-wireless-antenna² in [scripts-to-go](https://github.com/step-/scripts-to-go)
* [f4](https://github.com/step-/f4)²
* [desktop-wallpaper](https://github.com/step-/desktop-wallpaper)²

¹ `N * time(gettext) / time(gettext) = N` if `gettext` runs in the script's shell.  However, the typical gettext stanza is `var=$(gettext "string")`, which spawns a sub-shell to run `gettext`, and that is where we get `S` from.  
² Disclosure: I am the author/maintainer of this project.  

## Should you use these tools in your project?

If your script calls `gettext` more than a couple of times, then time gains stack up, and you should try i18n\_table.  I recommend trying with a new project first because when i18n\_table is introduced as a afterthought your code must be restructured a bit -- something you might not be willing to do.  Read the next section to see what I mean.

If you are also interested in enabling easier translator engagements as I mentioned then you should try i18n\_table.

## Defining localization strings

**[i18n_table.sh](i18n_table.sh)**

This file shows a sample `i18n_table` function and demostrates some common resource string usage cases.  You should adapt the function for your project then add `i18n_table` to your script.  Include it either directly or indirectly by sourcing the file.  In the direct case generate the .pot file by running:

```sh
xgettext.sh your-script-name > template.pot
```

In the sourced case adapt the extra files that are presented in section _Extra files_ further down.

### POSIX shell

The scripts and examples in this repository are intended to be compatible with the POSIX shell.  Extensions for bash are treated in side notes of the [README](README.md) file.

### i18n_table function

When you use `i18n_table` rewrite your script and change each call to `$(gettext "string")` to a variable name referencing "string" in your `i18n_table`.  For instance:

```sh
echo "$(gettext "Hello world!")"
```

becomes

```sh
# define resources
i18n_table() {
# reindent with care
	{
	read i18n_hello world
	} << EOF
$(gettext -es -- \
"Hello world!\n" \
)
EOF
}

# load resources
i18_table

# use resources
echo "$i18n_hello_world"
```

The function name, that is `i18n_table`, must be either the first word in a line or the second word when the first word is `function`.
Each variable name, like `i18n_hello` in the example above, must start with `i18n_`.  The rest of the name is your choice.  I like to use something descriptive of the English text but any valid identifier will do.

It is worth mentioning that your script _can_ also call `gettext` directly.  You are not required to move _all_ localization strings to your `i18n_table` function.  For instance, if you need `ngettext` or `eval_gettext` it might be easier to define the corresponding strings outside `i18n_table`.  There are ways to reframe even `ngettext` and `eval_gettext` into the i18n\_table method but the extra work required may not be worth the effort.

If you want to split localization resources into multiple groups, define and call an `i18n_table` function for each group because the extraction tool looks for that name specifically.

**Side note: bash arrays**

Here is a magic sauce to read all strings into a bash array¹'²:

```sh
typeset -a i18n_array
typeset -i i=0
	{
	while read i18n_array[$i]; do : $((++i)); done
	} << EOF
$(gettext -es \
"item 0\n" \
"item 1\n" \
)
EOF
```

¹ Why not using `mapfile`, `<( )`, `<<<`, `IFS=...`, etc. instead of a `read` loop?  I tried many variations, but I always come back to `read` to ensure that items don't include leading white space.

² Why the braces?  Indeed braces aren't needed; one could more simply write `while ... done << EOF`.  However, the extraction tool can annotate output with `i18n_` variable names, such as `i18n_array`, when it finds them _inside_ a pair of braces_.  That is why the magic sauce shows the braces.  If you don't need name annotations omit the braces altogether.  Moreover, an array will result in just one annotation, which isn't very useful anyway.


## Extracting localization strings

**[xgettext.sh](xgettext.sh)**

Use `xgettext.sh` to generate a .pot file from your script.  You can also use `xgettext.sh` as a replacement for the standard `xgettext` command because `xgettext.sh` runs `xgettext` on the input file before extracting strings from `i18n_table`.  By default comments and location information are extracted from the function body, and resource strings are annotated with the variable name they refer to.  You can turn off comments and annotations via `xgettext.sh` command options.  To affect the standard `xgettext` run pass `xgettext` options to `xgettext.sh`.

**LIMITATION**

**Currently, xgettext.sh is able to parse strings delimited by double quotes only.  Single quotes and the `$''` syntax are not supported. Contact me if you need this feature for your project.**

```
Usage: xgettext.sh [OPTIONS] ['--' xgettext_OPTIONS ...] FILE"

OPTIONS:
  --help    Print this message and exit. See also xgettext --help.
  --no-c1   Don't output [c1] lines.
  --no-c2   Don't output [c2] lines.
  --test    Generate test translation.
xgettext_OPTIONS:
  Any xgettext(1) option.  Default presets: -o - -LShell

If the script includes a function named i18_table:
[c1] Comment lines within the i18n_table body are reproduced with prefix "#."
[c2] For lines starting with "read i18n_<string>", i18n_<string> is
     prefixed with "#." then output above its corresponding MSGID.

Location information is generated for lines [c0] and [c2] unless
xgettext_OPTIONS includes option --no-location.

Inside the `$(gettext -es ...)` block, a line that ends with "##" is ignored.
A line that ends with "<<<##" marks the start of a block of ignored lines,
which need not end with "##" themselves. The block ends at the next line that
ends with ">>>##".
```

## Extras

I have successfully used these tools with small to mid-sized shell scripting projects.  I do not know how well they could work for larger scale scripting projects.  For my projects, which tend to have similar structures involving some shell and markdown files, I wrote a script to drive xgettext.sh in a repeatable way.  This script takes a configuration file that I customize for each new project. Take a look at [make-pot.sh](make-pot.sh) and [make-pot.cfg](make-pot.cfg).  You can reuse my make-pot files or develop your own variations.  Again, xgettext.sh is all you need to generate a .pot file for the i18n\_table function.

