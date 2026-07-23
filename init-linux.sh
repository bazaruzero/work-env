#!/bin/bash

# +--------------------------------------------------------------------------+
# |                                  CONFIG                                   |
# +--------------------------------------------------------------------------+

ORG_NAME="mycompany"
PROJECT_ROOT_DIR="${HOME}/workspace-${ORG_NAME}"
DOWNLOADS_DIR="${HOME}/downloads"
DEFAULT_PGUSER="MYUSERNAME"

# dir_name:dir_description::subdir1,subdir2,...
STRUCTURE=(
    "cert:SSL/TLS certificates, CA bundles, and other certificate-related files.::"
    "hr:HR-related documents and instructions.::"
    "inventory:List of hosts and groups of servers/databases.::"
    "keys:SSH keys, GPG keys, and encryption keys for secure access and communication.::private,public"
    "learning:Educational materials, tutorials, documentation, and notes.::"
    "notes:Useful technical notes, cheatsheets, and quick-reference materials.::"
    "projects:Project-specific files, documents, reports, etc.::"
    "secrets:Sensitive credentials, passwords, and secrets management files.::"
    "settings:Configuration files, environment templates, and tool settings.::"
    "soft:Portable software tools, utilities and scripts.::sh,sql,putty,keepass2"
    "tmp:Location for temporary files.::"
)

SYMLINKS=(
    "downloads:${DOWNLOADS_DIR}"
)

# +--------------------------------------------------------------------------+
# |                               FUNCTIONS                                  |
# +--------------------------------------------------------------------------+

# === check_internet ===

check_internet() {
    local test_urls=(
        "https://github.com"
        "https://ftp.postgresql.org"
        "https://www.cpan.org"
        "https://jdbc.postgresql.org"
    )
    local timeout=10

    echo "INFO: Checking internet connection..."

    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        echo "ERROR: Neither wget nor curl is available. Cannot check internet connection."
        echo "       Please install wget or curl first."
        exit 1
    fi

    for url in "${test_urls[@]}"; do
        if command -v wget &> /dev/null; then
            if wget -q --spider --timeout="${timeout}" "${url}" 2>/dev/null; then
                echo "INFO: Internet connection available (reached ${url})."
                return 0
            fi
        elif command -v curl &> /dev/null; then
            if curl -s -o /dev/null --max-time "${timeout}" --head "${url}" 2>/dev/null; then
                echo "INFO: Internet connection available (reached ${url})."
                return 0
            fi
        fi
    done

    echo "ERROR: No internet connection detected."
    echo "       The following hosts were unreachable:"
    for url in "${test_urls[@]}"; do
        echo "         - ${url}"
    done
    echo "       Most setup_* functions require internet access to download files."
    echo "       Please check your network connection and proxy settings, then re-run the script."
    exit 1
}

# === create_project_root_dir ===

create_project_root_dir() {
    echo "INFO: Creating project root directory \"${PROJECT_ROOT_DIR}\"."

    if ! [[ -d ${PROJECT_ROOT_DIR} ]]; then
        mkdir -p ${PROJECT_ROOT_DIR}
    else
        echo "ERROR: directory \"${PROJECT_ROOT_DIR}\" already exists."
        exit 1
    fi
}

# === create_dir_structure ===

create_dir_structure() {
    echo "INFO: Creating directory structure inside \"${PROJECT_ROOT_DIR}\"."

    for entry in "${STRUCTURE[@]}"; do
        local dir_name="${entry%%:*}"
        local rest="${entry#*:}"
        local subdirs="${rest##*::}"
        local dir_path="${PROJECT_ROOT_DIR}/${dir_name}"

        mkdir -p "${dir_path}"

        if [[ -n "${subdirs}" ]]; then
            for subdir in $(echo "${subdirs}" | tr ',' ' '); do
                mkdir -p "${dir_path}/${subdir}"
            done
        fi
    done

    cp "$(dirname "$0")/examples/example.env" ${PROJECT_ROOT_DIR}/inventory/
    cp "$(dirname "$0")/scripts/create_connection.sh ${PROJECT_ROOT_DIR}/soft/sh
}

# === create_readme ===

create_readme() {
    local dir_path="$1"
    local description="$2"
    local dir_name="${dir_path##*/}"

    cat > "${dir_path}/README.md" <<EOF
# ${dir_name}

${description}
EOF
    echo "INFO: Created README.md for \"${dir_name}\"."
}

# === create_readmes ===

create_readmes() {
    echo "INFO: Creating README.md files for first-level directories."

    for entry in "${STRUCTURE[@]}"; do
        local dir_name="${entry%%:*}"
        local rest="${entry#*:}"
        local description="${rest%%::*}"
        local dir_path="${PROJECT_ROOT_DIR}/${dir_name}"

        if [[ -n "${description}" ]]; then
            create_readme "${dir_path}" "${description}"
        fi
    done
}

# === create_symlinks ===

create_symlinks() {
    echo "INFO: Creating symbolic links."

    for entry in "${SYMLINKS[@]}"; do
        local link_name="${entry%%:*}"
        local target="${entry#*:}"

        if ! [[ -L "${PROJECT_ROOT_DIR}/${link_name}" ]]; then
            ln -s "${target}" "${PROJECT_ROOT_DIR}/${link_name}"
            echo "INFO: Symlink \"${link_name}\" -> \"${target}\" created."
        else
            echo "WARNING: Symlink \"${link_name}\" already exists."
        fi
    done
}

# === create_profile_template ===

create_profile() {
    local template_file="$(dirname "$0")/templates/template_profile"
    local target_file="${PROJECT_ROOT_DIR}/settings/profile"

    echo "INFO: Creating profile from template."

    if [[ ! -f "${template_file}" ]]; then
        echo "ERROR: Template file \"${template_file}\" not found."
        return 1
    fi

    sed -e "s|#{ORG_NAME}|${ORG_NAME}|g" \
        -e "s|#{PROJECT_ROOT_DIR}|${PROJECT_ROOT_DIR}|g" \
        -e "s|#{DOWNLOADS_DIR}|${DOWNLOADS_DIR}|g" \
        -e "s|#{DEFAULT_PGUSER}|${DEFAULT_PGUSER}|g" \
        "${template_file}" > "${target_file}"

    chmod 750 $target_file

    echo "INFO: Profile created at \"${target_file}\"."
}

# === create_psqlrc ===

create_psqlrc() {
    local template_file="$(dirname "$0")/templates/template_psqlrc"
    local target_file="${PROJECT_ROOT_DIR}/settings/psqlrc"

    echo "INFO: Creating psqlrc from template."

    if [[ ! -f "${template_file}" ]]; then
        echo "ERROR: Template file \"${template_file}\" not found."
        return 1
    fi

    cp ${template_file} ${target_file}
    chmod 750 $target_file

    echo "INFO: PSQLRC file created at \"${target_file}\"."
}

# === setup_ash_viewer ===

setup_ash_viewer() {
    local ash_viewer_dir="${PROJECT_ROOT_DIR}/soft/ash-viewer"
    local download_url="https://github.com/akardapolov/ASH-Viewer/releases/download/v4.4.0/ashv-4.4.1-bin.zip"
    local zip_file="${ash_viewer_dir}/ashv-4.4.1-bin.zip"

    echo "INFO: Setting up ASH-Viewer in \"${ash_viewer_dir}\"."

    if [[ ! -d "${ash_viewer_dir}" ]]; then
        mkdir -p "${ash_viewer_dir}"
        echo "INFO: Created directory \"${ash_viewer_dir}\"."
    fi

    if command -v wget &> /dev/null; then
        echo "INFO: Downloading ASH-Viewer using wget..."
        wget -O "${zip_file}" "${download_url}"
    elif command -v curl &> /dev/null; then
        echo "INFO: Downloading ASH-Viewer using curl..."
        curl -L -o "${zip_file}" "${download_url}"
    else
        echo "ERROR: Neither wget nor curl is available. Please install one of them."
        return 1
    fi

    if [[ $? -ne 0 ]] || [[ ! -f "${zip_file}" ]]; then
        echo "ERROR: Failed to download ASH-Viewer from ${download_url}"
        return 1
    fi

    echo "INFO: Download completed successfully."

    if ! command -v unzip &> /dev/null; then
        echo "ERROR: unzip is not installed. Please install unzip to extract the archive."
        return 1
    fi

    echo "INFO: Extracting archive..."
    unzip -o "${zip_file}" -d "${ash_viewer_dir}"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to extract archive."
        rm -f "${zip_file}"
        return 1
    fi

    rm -f "${zip_file}"

    local extracted_dir=$(find "${ash_viewer_dir}" -maxdepth 1 -type d -name "ashv-*" | head -1)
    
    if [[ -z "${extracted_dir}" ]]; then
        echo "ERROR: Could not find extracted directory."
        return 1
    fi
    
    if [[ -L "${ash_viewer_dir}/bin" ]]; then
        rm -f "${ash_viewer_dir}/bin"
        echo "INFO: Removed existing symlink bin."
    fi
    
    ln -s "$(basename "${extracted_dir}")" "${ash_viewer_dir}/bin"
    echo "INFO: Symlink \"bin\" -> \"$(basename "${extracted_dir}")\" created."

    if [[ ! -d "${ash_viewer_dir}/logs" ]]; then
        mkdir -p "${ash_viewer_dir}/logs"
        echo "INFO: Created directory \"${ash_viewer_dir}/logs\"."
    fi

    chmod -R 750 ${ash_viewer_dir}

    echo "INFO: ASH-Viewer successfully installed in \"${ash_viewer_dir}\"."
}

# === setup_java ===

setup_java() {
    local java_dir="${PROJECT_ROOT_DIR}/soft/java"
    local download_url="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.31%2B11/OpenJDK11U-jdk_x64_linux_hotspot_11.0.31_11.tar.gz"
    local archive_file="${java_dir}/openjdk-jdk.tar.gz"

    echo "INFO: Setting up portable Java in \"${java_dir}\"."

    if [[ ! -d "${java_dir}" ]]; then
        mkdir -p "${java_dir}"
        echo "INFO: Created directory \"${java_dir}\"."
    fi

    if command -v wget &> /dev/null; then
        echo "INFO: Downloading Java using wget..."
        wget -O "${archive_file}" "${download_url}"
    elif command -v curl &> /dev/null; then
        echo "INFO: Downloading Java using curl..."
        curl -L -o "${archive_file}" "${download_url}"
    else
        echo "ERROR: Neither wget nor curl is available. Please install one of them."
        return 1
    fi

    if [[ $? -ne 0 ]] || [[ ! -f "${archive_file}" ]]; then
        echo "ERROR: Failed to download Java from ${download_url}"
        return 1
    fi

    echo "INFO: Download completed successfully."

    if ! command -v tar &> /dev/null; then
        echo "ERROR: tar is not installed. Please install tar to extract the archive."
        rm -f "${archive_file}"
        return 1
    fi

    echo "INFO: Extracting archive..."
    tar -xzf "${archive_file}" -C "${java_dir}"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to extract archive."
        rm -f "${archive_file}"
        return 1
    fi

    rm -f "${archive_file}"

    local extracted_path=$(find "${java_dir}" -maxdepth 1 -type d -name "jdk-*" | head -1)
    
    if [[ -z "${extracted_path}" ]]; then
        echo "ERROR: Could not find extracted Java directory."
        return 1
    fi
    
    chmod -R 750 ${java_dir}

    echo "INFO: Java successfully installed in \"${java_dir}\"."
    echo "INFO: Java version:"
    "${extracted_path}/bin/java" -version 2>&1
}

# === setup_jdbc ===

setup_jdbc() {
    local jdbc_dir="${PROJECT_ROOT_DIR}/soft/java/jdbc"
    local jdbc_version="42.7.5"
    local download_url="https://jdbc.postgresql.org/download/postgresql-${jdbc_version}.jar"
    local jar_file="${jdbc_dir}/postgresql-${jdbc_version}.jar"

    echo "INFO: Setting up PostgreSQL JDBC driver (version ${jdbc_version}) in \"${jdbc_dir}\"."

    if [[ ! -d "${jdbc_dir}" ]]; then
        mkdir -p "${jdbc_dir}"
        echo "INFO: Created directory \"${jdbc_dir}\"."
    fi

    if [[ -f "${jar_file}" ]]; then
        echo "INFO: JDBC driver version ${jdbc_version} already exists at \"${jar_file}\"."
		return 1
	fi

    if command -v wget &> /dev/null; then
        echo "INFO: Downloading PostgreSQL JDBC driver using wget..."
        wget -O "${jar_file}" "${download_url}"
    elif command -v curl &> /dev/null; then
        echo "INFO: Downloading PostgreSQL JDBC driver using curl..."
        curl -L -o "${jar_file}" "${download_url}"
    else
        echo "ERROR: Neither wget nor curl is available. Please install one of them."
        return 1
    fi

    if [[ $? -ne 0 ]] || [[ ! -f "${jar_file}" ]]; then
        echo "ERROR: Failed to download JDBC driver from ${download_url}"
        return 1
    fi

    if [[ ! -s "${jar_file}" ]]; then
        echo "ERROR: Downloaded file is empty."
        rm -f "${jar_file}"
        return 1
    fi

    chmod -R 750 ${jdbc_dir}
    
    echo "INFO: JDBC driver version \"${jdbc_version}\" placed into \"${jdbc_dir}\"."
}

# === setup_pgbadger ===

setup_pgbadger() {
    local pgbadger_dir="${PROJECT_ROOT_DIR}/soft/pgbadger"
    local version="13.2"
    local base_url="https://github.com/darold/pgbadger/archive/refs/tags"
    local archive_name="v${version}.tar.gz"
    local download_url="${base_url}/${archive_name}"
    local archive_file="${pgbadger_dir}/${archive_name}"
    local perl_bin="${PROJECT_ROOT_DIR}/soft/perl/bin/perl"

    echo "INFO: Setting up pgBadger v${version} in \"${pgbadger_dir}\"."

    if [[ ! -x "${perl_bin}" ]]; then
        echo "ERROR: Portable Perl not found at ${perl_bin}."
        echo "       Please run setup_perl first or ensure Perl is installed."
        return 1
    fi
    echo "INFO: Found portable Perl at ${perl_bin}."

    if [[ -f "${pgbadger_dir}/bin/pgbadger" ]]; then
        echo "INFO: pgBadger already exists at \"${pgbadger_dir}/bin/pgbadger\"."
        local current_version=$("${pgbadger_dir}/bin/pgbadger" --version 2>&1 | head -1 | grep -oP 'v\K[\d.]+')
        echo "INFO: Found version v${current_version}. Skipping installation."
        return 0
    fi

    if [[ ! -d "${pgbadger_dir}" ]]; then
        mkdir -p "${pgbadger_dir}"
        echo "INFO: Created directory \"${pgbadger_dir}\"."
    fi

    echo "INFO: Downloading pgBadger source code version ${version}..."
    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "${archive_file}" "${download_url}"
    elif command -v curl &> /dev/null; then
        curl -# -L -o "${archive_file}" "${download_url}"
    else
        echo "ERROR: Neither wget nor curl is available. Please install one of them."
        return 1
    fi
	
    if [[ $? -ne 0 ]] || [[ ! -f "${archive_file}" ]]; then
        echo "ERROR: Failed to download pgBadger source from ${download_url}"
        return 1
    fi
    echo "INFO: Download completed successfully."

    echo "INFO: Extracting archive..."
    if ! command -v tar &> /dev/null; then
        echo "ERROR: tar is not installed. Please install tar."
        rm -f "${archive_file}"
        return 1
    fi
    tar -xzf "${archive_file}" -C "${pgbadger_dir}"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to extract archive."
        rm -f "${archive_file}"
        return 1
    fi
    rm -f "${archive_file}"

    local source_dir="${pgbadger_dir}/pgbadger-${version}"

    if [[ ! -d "${source_dir}" ]]; then
        echo "ERROR: Could not find extracted source directory at ${source_dir}."
        return 1
    fi

    echo "INFO: Configuring pgBadger with portable Perl..."
    cd "${source_dir}"
	
    echo "INFO: Adjusting shebang to use portable Perl..."
    sed -i "1s|^#!.*|#!${perl_bin}|" "${source_dir}/pgbadger"
	
    mkdir -p "${pgbadger_dir}/bin"
    cp "${source_dir}/pgbadger" "${pgbadger_dir}/bin/"
    
    if [[ -d "${source_dir}/doc" ]]; then
        mkdir -p "${pgbadger_dir}/share"
        cp -r "${source_dir}/doc" "${pgbadger_dir}/share/"
        echo "INFO: Documentation copied to \"${pgbadger_dir}/share/doc\"."
    fi
    
    cd "${PROJECT_ROOT_DIR}"
    rm -rf "${source_dir}"
    chmod -R 750 "${pgbadger_dir}"
	
    echo "INFO: pgBadger successfully installed in \"${pgbadger_dir}\"."
    echo "INFO: pgBadger version:"
    "${pgbadger_dir}/bin/pgbadger" --version
}

# === setup_psql ===

setup_psql() {
    local psql_base_dir="${PROJECT_ROOT_DIR}/soft/psql"
    local version="16.2"
    local source_url="https://ftp.postgresql.org/pub/source/v${version}/postgresql-${version}.tar.gz"
    local work_dir="${psql_base_dir}/build"
    local source_dir="${work_dir}/postgresql-${version}"

    echo "INFO: Setting up portable psql (PostgreSQL ${version}) in \"${psql_base_dir}\"."

    local missing_deps=0
    for cmd in gcc make tar; do
        if ! command -v $cmd &> /dev/null; then
            echo "ERROR: $cmd is required for compilation but not installed."
            missing_deps=1
        fi
    done

    if ! ldconfig -p 2>/dev/null | grep -q "libreadline.so"; then
        echo "ERROR: libreadline development library is required but not installed."
        echo "       On Debian/Ubuntu: sudo apt-get install libreadline-dev"
        echo "       On RHEL/CentOS/Fedora: sudo yum install readline-devel"
        missing_deps=1
    fi

    if [[ $missing_deps -eq 1 ]]; then
        echo "ERROR: Missing required dependencies. Aborting."
        return 1
    fi

    if [[ -f "${psql_base_dir}/bin/psql" ]]; then
        echo "INFO: psql already exists at \"${psql_base_dir}/bin/psql\"."
        echo "INFO: Skipping build. Remove the directory to force reinstall."
        return 0
    fi

    mkdir -p "${psql_base_dir}/bin"
    mkdir -p "${psql_base_dir}/lib"
    mkdir -p "${work_dir}"

    echo "INFO: Downloading PostgreSQL source code..."
    if command -v wget &> /dev/null; then
        wget -O "${work_dir}/postgresql-${version}.tar.gz" "${source_url}"
    elif command -v curl &> /dev/null; then
        curl -L -o "${work_dir}/postgresql-${version}.tar.gz" "${source_url}"
    else
        echo "ERROR: Neither wget nor curl is available."
        rm -rf "${work_dir}"
        return 1
    fi

    if [[ $? -ne 0 ]] || [[ ! -f "${work_dir}/postgresql-${version}.tar.gz" ]]; then
        echo "ERROR: Failed to download source code from ${source_url}"
        echo "       Trying alternative mirror..."
        local alt_url="http://ftp.postgresql.org/pub/source/v${version}/postgresql-${version}.tar.gz"
        if command -v wget &> /dev/null; then
            wget -O "${work_dir}/postgresql-${version}.tar.gz" "${alt_url}"
        else
            curl -L -o "${work_dir}/postgresql-${version}.tar.gz" "${alt_url}"
        fi
        if [[ $? -ne 0 ]]; then
            echo "ERROR: Failed to download from alternative mirror as well."
            rm -rf "${work_dir}"
            return 1
        fi
    fi
    echo "INFO: Source code downloaded successfully."

    echo "INFO: Extracting source code..."
    tar -xzf "${work_dir}/postgresql-${version}.tar.gz" -C "${work_dir}"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to extract source code."
        rm -rf "${work_dir}"
        return 1
    fi

    echo "INFO: Configuring build for client tools only..."
    cd "${source_dir}"
    
    ./configure --prefix="${psql_base_dir}" --without-server --without-zlib --without-icu
    
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Configuration failed."
        echo "       Check that development libraries are installed."
        cd /
        rm -rf "${work_dir}"
        return 1
    fi
    
    echo "INFO: Compiling psql and client libraries..."
    make -C src/interfaces/libpq
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to compile libpq."
        cd /
        rm -rf "${work_dir}"
        return 1
    fi
    
    make -C src/bin/psql
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to compile psql."
        cd /
        rm -rf "${work_dir}"
        return 1
    fi

    echo "INFO: Installing psql to ${psql_base_dir}..."
    make -C src/interfaces/libpq install
    make -C src/bin/psql install

    find "${psql_base_dir}/lib" -name "*.so*" -exec chmod 755 {} \;
    cd /
    rm -rf "${work_dir}"
    echo "INFO: Cleaned up temporary build files."
    echo "INFO: psql installed to: ${psql_base_dir}/bin/psql"
}


# === setup_perl ===

setup_perl() {
    local perl_dir="${PROJECT_ROOT_DIR}/soft/perl"
    local version="5.40.0"
    local download_url="https://www.cpan.org/src/5.0/perl-${version}.tar.gz"
    local archive_file="${perl_dir}/perl-${version}.tar.gz"

    echo "INFO: Setting up portable Perl in \"${perl_dir}\"."

    if [[ -f "${perl_dir}/bin/perl" ]]; then
        echo "INFO: Perl already exists at \"${perl_dir}/bin/perl\"."
        local perl_version=$("${perl_dir}/bin/perl" -v | grep -oP '(?<=This is perl 5, version )\d+,\s*version \K\d+' | head -1)
        echo "INFO: Found version v${perl_version}. Skipping installation."
        return 0
    fi

    if [[ ! -d "${perl_dir}" ]]; then
        mkdir -p "${perl_dir}"
        echo "INFO: Created directory \"${perl_dir}\"."
    fi

    echo "INFO: Downloading Perl source code version ${version}..."
    if command -v wget &> /dev/null; then
        wget -O "${archive_file}" "${download_url}"
    elif command -v curl &> /dev/null; then
        curl -L -o "${archive_file}" "${download_url}"
    else
        echo "ERROR: Neither wget nor curl is available. Please install one of them."
        return 1
    fi

    if [[ $? -ne 0 ]] || [[ ! -f "${archive_file}" ]]; then
        echo "ERROR: Failed to download Perl source from ${download_url}"
        return 1
    fi
    echo "INFO: Download completed successfully."

    echo "INFO: Extracting archive..."
    if ! command -v tar &> /dev/null; then
        echo "ERROR: tar is not installed. Please install tar to extract the archive."
        rm -f "${archive_file}"
        return 1
    fi
    tar -xzf "${archive_file}" -C "${perl_dir}"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to extract archive."
        rm -f "${archive_file}"
        return 1
    fi

    rm -f "${archive_file}"
	
    local source_dir="${perl_dir}/perl-${version}"
    if [[ ! -d "${source_dir}" ]]; then
        echo "ERROR: Could not find extracted source directory at ${source_dir}."
        return 1
    fi

    echo "INFO: Configuring Perl for portable installation in \"${perl_dir}\"..."
    cd "${source_dir}"
    ./Configure -des -Dprefix="${perl_dir}" -Dusethreads -Duserelocatableinc

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Configuration failed."
        cd "${PROJECT_ROOT_DIR}"
        return 1
    fi

    echo "INFO: Compiling Perl (this may take a few minutes)..."
    make
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Compilation failed."
        cd "${PROJECT_ROOT_DIR}"
        return 1
    fi

    echo "INFO: Installing Perl to \"${perl_dir}\"..."
    make install
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Installation failed."
        cd "${PROJECT_ROOT_DIR}"
        return 1
    fi

    cd "${PROJECT_ROOT_DIR}"
    rm -rf "${source_dir}"
    chmod -R 750 "${perl_dir}"

    echo "INFO: Perl successfully installed in \"${perl_dir}\"."
    echo "INFO: Perl version:"
    "${perl_dir}/bin/perl" -v
}

# === setup_psql_dba_tools ===

setup_psql_dba_tools() {
    local tools_dir="${PROJECT_ROOT_DIR}/soft/psql-dba-tools"
    local repo_url="https://github.com/bazaruzero/psql-dba-tools"
    local init_script="${tools_dir}/init.sh"

    echo "INFO: Setting up psql-dba-tools in \"${tools_dir}\"."

    if [[ -d "${tools_dir}" ]]; then
        echo "INFO: psql-dba-tools directory already exists at \"${tools_dir}\"."
        echo "INFO: Skipping. Remove the directory to force reinstall."
        return 0
    fi

    if ! command -v git &> /dev/null; then
        echo "ERROR: git is required but not installed."
        echo "       On Debian/Ubuntu: sudo apt-get install git"
        echo "       On RHEL/CentOS/Fedora: sudo yum install git"
        return 1
    fi

    echo "INFO: Cloning repository..."
    git clone "${repo_url}" "${tools_dir}"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to clone repository from ${repo_url}."
        rm -rf "${tools_dir}"
        return 1
    fi

    rm -rf "${tools_dir}/.git"
    chmod -R 750 "${tools_dir}"

    if [[ ! -f "${init_script}" ]]; then
        echo "ERROR: Init script \"${init_script}\" not found."
        return 1
    fi

    echo "INFO: Running init script..."
    bash "${init_script}" "${tools_dir}"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Init script failed."
        return 1
    fi

    if [[ -f ${PROJECT_ROOT_DIR}/settings/psqlrc ]]; then
        rm -f "${tools_dir}/psqlrc"
        echo "" >> ${PROJECT_ROOT_DIR}/settings/psqlrc
        echo "\set dba '\\\\i ${tools_dir}/dba.psql'" >> ${PROJECT_ROOT_DIR}/settings/psqlrc
    fi

    echo "INFO: psql-dba-tools successfully installed in \"${tools_dir}\"."
}

# === notice ===

notice() {
    echo ""
    echo "---------- NOTICE ----------"
    echo ""
    echo "1) Update your ~/.bashrc or ~/.profile files with aliases below:"
    echo ""
    echo "alias env${ORG_NAME}=\"source ${PROJECT_ROOT_DIR}/settings/profile\""
    echo "alias env${ORG_NAME}skipcreds=\"SKIP_CREDS=\"yes\" source ${PROJECT_ROOT_DIR}/settings/profile\""
}

# === update_bashrc

update_bashrc() {

    if [[ ! -f ${HOME}/.bashrc ]]; then
        echo "INFO: File ${HOME}/.bashrc file not found."
        notice
        return 1 
    fi

    cp ${HOME}/.bashrc ${HOME}/.bashrc_BKP_$(date +%Y%m%d)T$(date +%H%M%S)

    echo "" >> ${HOME}/.bashrc
    echo "##" >> ${HOME}/.bashrc
    echo "## ORG_NAME: ${ORG_NAME}" >> ${HOME}/.bashrc
    echo "## WORK_DIR: ${PROJECT_ROOT_DIR}" >> ${HOME}/.bashrc
    echo "##" >> ${HOME}/.bashrc
    echo "" >> ${HOME}/.bashrc
    echo "alias env${ORG_NAME}=\"source ${PROJECT_ROOT_DIR}/settings/profile\"" >> ${HOME}/.bashrc
    echo "alias env${ORG_NAME}skipcreds=\"SKIP_CREDS=\"yes\" source ${PROJECT_ROOT_DIR}/settings/profile\"" >> ${HOME}/.bashrc
    echo "INFO: Updated \"${HOME}/.bashrc\" file with aliases."
}

# === main ===

main() {
    create_project_root_dir
    create_dir_structure
    create_symlinks
    create_readmes
    create_profile
    create_psqlrc
    check_internet
    setup_ash_viewer
    setup_java
    setup_jdbc
    setup_perl
    setup_pgbadger
    setup_psql
    setup_psql_dba_tools
    update_bashrc
}

# +--------------------------------------------------------------------------+
# |                                 MAIN                                     |
# +--------------------------------------------------------------------------+

main
