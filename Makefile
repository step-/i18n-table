# =============================================================================
# Makefile - sample Makefile for shell script containing i18n_table function
# (C)2023, step - https://github.com/step-/i18n-table
# License: GNU GPL3 or MIT
# Version: 20230206
# =============================================================================

include project.mk

SHELL:=/bin/sh
.ONESHELL:

# = (xgettext)
XGT_OPTS = \
	--package-name="$(PACKAGE_NAME)" \
	--package-version="$(PACKAGE_VERSION)" \
	--msgid-bugs-address="$(PACKAGE_POT_BUGS_ADDRESS)" \
	--from-code=$(INPUT_ENCODING)

XGT_OPTS_INIT = -L C++ --force-po
XGT_OPTS_SCAN = -L Shell -ci18n $(NO_LOCATION) --omit-header

# = (xgettext.sh) -- (xgettext)
XXGT_OPTS = -- $(XGT_OPTS_SCAN)

clean:
	rm -f *.pot.hdr *.pot.rem *.pot.xgt *.pot.xxgt

# init_po_file
%.pot.hdr : $(SRC_DIR)/%.sh
	@echo creating pot file header $@
	@env TZ="$(PACKAGE_POT_CREATION_TZ)" $(XGT) $(XGT_OPTS) \
		$(XGT_OPTS_INIT) -o - /dev/null |
	sed '
	{
	s~SOME DESCRIPTIVE TITLE~'"$(PACKAGE_TITLE)"'~
	s~YEAR THE PACKAGE.*$$~'"$(PACKAGE_COPYRIGHT)"'~
	s~FIRST AUTHOR.*$$~'"$(PACKAGE_FIRST_POT_AUTHOR)"'~
	s~Language: ~&'"$(PACKAGE_POT_LANGUAGE)"'~
	s~=CHARSET~='"$(PACKAGE_CHARSET)"'~
	s~^# ~#. ~
	s~^#$~#. ___________________________________________________________________________~
	}
	$$ a "Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\\n"' > $@

# insert_notes - copy comment blocks by calling shell funtions __notes_on_*
%.pot.rem : $(CFG_DIR)/%.cfg
ifeq ($(COMMENT_DIR), CFG_DIR)
	@echo copying file comment blocks from $< to $@
	# Search .cfg file for function names that start with '__notes_on_file',
	# excluding names commented with 'excluded', and call the names.
	@. $(CFG_DIR)/$<
	@for f in $$(gawk -F '[ \t()]' '
	/^__notes_on_pot_file/ && !/excluded/ { f[ 0 ] = $$1 }
	/^__notes_on_file/     && !/excluded/ { f[++n] = $$1 }
	END { for (i = 0; i <= n; i++) if (f[i]) print f[i]  }' $<)
	do $$f; done > $@
endif

# copy comment block from text file
%.pot.rem : $(COM_DIR)/%.com
ifeq ($(COMMENT_DIR), COM_DIR)
	@echo copying comment block from $< to $@
	@cat $< > $@
endif

# leave comment block empty
%.pot.rem : $(SRC_DIR)/%.sh
ifndef COMMENT_DIR
	@touch $@
endif

# scan_source_file (xgettext)
%.pot.xgt : $(SRC_DIR)/%.sh
	@echo xgettext $<
	@env TZ="$(PACKAGE_POT_CREATION_TZ)" $(XGT) $(XGT_OPTS) \
		$(XGT_OPTS_SCAN) $(NO_WRAP) -o - $< |
	@awk ' # erase output of "gettext -es", if any
	/^#:/ { buf = $$0 }
	/^msgid "-es"$$/ { getline; next } # erase this line, the one after and buf, if any
	$$0 !~ /^#:/ { if(buf) { print buf }; print; buf = ""} ' > $@

# scan_i18n_table_file (xgettext.sh)
%.pot.xxgt : $(SRC_DIR)/%.sh
	@echo xgettext.sh i18n_table in $<
	@env TZ="$(PACKAGE_POT_CREATION_TZ)" $(XXGT) $(XXGT_OPTS) \
		$(NO_WRAP) -o - $< > $@

# append .md file scans - TODO in future
# until then if you need to extract MSGIDs from markdown files
# with mdview use make-pot.sh instead of this Makefile

%.new.pot : %.pot.hdr %.pot.rem %.pot.xgt %.pot.xxgt
	# Delete duplicate MSGIDs
	@awk '
	# Replace plain comments with #. comments to avoid msguniq cumulating them
	/^#[ \t]/ { print "#." substr($$0, 2); next }
	# Replace temporary unique MSGID/MSGSTR for empty lines to avoid removal
	/^[ \t]*$$/ { print "msgid \"" NR "\"\nmsgstr \"\""; next }
	{ print; next }
	' $+ | msguniq -t $(OUTPUT_ENCODING) --no-wrap -o $@ -
	# Reduce output noise
	@sed -i -e '
	# undo temporary MSGID/MSGSTR
	/^msgid "[0-9]+"$$/{N;N;d}
	# shorten path prefix leading to /usr, e.g. <...prefix...>/usr/...
	/^#: /{s~ .*/usr/~ /usr/~g}
	# comments added by msguniq
	/#-#-#-#-#/d
	' $@

