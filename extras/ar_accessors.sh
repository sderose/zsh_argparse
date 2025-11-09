#!/bin/zsh
# Notes for support for zsh (non-associative) arrays.

if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    return ZERR_UNDEF
fi


###############################################################################
# Basics: init, clear, copy
#
ar_init() {
    typeset -a $1
    : ${(P)1::=()}

}

ar_clear() {
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    typeset -a $1
    : ${(P)1::=()}
}

ar_copy() {
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    return ZERR_NOT_YET
}


###############################################################################
# Predicates: len, eq, has (=contains)
#
ar_len() {
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    echo ${(P)#1}
}

ar_eq() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    [[ ${(P)#1} -eq ${(P)#2} ]] || return 1
    local i
    for (i=1; i<=$(P)#1}; i++); do
        [[ ${${(P)1}[$i]} -eq ${${(P)1}[$i]} ]] || return 2  # TODO which compare
    done
    return 0
}

ar_has() {  ## cf ar_find? if (( $x[(Ie)value] ));
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    for (i=1; i<=$(P)#1}; i++); do
        [[ ${${(P)1}[$i]} -eq $2 ]] && return 0
    done
    return 1
}

ar_homogeneous() {
    if [[ "$1" == "-h" ]] then
        cat <<'EOF'
Usage: ar_homogeneous arrayname zerg_type
Return 0 (success) if the zsh array's entries all pass is_of_zerg_type
   for the given type. Note that many strings can satisfy multiple types.
   For example, integer, complex, and some boolean values are also floats,
   and everything is a string.
EOF
        return 0
    fi
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    req_aa_has zerg_types "$2" || return ZERR_ENUM
    local -i nitems=$(P)#1}
    for (i=1; i<=$nitems; i++); do
        local item=${${(P)1}[$i]}
        [ is_of+sv_type $1 $2 ] || return 1
    done
    return 0
}


###############################################################################
# Item access: set, get, unset (=del)
#
ar_set() {
    req_argc 3 3 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    return ZERR_NOT_YET
}

ar_get() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    req_zerg_type integer "$2" || return ZERR_ZERG_TVALUE
    # slicing
    return ZERR_NOT_YET
}

ar_unset() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    req_zerg_type integer "$2" || return ZERR_ZERG_TVALUE
    return ZERR_NOT_YET
}

ar_append() {
    req_argc 2 2 $# || return ZERR_ARGC
    req_zerg_type array "$1" || return ZERR_ZERG_TVALUE
    return ZERR_NOT_YET
}

ar_insert() {
    req_argc 3 3 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    req_zerg_type integer "$2" || return ZERR_ZERG_TVALUE
    return ZERR_NOT_YET
}


###############################################################################
# Extractors: values, export
#
ar_values() {  # TODO Or keys?
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    return ZERR_NOT_YET
}

ar_find_value() {
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    local -i nitems=$(P)#1}
    for (i=1; i<=$nitems; i++); do
        local item=${${(P)1}[$i]}
        if [[ $item == $2 ]]; then
            echo $i
            return 0
        fi
    done
    return 1
}

ar_count() {
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    local -i nitems=$(P)#1} nfound=0
    for (i=1; i<=$nitems; i++); do
        local item=${${(P)1}[$i]}
        [[ $item -eq $2 ]] && nfound+=1
    done
    echo $nfound
}

ar_export() {
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    return ZERR_NOT_YET
}


###############################################################################
#
#
ar_sort() {  # TODO Does this change externality, etc?
    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type array "$1" || return ZERR_SV_TYPE
    local -a tmp=(${(o)1})
    typeset -a $1
    : ${(P)1::=($tmp)}
}

# add, mult  TODO
