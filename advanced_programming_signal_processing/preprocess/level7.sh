#!/bin/sh
# Preprocessing module: shuffled level7 dispatcher

LEVEL7_STRATEGIES="base denoise contrast edge scale rotate"

level7_keep_best_result() {
    local f="$1"
    [ -f "$f" ] || return
    awk 'BEGIN{b=-1}{d=$7+0;if(b<0||d<b){b=d;l=$0}}END{if(b>=0)print l}' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
}

level7_get_strategy_modules() {
    case "$1" in
        base)
            echo "base"
            ;;
        denoise)
            echo "base denoise"
            ;;
        contrast)
            echo "base contrast"
            ;;
        edge)
            echo "edge"
            ;;
        scale)
            echo "base scale"
            ;;
        rotate)
            echo "base rotate"
            ;;
    esac
}

level7_get_strategy_preprocess() {
    case "$1" in
        base|scale|rotate)
            echo "base"
            ;;
        denoise)
            echo "denoise"
            ;;
        contrast)
            echo "contrast"
            ;;
        edge)
            echo "edge"
            ;;
    esac
}

level7_get_strategy_threshold() {
    local strategy="$1"
    local threshold="$2"
    local threshold_set="$3"

    if [ "${threshold_set}" -eq 1 ]; then
        echo "${threshold}"
        return
    fi

    case "${strategy}" in
        contrast)
            echo "0.6"
            ;;
        edge)
            echo "1.0"
            ;;
        *)
            echo "0.5"
            ;;
    esac
}

level7_get_variants_for_modules() {
    local template="$1"
    local module_list="$2"
    local mod

    for mod in ${module_list}; do
        "get_template_variants_${mod}" "${template}"
    done | sort -u
}

level7_prepare_modules() {
    local src_dir="$1"
    local mod

    for mod in denoise contrast edge scale rotate; do
        "prepare_templates_${mod}" "${src_dir}"
    done
}

level7_cleanup_modules() {
    local mod

    for mod in denoise contrast edge scale rotate; do
        "cleanup_${mod}"
    done
}

level7_run_strategy() {
    local strategy="$1"
    local image="$2"
    local image_base="$3"
    local level_dir="$4"
    local threshold="$5"
    local threshold_set="$6"
    local aggregate_file="$7"
    local variants_file="$8"
    local preprocess
    local modules
    local strategy_image
    local strategy_result_file
    local template

    preprocess=$(level7_get_strategy_preprocess "${strategy}")
    modules=$(level7_get_strategy_modules "${strategy}")
    threshold=$(level7_get_strategy_threshold "${strategy}" "${threshold}" "${threshold_set}")

    strategy_image="${PREP_TMPDIR}/level7/${strategy}/${image_base}"
    strategy_result_file="result/.${strategy}_${image_base%.ppm}.txt"

    : > "${strategy_result_file}"
    "preprocess_image_${preprocess}" "${image}" "${strategy_image}"

    for template in "${level_dir}"/*.ppm; do
        level7_get_variants_for_modules "${template}" "${modules}" > "${variants_file}"
        while IFS=' ' read -r variant_path rotation; do
            ./matching "${strategy_image}" "${variant_path}" "${rotation}" "${threshold}" pg
        done < "${variants_file}"
    done

    level7_keep_best_result "${strategy_result_file}"
    if [ -s "${strategy_result_file}" ]; then
        cat "${strategy_result_file}" >> "${aggregate_file}"
    fi
    rm -f "${strategy_result_file}"
}

run_level7() {
    local level_dir="$1"
    local output_image_dir="$2"
    local threshold="$3"
    local threshold_set="$4"
    local image
    local bname
    local result_file
    local aggregate_file
    local variants_file
    local answer_file
    local strategy

    . ./preprocess/base.sh
    . ./preprocess/denoise.sh
    . ./preprocess/contrast.sh
    . ./preprocess/edge.sh
    . ./preprocess/scale.sh
    . ./preprocess/rotate.sh

    level7_prepare_modules "${level_dir}"

    variants_file="${PREP_TMPDIR}/level7_variants.txt"

    for image in "${level_dir}"/test/*.ppm; do
        bname=$(basename "${image}")
        result_file="result/${bname%.ppm}.txt"
        aggregate_file="${PREP_TMPDIR}/level7/.${bname%.ppm}.candidates"

        echo "imgproc/${bname}"
        convert "${image}" "${output_image_dir}/${bname%.ppm}.png"
        answer_file="${level_dir}/test/${bname%.ppm}.txt"
        [ -f "${answer_file}" ] && cp "${answer_file}" "${output_image_dir}/"

        : > "${aggregate_file}"
        for strategy in ${LEVEL7_STRATEGIES}; do
            level7_run_strategy "${strategy}" "${image}" "${bname}" "${level_dir}" "${threshold}" "${threshold_set}" "${aggregate_file}" "${variants_file}"
        done

        : > "${result_file}"
        if [ -s "${aggregate_file}" ]; then
            level7_keep_best_result "${aggregate_file}"
            mv "${aggregate_file}" "${result_file}"
        else
            rm -f "${aggregate_file}"
        fi

        echo ""
    done

    level7_cleanup_modules
    rm -f "${variants_file}"
    rmdir "${PREP_TMPDIR}" 2>/dev/null
    wait
}
