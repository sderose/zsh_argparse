#!/bin/zsh
# Create a new argument parser

zerg_new() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zerg_new parser_name [options]
Create a new argument parser

Options:
  --description TEXT    Description for help text
  --ignore-case         Enable case-insensitive option matching
  --allow-abbrev        Allow abbreviated option names (default: on)
  --var-style STYLE     How to store results: 'separate' (default) or 'assoc'

Example:
  zerg_new MYPARSER --description "My cool script"
  zerg_add MYPARSER "--verbose -v" --counter
  zerg_parse MYPARSER "$@"
EOF
        return
    fi

    if [[ $# -lt 1 ]]; then
        tMsg 0 "zerg_new: Expected parser name"
        return 99
    fi

    local parser_name="$1"
    shift

    # Check if already exists
    if typeset -p "$parser_name" &>/dev/null; then
        tMsg 0 "zerg_new: Parser '$parser_name' already exists"
        return 98
    fi

    # Create hidden parser registry assoc
    typeset -ghA "$parser_name"

    # Set defaults
    aa_set "$parser_name" "__ignore_case" "0"
    aa_set "$parser_name" "__allow_abbrev" "1"
    aa_set "$parser_name" "__var_style" "separate"
    aa_set "$parser_name" "__description" ""
    aa_set "$parser_name" "__registered_args" ""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --description)
                aa_set "$parser_name" "__description" "$2"
                shift 2 ;;
            --ignore-case)
                aa_set "$parser_name" "__ignore_case" "1"
                shift ;;
            --allow-abbrev)
                aa_set "$parser_name" "__allow_abbrev" "1"
                shift ;;
            --no-abbrev)
                aa_set "$parser_name" "__allow_abbrev" "0"
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
