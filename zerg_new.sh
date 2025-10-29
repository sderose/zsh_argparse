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

    if [[ "$1" == "-h" ]]; then
        local pr=`typeset -p zerg_opts | sed -e 's/\[/\n    --/g' -e 's/_/-/g' -e 's/]=/ \t/'`
        cat <<EOF
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
        return
    fi

    req_argc 1 99 $# || return 98
    local parser_name="$1"
    shift

    # Check if already exists, and deal.
    if typeset -p "$parser_name" &>/dev/null; then
        local disp=$(aa_get "$parser_name" "on_redefine")
        # TODO: When is option parsed???
        if [[ $disp == error ]]; then
            tMsg 0 "zerg_new: Error: Parser '$parser_name' already exists."
            return 98
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "zerg_new: Warning: Parser '$parser_name' already exists."
            zerg_del "$parser_name"
        elif [[ $disp == allow ]]; then
            zerg_del "$parser_name"
        else
            tMsg 0 "new: For --on-redefine: Unknown value '$disp'."
            return 89
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
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
                    return 97
                fi
                aa_set "$parser_name" "var_style" "$2"
                shift 2 ;;
            -*)
                tMsg 0 "zerg_new: Unknown option: $1"
                return 96 ;;
            *)
                tMsg 0 "zerg_new: Unexpected argument: $1"
                return 95 ;;
        esac
    done
    return 0
}

zerg_del() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zerg_del parser_name
Delete/destroy an argument parser and all its defined arguments.
Arguments that were re-used from another parser are not destroyed.

EOF
        return
    fi

    req_sv_type assoc "$1" || return 97

    for name in "${(P)1}[@]"; do
        [[ $name =~ ^$1__ ]] || continue
        [[ `sv_type $name` == "assoc" ]] && unset $name
    done
    unset "$1"
}

zerg_print() {
    req_sv_type assoc "$1" || return 97
    aa_export -f view $1
    local args=$(aa_get "$1" "$art_names_list")
    for arg in ${(zO)args}; do
        aa_export -f view $arg
    done
}

zerg_to_argparse() {
    if [[ "$1" == "-h" ]]; then
        cat <<EOF
Usage: zerg_to_argparse parserName
Writes out a zerg parser as roughly equivalent Python argparse calls.
A few things don't quite transfer -- for example, zerg has quite a few more
types, and at least one more action.
TODO: Aliases are not yet included -- just the reference name.
EOF
        return
    fi

    req_sv_type assoc "$1" || return 97
    local p=$1

    print "    def processOptions() -> argparse.Namespace:\n"
    print "        parser = argparse.ArgumentParser(\n"

    # TODO flag options (no value tokens following)
    for po in ignore_case allow_abbrev var_style description usage epilog; do
        local poval=$(aa_get "$p" "$po")
        print "            $po='$poval',"
    done
    print "        )"

    local argopts="type action dest default choices const"
    argopts+=" counter flag fold on_redefine format nargs required reset help "
    local args=$(aa_get "$1" "arg_names_list")

    tMsg 0 "Args to export: $args"
    local cutLen=(( $#1 + 3 ))
    for arg in ${(zO)args}; do
        sv_type $arg assoc || tMsg 0 "Bad arg storage."
        tMsg 0 "zerg_to_argparse: $arg"
        local argShort=$arg[$cutLen:-1]
        local buf="            parser.add_argument(\"$argShort\""
        for ao in ${(arg)argopts}; do
            local val=$(aa_get "$arg" "$ao")
            tMsg 0 "got $ao = $val"
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
