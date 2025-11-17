#!/bin/zsh
#
# Steven J. DeRose, 2025-05ff.
#
# Infrastructure for flagging zsh assocs as pseudo-objects of various classes.
# This reserves all keys beginning with U+EDDA (a private-use characters, and
# a less likely one to be used since it's a long way into the range).
#
help=`cat <<'EOF'
An EDDA object instance is a zsh assoc with a non-empty value for the key
   whose name is U+EDDA plus "_CLASS". This is called "the class item".
All keys whose first character is U+EDDA are reserved for EDDA.
The value of the class item is the class name, which must be
    a valid zsh identifier.
An EDDA object may constrain the keys or values its instances may contain.
Such constraints are created in another assoc, which must:
    * be of EDDA class 'CLASS_DEF' (that is, it contains an item
      ["\uEDDA_CLASS]='CLASS_DEF'), and
    * is named __EDDA__classname.
A class definition contains an item for each permitted key, named the same
    as the item it constrains. It's value must include a zerg type name.
    Probably it will allow a "?" suffix for optionality? Maybe a default,
    regex pattern, range constraints, normalizer function?
Need a way to do nameref.... Perhaps just declaring type 'varname' means
that if you fetch, you get the valuable that was indirected to (or should
the user prefix "*" or something (totally random choice....) to get that?
Recursion? Circularity? Ouroboros?

Possible features:
    * Custom check functions
    * Repetition indicators
    * Parameterized types (like is_xxx with options -- pid, path, ...)
    * meta-keys like globs?
EOF
`

typeset -gxH EDDA_CHAR="\uEDDA"
typeset -gxH EDDA_CLASS_KEY=$EDDA_CHAR"_CLASS"
typeset -gxH EDDA_CLASS_DEF_KEY=$EDDA_CHAR"_CLASS_DEF"  # needed?

req_edda_class() {
    local quiet ic
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_edda_class [-q] classname varname
Check whether the named variable (not a value) is of the
named edda class (see \$EDDA_CLASS_KEY). Return 0 iff so;
otherwise print a message and return non-zero rc.
Options:
    -q|--quiet: Suppress messages.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return $ZERR_ARGC
    req_zerg_type ident "$1" || return $ZERR_ARGC
    req_sv_type assoc "$2" || return $ZERR_ARGC

    if ! [[ `edda_get_class "$2"` == "$1" ]]; then
        [ $quiet ] || tMsg 0 "Assoc '$2' is not of EDDA class '$1'."
        return $ZERR_SV_TYPE
    fi
}

edda_set_class() {
    local quiet force
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: edda_set_class varname classname
    Find or create a sh assoc named varname, and mark it as being of
    EDDA class classname. This involves adding a magic value that says so.
    If the assoc is already assigned to a different classname, an error
    is reported unless -f is specified.
    If classname is '', the magic value (if any) is removed.
See also: edda_get_class.
EOF
            return ;;
        -f|--force) force=1 ;;
        -q|--quiet) quiet="-q" ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return $ZERR_ARGC
    [ -z $2 ] || req_zerg_type ident "$2" || return $ZERR_ARGC
    local svt=`sv_type "$1"`
    if [[ $svt == undef ]]; then
        typeset -A $1
    elif [[ $svt != assoc ]]; then
        [ $quiet ] || tMsg 0 "sv_quote: Variable '$1' is not an assoc."
        return $ZERR_UNDEF
    fi
    if [ -z $2 ]; then
        aa_unset -q $1 $EDDA_CLASS_KEY
    else
        local edda_class=${${(P)1}[$EDDA_CLASS_KEY]}
        if [ -n $edda_class ] && [ -z $force ]; then
            [ $quiet ] || tMsg 0 "sv_quote: Variable '$1' already of type '$edda_class' (consider -f?)."
            return $ZERR_UNDEF
        fi
        aa_set $1 $EDDA_CLASS_KEY "$2"
    fi
}

edda_get_class() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: edda_get_class varname
    Retrieve the EDDA class name (if any) of the variable.
    If varname is an assoc but has no EDDA class, "" is returned with
    rc 0 (success), but a warning is displayed unless -q was set.
See also: edda_set_class.
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    req_sv_type assoc "$1" || return $ZERR_SV_TYPE
    local edda_class=`aa_get $1 $EDDA_CLASS_KEY`
    ### ${${(P)1}[$EDDA_CLASS_KEY]}
    if [ -z $edda_class ]; then
        [ $quiet ] || tMsg 0 "Assoc '$1' has no edda class (key '$EDDA_CLASS_KEY')."
        return 1
    fi
    echo $edda_class
}

edda_get_class_def() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: edda_get_class_def classname
    Return the name of the assoc holding the class definition for
    the given EDDA classname and rc 0; or nothing and rc non-zero.
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    req_zerg_type ident "$1" || return $ZERR_ARGC
    local def_name="__EDDA__$1"
    sv_type assoc $def_name || return $ZERR_SV_TYPE
    echo $def_name
}


edda_check() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: edda_check varname
    Check the named assoc, which must be an instance of an EDDA class,
    for validity according to its class definition. If there is no such
    definition, the check fails.
    Errors found are displayed to stderr unless -q is set.
    TODO: No provision yet for optional items.
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    req_sv_type assoc "$1" || return $ZERR_ARGC
    local ec=`edda_get_class edda_get_class_def` || return $ZERR_NO_CLASS
    local def_name=`edda_get_class_def $ec` || return $ZERR_NO_CLASS_DEF
    local key probs
    for key in ${(k)1}; do
        local val=${${(P)1}[$key]}
        local curdef=${${(P)def_name}[$key]}
        if [ -z $curdef ]; then
            probs+="Unexpected item '$key'. "
        elif ! edda_check_value "$curDef" "$val"; then
            probs+="Type error on [$key]='$val' vs. def '$curdef'. "
        fi
    done
    for key in ${(k)def_name}; do
        aa_has "$1" "$key" && continue
        probs+="Missing expected item '$key'. "
    done
    if [ -n $probs ]; then
        [ $quiet ] || tMsg 0 "$probs"
        return $ZERR_CLASS_CHECK
    fi
}
