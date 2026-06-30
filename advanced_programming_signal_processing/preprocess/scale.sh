#!/bin/sh
# Preprocessing module: scale (0.5x, 2x)
# Interface: prepare_templates / get_template_variants / cleanup

SCALES="50 200"
SCALE_DIR="${PREP_TMPDIR}/scale"

prepare_templates_scale() {
    local src_dir="$1"
    for scale in ${SCALES}; do
        mkdir -p "${SCALE_DIR}/${scale}"
        for t in "${src_dir}"/*.ppm; do
            "${IM_CMD:-convert}" -resize "${scale}%" "$t" "${SCALE_DIR}/${scale}/$(basename "$t")"
        done
    done
}

get_template_variants_scale() {
    local template="$1"
    local tbase
    tbase=$(basename "${template}")
    echo "${template} 0"
    for scale in ${SCALES}; do
        echo "${SCALE_DIR}/${scale}/${tbase} 0"
    done
}

cleanup_scale() {
    [ -d "${SCALE_DIR}" ] && rm -rf "${SCALE_DIR}"
}
