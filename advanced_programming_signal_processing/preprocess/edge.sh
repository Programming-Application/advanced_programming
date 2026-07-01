#!/bin/sh
# Preprocessing module: edge extraction for transparent-background templates

EDGE_RADIUS="1"
IMAGE_PREPROCESS="edge"

prepare_templates_edge() {
    local src_dir="$1"
    local template
    local base
    local edge_dir

    edge_dir="${PREP_TMPDIR}/edge"
    mkdir -p "${edge_dir}"
    for template in "${src_dir}"/*.ppm; do
        base=$(basename "${template}")
        convert "${template}" -colorspace Gray -auto-level -canny 0x1+10%+30% -normalize "${edge_dir}/${base}" 2>/dev/null || \
            convert "${template}" -colorspace Gray -auto-level -edge "${EDGE_RADIUS}" -normalize "${edge_dir}/${base}"
    done
}

get_template_variants_edge() {
    local template="$1"
    local base
    local edge_dir

    edge_dir="${PREP_TMPDIR}/edge"
    base=$(basename "${template}")
    echo "${edge_dir}/${base} 0"
}

preprocess_image_edge() {
    local image="$1"
    local output="$2"

    mkdir -p "$(dirname "${output}")"
    convert "${image}" -colorspace Gray -auto-level -canny 0x1+10%+30% -normalize "${output}" 2>/dev/null || \
        convert "${image}" -colorspace Gray -auto-level -edge "${EDGE_RADIUS}" -normalize "${output}"
}

cleanup_edge() {
    local edge_dir

    edge_dir="${PREP_TMPDIR}/edge"
    [ -d "${edge_dir}" ] && rm -rf "${edge_dir}"
}
