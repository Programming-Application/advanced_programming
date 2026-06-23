#!/bin/sh
# Base preprocessing module (no transformation)
# All modules follow this interface:
#   prepare_templates_<name>  <level_dir>          — one-time setup
#   get_template_variants_<name>  <template_path>  — output "path rotation" per variant
#   cleanup_<name>                                 — teardown

prepare_templates_base() {
    :
}

get_template_variants_base() {
    local template="$1"
    echo "${template} 0"
}

cleanup_base() {
    :
}
