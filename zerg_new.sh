#!/bin/zsh
# Create a new argument parser

zerg_new() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zerg_new parser_name [options]
Create a new argument parser.

Options:
  --add-help            Automatically add a "--help -h" option
  --allow_abbrev        Allow abbreviated option names (default: on)
  --description TEXT    Description for help text
  --description-paras   Retain blank lines in `description`.
  --epilog TEXT         Show at end of help
  --on-redefine V       Redefining parser or arg does error|warn|allow|ignore
  --help-file path      Path to help information
  --help-tool name      Name of a renderer for help information
  --ignore-case         Enable case-insensitive option matching
  --ignore-hyphens      E.g. "out-file" and "outfile" are the same
  --ic-choices          Ignore case on --choices values
  --usage               Show shorter help, mainly list of options
  --var-style STYLE     How to store results: 'separate' (default) or 'assoc'

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
        local disp=$(aa_get "$parser_name" "__on_redefine")
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
            tMsg 0 "Unknown value '$disp' for --on-redefine."
            return 89
        fi
    fi

    # Create hidden parser registry assoc
    typeset -ghA "$parser_name"

    # Set defaults
    aa_set "$parser_name" "__allow_abbrev" "1"
    aa_set "$parser_name" "__arg_names" ""
    #aa_set "$parser_name" "__description" ""
    #aa_set "$parser_name" "__epilog" ""
    aa_set "$parser_name" "__ignore_case" "0"  # TODO Use ""
    aa_set "$parser_name" "__on_redefine" "error"
    #aa_set "$parser_name" "__usage" ""
    aa_set "$parser_name" "__var_style" "separate"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --description)
                aa_set "$parser_name" "__description" "$2"
                shift 2 ;;
            --description-paras)
                aa_set "$parser_name" "__description-paras" 1
                shift ;;
            --epilog)
                aa_set "$parser_name" "__epilog" "$2"
                shift 2 ;;
            --help-file)
                aa_set "$parser_name" "__help_file" "$2"
                shift 2 ;;
            --help-tool)
                aa_set "$parser_name" "__help_tool" "$2"
                shift 2 ;;
            --ignore-case|-i)
                aa_set "$parser_name" "__ignore_case" "1"
                shift ;;
            --ignore-hyphens)
                aa_set "$parser_name" "__ignore_hyphens" "1"
                tMsg 0 "--ignore-hyphens is unfinished."
                shift ;;
            --allow-abbrev|--abbrev)
                aa_set "$parser_name" "__allow_abbrev" "1"
                shift ;;
            --no-allow_abbrev|--no-abbrev)
                aa_set "$parser_name" "__allow_abbrev" "0"
                shift ;;
            --usage)_
                aa_set "$parser_name" "__usage" ""
                shift ;;
            --var-style)
                if [[ "$2" != "separate" && "$2" != "assoc" ]]; then
                    tMsg 0 "zerg_new: --var-style must be 'separate' or 'assoc'"
                    return 97
                fi
                aa_set "$parser_name" "__var_style" "$2"
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
    local args=$(aa_get "$1" "$option_names")
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

    # TODO toggle
    local popts="ignore_case allow_abbrev var_style description usage epilog"

    req_sv_type assoc "$1" || return 97
    local p=$1
    print "    def processOptions() -> argparse.Namespace:\n"
    print "        parser = argparse.ArgumentParser(\n"
    for po in ${(x)popts}; do
        local poval=$(aa_get "$p" "$po")
        print "            $po='$poval',\n"
    done
    print "        )\n\n"

    local argopts="type action dest default choices const"
    argopts+=" counter flag fold on_redefine format nargs required reset help "
    local args=$(aa_get "$1" "$option_names")
    local cutLen=(( $#1 + 3 ))
    for arg in ${(zO)args}; do
        local argShort=$arg[$cutLen:-1]
        print "            parser.add_argument(\"$argShort\",\n"
        for ao in ${(arg)argopts}; do
            local val=$(aa_get "$arg" "$ao")
            [ "$val" ] || continue
            # TODO choices, nargs->int, help->esc
            print "                $ao=\"$val\",\n"
        done
        print "            )\n"
    done

    print "\n        return parser.parse_args()\n"
}
