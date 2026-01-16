#!/bin/zsh
# Create a new argument parser

_zerg_parser_init() {
    # Check if already exists, and deal.
    local priorType=`zsh_type $parser_name`
    if [[ $priorType =~ ^(scalar|integer|float|array)$ ]]; then
        warn 0 "Cannot create zerg parser '$parser_name', variable already in use as $priorType."
        return $ZERR_DUPLICATE
    elif [[ $priorType == "assoc" ]]; then
        local disp=$(aa_get "$parser_name" "on_redefine")
        # TODO: When is option parsed???
        if [[ $disp == allow ]] || [[ $disp == "" ]]; then
            zerg_del "$parser_name"
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            warn 0 "Warning: Parser '$parser_name' already exists."
            zerg_del "$parser_name"
        elif [[ $disp == error ]]; then
            warn 0 "Error: Parser '$parser_name' already exists."
            return $ZERR_DUPLICATE
        else
            warn 0 "Unknown value '$disp' for --on-redefine."
            return $ZERR_ENUM
        fi
    fi

    # Create hidden parser assoc with default options, etc.
    typeset -ghA "$parser_name"

    aa_set $parser_name "$ZERG_CLASS_KEY" "ZERG_PARSER"
    aa_set $parser_name all_arg_names ""
    aa_set $parser_name all_def_names ""
    aa_set $parser_name required_arg_names ""

    aa_set $parser_name add_help ""
    aa_set $parser_name allow_abbrev 1
    aa_set $parser_name allow_abbrev_choices 1
    aa_set $parser_name description ""
    aa_set $parser_name description_paras ""
    aa_set $parser_name epilog ""
    aa_set $parser_name export 1
    aa_set $parser_name help_file ""
    aa_set $parser_name help_tool ""
    aa_set $parser_name ignore_case 1
    aa_set $parser_name ignore_case_choices 1
    aa_set $parser_name ignore_hyphens ""
    aa_set $parser_name on_redefine "allow"
    aa_set $parser_name usage ""
    aa_set $parser_name var_style "separate"
}

zerg_new() {
    local -A zerg_opts=(
        [add_help]="Automatically add a '--help -h' option"
        [allow_abbrev]="Allow abbreviated option names (default: on)"
        [allow_abbrev_choices]="Allow abbreviated choices values"
        [description]="text: Description for help text"
        [description_paras]="Retain blank lines in 'description'"
        [epilog]="text: Show at end of help"
        [export]="Export the assocs that store the parser and args."
        [help_file]="path: to help information"
        [help_tool]="name: of a renderer for help information"
        [ignore_case]="Enable case-insensitive option matching"
        [ignore_case_choices]="Ignore case on choices values"
        [ignore_hyphens]="E.g. 'out-file' and 'outfile' are the same"
        [on_redefine]="What redefining parser or arg does (allow|error|warn|ignore)"
        [usage]="Show shorter help, mainly list of options"
        [var_style]="separate (default) | assoc: How to store results"
    )
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR})
        local pr=$(aa_export zerg_opts)
        #local pr=$(typeset -p zerg_opts | sed -e 's/\[/\n    --/g' -e 's/_/-/g' -e 's/]=/ \t/')
        cat <<EOF
Usage: zerg_new parser_name [options]
Create a new argument parser.

Options (flag options can be turned off via --no-....):
$pr

Example:
    zerg_new MYPARSER --description "My cool script"
    zerg_add MYPARSER "--verbose -v" --counter
    zerg_parse MYPARSER "\$@"

These options of Python ArgumentParser are not (yet) supported:
  prog, parents, formatter_class, prefix_chars, fromfile_prefix_chars,
  argument_default, conflict_handler, exit_on_error
EOF
            return ;;
        (*) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 99 $# || return $ZERR_ARGC
    local parser_name="$1"
    shift

    warn "Creating parser '$parser_name'"
    _zerg_parser_init $parser_name || return $?

    # Parse options
    while [[ "$1" == -* ]]; do case "$1" in
            (--allow-abbrev|--abbrev)
                aa_set "$parser_name" "allow_abbrev" 1 ;;
            (--no-allow-abbrev|--no-abbrev)
                aa_set "$parser_name" "allow_abbrev" "" ;;
            (--allow-abbrev-choices|--abbrevc)
                aa_set "$parser_name" "allow_abbrev_choices" 1 ;;
            (--no-allow-abbrev-choices|--no-abbrevc)
                aa_set "$parser_name" "allow_abbrev_choices" "" ;;
            (--description)
                shift; aa_set "$parser_name" "description" "$1" ;;
            (--description-paras|--dparas)
                aa_set "$parser_name" "description_paras" 1 ;;
            (--epilog)
                shift; aa_set "$parser_name" "epilog" "$1";;
            (--export|-x)
                aa_set "$parser_name" "export" 1 ;;
            (--no-export|--nx)
                aa_set "$parser_name" "export" "" ;;
            (--help-file)
                shift; aa_set "$parser_name" "help_file" "$1" ;;
            (--help-tool)
                shift; aa_set "$parser_name" "help_tool" "$1" ;;
            (--ignore-case-choices|--icc)
                aa_set "$parser_name" "ignore_case_choices" 1 ;;
            (--no-ignore-case-choices|--no-icc|--nicc)
                aa_set "$parser_name" "ignore_case_choices" "" ;;
            (--ignore-case-options|--ignore-case|--ic|-i)
                aa_set "$parser_name" "ignore_case" 1 ;;
            (--no-ignore-case-options|--no-ignore-case|--no-ic|--nic)
                aa_set "$parser_name" "ignore_case_choices" "" ;;
            (--ignore-hyphens|--ih)
                aa_set "$parser_name" "ignore_hyphens" 1
                warn 0 "--ignore-hyphens is unfinished." ;;
            (--no-ignore-hyphens|--no-ih|--nih)
                aa_set "$parser_name" "ignore_hyphens" "" ;;
            (--on-redefine|--redef)
                shift; aa_set "$parser_name" "on_redefine" "$1" ;;
            (--usage)
                aa_set "$parser_name" "usage" "" ;;
            (--var-style|--vars)
                shift
                if [[ "$1" != "separate" && "$1" != "assoc" ]]; then
                    warn 0 "--var-style must be 'separate' or 'assoc'"
                    return $ZERR_ENUM
                fi
                aa_set "$parser_name" "var_style" "$1" ;;
            (*)
                warn 0 "Unknown option: $1"; return $ZERR_BAD_OPTION ;;
        esac
        shift
    done

    local exp=`aa_get -q -d "" "$parser_name" "export"`
    [ -n "$exp" ] && export $parser_name
}

zerg_del() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_del parser_name
Delete/destroy an argument parser and all its defined arguments.
Arguments that were re-used from another parser are not destroyed.

EOF
            return ;;
        (*) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    is_of_zerg_class ZERG_PARSER "$1" || return $?
    local def_names=`aa_get "$1" all_def_names`
    for def_name in ${(z)def_names}; do
        #warn 0 "Deleting '$def_name'."
        #is_of_zerg_class ZERG_ARG_DEF "$name" &&
        unset $def_name
    done
    unset "$1"
}


###############################################################################
#
zerg_print() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_print parser_name
Display a zerg parser and its argument definition assocs.
EOF
            return ;;
        (*) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    is_of_zerg_class ZERG_PARSER "$1" || return $?
    aa_export -f view "$1"
    local args=$(aa_get "$1" "$art_names_list")
    for arg in ${(zO)args}; do
        aa_export -f view $arg
    done
}


###############################################################################
#
zerg_to_argparse() {
    local sp="            " po
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_to_argparse parser_name
Write out a zerg parser as roughly equivalent Python argparse calls.
A few things don't quite transfer.
EOF
            return ;;
        (*) warn 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    is_of_zerg_class ZERG_PARSER "$1" || return $?
    local parser_name="$1"

    local -A notpython=(  # These aren't in Python argparse
        [allow_abbrev_choices]=1 [description_paras]=1 [export]=1
        [help_file]=1 [help_tool]=1 [ignore_case]=1 [ignore_case_choices]=1
        [ignore_hyphens]=1 [on_redefine]=1 [var_style]=1
    )
    print "    def processOptions() -> argparse.Namespace:"
    print "        parser = argparse.ArgumentParser("
    for po in ignore_case allow_abbrev description usage epilog; do
        [ "$notpython[$arg]" ] && continue
        local poval=$(aa_get "$1" "$po")
        is_float -q $poval || poval="\"$poval\""
        print "$sp$po=$poval,"
    done
    print "        )"

    # Collect an assoc of argdefname->optnames
    local adf=`aa_get $parser_name all_def_names` def_name
    local -a all_def_names=(${(z)adf})
    for def_name in ${(zo)all_def_names}; do
        local ty=`zsh_type -q $def_name`
        if [[ "$ty" != assoc ]]; then
            warn 0 "Argdef '$def_name' is a $ty, not an assoc."
        else
            _zerg_def_to_argparse $def_name
        fi
    done
    print "        return parser.parse_args()"
}

_zerg_def_to_argparse() {
    local def_name="$1"
    local aliases=`aa_get $def_name "arg_names"`
    local action=$(aa_get -q "$def_name" action)
    local sp="        "
    local buf="${sp}parser.add_argument("
    for name in ${(z)aliases}; do
        buf+="\"$name\", "
    done
    buf=$buf[1,-3]

    local -i resultLen
    local ao
    for ao in action type default choices const dest nargs required help; do
        local val=$(aa_get -q "$def_name" "$ao")
        [ -z "$val" ] && continue
        if [[ "$ao" == action ]]; then
            [[ "$val" == store ]] && continue
        fi

        is_float -q "$val" || val="\"$val\""
        local item="$ao=$val"
        let resultLen="$#buf + $#item + 2"
        if [[ resultLen -gt 79 || $ao == help ]]; then
            print "$buf,"
            buf="$sp    $item"
        else
            buf+=", $item"
        fi
    done
    print "$buf\n        )"
}


###############################################################################
#
zerg_to_case() {
    local sp="            "
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_to_case parser_name
Writes out a zerg parser as roughly equivalent zsh while/case code.
This makes it usable without zerg itself, though not every feature
is supported.
EOF
            return ;;
        (-q|--quiet) quiet=" -q" ;;
        (*) tMsg warn "Unrecognized option '$1'."; return 99 ;;
    esac; shift; done

    is_of_zerg_class ZERG_PARSER "$1" || return $?
    local parser_name="$1"

    # Parser-level options
    local ignore_case=$(aa_get -q "$parser_name" ignore_case)
    local allow_abbrev=$(aa_get -q "$parser_name" allow_abbrev)
    local fold=$(aa_get -q "$parser_name" fold)

    # Collect all arg definitions
    local adf=$(aa_get "$parser_name" all_def_names)
    local -a all_def_names=(${(z)adf})

    # First pass: declare destination variables and set defaults
    local def_name dest default
    for def_name in ${(o)all_def_names}; do
        local ty=$(zsh_type -q "$def_name")
        if [[ "$ty" != assoc ]]; then
            tMsg warn "Argdef '$def_name' is a $ty, not an assoc."
            return 98
        fi

        local ref_name=$(split_argdef_name -r "$def_name")
        dest=$(aa_get -d "$ref_name" "$def_name" dest)
        default=$(aa_get -q "$def_name" default)

        local action=$(aa_get -q "$def_name" action)
        case "$action" in
            (append|extend) print "    local -a $dest=(${default:+$default})" ;;
            (count) print "    local $dest=${default:-0}" ;;
            (*) [[ -n "$default" ]] && print "    local $dest=\"$default\"" || print "    local $dest" ;;
        esac
    done

    # Build case statement with optional case-insensitivity
    local case_var='$1'
    [[ "$ignore_case" == true ]] && case_var='${1:l}'

    print "\n    while [[ \"\$1\" == -* ]]; do case \"$case_var\" in"

    # Second pass: generate case branches
    for def_name in ${(o)all_def_names}; do
        _zerg_def_to_case "$parser_name" "$def_name" "$allow_abbrev" "$fold" || return $?
    done

    print '        (--) shift; break ;;'
    print "        (*) tMsg warn \"Unrecognized option '\$1'.\"; return \$ZERR_BAD_OPTION ;;"
    print '    esac; shift; done\n'

    # Third pass: check required options
    local required
    for def_name in ${(o)all_def_names}; do
        required=$(aa_get -q "$def_name" required)
        if [[ "$required" == true || "$required" == 1 ]]; then
            local ref_name=$(split_argdef_name -r "$def_name")
            dest=$(aa_get -d "$ref_name" "$def_name" dest)
            local aliases=$(aa_get "$def_name" arg_names)
            local -a alias_arr=(${(z)aliases})
            print "    [[ -z \"\${$dest+set}\" ]] && { tMsg error \"Required option ${alias_arr[1]} not provided.\"; return 97; }"
        fi
    done
}

_zerg_def_to_case() {
    # Generate the case-part for one option (including its aliases).
    local parser_name="$1" def_name="$2" allow_abbrev="$3" fold="$4"

    local ref_name=$(split_argdef_name -r "$def_name")
    local dest=$(aa_get -d "$ref_name" "$def_name" dest)
    local action=$(aa_get -q "$def_name" action)
    local ignore_case=$(aa_get -q "$parser_name" ignore_case)

    local case_expr=""
    local aliases=`aa_find_keys_by_value "$parser_name" "$def_name"`
    for calias in ${(z)aliases}; do
        if [ -z "$allow_abbrev" ] || [[ $calias =~ (^-.$) ]]; then
            case_expr+="|$calias"
        else
            local abbs=`_generate_abbrevs "$parser_name" "$calias"`
            case_expr+="|$abbs"
        fi
    done
    case_expr=$case_expr[2,-1]
    _gen_case "$def_name" "$case_expr" "$dest" "$action" "$fold"

    if [[ "$action" == "negatable" ]]; then
        local neg_case_expr=$case_expr:gs/\|--/\|--no-/
        _gen_case "$def_name" "$neg_case_expr" "$dest" "$action" "$fold"
    fi
}

_gen_case() {
    # Print one case expression and action.
    local def_name=$1 case_expr=$2 dest=$3 action=$4 fold=$5

    # Set up case-folding (or not) for option value in \$1
    local value_ref='$1'
    case "$fold" in
        (lower) value_ref='${1:l}' ;;
        (upper) value_ref='${1:u}' ;;
        (none|'') value_ref='$1' ;;
        (*) tMsg warn "Invalid fold value '$fold'. Expected: upper, lower, none, or empty."
            return 94 ;;
    esac

    local buf="        ($case_expr) "

    case "$action" in
        (help)
            local helptext=$(aa_get -q "$def_name" help)
            buf+="print \"${helptext:-Help text}\"; return 0" ;;
        (version)
            local version=$(aa_get -q "$def_name" version)
            buf+="print \"${version:-1.0.0}\"; return 0" ;;
        (append_const)
            local const=$(aa_get "$def_name" const)
            buf+="$dest+=(\"$const\")" ;;
        (count)
            buf+="(( $dest++ ))" ;;

        (store_true)  buf+="$dest=1" ;;
        (store_false) buf+="$dest=''" ;;
        (store_const)
            local const=$(aa_get "$def_name" const)
            buf+="$dest=\"$const\"" ;;

        (append)
            buf+="shift; $dest+=(\"$value_ref\")" ;;
        (extend)
            buf+="shift; $dest+=(\"$value_ref\")" ;;
        (store)
            buf+="shift"
            local typ=$(aa_get -q "$def_name" type)
            local choices=$(aa_get -q "$def_name" choices)
            if [[ -n "$choices" ]]; then
                local -a choice_arr=(${(z)choices})
                if [[ "$ignore_case" == true ]]; then
                    buf+="; _validate_choice_ci \"$value_ref\" ${(qq)choice_arr} || return 96"
                else
                    buf+="; _validate_choice \"$value_ref\" ${(qq)choice_arr} || return 96"
                fi
            elif [[ -n "$typ" ]]; then
                buf+="; is_$typ \"$value_ref\" || { tMsg error \"Invalid $typ value: $value_ref\"; return 96; }"
            fi
            buf+="; $dest=\"$value_ref\""
            ;;

        (negatable)
            # Check if this is a negated form
            buf+="case \"\$1\" in (--no-*|--no) $dest='' ;; (*) $dest=1 ;; esac" ;;
        (*)
            tMsg warn "Unknown action '$action'."
            return 95 ;;
    esac
    print "$buf ;;"
}

_generate_abbrevs() {
    # Generate all non-ambiguous abbreviations for one alias of an option,
    # as a "|"-separated string.
    # Stops when abbreviation would collide with another option.
    local parser_name="$1" opt="$2"
    is_of_zerg_class ZERG_PARSER "$parser_name" || return $?
    if [[ "$opt" != --* ]]; then
        warn "Option to expand ('$opt') does not start with '--'."
        print "%s" "$opt";
        return;
    fi

    local base="${opt#--}"
    local abbrevs="$opt"  # Always include full option

    # Get all option names from parser  TODO Factor out
    local all_names=$(aa_get "$parser_name" all_arg_names)
    local -a all_names_arr=(${(z)all_names})
    local -A all_options=()
    aa_from_keys all_options all_names_arr
    #aa_export all_options

    # Generate from longest to shortest (no single letters, though)
    local i
    for (( i = ${#base} - 1; i >= 2; i-- )); do
        local abbrev="--${base[1,$i]}"

        # Check if this abbreviation collides with any existing option
        local found=$(aa_find_key -q all_options "$abbrev")
        local rc=$?
        if [[ $rc -eq 2 ]]; then
            break  # collision, stop
        elif [[ $rc -eq 0 ]]; then
            if [[ "$found" != "$opt" ]]; then
                # It's another option (probably exact match), stop
                break
            fi
        fi
        # rc == 1 means not found, which is fine - no collision
        abbrevs+="|$abbrev"
    done
    #warn "Expanded to: $abbrevs."
    printf "%s" "$abbrevs"
}

_validate_choice() {
    local val="$1"; shift
    local choice
    for choice in "$@"; do
        [[ "$val" == "$choice" ]] && return 0
    done
    tMsg error "Invalid choice '$val'. Valid choices: $*"
    return 1
}

_validate_choice_ci() {
    local val="${1:l}"; shift
    local choice
    for choice in "$@"; do
        [[ "$val" == "${choice:l}" ]] && return 0
    done
    tMsg error "Invalid choice '${1}'. Valid choices: $*"
    return 1
}
