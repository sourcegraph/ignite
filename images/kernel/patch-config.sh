#!/usr/bin/env bash

set -xeo pipefail

OLD_FILE="${1}"
NEW_FILE="${2}"
# The path to where the "patch instructions" are
PATCH_FILE="${3}"

# Note: set_kernel_config and unset_kernel_config are courtesy of @sakaki- on Github
# https://github.com/sakaki-/bcm2711-kernel-bis/blob/master/conform_config.sh.
# Slight modifications have been made to fit this context

set_kernel_config() {
    # flag as $1, value to set as $2, config file as $3
    local TGT="CONFIG_${1#CONFIG_}"
    local VALUE="${2}"
    local REP="${VALUE//\//\\/}"
    REP="${REP//&/\\&}"
    local FILE="${3}"

    if grep -Eq "^(${TGT}=|# ${TGT} is not set)" "${FILE}"; then
        sed -E "s/^(${TGT}=.*|# ${TGT} is not set)/${TGT}=${REP}/" "${FILE}" > "${FILE}.replaced"
        mv "${FILE}.replaced" "${FILE}"
    else
        echo "${TGT}=${VALUE}" >> "${FILE}"
    fi
}

unset_kernel_config() {
    # unsets flag as $1 in config file as $2
    local TGT="CONFIG_${1#CONFIG_}"
    local FILE="${2}"

    if grep -Eq "^(${TGT}=|# ${TGT} is not set)" "${FILE}"; then
        sed -E "s/^(${TGT}=.*|# ${TGT} is not set)/# ${TGT} is not set/" "${FILE}" > "${FILE}.replaced"
        mv "${FILE}.replaced" "${FILE}"
    else
        echo "# ${TGT} is not set" >> "${FILE}"
    fi
}

patch_file() {
    # patches a config file $1 according to the recipe of $PATCH_FILE
    config_file=$1
    echo "Patching ${config_file}..."

    while IFS= read -r line; do
        # Strip comments, including inline comments, and trim whitespace.
        line="${line%%#*}"
        line="$(echo "${line}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [[ -z "${line}" ]] && continue

        # From https://stackoverflow.com/questions/10638538/split-string-with-bash-with-symbol
        config_key=${line%=*}
        config_value=${line#*=}
        echo "    Applying: ${config_key}=${config_value}"
        if [[ ${config_value} == "n" ]]; then
            unset_kernel_config "${config_key}" "${config_file}"
        else
            set_kernel_config "${config_key}" "${config_value}" "${config_file}"
        fi
    done < "${PATCH_FILE}"
}


# Copy the old config file to the new (overwrite if present), and patch the new one in-place
cp -f "${OLD_FILE}" "${NEW_FILE}"
# Add an extra newline to the upstream file if it hasn't got it
# From https://backreference.org/2010/05/23/sanitizing-files-with-no-trailing-newline/
tail -c1 "${NEW_FILE}" | read -r _ || echo >> "${NEW_FILE}"
# Apply patches to the new file
patch_file "${NEW_FILE}"
