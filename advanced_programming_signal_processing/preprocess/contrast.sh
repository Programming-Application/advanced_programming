#!/bin/sh
# Preprocessing module: contrast variations for level 3

CONTRAST_FACTORS="0.5 1.0 1.5 2.0"

prepare_templates_contrast() {
    local src_dir="$1"
    local template
    local base
    local factor
    local contrast_dir
    local out_dir
    local out_file

    contrast_dir="${PREP_TMPDIR}/contrast"

    for template in "${src_dir}"/*.ppm; do
        base=$(basename "${template}")

        for factor in ${CONTRAST_FACTORS}; do
            out_dir="${contrast_dir}/factor_$(echo "${factor}" | tr '.' '_')"
            mkdir -p "${out_dir}"
            out_file="${out_dir}/${base}"
            convert "${template}" -fx "0.5+${factor}*(u-0.5)" "${out_file}"
        done
    done
}

get_template_variants_contrast() {
    local template="$1"
    local base
    local factor
    local contrast_dir

    contrast_dir="${PREP_TMPDIR}/contrast"

    base=$(basename "${template}")
    echo "${template} 0"
    for factor in ${CONTRAST_FACTORS}; do
        echo "${contrast_dir}/factor_$(echo "${factor}" | tr '.' '_')/${base} 0"
    done
}

cleanup_contrast() {
    local contrast_dir

    contrast_dir="${PREP_TMPDIR}/contrast"
    [ -d "${contrast_dir}" ] && rm -rf "${contrast_dir}"
}