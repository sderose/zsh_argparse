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
typeset -A _bootstrap_refname=(
    type        str
    required    ""
    pattern     "^\w+$"
    help        "Name of associative array to store argument definition"
)

# TODO Fix order of names.
# TODO put in "=" to be clearer
typeset -A _bootstrap_type=(
    names       "-t --type"
    type        str
    choices     "INT HEXINT OCTINT ANYINT FLOAT BOOL STR TOKEN CHAR REGEX PATH URL TIME DATE DATETIME"
    default     STR
    pattern     "^(INT|HEXINT|OCTINT|ANYINT|FLOAT|BOOL|STR|TOKEN|CHAR|REGEX|PATH|URL|TIME|DATE|DATETIME)$"
    help        "Argument data type"
)

typeset -A _bootstrap_action=(
    names       "-a --action"
    type        str
    choices     "STORE STORE_CONST STORE_FALSE STORE_TRUE APPEND APPEND_CONST EXTEND TOGGLE COUNT"
    default     STORE
    pattern     "^(STORE|STORE_CONST|STORE_FALSE|STORE_TRUE|APPEND|APPEND_CONST|EXTEND|TOGGLE|COUNT)$"
    help        "Action to take when argument is encountered"
)

typeset -A _bootstrap_required=(
    names       "-r --required"
    type        bool
    action      store_true
    help        "Argument is required"
)

typeset -A _bootstrap_default=(
    names       "-d --default"
    type        str
    help        "Default value if argument not provided"
)

typeset -A _bootstrap_help=(
    names       "-h --help"
    type        str
    help        "Help text for this argument"
)

typeset -A _bootstrap_choices=(
    names       "-c --choices"
    type        str
    help        "Space-separated list of valid choices"
)

typeset -A _bootstrap_nargs=(
    names       "-n --nargs"
    type        str
    pattern     "^(\?|\*|\+|[0-9]+)$"
    help        "Number of arguments (?, *, +, or integer)"
)

typeset -A _bootstrap_const=(
    names       "-k --const"
    type        str
    help        "Constant value for store_const action"
)

typeset -A _bootstrap_dest=(
    names       "-v --dest"
    type        str
    pattern     "^\w+$"
    help        "Variable name to store result (defaults to option name)"
)

typeset -A _bootstrap_fold=(
    names       "--fold"
    type        str
    choices     "UPPER LOWER NONE"
    default     NONE
    pattern     "^(UPPER|LOWER|NONE)$"
    help        "Case folding: UPPER, LOWER, or NONE"
)

typeset -A _bootstrap_format=(
    names       "--format"
    type        str
    pattern     "^.*%.*$"
    help        "sprintf-style format string for display"
)

typeset -A _bootstrap_pattern=(
    names       "-x --pattern"
    type        regex
    help        "Regex pattern that string values must match"
)

typeset -A _bootstrap_force=(
    names       "--force"
    type        bool
    action      store_true
    help        "Overwrite existing argument definition"
)

typeset -A _bootstrap_names=(
    type        str
    help        "Option names (positional arguments after options)"
)
