#!/bin/zsh
# Notes for support for zsh -U arrays like Python sets.

###############################################################################
# Basics: init, clear, copy, update, set_default
#
set_init() {
    req_sv_type undef $1 || return ZERR_SV_TYPE
    typeset -A "$1"
    : ${(P)1::=()}
}

set_clear() {
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    typeset -A "$1"
    : ${(P)1::=()}
}

set_copy() {
    aa_copy $1 $2
    return $?
}


###############################################################################
# Predicates: len, eq, has (=contains)
#
set_has() {  # contains item
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    return aa_has "$1" "$2"
}

set_eq() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || return ZERR_SV_TYPE
    [[ ${(P)#1} == ${(P)#2} ]] || return 1
    for key in ${(P)1[@]}; do
        aa_has $2 $key || return 1
    done
}

set_ne() {
    set_eq $1 $2 && return 1 || return 0
}

set_lt() {  # proper subset
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    [[ ${(P)#1} < ${(P)#2} ]] && return 1
    for key in ${(P)1[@]}; do
        aa_has $2 $key || return 1
    done
}

set_le() {  # subset
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    [[ ${(P)#1} <= ${(P)#2} ]] && return 1
    for key in ${(P)1[@]}; do
        aa_has $2 $key || return 1
    done
}

set_ge() {  # proper superset
    set_lt $2 $1; return $?
}

set_gt() {  # superset
    set_le $2 $1; return $?
}

set_disjoint() {
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    for key in ${(P)1[@]}; do
        aa_has $2 $key && return 1
    done
    for key in ${(P)2[@]}; do
        aa_has $1 $key && return 1
    done
    return 0
}

set_intersects() {  # intersect-or-equal?
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    for key in ${(P)1[@]}; do
        aa_has $2 $key && return 0
    done
    return 1
}


###############################################################################
# Item access
#
set_insert() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    aa_set $1 $2 1
}

set_del() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    aa_unset $1 $2
}


###############################################################################
# Extractors: keys, values, export
#
set_values() {
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    aa_keys $1
}

set_export() {
    # TODO handle --format
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    echo (${(Pqq)1[@]})
}


###############################################################################
# Combinators (modify the first assoc?)
#
set_intersect() {  # inplace?
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    for key in ${(P)1[@]}; do
        aa_has $2 $key || aa_unset $1 $key
    done
}

set_union() {
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    for key in ${(P)2[@]}; do
        aa_has $1 $key || aa_set $1 $key 1
    done
}

set_diff() {
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    for key in ${(P)2[@]}; do
        aa_has $1 $key && aa_unset $1 $key
    done
}

set_symmdiff() {
    req_sv_type assoc $1 || return ZERR_SV_TYPE
    req_sv_type assoc $2 || typeset -A $2
    for key in ${(P)1[@]}; do
        aa_has $2 $key && aa_unset $1 $key
    done
    for key in ${(P)2[@]}; do
        if [ aa_has $1 $key ]; then
            aa_unset $1 $key
        else
            aa_set $1 $key
        fi
    done
    # TODO
}
