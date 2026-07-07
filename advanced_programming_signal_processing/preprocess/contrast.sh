#!/bin/sh
# Preprocessing module: contrast normalization for level 3
# Normalizes both templates and input images to eliminate contrast differences

CONTRAST_DIR="${PREP_TMPDIR}/contrast"

prepare_templates_contrast() {
    local src_dir="$1"
    mkdir -p "${CONTRAST_DIR}"
    for template in "${src_dir}"/*.ppm; do
        convert "${template}" -normalize "${CONTRAST_DIR}/$(basename "${template}")"
    done
}

get_template_variants_contrast() {
    local template="$1"
    local base
    base=$(basename "${template}")
    echo "${template} 0"
    echo "${CONTRAST_DIR}/${base} 0"
}

preprocess_image_contrast() {
    local image="$1"
    local output="$2"
    mkdir -p "$(dirname "${output}")"
    convert "${image}" -normalize "${output}"
}

cleanup_contrast() {
    [ -d "${CONTRAST_DIR}" ] && rm -rf "${CONTRAST_DIR}"
}
