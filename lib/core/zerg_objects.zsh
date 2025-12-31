#!/bin/zsh
#
# Steven J. DeRose, 2025-05ff.
#
# Infrastructure for flagging zsh assocs as (quasi-) objects of various classes.
# This reserves all keys beginning with U+EDDA (a private-use character, and
# a less likely one to be used since it's a long way into the range).
#
typeset -gxH ZERG_CLASS_CHAR="\uEDDA"
typeset -gxH ZERG_CLASS_KEY=$ZERG_CLASS_CHAR"_CLASS"
typeset -gxH ZERG_CLASS_DEF_KEY=$ZERG_CLASS_CHAR"_CLASS_DEF"  # needed?

zerg_set_class() {
    local quiet force
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_set_class varname classname
    Find or create a sh assoc named varname, and mark it as being of
    zerg class classname. This involves adding a magic value that says so.
    If the assoc is already assigned to a different classname, an error
    is reported unless -f is specified.
    If classname is '', the magic value (if any) is removed.
See also: zerg_get_class.
EOF
            return ;;
        -f|--force) force=1 ;;
        -q|--quiet) quiet="-q" ;;
        --) shift ; break ;;
        *) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return $ZERR_ARGC
    [ -z "$2" ] || is_of_zerg_type ident "$2" || return $ZERR_ARGC
    local svt=`zsh_type "$1"`
    if [[ $svt == undef ]]; then
        typeset -A $1
    elif [[ $svt != assoc ]]; then
        [ $quiet ] || warn 0 "zsh_quote: Variable '$1' is not an assoc."
        return $ZERR_UNDEF
    fi
    if [ -z "$2" ]; then
        aa_unset -q $1 $ZERG_CLASS_KEY
    else
        local zerg_class=${${(P)1}[$ZERG_CLASS_KEY]}
        if [ -n "$zerg_class" ] && [ -z "$force" ]; then
            [ $quiet ] || warn 0 "zsh_quote: Variable '$1' already of type '$zerg_class' (consider -f?)."
            return $ZERR_UNDEF
        fi
        aa_set $1 $ZERG_CLASS_KEY "$2"
    fi
}

### See also is_of_zerg_class in ../zerg_types.sh.

zerg_get_class() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_get_class varname
    Retrieve the zerg class name (if any) of the variable.
    If varname is an assoc but has no zerg class, "" is returned with
    rc 0 (success), but a warning is displayed unless -q was set.
See also: zerg_set_class.
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        --) shift ; break ;;
        *) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    is_of_zsh_type assoc "$1" || return $ZERR_ZSH_TYPE
    local zerg_class=`aa_get "$1" "$ZERG_CLASS_KEY"`
    ### ${${(P)1}[$ZERG_CLASS_KEY]}
    if [ -z "$zerg_class" ]; then
        [ $quiet ] || warn 0 "Assoc '$1' has no zerg class (key '$ZERG_CLASS_KEY')."
        return 1
    fi
    echo $zerg_class
}

zerg_get_class_def() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_get_class_def classname
    Echo the name of the associative array holding the class definition for
    the given zerg classname (with rc 0); or nothing (with rc non-zero) if
Note: By convention, the assoc containing the class definition should be named
    "__CLASS__" plus the class name. zerg_get_class_def assumes that convention,
    but support for classes in general does not. In fact, you can flag an
    assoc as being of a given class, without there being any explicit definition
    at all, for example using zerg_set_class. You just don't get free
    checking of item names, types, or values in that case.
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        --) shift ; break ;;
        *) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    is_of_zerg_type ident "$1" || return $ZERR_ARGC
    local def_name="__CLASS__$1"
    zsh_type assoc $def_name || return $ZERR_ZSH_TYPE
    echo $def_name
}

zerg_class_check() {
    local quiet optional
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_class_check varname
    Check the named assoc, which must be an instance of a zerg class,
    for validity according to its class definition. If there is no such
    definition, the check fails unless --optional (or -o) is set.
    Errors found are displayed to stderr unless -q is set.
    TODO: No provision yet for optional items.
EOF
            return ;;
        -o|--optional) optional=1 ;;
        -q|--quiet) quiet="-q" ;;
        --) shift ; break ;;
        *) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    is_of_zsh_type assoc "$1" || return $ZERR_ARGC
    local ec=`zerg_get_class zerg_get_class_def` || return $ZERR_NO_CLASS
    local def_name=`zerg_get_class_def $ec` || return $ZERR_NO_CLASS_DEF
    [ -z "$def_name" ] && [ -n "$optional" ] && return 0  # No def, but ok.
    local key probs
    for key in ${(k)1}; do
        local val=${${(P)1}[$key]}
        local curdef=${${(P)def_name}[$key]}
        if [ -z "$curdef" ]; then
            probs+="Unexpected item '$key'. "
        elif ! zerg_class_check_value -q "$curDef" "$val"; then
            probs+="Type error on [$key]='$val' vs. def '$curdef'. "
        fi
    done
    for key in ${(k)def_name}; do
        aa_has "$1" "$key" && continue
        probs+="Missing expected item '$key'. "
    done
    if [ -n "$probs" ]; then
        [ $quiet ] || warn 0 "$probs"
        return $ZERR_CLASS_CHECK
    fi
}
