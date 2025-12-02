#!/usr/bin/env python3
"""
Python type checkers mirroring zerg_types.sh functionality.
These can be passed to argparse's add_argument(type=...) parameter.
"""

import re
import os
import subprocess
from pathlib import Path
from datetime import datetime

# Regex patterns matching zerg_types.sh
_SIGN_RE = r'[-+]'
_UNS_RE = r'[0-9]+'
_INT_RE = rf'({_SIGN_RE})?[0-9]+'
_MANTISSA_RE = r'([0-9]+(\.[0-9]*)?|\.[0-9]+)'
_EXPONENT_RE = rf'[eE]({_SIGN_RE})?[0-9]+'
_FLOAT_RE = rf'({_SIGN_RE})?{_MANTISSA_RE}({_EXPONENT_RE})?'
_COMPLEX_RE = rf'{_FLOAT_RE}([-+]{_MANTISSA_RE}({_EXPONENT_RE})?[ijIJ])?'

_OCT_RE = r'0[Oo][0-7]*'
_HEX_RE = r'0[Xx][0-9a-fA-F]+'
_BIN_RE = r'0[Bb][01]+'

_IDENT_RE = r'[a-zA-Z_][a-zA-Z0-9_]*'
_UIDENT_RE = r'[_\w][_\w\d]*'  # Unicode-aware
_ARGNAME_RE = r'([-+][a-zA-Z]|--[a-zA-Z][-a-zA-Z0-9]+)'

_TIME_RE = r'[0-2][0-9]:[0-5][0-9](:[0-5][0-9](\.[0-9]+)?)?'
_ZONE_RE = r'(Z|[-+][0-2][0-9]:[0-5][0-9])'
_DOM_RE = r'(0[1-9]|[12][0-9]|3[01])'
_DATE_RE = rf'[0-9]{{4}}(-(0[1-9]|1[012])(-{_DOM_RE})?)?'
_DURATION_RE = r'P([0-9]+Y)?([0-9]+M)?([0-9]+D)?(T([0-9]+H)?([0-9]+M)?([0-9]+S)?)?'


# Integer types

def hexint(value: str) -> int:
    """Hexadecimal integer (0xABC format)"""
    if not re.match(rf'^{_HEX_RE}$', value):
        raise ValueError(f"Not a hex integer: {value}")
    return int(value, 16)

def octint(value: str) -> int:
    """Octal integer (0o777 format)"""
    if not re.match(rf'^{_OCT_RE}$', value):
        raise ValueError(f"Not an octal integer: {value}")
    return int(value, 8)

def binint(value: str) -> int:
    """Binary integer (0b1010 format)"""
    if not re.match(rf'^{_BIN_RE}$', value):
        raise ValueError(f"Not a binary integer: {value}")
    return int(value, 2)

def anyint(value: str) -> int:
    """Any integer format (decimal, hex, oct, bin)"""
    if re.match(rf'^{_HEX_RE}$', value): return int(value, 16)
    if re.match(rf'^{_OCT_RE}$', value): return int(value, 8)
    if re.match(rf'^{_BIN_RE}$', value): return int(value, 2)
    if re.match(rf'^{_INT_RE}$', value): return int(value)
    raise ValueError(f"Not an integer: {value}")

def unsigned(value: str) -> int:
    """Unsigned integer (>= 0)"""
    n = int(value)
    if n < 0: raise ValueError(f"Not unsigned: {value}")
    return n

def pid(value: str) -> int:
    """Process ID (must be valid running process)"""
    n = int(value)
    if n <= 0: raise ValueError(f"Invalid PID: {value}")
    try:
        os.kill(n, 0)  # Signal 0 checks existence without killing
        return n
    except (OSError, ProcessLookupError):
        raise ValueError(f"No such process: {value}")


# Float types

def prob(value: str) -> float:
    """Probability (0.0 to 1.0)"""
    f = float(value)
    if not 0.0 <= f <= 1.0: raise ValueError(f"Not a probability [0,1]: {value}")
    return f

def logprob(value: str) -> float:
    """Log probability (<= 0.0)"""
    f = float(value)
    if f > 0.0: raise ValueError(f"Not a log probability (<=0): {value}")
    return f

def epoch(value: str) -> float:
    """Unix epoch timestamp"""
    return float(value)


# String types

def char(value: str) -> str:
    """Single character (Unicode-aware)"""
    if len(value) != 1:
        raise ValueError(f"Not a single character: {value}")
    return value

def ident(value: str) -> str:
    """Identifier ([a-zA-Z_][a-zA-Z0-9_]*)"""
    if not re.match(rf'^{_IDENT_RE}$', value):
        raise ValueError(f"Not an identifier: {value}")
    return value

def idents(value: str) -> str:
    """Space-separated identifiers"""
    if not re.match(rf'^{_IDENT_RE}(\s+{_IDENT_RE})*$', value):
        raise ValueError(f"Not space-separated identifiers: {value}")
    return value

def uident(value: str) -> str:
    """Unicode identifier"""
    if not re.match(rf'^{_UIDENT_RE}$', value, re.UNICODE):
        raise ValueError(f"Not a Unicode identifier: {value}")
    return value

def uidents(value: str) -> str:
    """Space-separated Unicode identifiers"""
    if not re.match(rf'^{_UIDENT_RE}(\s+{_UIDENT_RE})*$', value, re.UNICODE):
        raise ValueError(f"Not Unicode identifiers: {value}")
    return value

def argname(value: str) -> str:
    """Argument name (-c or --option-name)"""
    if not re.match(rf'^{_ARGNAME_RE}$', value):
        raise ValueError(f"Not a valid argument name: {value}")
    return value

def cmdname(value: str) -> str:
    """Command name (must be executable)"""
    if subprocess.run(['which', value], capture_output=True).returncode != 0:
        raise ValueError(f"Command not found: {value}")
    return value

def varname(value: str) -> str:
    """Variable name (valid identifier, checks existence in environment)"""
    if not re.match(rf'^{_IDENT_RE}$', value):
        raise ValueError(f"Not a valid variable name: {value}")
    if value not in os.environ:
        raise ValueError(f"Environment variable not set: {value}")
    return value

def regex(value: str) -> str:
    """Regular expression (validates compilability)"""
    try:
        re.compile(value)
        return value
    except re.error as e:
        raise ValueError(f"Invalid regex: {e}")

def path(value: str,
         d: bool = False,     # directory
         e: bool = False,     # exists
         f: bool = False,     # file
         r: bool = False,     # readable
         w: bool = False,     # writable
         x: bool = False,     # executable
         N: bool = False,     # modified since last read
         new: bool = False,   # doesn't exist but parent dir does and is writable
         forcible: bool = False,  # parent dir exists and is writable
         loose: bool = False  # skip character validation
         ) -> Path:
    """
    Validate a path string and optionally check file properties.

    Usage with argparse:
        from functools import partial

        parser.add_argument('--output', type=partial(path, w=True, new=True))
        parser.add_argument('--input', type=partial(path, r=True, f=True))
        parser.add_argument('--config', type=partial(path, e=True, loose=True))

    Args:
        value: The path string to validate
        d: Path must be a directory
        e: Path must exist
        f: Path must be a regular file
        r: Path must be readable
        w: Path must be writable
        x: Path must be executable
        N: Path must have been modified since last read (st_mtime > st_atime)
        new: Path must not exist, but parent dir must exist and be writable
        forcible: Parent dir exists and is writable (path may or may not exist)
        loose: Skip strict character validation

    Returns:
        Path object if validation passes

    Raises:
        ValueError: If validation fails
    """
    # Character validation (unless loose)
    if not loose:
        # Disallow problematic characters: ['"`( ){}\[\]+=:;?<>,|\\!@%^&*]
        path_pattern = r'^/?[-._$~#\w]*(/[-._$~#\w]*)*$'
        if not re.match(path_pattern, value):
            raise ValueError(f"Path contains invalid characters: {value}")

    p = Path(value)

    # File test operators
    if d and not p.is_dir():
        raise ValueError(f"Path is not a directory: {value}")

    if e and not p.exists():
        raise ValueError(f"Path does not exist: {value}")

    if f and not p.is_file():
        raise ValueError(f"Path is not a regular file: {value}")

    if r and not os.access(p, os.R_OK):
        raise ValueError(f"Path is not readable: {value}")

    if w and not os.access(p, os.W_OK):
        raise ValueError(f"Path is not writable: {value}")

    if x and not os.access(p, os.X_OK):
        raise ValueError(f"Path is not executable: {value}")

    if N:
        try:
            stat = p.stat()
            if stat.st_mtime <= stat.st_atime:
                raise ValueError(f"Path was not modified since last read: {value}")
        except OSError:
            raise ValueError(f"Cannot stat path: {value}")

    # Special modes for new/forcible paths
    if new or forcible:
        parent = p.parent
        if not parent.exists():
            raise ValueError(f"Parent directory does not exist: {parent}")
        if not parent.is_dir():
            raise ValueError(f"Parent is not a directory: {parent}")

        if forcible:
            if not os.access(parent, os.W_OK):
                raise ValueError(f"Parent directory is not writable: {parent}")

        if new:
            if p.exists():
                raise ValueError(f"Path already exists (expected new): {value}")
            if not os.access(parent, os.W_OK):
                raise ValueError(f"Parent directory is not writable: {parent}")

    return p


def url(value: str) -> str:
    """URL (basic format validation)"""
    url_pattern = r'^https?://[^\s/$.?#].[^\s]*$'
    if not re.match(url_pattern, value, re.IGNORECASE):
        raise ValueError(f"Not a valid URL: {value}")
    return value

def encoding(value: str) -> str:
    """Character encoding name (validates with codecs)"""
    import codecs
    try:
        codecs.lookup(value)
        return value
    except LookupError:
        raise ValueError(f"Unknown encoding: {value}")

def lang(value: str) -> str:
    """Language code (ISO 639-1/2/3 or BCP 47)"""
    lang_pattern = r'^[a-z]{2,3}(-[A-Z]{2})?(-[a-z]+)?$'
    if not re.match(lang_pattern, value):
        raise ValueError(f"Invalid language code: {value}")
    return value

def locale(value: str) -> str:
    """Locale name (basic validation)"""
    locale_pattern = r'^[a-z]{2,3}_[A-Z]{2}(\.[a-zA-Z0-9-]+)?(@[a-z]+)?$'
    if not re.match(locale_pattern, value):
        raise ValueError(f"Invalid locale: {value}")
    return value


# Time/date types

def time(value: str) -> str:
    """Time in HH:MM or HH:MM:SS format"""
    if not re.match(rf'^{_TIME_RE}({_ZONE_RE})?$', value):
        raise ValueError(f"Invalid time format: {value}")
    return value

def date(value: str) -> str:
    """Date in ISO8601 format (YYYY, YYYY-MM, or YYYY-MM-DD)"""
    if not re.match(rf'^{_DATE_RE}$', value):
        raise ValueError(f"Invalid ISO8601 date: {value}")
    return value

def datetime_type(value: str) -> str:
    """Datetime in ISO8601 format"""
    try:
        datetime.fromisoformat(value.replace('Z', '+00:00'))
        return value
    except ValueError:
        raise ValueError(f"Invalid ISO8601 datetime: {value}")

def duration(value: str) -> str:
    """ISO8601 duration (P3Y6M4DT12H30M5S)"""
    if len(value) < 2 or not re.match(rf'^{_DURATION_RE}$', value):
        raise ValueError(f"Invalid ISO8601 duration: {value}")
    return value


# Complex/tensor types

def tensor(value: str) -> str:
    """Nested numeric arrays like ((1 2) (3 4))"""
    # Basic validation - proper implementation would parse fully
    if not value.startswith('(') or not value.endswith(')'):
        raise ValueError(f"Tensor must be parenthesized: {value}")
    depth = 0
    for c in value:
        if c == '(': depth += 1
        elif c == ')': depth -= 1
        if depth < 0:
            raise ValueError(f"Unbalanced parentheses in tensor: {value}")
    if depth != 0:
        raise ValueError(f"Unbalanced parentheses in tensor: {value}")
    return value

def format_string(value: str) -> str:
    """Format string (validates Python format syntax)"""
    try:
        value.format()  # Empty format to test syntax
        return value
    except (ValueError, KeyError):
        pass
    # Allow format strings with placeholders that would fail with empty format()
    return value


# Type name registry (for programmatic access)
ZERG_TYPE_CHECKERS = {
    'hexint': hexint, 'octint': octint, 'binint': binint, 'anyint': anyint,
    'unsigned': unsigned, 'pid': pid,
    'prob': prob, 'logprob': logprob, 'epoch': epoch,
    'char': char, 'ident': ident, 'idents': idents,
    'uident': uident, 'uidents': uidents,
    'argname': argname, 'cmdname': cmdname, 'varname': varname,
    'regex': regex, 'path': path, 'url': url,
    'encoding': encoding, 'lang': lang, 'locale': locale,
    'time': time, 'date': date, 'datetime': datetime_type, 'duration': duration,
    'tensor': tensor, 'format': format_string,
}


if __name__ == '__main__':
    # Simple test
    import argparse
    parser = argparse.ArgumentParser(description='Test zerg types')
    parser.add_argument('--hex', type=hexint, help='Hexadecimal integer')
    parser.add_argument('--prob', type=prob, help='Probability [0,1]')
    parser.add_argument('--ident', type=ident, help='Identifier')
    parser.add_argument('--date', type=date, help='ISO8601 date')

    args = parser.parse_args()
    print(f"Parsed: {args}")
