#!/bin/sh
# Template matching pipeline
# Usage: sh run.sh <level_dir> [-r] [-s] [-d] [-m radius] [-t threshold] [-e] ...
#   -r  enable rotation (preprocess/rotate.sh)
#   -s  enable scaling  (preprocess/scale.sh)
#   -d  enable denoise   (preprocess/denoise.sh)
#   -e  enable edge      (preprocess/edge.sh)
#   -c  enable contrast variants (preprocess/contrast.sh)
# No flags: base matching only (rotation=0)

LEVEL_DIR="$1"
shift

THRESHOLD=0.5
IMAGE_PREPROCESS="base"
THRESHOLD_SET=0

PREP_TMPDIR="imgproc/variants"
mkdir -p "${PREP_TMPDIR}"

# Archive the test data (fake images) and ground truth (correct answers) used in this run
OUTPUT_IMAGE_DIR="outputImage/$(date +%Y%m%d_%H%M%S)"
mkdir -p "${OUTPUT_IMAGE_DIR}"

# Always load base module
. ./preprocess/base.sh
MODULES="base"

# Load modules based on flags
while [ $# -gt 0 ]; do
    case "$1" in
        -r)
            . ./preprocess/rotate.sh
            MODULES="${MODULES} rotate"
            ;;
        -s)
            if [ -f ./preprocess/scale.sh ]; then
                . ./preprocess/scale.sh
                MODULES="${MODULES} scale"
            else
                echo "Warning: preprocess/scale.sh not found, skipping -s" >&2
            fi
            ;;
        -c)
            . ./preprocess/contrast.sh
            MODULES="${MODULES} contrast"
            ;;
        -d)
            . ./preprocess/denoise.sh
            MODULES="${MODULES} denoise"
            IMAGE_PREPROCESS="denoise"
            ;;
        -m)
            shift
            DENOISE_RADIUS="$1"
            . ./preprocess/denoise.sh
            MODULES="${MODULES} denoise"
            IMAGE_PREPROCESS="denoise"
            ;;
        -e)
            . ./preprocess/edge.sh
            MODULES="edge"
            IMAGE_PREPROCESS="edge"
            ;;
        -t)
            shift
            THRESHOLD="$1"
            THRESHOLD_SET=1
            ;;
    esac
    shift
done

# Clean previous results for this level
for image in "${LEVEL_DIR}"/test/*.ppm; do
    rm -f "result/$(basename "${image}" .ppm).txt"
done

NEED_BEST=0
if [ "${MODULES}" != "base" ]; then
    NEED_BEST=1
fi

if [ "${THRESHOLD_SET}" -eq 0 ] && [ "${MODULES}" = "contrast" ]; then
    THRESHOLD=0.55
fi

if [ "${THRESHOLD_SET}" -eq 0 ] && [ "${MODULES}" = "edge" ]; then
    THRESHOLD=1.2
fi

# Prepare all modules
for mod in ${MODULES}; do
    "prepare_templates_${mod}" "${LEVEL_DIR}"
done

VARIANTS_FILE="${PREP_TMPDIR}/_variants.txt"

# Collect all template variants from active modules
get_all_variants() {
    local template="$1"
    for mod in ${MODULES}; do
        "get_template_variants_${mod}" "${template}"
    done | sort -u
}

keep_best_result() {
    local f="$1"
    [ -f "$f" ] || return
    awk 'BEGIN{b=-1}{d=$7+0;if(b<0||d<b){b=d;l=$0}}END{if(b>=0)print l}' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
}

for image in "${LEVEL_DIR}"/test/*.ppm; do
    bname=$(basename "${image}")
    name="imgproc/${bname}"
    result_file="result/${bname%.ppm}.txt"

    echo "${name}"
    "preprocess_image_${IMAGE_PREPROCESS}" "${image}" "${name}"

    # Archive the test image (fake data) and its ground truth (correct answer)
    convert "${image}" "${OUTPUT_IMAGE_DIR}/${bname%.ppm}.png"
    answer_file="${LEVEL_DIR}/test/${bname%.ppm}.txt"
    [ -f "${answer_file}" ] && cp "${answer_file}" "${OUTPUT_IMAGE_DIR}/"

    # Clear result file before matching
    : > "${result_file}"

    for template in "${LEVEL_DIR}"/*.ppm; do
        get_all_variants "${template}" > "${VARIANTS_FILE}"
        while IFS=' ' read -r variant_path rotation; do
            ./matching "${name}" "${variant_path}" "${rotation}" "${THRESHOLD}" pg
        done < "${VARIANTS_FILE}"
    done

    if [ "${NEED_BEST}" -eq 1 ]; then
        keep_best_result "${result_file}"
    fi

    echo ""
done

# Cleanup all modules
for mod in ${MODULES}; do
    "cleanup_${mod}"
done
rm -f "${VARIANTS_FILE}"
rmdir "${PREP_TMPDIR}" 2>/dev/null

wait
