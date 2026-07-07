#!/bin/sh
# Preprocessing module: alpha mask for transparent-background templates (level 4)
# Generates PGM masks from templates: foreground pixels (non-black) = white, background (black) = black
# The mask is passed to matching as a 3rd column in the variants file

MASK_DIR="${PREP_TMPDIR}/masks"

prepare_templates_edge() {
    local src_dir="$1"
    mkdir -p "${MASK_DIR}"
    for template in "${src_dir}"/*.ppm; do
        local base
        base=$(basename "${template}" .ppm)
        convert "${template}" -colorspace Gray -threshold 3% "${MASK_DIR}/${base}.pgm"
    done
}

get_template_variants_edge() {
    local template="$1"
    local base
    base=$(basename "${template}" .ppm)
    echo "${template} 0 ${MASK_DIR}/${base}.pgm"
}

preprocess_image_edge() {
    local image="$1"
    local output="$2"
    convert "${image}" "${output}"
}

cleanup_edge() {
    [ -d "${MASK_DIR}" ] && rm -rf "${MASK_DIR}"
}
