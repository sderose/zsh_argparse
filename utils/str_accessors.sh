#!/bin/zsh
# Support for Python-like string operations in zsh.

###############################################################################
# Character set based constants
#
chr_ascii_lowercase='abcdefghijklmnopqrstuvwxyz'
chr_ascii_uppercase='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
chr_ascii_letters="$ascii_lowercase$ascii_uppercase"
chr_digits='0123456789'
chr_hexdigits='0123456789abcdefABCDEF'
chr_octdigits='01234567'
chr_punctuation='!"#$%&'"'()*+,-./:;<=>?@[\]^_\`{|}~"
chr_printable="$chr_ascii_letters$chr_digits$chr_punctuation$chr_whitespace"
chr_whitespace=$' \t\n\r\f\v'


###############################################################################
# Predicates
#
str_eq() { [[ "$1" == "$2" ]] || return 1 }
str_ge() { [[ "$1" > "$2" ]] || [[ "$1" == "$2" ]] || return 1 }
str_gt() { [[ "$1" > "$2" ]] || return 1 }
str_le() { [[ "$1" < "$2" ]] || [[ "$1" == "$2" ]] || return 1 }
str_lt() { [[ "$1" < "$2" ]] || return 1 }
str_ne() { [[ "$1" != "$2" ]] || return 1 }
str_contains() { [[ "$1" == *"$2"* ]] || return 1 }
str_endswith() { [[ "$1" == *"$2" ]] || return 1 }
str_startswith() { [[ "$1" == "$2"* ]] || return 1 }


###############################################################################
# isa
#
str_isalnum() { [[ "$1" =~ ^[a-zA-Z0-9]+$ ]] || return 1 }
str_isalpha() { [[ "$1" =~ ^[a-zA-Z]+$ ]] || return 1 }
str_isascii() { [[ "$1" =~ ^[\x01-\x7F]+$ ]] || return 1 }
str_isdecimal() { [[ "$1" =~ ^[0-9]+$ ]] || return 1 }
str_isdigit() { [[ "$1" =~ ^[0-9]+$ ]] || return 1 }
str_isidentifier() { is_ident "$1"; return $? }
str_islower() { [[ "$1" =~ ^[a-z]+$ ]] || return 1 }
str_isnumeric() { [[ "$1" =~ ^[0-9]+$ ]] || return 1 }
str_isprintable() { [[ "$1" =~ ^[\ -~]+$ ]] || return 1 }
str_isspace() { [[ "$1" =~ ^[$WHITESPACE]+$ ]] || return 1 }
str_isupper() { [[ "$1" =~ ^[A-Z]+$ ]] || return 1 }
str_istitle() {
    [[ "$1" =~ ^[A-Z][a-z]*([[:space:]]+[A-Z][a-z]*)*$ ]] || return 1
    # More like Python:
    # ^([^a-zA-Z]*[A-Z][a-z]*[^a-zA-Z]+)*[^a-zA-Z]*[A-Z][a-z]*[^a-zA-Z]*$
}


###############################################################################
# Case and charset
#
str_capitalize() { echo ${(C)1} }

str_casefold() { return ZERR_NOT_YET }  # TODO
str_encode() {  # use iconv?
    return ZERR_NOT_YET }
str_lower() { echo ${(L)1} }
str_swapcase() { echo "$1" | tr 'a-zA-Z' 'A-Za-z' }
str_title() { return ZERR_NOT_YET }   # TODO
str_translate() {  # just use tr
    return ZERR_NOT_YET }
str_upper() { echo ${(U)1} }
str_visible() { echo ${(V)1} }
str_normspace() {
    # includes \f, but that's not an XML char anyway.
    local x="$1"
    while [[ $x[1] =~ [$WHITESPACE] ]]; x=$x[2:-1]
    while [[ $x[-1] =~ [$WHITESPACE] ]]; x=$x[1:-2]
    echo ${x//[$WHITESPACE]##/ }
}


###############################################################################
# Strip and pad
#
str_center() {
    return ZERR_NOT_YET  # TODO
}

str_expandtabs() {  # just use *nix expand
    return ZERR_NOT_YET
}

str_ljust() {  # cf r:expr:s1:s2  # TODO
    return ZERR_NOT_YET
}

str_lstrip() {
    local x="$1"
    local tostrip="$2"
    [[ -z "$tostrip" ]] && tostrip="$WHITESPACE"
    while [[ "$x[1]" == [$tostrip] ]]; do
        x="${x:1}"
    done
    echo "$x"
}

str_removeprefix() {
    local str="$1"
    local prefix="$2"
    if [[ "$str" == "$prefix"* ]]; then
        echo "${str#$prefix}"
    else
        echo "$str"
    fi
}

str_removesuffix() {
    local str="$1"
    local suffix="$2"
    if [[ "$str" == *"$suffix" ]]; then
        echo "${str%$suffix}"
    else
        echo "$str"
    fi
}

str_rjust() {  # cf l:expr:s1:s2
    local x="$1"
    local -i needed=(( $#1 - $2 ))
    if [[ $needed > 0 ]]; then
        fill=$3
        [ -n "$fill" ] || fill=" "
        while [[ $needed > 0 ]]; do
            x+=$fill
            $needed-=$#fill
        done
    fi
    echo "$x"
}

str_rstrip() {
    local x="$1"
    local tostrip="$2"
    [[ -z "$tostrip" ]] && tostrip="$WHITESPACE"
    while [[ "$x[-1]" == [$tostrip] ]]; do
        x="${x:0:-1}"
    done
    echo "$x"
}

str_strip() {
    local x
    x=$(lstrip "$1" "$2")
    rstrip "$x" "$2"
}

str_zfill() {
    local str="$1"
    local width="$2"
    local sign=""
    if [[ "$str" =~ ^[+-] ]]; then
        sign="${str:0:1}"
        str="${str:1}"
    fi
    local padlen=$(( width - ${#str} - ${#sign} ))
    if (( padlen > 0 )); then
        printf "%s%0${padlen}d%s" "$sign" 0 "$str"
    else
        echo "$sign$str"
    fi
}


###############################################################################
# Find/replace/transform
#
str_partition() {
    return ZERR_NOT_YET  # TODO
}

str_replace() {  # TODO support count?
    local str="$1"
    echo "$1:s//$2/$3"
}

str_rfind() {
    local str="$1"
    local sub="$2"
    local end="${3:-${#str}}"
    local temp="${str:0:$end}"
    local pos="${temp%$sub*}"
    if [[ "$temp" == *"$sub"* ]]; then
        echo ${#pos}
    else
        echo -1; return 1
    fi
}

str_rindex() {
    local str="$1"
    local sub="$2"
    local end="${3:-${#str}}"
    local temp="${str:0:$end}"
    local pos="${temp%$sub*}"
    if [[ "$temp" == *"$sub"* ]]; then
        echo ${#pos}
        return 0
    else
        warn 1 "substring not found"
        return 1
    fi
}

str_rpartition() {
    return ZERR_NOT_YET  # TODO
}

str_rsplit() {
    return ZERR_NOT_YET  # TODO
}

str_split() {
    local str="$1"
    local delim="${2:- }"
    local -a result
    if [[ -z "$delim" ]]; then
        result=("${(@s::)str}")
    else
        result=("${(@s/$delim/)str}")
    fi
    printf '%s\n' "${result[@]}"
}

str_splitlines() {
    local str="$1"
    local keepends="${2:-0}"
    if (( keepends )); then
        echo "$str" | grep -o '.*$'
    else
        echo "$str" | sed 's/\r$//' | grep -o '^.*'
    fi
}


###############################################################################
# Misc
#
str_len() {
    echo $#1
}

str_mul() {
    local str="$1"
    local -i n="$2"
    local result=""
    for (( i=0; i<n; i++ )); do
        result+="$str"
    done
    echo "$result"
}

str_rmul() {
    __mul__ "$1" "$2"
}

str_hash() {
    echo "$1" | md5
}

str_getitem() {
    local str="$1"
    local -i idx="$2"
    if [[ "$idx" == *:* ]]; then
        # Slice notation start:end
        local start="${idx%%:*}"
        local end="${idx#*:}"
        [[ -z "$start" ]] && start=0
        [[ -z "$end" ]] && end=${#str}
        echo "${str:$start:$((end-start))}"
    else
        # Single index
        echo "${str:$idx:1}"
    fi
}

str_count() {
    local str="$1"
    local sub="$2"
    local -i cnt=0
    local temp="$str"
    while [[ "$temp" == *"$sub"* ]]; do
        temp="${temp#*$sub}"
        (( cnt++ ))
    done
    echo $cnt
}

str_find() {
    local str="$1"
    local sub="$2"
    local start="${3:-0}"
    local temp="${str:$start}"
    local pos="${temp%%$sub*}"
    if [[ "$temp" == *"$sub"* ]]; then
        echo $(( start + ${#pos} ))
    else
        echo -1
    fi
}

str_format() {  # just use printf
    return ZERR_NOT_YET
}

str_format_map() {  # just use printfx
    return ZERR_NOT_YET
}

str_index() {
    local str="$1"
    local sub="$2"
    local start="${3:-0}"
    local temp="${str:$start}"
    local pos="${temp%%$sub*}"
    if [[ "$temp" == *"$sub"* ]]; then
        echo $(( start + ${#pos} ))
        return 0
    else
        warn 1 "substring not found"
        return 1
    fi
}

str_join() {  # cf  j:string:
    local delim="$1"
    shift
    local buf="$1"
    shift
    for x in "$@"; do
        buf+="$delim$x"
    done
    echo "$buf"
}

str_maketrans() {  $ just use tr
    return ZERR_NOT_YET
}
