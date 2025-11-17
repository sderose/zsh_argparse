#!/bin/zsh
#
###############################################################################
# Test harnesses loosely like Python unittest.
# But shell functions sort of "return" different things: value, RC, and stdout.

print_chars() {
    local i c
    for (( i=1; i <= $#; i+=1 )); do
        local arg=$argv[$i]
        print "Argument $i:"
        for (( c=1; c <= $#arg; c+=1 )); do
            printf "    @%03d:  0x%02X  '%s'\n" $c "'${arg[$c]}" $arg[$c]
        done
    done
}

testRC() {
    if [[ $# < 2 ]]; then
        echo "testRC: Need 2 arguments (result, command), not $#."
        return $ZERR_ARGC
    fi
    local expect=$1  # 'PASS', 'FAIL', or a specific number
    shift
    tMsg 1 "testRC: running /$@/. ($# args)"
    "$@"
    local rc=$?
    if [[ $expect == 'PASS' ]]; then
        if [[ $rc == 0 ]]; then
            tMsg 1 "PASS: $@"
            return 0
        else
            tMsg 0 "FAIL: $@\n    expected RC $expect but got $rc."
            ((FAILCT+=1))
            return $ZERR_TEST_FAIL
        fi
    elif [[ $expect == 'FAIL' ]]; then
        if [[ $rc == 0 ]]; then
            tMsg 0 "FAIL (unexpected pass): $@"
            ((FAILCT+=1))
            return $ZERR_TEST_FAIL
        else
            tMsg 1 "PASS: $@"
            return 0
        fi
    else
        if [[ $rc == $expect ]]; then
            tMsg 1 "PASS: $@"
            return 0
        else
            tMsg 0  "FAIL: $@"
            tMsg 0  "    (expected RC $expect but got $rc)"
            ((FAILCT+=1))
            return $ZERR_TEST_FAIL
        fi
    fi
}

testOutput() {
    if [[ $# < 2 ]]; then
        tMsg 0 "testOutput: Need 2 arguments (result, command), not $#."
        return 99
    fi
    local expect="$1"
    shift
    local gotten=`"$@"`
    local rc=$?
    if [[ "$gotten" == "$expect" ]]; then
        tMsg 1 "PASS: $@"
        return 0
    fi
    echo "FAIL: $@" >&2
    echo "  Lengths: expect $#expect, gotten $#gotten."
    typeset -p expect >&2
    typeset -p gotten >&2
    #print_chars $expect
    #print_chars $gotten
    ((FAILCT+=1))
    return $ZERR_TEST_FAIL
}

testEQ() {
    if [[ $# < 2 ]]; then
        tMsg 0 "testEq: Need 2 arguments (result, command), not $#."
        return 99
    fi
    local expect="$1"
    shift
    local gotten=$("$@")
    local rc=$?
    if [[ "$gotten" == "$expect" ]]; then
        tMsg 1 "PASS: $@"
        return 0
    fi
    tMsg 0 "FAIL: $@\n    expected '$expect'\n     but got '$gotten' (and RC $rc)"
    ((FAILCT+=1))
    return $ZERR_TEST_FAIL
}
