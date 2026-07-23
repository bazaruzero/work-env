#!/bin/bash

# +--------------------------------------------------------------------------+
# |                                  CONFIG                                   |
# +--------------------------------------------------------------------------+

INVENTORY_DIR="${WORKSPACE}/inventory"
DEFAULT_PRIVATE_KEY="${WORKSPACE}/keys/private/id_rsa"
PSQL_BIN="${WORKSPACE}/soft/psql/bin/psql"

# +--------------------------------------------------------------------------+
# |                               FUNCTIONS                                  |
# +--------------------------------------------------------------------------+

# === ask_question ===
# Args: prompt, default_value (optional)
# Prints user input (or default) to stdout.

ask_question() {
    local prompt="$1"
    local default="${2:-}"

    if [[ -n "${default}" ]]; then
        read -p "${prompt} [${default}]: " answer
        echo "${answer:-${default}}"
    else
        while true; do
            read -p "${prompt}: " answer
            if [[ -n "${answer}" ]]; then
                echo "${answer}"
                break
            fi
            echo "ERROR: Value cannot be empty. Please try again." >&2
        done
    fi
}

# === ask_password ===
# Args: prompt
# Prints password (non-empty) to stdout.

ask_password() {
    local prompt="$1"
    local password

    while true; do
        read -s -p "${prompt}: " password
        echo "" >&2
        if [[ -n "${password}" ]]; then
            echo "${password}"
            break
        fi
        echo "ERROR: Password cannot be empty. Please try again." >&2
    done
}

# === ask_yes_no ===
# Args: prompt, default (y/n)
# Prints "yes" or "no" to stdout.

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local hint

    if [[ "${default}" == "y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    read -p "${prompt} ${hint}: " answer
    answer="${answer:-${default}}"

    if [[ "${answer}" =~ ^[Yy] ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# === select_env_file ===
# Interactively choose an existing .env file or create a new one.
# Prints the chosen file path to stdout. All status messages go to stderr.

select_env_file() {
    echo "INFO: Selecting target .env file in \"${INVENTORY_DIR}\"." >&2

    if [[ ! -d "${INVENTORY_DIR}" ]]; then
        echo "ERROR: Inventory directory \"${INVENTORY_DIR}\" not found." >&2
        echo "       Run init-linux.sh first or ensure WORKSPACE is set." >&2
        return 1
    fi

    local existing_files=()

    while IFS= read -r -d '' f; do
        existing_files+=("${f}")
    done < <(find "${INVENTORY_DIR}" -maxdepth 1 -type f -name "*.env" -print0 | sort -z)

    if [[ ${#existing_files[@]} -gt 0 ]]; then
        echo "INFO: Existing .env files:" >&2
        for j in "${!existing_files[@]}"; do
            echo "  $((j + 1))) $(basename "${existing_files[$j]}")" >&2
        done
        echo "  $(( ${#existing_files[@]} + 1 ))) Create new file" >&2

        local choice
        local max=$(( ${#existing_files[@]} + 1 ))
        while true; do
            read -p "Select option [1-${max}]: " choice
            if [[ "${choice}" =~ ^[0-9]+$ ]] && [[ "${choice}" -ge 1 ]] && [[ "${choice}" -le "${max}" ]]; then
                break
            fi
            echo "ERROR: Invalid choice. Please enter a number between 1 and ${max}." >&2
        done

        if [[ "${choice}" -le ${#existing_files[@]} ]]; then
            echo "${existing_files[$((choice - 1))]}"
            return 0
        fi
    fi

    local new_name
    while true; do
        new_name=$(ask_question "Enter new .env file name (without extension)" "connections")
        if [[ "${new_name}" != *.env ]]; then
            new_name="${new_name}.env"
        fi
        local new_path="${INVENTORY_DIR}/${new_name}"
        if [[ -f "${new_path}" ]]; then
            echo "ERROR: File \"${new_path}\" already exists. Choose another name." >&2
            continue
        fi
        echo "${new_path}"
        break
    done
}

# === build_db_alias ===
# Interactively collects DB connection parameters and prints the alias line to stdout.

build_db_alias() {
    local project_name="$1"
    local env_type="$2"
    local server_name="$3"
    local port="$4"
    local user_name="$5"

    local db_name
    db_name=$(ask_question "Enter database name")

    local alias_name="db_${project_name}_${env_type}_${server_name}_${db_name}"

    if [[ "${user_name}" == "${DEFAULT_PGUSER}" ]]; then
        echo "INFO: User \"${user_name}\" matches DEFAULT_PGUSER." >&2
        echo "INFO: Password will be taken from \${PGPASSWORD} at runtime." >&2
        local alias_value="\${WORKSPACE}/soft/psql/bin/psql -q -h ${server_name} -p ${port} -d ${db_name} -U \${PGUSER}"
        echo "alias ${alias_name}=\"${alias_value}\""
    else
        echo "INFO: User \"${user_name}\" differs from DEFAULT_PGUSER (\"${DEFAULT_PGUSER}\")." >&2
        local password
        password=$(ask_password "Enter password for \"${user_name}\"")
        local inner="PGPASSWORD=\"${password}\" \${WORKSPACE}/soft/psql/bin/psql -q -h ${server_name} -p ${port} -d ${db_name} -U \"${user_name}\""
        echo "alias ${alias_name}='bash -c '\''${inner}'\'"
    fi
}

# === build_ssh_alias ===
# Interactively collects SSH connection parameters and prints the alias line to stdout.

build_ssh_alias() {
    local project_name="$1"
    local env_type="$2"
    local server_name="$3"
    local port="$4"
    local user_name="$5"

    local alias_name="ssh_${project_name}_${env_type}_${server_name}"

    local use_key
    use_key=$(ask_yes_no "Use private key for SSH connection?" "y")

    if [[ "${use_key}" == "yes" ]]; then
        local key_path
        key_path=$(ask_question "Enter path to private key" "${DEFAULT_PRIVATE_KEY}")
        if [[ ! -f "${key_path}" ]]; then
            echo "WARNING: Key file \"${key_path}\" does not exist yet." >&2
        fi
        if [[ "${key_path}" == "${DEFAULT_PRIVATE_KEY}" ]]; then
            key_path='${WORKSPACE}/keys/private/id_rsa'
        fi
        local alias_value="ssh -i ${key_path} ${user_name}@${server_name}"
        echo "alias ${alias_name}=\"${alias_value}\""
    else
        local alias_value="ssh ${user_name}@${server_name}"
        echo "alias ${alias_name}=\"${alias_value}\""
    fi
}

# === append_to_env_file ===
# Args: file_path, alias_line
# Appends the alias line to the file with a header comment.

append_to_env_file() {
    local file_path="$1"
    local alias_line="$2"

    if [[ ! -f "${file_path}" ]]; then
        echo "##" >> "${file_path}"
        echo "## alias <connection_type>_<project_name>_<environment_type>_<server_name>_<db_name>" >> "${file_path}"
        echo "##" >> "${file_path}"
        echo "" >> "${file_path}"
    fi

    echo "${alias_line}" >> "${file_path}"
    echo "INFO: Alias appended to \"${file_path}\"."
}

# === main ===

main() {
    if [[ -z "${WORKSPACE}" ]]; then
        echo "ERROR: WORKSPACE environment variable is not set."
        echo "       Activate the workspace first: source \${WORKSPACE}/settings/profile"
        exit 1
    fi

    if [[ -z "${DEFAULT_PGUSER}" ]]; then
        echo "ERROR: DEFAULT_PGUSER environment variable is not set."
        echo "       Activate the workspace first: source \${WORKSPACE}/settings/profile"
        exit 1
    fi

    echo ""
    echo "+--------------------------------------------------------------------------+"
    echo "|              Create Connection Alias - Interactive Wizard               |"
    echo "+--------------------------------------------------------------------------+"
    echo ""

    local env_file
    env_file=$(select_env_file)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    echo "INFO: Target file: \"${env_file}\"."

    local project_name
    project_name=$(ask_question "Enter project name (e.g. hr, finance)")

    local env_type
    env_type=$(ask_question "Enter environment type (e.g. prod, dev, test)")

    local server_name
    server_name=$(ask_question "Enter server name (e.g. prod.example.com)")

    local port
    port=$(ask_question "Enter port" "5432")

    local user_name
    user_name=$(ask_question "Enter user name" "${DEFAULT_PGUSER}")

    local conn_type
    conn_type=$(ask_question "Connection type (db or ssh)" "db")

    local alias_line

    if [[ "${conn_type}" == "db" ]]; then
        alias_line=$(build_db_alias "${project_name}" "${env_type}" "${server_name}" "${port}" "${user_name}")
    elif [[ "${conn_type}" == "ssh" ]]; then
        alias_line=$(build_ssh_alias "${project_name}" "${env_type}" "${server_name}" "${port}" "${user_name}")
    else
        echo "ERROR: Unknown connection type \"${conn_type}\". Use \"db\" or \"ssh\"."
        exit 1
    fi

    echo ""
    echo "INFO: Generated alias:"
    echo "  ${alias_line}"
    echo ""

    local confirm
    confirm=$(ask_yes_no "Append this alias to the file?" "y")
    if [[ "${confirm}" == "yes" ]]; then
        append_to_env_file "${env_file}" "${alias_line}"
        echo "INFO: Done. Re-activate the workspace to pick up the new alias:"
        echo "  source \${WORKSPACE}/settings/profile"
    else
        echo "INFO: Cancelled. No changes were made."
    fi
}

# +--------------------------------------------------------------------------+
# |                                 MAIN                                     |
# +--------------------------------------------------------------------------+

main
