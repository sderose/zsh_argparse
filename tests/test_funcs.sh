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
        return 99
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
            return 1
        fi
    elif [[ $expect == 'FAIL' ]]; then
        if [[ $rc == 0 ]]; then
            tMsg 0 "FAIL (unexpected pass): $@"
            ((FAILCT+=1))
            return 2
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
            return 3
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
    local x=`"$@"`
    local rc=$?
    if [[ "$x" == "$expect" ]]; then
        tMsg 1 "PASS: $@"
        return 0
    fi
    echo "Failed: $@\n    expected '$expect' (len ${#expect})\n     but got '$x'  (len ${#x}, RC $rc)" >&2
    #print_chars $expect
    #print_chars $x
    ((FAILCT+=1))
    return 1
}

testEQ() {
    if [[ $# < 2 ]]; then
        tMsg 0 "testEq: Need 2 arguments (result, command), not $#."
        return 99
    fi
    local expect="$1"
    shift
    local x=$("$@")
    local rc=$?
    if [[ "$x" == "$expect" ]]; then
        tMsg 1 "PASS: $@"
        return 0
    fi
    tMsg 0 "FAIL: $@\n    expected '$expect'\n     but got '$x' (and RC $rc)"
    ((FAILCT+=1))
    return 1
}


