#!/bin/zsh
#
# Define a bunch of commonly-used arguments so that zerg parsers
# can re-use them easily (see `zerg_use`).

zerg_new ZERG

zerg_add ZERG "--quiet -q --silent" --action store_true --help "Be less chatty."

zerg_add ZERG "--verbose -v" --action count --help "Be more chatty."

zerg_add ZERG "-ignore-case -i" --action store_true --dest no_case --help "Ignore upper/lower case distinction."

zerg_add ZERG "--recursive" --action store_true --help "Traverse subdirectories."

zerg_add ZERG "--dry-run" --action store_true --help "Show but don't really do changes."

zerg_add ZERG "--dry-run" --action store_true --help "Show but don't really do changes."

zerg_add ZERG "--color" --choices "always auto never" --help "Colorize output in these cases."

zerg_add ZERG "--force" --action store_true --help "Overwrite if needed."

zerg_add ZERG "--encoding" -type str --help "Assume this character set for input."
