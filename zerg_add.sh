#!/bin/zsh
# zerg_add function -- add_argument for the zerg parser.
#
if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    #return $ZERR_UNDEF
fi

# [help] action is added after generating $zerg_actions_re, because
# it would collide with --help [message].
typeset -A zerg_actions=(
    [store]=1 [store_const]=0 [store_false]=0 [store_true]=0
    [toggle]=0 [count]=0 [version]=0
    [append]=1 [append_const]=0 [extend]=1
)
# turn that into 'case' expr --store|--store-const....
zerg_actions_re="--"${(j:|--:)${(k)zerg_actions}}
zerg_actions_re=$zerg_actions_re:gs/_/-/
zerg_actions[help]=0  # See note above

typeset -A aa_fold_values=( [upper]=1 [lower]=2 [""]=0 )

typeset -a zerg_argdef_fields=(
    arg_names action choices const default dest
    fold format help nargs pattern required type )
    #  counter flag on_redefine reset??

_zerg_argdef_init() {
    # Usage: _zerg_argdef_init def_name arg_names
    # Check for existing definition and deal  ### TODO Factor out, move up?
    local def_name="$1" arg_names="$2"
    local priorType=`sv_type $def_name`
    if [[ $priorType == ^(scalar|integer|float|array)$ ]]; then
        tMsg 0 "Cannot create zerg parser arg '$def_name', variable already exists."
        return $ZERR_DUPLICATE
    elif [[ $priorType == "assoc" ]]; then
        local parser_name=${def_name/__*/}
        local disp=$(aa_get "$parser_name" "on_redefine")
        if [[ $disp == allow ]] || [[ $disp == "" ]]; then
            unset "$def_name"
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "Warning: Argument def '$def_name' already exists."
            unset "$def_name"
        elif [[ $disp == error ]]; then
            tMsg 0 "Error: Argument '$def_name' already exists."
            return $ZERR_DUPLICATE
        else
            tMsg 0 "Unknown value '$disp' for --on-redefine."
            return $ZERR_ENUM
        fi
    fi

    # Create assoc to store the argdef, and apply defaults
    typeset -gHA $def_name
    aa_set $def_name "$ZERG_CLASS_KEY" "ZERG_ARG_DEF"
    aa_set $def_name action "store"
    aa_set $def_name arg_names "$arg_names"
    #aa_set $def_name const ""
    #aa_set $def_name default ""
    #aa_set $def_name dest ""
    #aa_set $def_name fold ""
    #aa_set $def_name required ""
    #aa_set $def_name type "str"
}


###############################################################################
#
zerg_add() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_add [-q] parser_name "arg_names" [argOptions...]
    parser_name: name of the parser to add to (see zerg_new)
    arg_names: space-separated list of aliases (e.g. "--quiet -q --silent")
        The first one is the reference name.
    argOptions: Options that determine the treatment of the argument being defined.
        Most are the same as Python `argparse`, such as --type, --default, --help...
Options:
    -q: Suppress message from the zerg_add operation itself

parser_name must be an already-existing associative array, typically created by
`zerg_new`. `zerg_add` creates another associative array for the definition, named as
parser_name plus "__" plus the argument's reference name. For example, "PAR1__quiet".
The reference and other names are also added to "arg_names" in parser_name, with
each value being the full name of that argument's associative array.

To re-use an option already defined in another parser, see `zerg_use` (no new
associative array is created in that case -- the current parsers entry(s) for
the argument name(s) simply point to the old one (which must still exist).

Once all arguments have been added to the parser (whether by zerg_add or zerg_use),
parse the command line like (be careful how you refer to "$*", so the user's
actual arguments to you shell function don't get re-parsed):
     zerg_parse parser_name "$*"
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 99 $# || return $ZERR_ARGC
    req_zerg_class ZERG_PARSER "$1" || return $?

    # Process the parser name and quoted list of this arg's names/aliases
    local parser_name="$1"
    local arg_names="$2"
    local -a arg_names_list=(${(z)arg_names})  # split on whitespace
    if [[ $#arg_names_list -eq 0 ]]; then
        [ $quiet ] || tMsg 0 "No option name(s) provided."
        return $ZERR_BAD_NAME
    fi
    for arg_name in $arg_names_list; do
        if ! is_argname -q "$arg_name"; then
            [ $quiet ] || tMsg 0 "Option name to add is invalid: '$arg_name'."
            return $ZERR_BAD_NAME
        fi
    done
    local ref_name=$arg_names_list[1]
    local def_name="${parser_name}__"`zerg_opt_to_var "$ref_name"`
    #print "\nAliases '$arg_names', ref_name '$ref_name', def_name '$def_name'."
    shift 2

    _zerg_argdef_init "$def_name" "$arg_names" || return $?

    # Parse options making up this argument definition
    while [[ $# -gt 0 ]]; do
        #tMsg 0 "Args are now: $1 | $2 | $3".
        local name=`zerg_opt_to_var "$1"`
        #tMsg 0 "Arg '$1' (->$name)."
        case "$1:l" in
            --type|-t)
                shift
                name=`zerg_opt_to_var "$1"`
                aa_has zerg_types "$name" || return $ZERR_ENUM
                aa_set $def_name type "$name" ;;

            ${~zerg_types_re})
                aa_set $def_name type "$name" ;;

            --action|-a)
                shift
                name=`zerg_opt_to_var "$1"`
                #tMsg 0 "Action '$name' for $def_name."
                aa_has zerg_actions "$name" || return $ZERR_ENUM
                aa_set $def_name action "$name" ;;

            # following does not include --help, to avoid conflict.
            ${~zerg_actions_re})
                aa_set $def_name action "$name" ;;

            --help|-h)
                shift; aa_set $def_name help "$1" ;;

            # Convenient combo shorthands
            --flag)
                aa_set $def_name type "bool"
                aa_set $def_name action "store_true" ;;
            --counter)
                aa_set $def_name type "int"
                aa_set $def_name action "count" ;;

            # Other options
            --choices|-c)
                shift
                req_zerg_type idents "$1" || return $?
                aa_set $def_name choices "$1" ;;
            --const|-k)
                shift; aa_set $def_name const "$1" ;;  # Type-check at end
            --default|-d)
                shift; aa_set $def_name default "$1" ;;  # Type-check at end
            --dest|-v)
                shift
                req_zerg_type ident "$1" || return $?
                aa_set $def_name dest "$1" ;;
            --fold)
                shift
                #aa_has aa_fold_values "$1:l" || return $?
                aa_set $def_name fold "$1:l" ;;
            --format)
                shift
                req_zerg_type format "$1" || return $?
                aa_set $def_name format "$1" ;;  # TODO Check
            --metavar)
                shift
                req_zerg_type ident "$1" || return $?
                aa_set $def_name metavar "$1" ;;
            --nargs|-n)
                shift
                [[ $1 == remainder ]] || req_zerg_type int "$1" || return $?
                aa_set $def_name nargs "$1" ;;
            --pattern|-x)
                shift
                req_zerg_type regex "$1" || return $?
                aa_set $def_name pattern "$1" ;;
            --required|-r)
                aa_set $def_name required "1" ;;
            -*)
                [ $quiet ] || tMsg 0 "Unknown option '$1'."
                return $ZERR_BAD_OPTION ;;
            *)
                [ $quiet ] || tMsg 0 "Unexpected positional argument '$1'."
                return $ZERR_BAD_OPTION ;;
        esac
        shift;
    done

    # Check type of default and const if provided and typed.
    local type=`aa_get -q $def_name type`
    local const=`aa_get -q $def_name const`
    local default=`aa_get -q $def_name default`
    local required=`aa_get -q $def_name required`

    if [ -n "$type" ]; then
        if [ -n "$const" ]; then
            req_zerg_type "$type" "$const" || return $?
        fi
        if [ -n "$default" ]; then
            req_zerg_type "$type" "$default" || return $?
        fi
    fi

    for name in $arg_names_list; do
        aa_set "$parser_name" "$name" "$def_name"
    done

    local action=`aa_get $def_name action`
    if [[ $action == toggle ]]; then
        aa_set $def_name action store_true
        # Build negated version of the arg def form
        local neg_ref_name=`_zerg_negate_opt_name $ref_name`
        local neg_def_name="${parser_name}__$neg_ref_name"
        typedef -ghA $neg_def_name
        local dft_dest=$ref_name[${#parser_name}+2,-1]
        aa_set $neg_def_name dest $dft_dest
        for k in ${(k)def_name}; do
            if [[ $k =~ ^- ]]; then
                local neg_k=`_zerg_negate_opt_name $k`
                aa_set $neg_def_name $neg_k $neg_ref_name
                aa_append_value "$parser_name" "all_arg_names" "$neg_k "
            else
                aa_set $neg_def_name $k `aa_get $def_name $k`
            fi
        done
        aa_set $neg_def_name action store_false
    fi

    [ `aa_get -q "$parser_name" "export"` ] || export -n $def_name
    aa_append_value $parser_name "all_def_names" "$def_name "
    aa_append_value "$parser_name" "all_arg_names" "$arg_names "
    [ $required ] && aa_append_value "$parser_name" "required_arg_names" "$ref_name "

    #tHead "parser and argdef before zerg_add returns: "
    #aa_export -f view --sort $parser_name
    #aa_export -f view --sort $def_name
    return 0
}

_zerg_negate_opt_name() {
    #  --ignore-case --> --no-ignore-case;  -i --> +i
    is_argname "$1" || return $ZERR_ZTYPE_VALUE
    if [[ $1 =~ ^-- ]]; then
        echo "--no-"$1[3,-1]
    else
        echo "+"$1][2,-1]
    fi
}


###############################################################################
#
zerg_parent() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_parent parser_name parent_name
Re-use all argument(s) defined in another zerg parser. The parser and its
argument(s) must still exist.
    parser_name: name of the parser to add to (see zerg_new)
    parent_name: the name of the parser to take argdefs from.
This is just a wrapper around zerg_use.
EOF
            return ;;
        -q) quiet="-q" ;;
        *) break ;;
      esac
      shift
    done

    req_argc 2 2 $# || return $ZERR_ARGC
    req_zerg_class ZERG_PARSER "$1" || return $?
    req_zerg_class ZERG_PARSER "$2" || return $?
    local -a parent_def_names=(${(z)${${(P)2}[all_def_names]}})
    for def_name in parent_def_names; do
        zerg_use $1 $def_name
    done
}

zerg_use() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_use parser_name "full_arg_name"...
Re-use an argument(s) defined in another zerg parser. The parser and its
argument(s) must still exist.
    parser_name: name of the parser to add to (see zerg_new)
    full_arg_name: the name of an assoc holding an argument definition created
    by another parser. This consists of the parser name, "__", and a ref_name.
    The name and it's aliases (if any) will be the same in both parsers.
    Multiple of these can be given on the same or different calls to `zerg_use`.
Once all options have been added, use `zerg_parse` to parse the command line.
EOF
            return ;;
        -q) quiet="-q" ;;
        *) break ;;
      esac
      shift
    done

    req_argc 2 99 $# || return $ZERR_ARGC
    req_zerg_class ZERG_PARSER "$1" || return $?
    local parser_name=$1
    shift

    tMsg 0 "zerg_use not yet fully supported."
    while [ -n "$1" ]; do
        req_zerg_class ZERG_ARG_DEF "$1" || return $?
        local arg_names=`aa_get $1 "arg_names"`
        aa_append_value "$parser_name" "all_arg_names" "$arg_names "
        local req=`aa_get $1 "required"`
        [ $req ] && aa_append_value "$parser_name" "required_arg_names" " $arg_names"
        shift
    done
}
