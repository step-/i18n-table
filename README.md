# i18n-table

## Introduction

The idea underlying this framework is simple:
if you can combine multiple scattered calls of `gettext` in your script into a single command then your script's startup time will improve.
This framework leads the developer to keeping all source strings inside the user-defined `i18n_table()` shell function.
Such centralization helps code maintenance.
Engagement with novice translators gets easier because they only need to text-edit the `i18n_table` function body.
For expert translators using the "GNU gettext" tool suite and expecting to be handed a POT file,
the framework provides developers with `xgettext.sh`,
which extracts an annotated POT file from a shell script including the `i18n_table` function.
The framework provides a `make-pot.sh` script for developers to help generate the POT file.
A `Makefile` alternative is also included.

## When Should You Use i18n-table To Speed Up Your Script?

Typically, scripts that create a (graphical) user interface can gain more speed.
Usually the user interface contains many labels, all needing to be translated.
This is how it is usually coded without i18n-table:

```sh
echo "$(gettext "label A)"
...
echo "$(gettext "label Z)"
```

And this is with i18n-table:

```sh
i18n_table() {
{
read i18n_label_A
...
read i18n_label_Z
} << EOF
$(gettext -es -- \
"label A\n" \
... \
"label Z\n" \
)
EOF
}
i18n_table
echo "$i18n_label_A"
...
echo "$i18n_label_Z"
```

I told you the underlying idea was simple!
If your script calls `gettext` more than a few times, then gains stack up, and you should try i18n-table.

## Defining Localization Strings

**[i18n_table.sh](i18n_table.sh)**

This file shows a sample `i18n_table` function and demonstrates some common resource string usage cases.
You should adapt the function for your project then add `i18n_table` to your script.
Include it either directly or indirectly by sourcing the file.
In the direct case generate the POT file by running:

```sh
xgettext.sh your-script-name > your-script-name.pot
```

In the sourced case adapt the extra files presented in the [Extra Files] section.

### POSIX Shell

This framework is compatible with the POSIX shell.
Extensions for the bash shell are discussed in the [Bash Notes] section.

### The i18n_table Function

Conceptually you are rewriting your script replacing a call to `$(gettext "string")` with a variable referencing "string", and defining the variable in the `i18n_table` function.

```sh
echo "$(gettext "Hello world!")"
```

Becomes

```sh
# define resources
i18n_table() {
# Better keep everything flush with the left margin.
{
read i18n_hello world
} << EOF
$(gettext -es -- \
"Hello world!\n" \
)
EOF
}

# load resources
i18n_table

# use resources
echo "$i18n_hello_world"
```

The function name, that is `i18n_table`, must be either the first word in a line or the second word when the first word is `function`.
Variable identifiers, like `i18n_hello` in the example above, must start with `i18n_`

Note your script _can_ still (occasionally) call `gettext` directly.
You script will benefit as long as the bulk of your localization strings is defined within `i18n_table`.
For instance, if you need `ngettext` it might be easier to define the corresponding strings outside `i18n_table`.
There are ways to reframe even `ngettext` to this framework but the extra work may not be worth the effort.

If you want to split localization resources into multiple files, define and call an `i18n_table` function in each file because the extraction tool looks specifically for that name.

### Bash Notes

Here is an example of how to read all strings into a bash array.

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

Why not using `mapfile`, `<( )`, `<<<`, `IFS=...`, etc. instead of a `read` loop?
I tried many variations, but I always come back to `read` to ensure that items do not include leading white space.

Why the braces?
Indeed braces are not necessary and one could write just the `while ... done << EOF` loop.
However, `xgettext.sh` looks for the paired braces to decide to annotate `i18n_`-prefixed identifiers, such as `i18n_array`.

## Extracting Localization Strings

**[xgettext.sh](xgettext.sh)**

Use `xgettext.sh` to generate a POT file from your script.
By default comments and location information are extracted from the function body,
and resource strings are annotated with the variable name they refer to.
You can turn off comments and annotations via `xgettext.sh` command options.
To affect the standard `xgettext` run, pass `xgettext` options to `xgettext.sh` or set the `xgettext_OPTIONS` environment variable.

See also `xgettext.sh --help`.

## Extra Files

I have successfully used these tools with small to mid-sized shell scripting projects. My projects tend to have similar source tree structures for shell and markdown files. I wrote `make-pot.sh` - a script that generates a pot file using xgettext.sh. Alternatively, I use a `Makefile` for the same purpose. Both are included in the repo. You could adapt them for your own project.

### The make-pot.sh Script

The [make-pot.sh](make-pot.sh) script takes a configuration file as input.
The supplied sample configuration file [cfg/make-pot.cfg](cfg/make-pot.cfg) can be copied and customized for each new project.

Note `make-pot.sh` is optional because `xgettext.sh` is able to generate the POT file.
However, with `make-pot.sh` developers can automate the following extra tasks so they do not need to do them manually:
- Filling the POT header with your project meta data
- De-duplicating and cleaning up the POT file
- Inserting a custom comment block, such as [com/default_notes.com](com/default_notes.com)
- Running a user-supplied markdown extractor to merge the extracted MSGIDs into the POT file.

### The Makefile Alternative

The sample [Makefile](Makefile) and [project.mk](project.mk) files can be used instead of `make-pot.sh`.
Compared to the latter the `Makefile` is easier to configure and maintain.
However, it lacks the following extra features:
- Inserting a custom comment block
- Merging markdown MSGIDs into the POT file.

To use the `Makefile`, make a backup copy of `project.mk` then edit the basic settings in `project.mk` to reflect your project.
You should not need to edit the `Makefile` itself.

Note `Makefile` is optional because `xgettext.sh` is able to generate the POT file.
