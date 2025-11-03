#!/bin/zsh
# Create a new argument parser

zerg_new() {
    local -A zerg_opts=(
        [add_help]="Automatically add a '--help -h' option"
        [allow_abbrev]="Allow abbreviated option names (default: on)"
        [abbrev_enums]="Allow abbreviated enum values"
        [description]="TEXT: Description for help text"
        [description_paras]="Retain blank lines in 'description'"
        [epilog]="TEXT: Show at end of help"
        [help_file]="path: to help information"
        [help_tool]="name: of a renderer for help information"
        [ignore_case]="Enable case-insensitive option matching"
        [ignore_hyphens]="E.g. 'out-file' and 'outfile' are the same"
        [ic_choices]="Ignore case on choices values"
        [on_redefine]="[error|warn|allow|ignore]: What redefining parser or arg does "
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
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 99 $# || return ZERR_ARGC
    local parser_name="$1"
    shift

    # Check if already exists, and deal.
    if typeset -p "$parser_name" &>/dev/null; then
        local disp=$(aa_get "$parser_name" "on_redefine")
        # TODO: When is option parsed???
        if [[ $disp == error ]]; then
            tMsg 0 "zerg_new: Error: Parser '$parser_name' already exists."
            return ZERR_DUPLICATE
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "zerg_new: Warning: Parser '$parser_name' already exists."
            zerg_del "$parser_name"
        elif [[ $disp == allow ]]; then
            zerg_del "$parser_name"
        else
            tMsg 0 "new: For --on-redefine: Unknown value '$disp'."
            return ZERR_ENUM
        fi
    fi

    # Create hidden parser registry assoc with defaults
    #setopt xtrace
    echo "pname '$parser_name'"
    typeset -ghA "$parser_name"
    aa_set $parser_name add_help ""
    aa_set $parser_name allow_abbrev 1
    aa_set $parser_name abbrev_enums 1
    aa_set $parser_name description ""
    aa_set $parser_name description_paras ""
    aa_set $parser_name epilog ""
    aa_set $parser_name help_file ""
    aa_set $parser_name help_tool ""
    aa_set $parser_name ignore_case 1
    aa_set $parser_name ignore_hyphens ""
    aa_set $parser_name ic_choices ""
    aa_set $parser_name on_redefine "error"
    aa_set $parser_name usage ""
    aa_set $parser_name var_style "separate"
    aa_set $parser_name arg_names ""

    # Parse options
    while [[ "$1" == -* ]]; do case "$1" in
            --allow-abbrev|--abbrev-options)
                aa_set "$parser_name" "allow_abbrev" "1"
                shift ;;
            --no-allow-abbrev|--no-abbrev-options)
                aa_set "$parser_name" "allow_abbrev" ""
                shift ;;
            --abbrev-enums )
                aa_set "$parser_name" "enum_abbrev" "1"
                shift ;;
            --no-abbrev-enums )
                aa_set "$parser_name" "enum_abbrev" ""
                shift ;;
            --description)
                aa_set "$parser_name" "description" "$2"
                shift 2 ;;
            --description-paras)
                aa_set "$parser_name" "description_paras" 1
                shift ;;
            --epilog)
                aa_set "$parser_name" "epilog" "$2"
                shift 2 ;;
            --help-file)
                aa_set "$parser_name" "help_file" "$2"
                shift 2 ;;
            --help-tool)
                aa_set "$parser_name" "help_tool" "$2"
                shift 2 ;;
            --ignore-case-enums)
                aa_set "$parser_name" "ignore_case_enums" "1"
                shift ;;
            --no-ignore-case-enums)
                aa_set "$parser_name" "ignore_case" ""
                shift ;;
            --ignore-case-options|--ignore-case|-i)
                aa_set "$parser_name" "ignore_case" "1"
                shift ;;
            --no-ignore-case-options|--no-ignore-case)
                aa_set "$parser_name" "ignore_case_enums" ""
                shift ;;
            --ignore-hyphens)
                aa_set "$parser_name" "ignore_hyphens" "1"
                tMsg 0 "--ignore-hyphens is unfinished."
                shift ;;
            --on-redefine)
                aa_set "$parser_name" "on_redefine" "$2"
                shift 2;;
            --usage)
                aa_set "$parser_name" "usage" ""
                shift ;;
            --var-style)
                if [[ "$2" != "separate" && "$2" != "assoc" ]]; then
                    tMsg 0 "zerg_new: --var-style must be 'separate' or 'assoc'"
                    return ZERR_ENUM
                fi
                aa_set "$parser_name" "var_style" "$2"
                shift 2 ;;
            *)
                tMsg 0 "zerg_new: Unknown option: $1"; return ZERR_BAD_OPTION ;;
        esac
    done
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
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_sv_type assoc "$1" || return ZERR_SV_TYPE

    for name in "${(P)1}[@]"; do
        [[ $name =~ ^$1__ ]] || continue
        [[ `sv_type $name` == "assoc" ]] && unset $name
    done
    unset "$1"
}

zerg_print() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_print parser_name
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    aa_export -f view $1
    local args=$(aa_get "$1" "$art_names_list")
    for arg in ${(zO)args}; do
        aa_export -f view $arg
    done
}

zerg_to_argparse() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_to_argparse parserName
Writes out a zerg parser as roughly equivalent Python argparse calls.
A few things don't quite transfer -- for example, zerg has quite a few more
types, and at least one more action.
TODO: Aliases are not yet included -- just the reference name.
TODO: flag options (no value tokens following)
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    print "    def processOptions() -> argparse.Namespace:\n"
    print "        parser = argparse.ArgumentParser(\n"

    for po in ignore_case allow_abbrev var_style description usage epilog; do
        local poval=$(aa_get "$1" "$po")
        print "            $po='$poval',"
    done
    print "        )"

    # Keep a list of what options we've written, so aliases don't cause dups
    local -A defname2optnames=()

    local cutLen=(( $#1 + 3 ))
    for arg in ${(zO)1[@]}; do
        [ $arg == -* ] || continue
        local argdefname=${${(P)1}[$arg]}
        [ $defname2optnames[$argdefname] ] && continue
        $defname2optnames[$argdefname]=1

        sv_type $argdefname assoc || tMsg 0 "Bad storage for argdef '$argdefname'."
        local arg_names=`aa_get $arg "arg_names"`
        local arg_names_as_params=$arg_names:s/ /\", \"/
        local buf="            parser.add_argument(\"$arg_names_as_params\""
        for ao in ${(x)zerg_argdef_fields}; do
            [ $ao == arg_names ] && continue
            local val=$(aa_get "$arg" "$ao")
            [ "$val" ] || continue
            is_int "$val" || val="'$val'"
            local item=" $ao=$val"
            resultLen=(($#buf + $#item))
            if [[ resultLen > 79 ]]; then
                print "$buf,"
                buf="           $item"
            else
                buf+=", $item"
            fi
        done
        print "$buf\n            )\n"
    done

    print "\n        return parser.parse_args()"
}
