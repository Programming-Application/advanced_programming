#!/bin/sh
# Template matching pipeline
# Usage: sh run.sh <level_dir> [-r] [-s] ...
#   -r  enable rotation (preprocess/rotate.sh)
#   -s  enable scaling  (preprocess/scale.sh)
# No flags: base matching only (rotation=0)

LEVEL_DIR="$1"
shift

THRESHOLD=0.5
IMAGE_PREPROCESS="base"

PREP_TMPDIR="imgproc/variants"
mkdir -p "${PREP_TMPDIR}"

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
        -t)
            shift
            THRESHOLD="$1"
            ;;
    esac
    shift
done

# Clean previous results for this level
for image in "${LEVEL_DIR}"/test/*.ppm; do
    rm -f "result/$(basename "${image}" .ppm).txt"
done

THRESHOLD=0.5
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
    "preprocess_image_${IMAGE_PREPROCESS}" "${image}" "${name}"

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
