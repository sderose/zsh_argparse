#!/usr/bin/env zsh
# zerg.plugin.zsh - Entry point for zerg framework
# Works both as oh-my-zsh plugin and standalone installation

# Determine zerg root directory
if [[ -n "${ZERG_ROOT}" ]]; then
    # Use explicitly set ZERG_ROOT if available
    typeset -g ZERG_HOME="${ZERG_ROOT}"
elif [[ -n "${0:A:h}" ]]; then
    # Standard case: use the directory containing this script
    typeset -g ZERG_HOME="${0:A:h}"
else
    # Fallback: try to find via function path
    typeset -g ZERG_HOME="${${(%):-%x}:A:h}"
fi

# Verify we found a valid directory
if [[ ! -d "${ZERG_HOME}" ]]; then
    print -u2 "zerg: Unable to determine installation directory"
    return 1
fi

# Source core library files in dependency order
typeset -a zerg_core_files=(
    "${ZERG_HOME}/lib/core/zerg_setup.zsh"
    "${ZERG_HOME}/lib/core/zerg_types.zsh"
    "${ZERG_HOME}/lib/core/zerg_objects.zsh"
    "${ZERG_HOME}/lib/utils/aa_accessors.zsh"
    "${ZERG_HOME}/lib/argparse/zerg_new.zsh"
    "${ZERG_HOME}/lib/argparse/zerg_add.zsh"
    "${ZERG_HOME}/lib/argparse/zerg_parse.zsh"
)

for zerg_file in "${zerg_core_files[@]}"; do
    if [[ -f "${zerg_file}" ]]; then
        source "${zerg_file}"
    else
        print -u2 "zerg: Required file not found: ${zerg_file}"
        return 2
    fi
done

# Add zerg bin directory to PATH if it exists and isn't already there
if [[ -d "${ZERG_HOME}/bin" ]]; then
    if [[ "${PATH}" != *"${ZERG_HOME}/bin"* ]]; then
        path=("${ZERG_HOME}/bin" $path)
    fi
fi

# Export for subshells and scripts that need it
export ZERG_HOME

# Mark plugin as loaded
typeset -g ZERG_LOADED=1

# Optional: source examples if requested
if [[ "${ZERG_LOAD_EXAMPLES}" == "1" && -d "${ZERG_HOME}/examples" ]]; then
    for example in "${ZERG_HOME}/examples"/*.zsh; do
        [[ -f "${example}" ]] && source "${example}"
    done
fi
