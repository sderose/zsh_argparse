#!/bin/zsh
#
# Bootstrap definitions for add_argument's own parameters
# sjd and Claude, 2025-05-31
#
# Define the options for def_argument itself (which is very much like
# Python argparse.add_argument().
# Normally this would be done via def_argument itself, but this works even
# before it exists.
#
# Each arg definition is stored as a zsh associative array of its options.
# "Refname" is for functions to refer to it when assembling an actual parser,
# and defaults to the same name as the first name given.
#
# TODO Probably don't need an option def for the refname.
# TODO Predefine stable of common attrs such as
#     ignore-case, iencoding, oencoding, verbose, help, field-separator,
#     version, quiet, force, recursive, dry-run/no-act/test, output, count,
#     grep etc: expr, ignore-case, extended-regex, invert-match
#     number, bytes, characters, fields, lines, human-readable
#     field-sep, iformat, oformat, key


###############################################################################
# Enums that add_argument needs, such as types and actions.
# These are not zsh built-in types, they are types you can declare for
# arguments. Most will get stored as strings (after checking them).
# Testers to see if a string matches a given type, are in
typeset -a zap_types=(
    INT HEXINT OCTINT ANYINT BOOL FLOAT PROB LOGPROB
    STR CHAR TOKEN UTOKEN TOKENS UTOKENS REGEX PATH URL LANG
    TIME DATE DATETIME DURATION EPOCH
)
# TODO: TENSOR COMPLEX ENUM POS/NEG/NONPOS/NONNEG?

typeset -a zap_actions=(
    STORE STORE_CONST STORE_FALSE STORE_TRUE
    TOGGLE COUNT HELP VERSION
    APPEND APPEND_CONST EXTEND
)

typeset -a aa_folds=(UPPER LOWER NONE)


###############################################################################
# What add_arg would produce for it's own args.
#
typeset -A _zap_names=(
    type        str
    required    ""
    pattern     "^-[-\w]+( +-[-\w]+)$"
    help        "Name of associative array to store argument definition"
)

typeset -A _zap_action=(
    names       "-a --action"
    type        str
    choices     "${(k)zap_actions}"
    default     STORE
    pattern     "^("${(kj:|:)zap_actions}")$"
    help        "Action to take when argument is encountered"
)

typeset -A _zap_choices=(
    names       "-c --choices"
    type        str
    help        "Space-separated list of valid choices"
)

typeset -A _zap_const=(
    names       "-k --const"
    type        str
    help        "Constant value for store_const action"
)

typeset -A _zap_default=(
    names       "-d --default"
    type        str
    help        "Default value if argument not provided"
)

typeset -A _zap_dest=(
    names       "-v --dest"
    type        str
    pattern     "^\w+$"
    help        "Variable name to store result (defaults to option name)"
)

typeset -A _zap_fold=(
    names       "--fold"
    type        str
    choices     "${(k)aa_folds}"
    default     NONE
    pattern     "^("${(kj:|:)aa_folds}")$"
    help        "Case folding: ${(k)aa_folds}"
)

typeset -A _zap_force=(
    names       "--force"
    type        bool
    action      store_true
    help        "Overwrite existing argument definition"
)

typeset -A _zap_format=(
    names       "--format"
    type        str
    pattern     "^.*%.*$"
    help        "sprintf-style format string for display"
)

typeset -A _zap_help=(
    names       "-h --help"
    type        str
    help        "Help text for this argument"
)

typeset -A _zap_nargs=(
    names       "-n --nargs"
    type        str
    pattern     "^(\?|\*|\+|[0-9]+)$"
    help        "Number of arguments (?, *, +, or integer)"
)

typeset -A _zap_pattern=(
    names       "-x --pattern"
    type        regex
    help        "Regex pattern that string values must match"
)

typeset -A _zap_required=(
    names       "-r --required"
    type        bool
    action      store_true
    help        "Argument is required"
)

typeset -A _zap_type=(
    names       "-t --type"
    type        str
    choices     "${(k)zap_types}"
    default     STR
    pattern     "^(${(kj:|:)zap_types})$"
    help        "Argument data type"
)
