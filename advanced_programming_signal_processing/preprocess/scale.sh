#!/bin/sh
# Preprocessing module: scale (0.5x, 1x, 2x)
# Scaling is handled internally by main.c via the 's' option flag.
# This module only signals run.sh to add 's' to MATCH_OPTS.

prepare_templates_scale() {
    :
}

get_template_variants_scale() {
    local template="$1"
    echo "${template} 0"
}

cleanup_scale() {
    :
}
