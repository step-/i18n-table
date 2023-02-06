# =============================================================================
# project.mk - sample project settings for the Makefile
# (C)2023, step - https://github.com/step-/i18n-table
# License: GNU GPL3 or MIT
# Version: 20230206
# =============================================================================

# --- Basic settings -----------------------------------------------------

# location of prerequisite shell scripts from which to create target pot files
SRC_DIR = .

# enter target pot files - each one depends on a prerequisite shell script,
# e.g., $(SRC_DIR)/filename.sh leads to filename.new.pot
# e.g., ./your-file-here.sh leads to ./your-file-here.new.pot
# for a quick test swap the '#' character between the all: targets and run make
#all: i18n_table.new.pot
all: your-file-here.new.pot
.PHONY: all

# name or pathname of i18n commands
XGT  = xgettext
XXGT = ./xgettext.sh

# --- Advanced settings --------------------------------------------------

# location of .cfg file - only looked at if you want to copy shell-generated
# comment blocks into the output pot file, that is, calling __notes_on_*
# functions sourced from $(CFG_DIR)/filename.cfg
# see make-pot.cfg for examples of __notes_on_* functions.
CFG_DIR = ./cfg

# location of .com file - only looked at if you want to copy its content
# as a comment block into the output pot file, that is, copying all text
# from $(CFG_DIR)/filename.com
COM_DIR = ./com

# whether to generate comment blocks at all; leave empty for no comment blocks
# otherwise assign either the literal names CFG_DIR or COM_DIR
COMMENT_DIR = COM_DIR

# highly recommended GNU gettext options
# - don't wrap MSGID to be compatible with other tools of mine
# - don't add comments for source line number to reduce diff friction
NO_WRAP     = --no-wrap
NO_LOCATION = --no-location

INPUT_ENCODING           = UTF-8
OUTPUT_ENCODING          = UTF-8

# --- Required pot header settings ---------------------------------------

PACKAGE_VERSION          = {PackageVersion}
PACKAGE_NAME             = {PackageName}
PACKAGE_TITLE            = $(PACKAGE_NAME) $(PACKAGE_VERSION)
PACKAGE_COPYRIGHT        = {Copyright}
PACKAGE_FIRST_POT_AUTHOR = {Author}
PACKAGE_POT_CREATION_TZ  = UTC
PACKAGE_POT_LANGUAGE     = en
PACKAGE_CHARSET          = $(OUTPUT_ENCODING)
PACKAGE_POT_BUGS_ADDRESS = {E-mail}

# --- See Makefile from here ---------------------------------------------

