#!/bin/sh
# Preprocessing module: rotation (0, 90, 180, 270)
# Rotation is handled internally by main.c via the 'r' option flag.
# This module only signals run.sh to add 'r' to MATCH_OPTS.

prepare_templates_rotate() {
    :
}

get_template_variants_rotate() {
    local template="$1"
    echo "${template} 0"
}

cleanup_rotate() {
    :
}
