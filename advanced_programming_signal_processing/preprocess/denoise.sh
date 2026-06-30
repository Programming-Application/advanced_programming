#!/bin/sh

DENOISE_RADIUS=${DENOISE_RADIUS:-1}
DENOISE_DIR="${PREP_TMPDIR}/denoise"

prepare_templates_denoise() {
    :
}

get_template_variants_denoise() {
    local template="$1"
    echo "${template} 0"
}

preprocess_image_denoise() {
    local image="$1"
    local output="$2"
    local median_side=$((2 * DENOISE_RADIUS + 1))
    mkdir -p "${DENOISE_DIR}"
    if convert "${image}" -statistic Median "${median_side}x${median_side}" "${output}" 2>/dev/null; then
        :
    else
        convert "${image}" -median "${DENOISE_RADIUS}" "${output}"
    fi
}

cleanup_denoise() {
    [ -d "${DENOISE_DIR}" ] && rm -rf "${DENOISE_DIR}"
}
