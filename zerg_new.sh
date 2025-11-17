#!/bin/zsh
# Create a new argument parser

_zerg_parser_init() {
    # Check if already exists, and deal.
    local priorType=`sv_type $parser_name`
    if [[ $priorType == ^(scalar|integer|float|array)$ ]]; then
        tMsg 0 "Cannot create zerg parser '$parser_name', variable already exists."
        return $ZERR_DUPLICATE
    elif [[ $priorType == "assoc" ]]; then
        local disp=$(aa_get "$parser_name" "on_redefine")
        # TODO: When is option parsed???
        if [[ $disp == allow ]] || [[ $disp == "" ]]; then
            zerg_del "$parser_name"
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "Warning: Parser '$parser_name' already exists."
            zerg_del "$parser_name"
        elif [[ $disp == error ]]; then
            tMsg 0 "Error: Parser '$parser_name' already exists."
            return $ZERR_DUPLICATE
        else
            tMsg 0 "Unknown value '$disp' for --on-redefine."
            return $ZERR_ENUM
        fi
    fi

    # Create hidden parser assoc with default options, etc.
    typeset -ghA "$parser_name"

    aa_set $parser_name "$EDDA_CLASS_KEY" "ZERG_PARSER"
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
        local pr=`typeset -p zerg_opts | sed -e 's/\[/\n    --/g' -e 's/_/-/g' -e 's/]=/ \t/'`
        cat <<'EOF'
Usage: zerg_new parser_name [options]
Create a new argument parser.

Options (flag options can be turned off via --no-...._:
$pr

Example:
  zerg_new MYPARSER --description "My cool script"
  zerg_add MYPARSER "--verbose -v" --counter
  zerg_parse MYPARSER "$@"

These options of Python ArgumentParser are not (yet) supported:
  prog, parents, formatter_class, prefix_chars, fromfile_prefix_chars,
  argument_default, conflict_handler, exit_on_error
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 99 $# || return $ZERR_ARGC
    local parser_name="$1"
    shift

    echo "Creating parser '$parser_name'"
    _zerg_parser_init $parser_name || return $?

    # Parse options
    while [[ "$1" == -* ]]; do case "$1" in
            --allow-abbrev|--abbrev)
                aa_set "$parser_name" "allow_abbrev" 1 ;;
            --no-allow-abbrev|--no-abbrev)
                aa_set "$parser_name" "allow_abbrev" "" ;;
            --allow-abbrev-choices|--abbrevc)
                aa_set "$parser_name" "allow_abbrev_choices" 1 ;;
            --no-allow-abbrev-choices|--no-abbrevc)
                aa_set "$parser_name" "allow_abbrev_choices" "" ;;
            --description)
                shift; aa_set "$parser_name" "description" "$1" ;;
            --description-paras|--dparas)
                aa_set "$parser_name" "description_paras" 1 ;;
            --epilog)
                shift; aa_set "$parser_name" "epilog" "$1";;
            --export|-x)
                aa_set "$parser_name" "export" 1 ;;
            --no-export|--nx)
                aa_set "$parser_name" "export" "" ;;
            --help-file)
                shift; aa_set "$parser_name" "help_file" "$1" ;;
            --help-tool)
                shift; aa_set "$parser_name" "help_tool" "$1" ;;
            --ignore-case-choices|--icc)
                aa_set "$parser_name" "ignore_case_choices" 1 ;;
            --no-ignore-case-choices|--no-icc|--nicc)
                aa_set "$parser_name" "ignore_case_choices" "" ;;
            --ignore-case-options|--ignore-case|--ic|-i)
                aa_set "$parser_name" "ignore_case" 1 ;;
            --no-ignore-case-options|--no-ignore-case|--no-ic|--nic)
                aa_set "$parser_name" "ignore_case_choices" "" ;;
            --ignore-hyphens|--ih)
                aa_set "$parser_name" "ignore_hyphens" 1
                tMsg 0 "--ignore-hyphens is unfinished." ;;
            --no-ignore-hyphens|--no-ih|--nih)
                aa_set "$parser_name" "ignore_hyphens" "" ;;
            --on-redefine|--redef)
                shift; aa_set "$parser_name" "on_redefine" "$1" ;;
            --usage)
                aa_set "$parser_name" "usage" "" ;;
            --var-style|--vars)
                shift
                if [[ "$1" != "separate" && "$1" != "assoc" ]]; then
                    tMsg 0 "--var-style must be 'separate' or 'assoc'"
                    return $ZERR_ENUM
                fi
                aa_set "$parser_name" "var_style" "$1" ;;
            *)
                tMsg 0 "Unknown option: $1"; return $ZERR_BAD_OPTION ;;
        esac
        shift
    done

    if ! [ `aa_get -q "$parser_name" "export"` ]; then
        export -n $parser_name
    fi
    return 0
}

zerg_del() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_del parser_name
Delete/destroy an argument parser and all its defined arguments.
Arguments that were re-used from another parser are not destroyed.

EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_edda_class ZERG_PARSER "$1" || return $?
    for name in "${(P)1}[@]"; do
        [[ $name =~ ^--*$1 ]] || continue
        req_edda_class ZERG_ARG_DEF "$name" && unset ${(P)1}
    done
    unset "$1"
}

zerg_print() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_print parser_name
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_edda_class ZERG_PARSER "$1" || return $?
    aa_export -f view "$1"
    local args=$(aa_get "$1" "$art_names_list")
    for arg in ${(zO)args}; do
        aa_export -f view $arg
    done
}

zerg_to_argparse() {
    local sp="            "
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_to_argparse parser_name
Writes out a zerg parser as roughly equivalent Python argparse calls.
A few things don't quite transfer -- for example, zerg has quite a few more
types, at least one more action, and added parser options.
TODO: Aliases are not yet included -- just the reference name.
TODO: flag options (no value tokens following)
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_edda_class ZERG_PARSER "$1" || return $?
    local parser_name="$1"

    local -A notpython=(
        [allow_abbrev_choices]=1 [description_paras]=1 [export]=1
        [help_file]=1 [help_tool]=1 [ignore_case]=1 [ignore_case_choices]=1
        [ignore_hyphens]=1 [on_redefine]=1 [var_style]=1 )
    print "    def processOptions() -> argparse.Namespace:"
    print "        parser = argparse.ArgumentParser("
    for po in ignore_case allow_abbrev description usage epilog; do
        #[ "$notpython[$arg]" ] && continue
        local poval=$(aa_get "$1" "$po")
        is_float -q $poval || poval="\"$poval\""
        print "$sp$po=$poval,"
    done
    print "        )"

    # Collect an assoc of argdefname->optnames
    local adf=`aa_get $parser_name all_def_names`
    local -a all_def_names=(${(z)adf})
    for def_name in ${(oz)all_def_names}s; do
        tMsg 0 "Collecting, def_name '$def_name'."
        if ! [[ `sv_type $def_name` == assoc ]]; then
            tMsg 0 "Bad storage for argdef '$def_name'."
        else
            local add_buf=`zerg_arg_to_add_argument $def_name`
            print $add_buf
        fi
    done

    print "\n        return parser.parse_args()"
}

zerg_arg_to_add_argument() {
    local def_name="$1"
    local aliases=`aa_get $def_name "arg_names"`
    local sp="            "
    local buf="${sp}parser.add_argument("
    for name in ${(z)aliases}; do
        buf+="\"$name\", "
    done

    for ao in type action default choices const dest nargs required help; do
        local val=$(aa_get "$def_name" "$ao")
        [ "$val" ] || continue
        is_float "$val" || val="\"$val\""
        local item="$ao=$val"
        resultLen=(($#buf + $#item + 2))
        if [[ resultLen > 79 ]]; then
            print "$buf,"
            buf="$sp$item"
        else
            buf+=", $item"
        fi
    done
    print "$buf\n       )"
}
