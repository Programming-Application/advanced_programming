#!/bin/sh
# Preprocessing module: rotation (0, 90, 180, 270)
# Interface: prepare_templates / get_rotations / cleanup

ROTATIONS="0 90 180 270"
ROT_DIR="${PREP_TMPDIR}/rot"

prepare_templates_rotate() {
    local src_dir="$1"
    for rot in 90 180 270; do
        mkdir -p "${ROT_DIR}/${rot}"
        for t in "${src_dir}"/*.ppm; do
            "${IM_CMD:-convert}" -rotate "${rot}" "$t" "${ROT_DIR}/${rot}/$(basename "$t")"
        done
    done
}

get_template_variants_rotate() {
    local template="$1"
    local tbase
    tbase=$(basename "${template}")
    echo "${template} 0"
    for rot in 90 180 270; do
        echo "${ROT_DIR}/${rot}/${tbase} ${rot}"
    done
}

cleanup_rotate() {
    [ -d "${ROT_DIR}" ] && rm -rf "${ROT_DIR}"
}
