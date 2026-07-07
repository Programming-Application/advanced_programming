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

THRESHOLD=40.0
IMAGE_PIPELINE=""
MATCH_OPTS="pg"
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
            MATCH_OPTS="${MATCH_OPTS}r"
            ;;
        -s)
            if [ -f ./preprocess/scale.sh ]; then
                . ./preprocess/scale.sh
                MODULES="${MODULES} scale"
                MATCH_OPTS="${MATCH_OPTS}s"
            else
                echo "Warning: preprocess/scale.sh not found, skipping -s" >&2
            fi
            ;;
        -c)
            . ./preprocess/contrast.sh
            MODULES="${MODULES} contrast"
            NEED_CONTRAST=1
            ;;
        -d)
            . ./preprocess/denoise.sh
            MODULES="${MODULES} denoise"
            NEED_DENOISE=1
            ;;
        -m)
            shift
            DENOISE_RADIUS="$1"
            . ./preprocess/denoise.sh
            MODULES="${MODULES} denoise"
            NEED_DENOISE=1
            ;;
        -e)
            . ./preprocess/edge.sh
            MODULES="${MODULES} edge"
            ;;
        -t)
            shift
            THRESHOLD="$1"
            THRESHOLD_SET=1
            ;;
    esac
    shift
done

# Build IMAGE_PIPELINE (contrast only; denoise is a separate pass)
[ "${NEED_CONTRAST:-0}" -eq 1 ] && IMAGE_PIPELINE="${IMAGE_PIPELINE} contrast"

# Clean previous results for this level
for image in "${LEVEL_DIR}"/test/*.ppm; do
    rm -f "result/$(basename "${image}" .ppm).txt"
done

NEED_BEST=0
if [ "${MODULES}" != "base" ]; then
    NEED_BEST=1
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
    if [ -z "${IMAGE_PIPELINE}" ]; then
        preprocess_image_base "${image}" "${name}"
    else
        prev="${image}"
        step=0
        for stage in ${IMAGE_PIPELINE}; do
            step=$((step + 1))
            next="${PREP_TMPDIR}/_pipe_${step}.ppm"
            "preprocess_image_${stage}" "${prev}" "${next}"
            prev="${next}"
        done
        cp "${prev}" "${name}"
    fi

    # Archive the test image (fake data) and its ground truth (correct answer)
    convert "${image}" "${OUTPUT_IMAGE_DIR}/${bname%.ppm}.png"
    answer_file="${LEVEL_DIR}/test/${bname%.ppm}.txt"
    [ -f "${answer_file}" ] && cp "${answer_file}" "${OUTPUT_IMAGE_DIR}/"

    # Clear result file before matching
    : > "${result_file}"

    for template in "${LEVEL_DIR}"/*.ppm; do
        get_all_variants "${template}" > "${VARIANTS_FILE}"
        while IFS=' ' read -r variant_path rotation mask_path; do
            if [ -n "${mask_path}" ]; then
                ./matching "${name}" "${variant_path}" "${rotation}" "${THRESHOLD}" "${MATCH_OPTS}" "${mask_path}"
            else
                ./matching "${name}" "${variant_path}" "${rotation}" "${THRESHOLD}" "${MATCH_OPTS}"
            fi
        done < "${VARIANTS_FILE}"
    done

    # Separate denoise pass: denoised raw image vs original templates
    # Overwrites ${name} since main pass is done; getBaseName gives correct result file
    if [ "${NEED_DENOISE:-0}" -eq 1 ]; then
        preprocess_image_denoise "${image}" "${name}"
        for template in "${LEVEL_DIR}"/*.ppm; do
            ./matching "${name}" "${template}" 0 "${THRESHOLD}" "${MATCH_OPTS}"
        done
    fi

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
