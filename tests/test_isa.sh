#!/bin/zsh
#
if [ -z "$zerg_types" ]; then
    source zerg_setup.sh || warn "Could not source zerg_setup.sh."
fi

local -a int=( 0 1 99 -65537 )
local -a hexint=( 0x0 0X9999 0XdeadBEEF )
local -a octint=( 0o0 0O7777 0o1357001 )
local -a binint=( 0b0000 0B01011110 0b111111110000000010101010 )
local -a anyint=( 99 0o777 0b11000101 0xCA99 )

local -a unsigned=( 782772897027 )
local -a pid=( )

local -a bool=( 1 "" )

local -a float=( -3.14159E+10 .321 0 0. +3E8 -.3E-89 )
local -a prob=( 0.00001 0 1 0.99999 )
local -a logprob=( -999 0.0 -1.618  -99E-2 )

local -a complex=( "-1.2+12.45j" "55+3E-21i" "3.14" -99 "0-14J" )
local -a tensor=( "( (1 2)(3 4) (5 6))" "1 2 3 4 5 6" )

local -a str=( "thu34p038th^*^_+%" )
local -a char=( "a" "é" '1' 9 )

local -a ident=( foo _x_37 BAD0)
local -a idents=( "foo _x_37 BAD0" )
local -a uident=( "resumé" "naîve" )
local -a uidents=( "resumé naîve" )

local -a argname=( "--ignore-case" "-q" )
local -a cmdname=( ls ll grep )
local -a reserved=( if "[[" done )
local -a varname=( LANG EDITOR )
if ! [ -v PARSER ]; then
    warn 0 "No PARSER assoc around, so can't test is_objname."
else
    local -a objname=( PARSER )
fi
local -a zergtypename=( int datetime packed complex anyint )

local -a builtin=( alias cd )
local -a function=( is_of_zerg_type )
local -a alias=( ll )
local -a packed=( "( 1 2 3)" "( [black]=0 [blue]=4 [cyan]=6 [default]=9 [green]=2 [magenta]=5 [red]=1 [white]=7 [yellow]=3 )" "( )" )

local -a regex=( "a[b-z]*$" )
#local -a path=( "/tmp/stuff/bz.log" )
local -a url=( "https://example.com/foo+bar.zap#id1" )
local -a lang=( "en-uk" "el" "esp" )
local -a encoding=( "UTF-8" "EBCDIC-UK" "ASCII" )
local -a locale=( "C.UTF-8" "en_US.ISO8859-1" "es_ES.UTF-8" )
local -a format=( "%-12s" "%5.2f" )

local -a time=( "12:59:30" "1:1:33.456Z" "18:20" )
local -a date=( "2025-11-21" "1900-01-01" "2001-05" "1970" )
local -a datetime=( "2025-11-21T01:01:33.456-05:30" )

local -a duration=( P13Y42DT17H2M7S PT22H )
local -a epoch=( 134217727 -12 )


#############################

local -a non_int=( aardvark 9.9 \$12 aardvark )
local -a non_hexint=( BEEF 12 0xBEEG -0xff aardvark )
local -a non_octint=( 0777 12 0o789 -0O12 0x7 aardvark )
local -a non_binint=( 11110000  0c1111 aardvark )
local -a non_anyint=( cat 0XFFZ00 )

local -a non_unsigned=( -12 0x0D)
local -a non_pid=( )

local -a non_bool=( nope )

local -a non_float=( 1.0+9.8j )
local -a non_prob=( 1.1 -0.5 )
local -a non_logprob=( 1 +0.5 )

local -a non_complex=( something+1.0i )
local -a non_tensor=( "( 1 2 3.14E-2 ))" )

#local -a non_str=( )
local -a non_char=( word )

local -a non_ident=( 99 "_*" büllét ••• )
local -a non_idents=( )
local -a non_uident=( )
local -a non_uidents=( )

local -a non_argname=( foo_bar ---zsh -- -ghi )
local -a non_cmdname=( nocmd -- )
local -a non_reserved=( grep "&" PATH )
local -a non_varname=( NOVAR 78x )
#local -a non_objname=( )
local -a non_zergtypename=( integer"[]"• dict )

local -a non_builtin=( sed "[]"• ll )
local -a non_function=(  ^^^9 @#! • )
local -a non_alias=( gcc ^^^9 @#! • )
local -a non_packed=( "[ foo ]" )

local -a non_regex=( )
#local -a non_path=( )
local -a non_url=( )
local -a non_lang=( z89+2 .py "" )
local -a non_encoding=( BCD utf-93 ^^^9 @#! • )
local -a non_locale=( "klingon" "   " "•" )
#local -a non_format=( )

local -a non_time=( "34:26:01" "23:01:01W" "-01:02" ^^^9 @#! • )
local -a non_date=( "197-12-12" "2000-14" "2000-00" "2000-08-32" ^^^9 @#! • )
local -a non_datetime=( "2000-11-01W16:04:01" ^^^9 @#! • )

local -a non_duration=( "P3Q22D" ^^^9 @#! • )
local -a non_epoch=( ^^^9 @#! • )


#############################

local -i numtypes=0 numtests=0
for type_name in ${(ko)zerg_types}; do
    warn 0 "Trying type '$type_name'."
    [[ $type_name == path ]] && continue  # Special case
    numtypes+=1
    if ! [ -v $type_name ]; then
        warn 1 "No positive test cases for type '$type_name'."
        continue
    fi
    local value=""
    for value in ${(P)type_name}; do
        warn 1 "    Positive $type_name test value '$value'."
        numtests+=1
        if [[  $type_name == argname ]]; then  # (b/c hyphens)
            is_argname -- "$value" && continue
        else
            [[ $type_name == packed ]] && warn 0 "pack arg: $value"
            is_$type_name -q "$value" && continue
        fi
        warn 0 "is_$type_name failed for '$value' (rc $?)."
    done

    local nname="non_$type_name"
    if ! [ -v $nname ]; then
        warn 1 "No negative test cases for type '$type_name'."
        continue
    fi
    for value in ${(P)nname}; do
        warn 1 "    Negative $type_name  test value '$value'."
        numtests+=1
        if [[  $type_name == argname ]]; then
            is_argname -- "$value" || continue
        else
            is_$type_name -q "$value" || continue
        fi
        warn 0 "Error: type '$type_name', value '$value' passed."
    done
 done

# path

tHead "Positive tests: $numtypes types, $numtests tests."
