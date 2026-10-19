#!/usr/bin/env bash
# Instala os módulos usados por .atualizar.sh em Ubuntu/WSL.

set -o pipefail

MODULE="${1:-tudo}"

log() { printf '\n\033[1;36m[instalar] %s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m[AVISO] %s\033[0m\n' "$*"; }

apt_disponivel() {
    command -v apt-get >/dev/null 2>&1 || return 1
    local candidate
    candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
    [[ -n "$candidate" && "$candidate" != '(none)' ]]
}

apt_instalado() {
    dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -q '^installed$'
}

instalar_apt() {
    local pacote="$1"
    if apt_instalado "$pacote"; then
        return 0
    fi
    if apt_disponivel "$pacote"; then
        sudo apt-get install -y "$pacote"
    else
        return 1
    fi
}

ubuntu_codename() {
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        printf '%s' "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    fi
}

configurar_repo_mongodb() {
    local codename arch
    codename="$(ubuntu_codename)"
    arch="$(dpkg --print-architecture)"
    case "$codename:$arch" in
        focal:amd64|jammy:amd64|noble:amd64|focal:arm64|jammy:arm64|noble:arm64) ;;
        *) aviso "MongoDB oficial não tem configuração automática para Ubuntu $codename ($arch)."; return 1 ;;
    esac
    sudo install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg || return 1
    printf 'deb [ arch=%s signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu %s/mongodb-org/8.0 multiverse\n' "$arch" "$codename" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
    sudo apt-get update
}

configurar_repo_pgadmin() {
    local codename
    codename="$(ubuntu_codename)"
    case "$codename" in
        jammy|noble|resolute) ;;
        *) aviso "pgAdmin oficial não tem configuração automática para Ubuntu $codename."; return 1 ;;
    esac
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor --yes -o /etc/apt/keyrings/packages-pgadmin-org.gpg || return 1
    printf 'deb [signed-by=/etc/apt/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/%s pgadmin4 main\n' "$codename" | sudo tee /etc/apt/sources.list.d/pgadmin4.list >/dev/null
    sudo apt-get update
}

snap_instalado() {
    command -v snap >/dev/null 2>&1 && snap list "$1" >/dev/null 2>&1
}

instalar_snap_ou_apt() {
    local pacote="$1" classic="${2:-false}"
    if snap_instalado "$pacote"; then
        return 0
    fi
    if command -v snap >/dev/null 2>&1; then
        if [[ "$classic" == true ]]; then
            sudo snap install "$pacote" --classic && return 0
        else
            sudo snap install "$pacote" && return 0
        fi
    fi
    if instalar_apt "$pacote"; then
        return 0
    else
        aviso "$pacote não está disponível por Snap nem nos repositórios APT configurados."
        return 1
    fi
}

instalar_base() {
    log 'Instalando utilitários básicos para Ubuntu/WSL.'
    sudo apt-get update || return 1
    sudo apt-get install -y ca-certificates curl gnupg || return 1
    if ! command -v snap >/dev/null 2>&1 && apt_disponivel snapd; then
        sudo apt-get install -y snapd
    fi
    if command -v snap >/dev/null 2>&1; then
        if command -v systemctl >/dev/null 2>&1; then sudo systemctl enable --now snapd.socket >/dev/null 2>&1 || true; fi
        if command -v service >/dev/null 2>&1; then sudo service snapd start >/dev/null 2>&1 || true; fi
    fi
}

instalar_conda() {
    command -v conda >/dev/null 2>&1 && return 0
    log 'Instalando Miniforge (Conda com canal conda-forge, sem os canais Anaconda que pedem aceite de termos).'
    local arch installer prefix
    case "$(uname -m)" in
        x86_64) arch=x86_64 ;;
        aarch64|arm64) arch=aarch64 ;;
        *) aviso "Arquitetura $(uname -m) não suportada pelo instalador automático do Miniforge."; return 1 ;;
    esac
    installer="$(mktemp)" || return 1
    prefix="${CONDA_PREFIX_BASE:-$HOME/miniforge3}"
    if curl -fsSL "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${arch}.sh" -o "$installer"; then
        bash "$installer" -b -p "$prefix" && "$prefix/bin/conda" init bash
        local status=$?
        rm -f "$installer"
        return "$status"
    else
        aviso 'Não foi possível baixar o instalador do Miniforge.'
        rm -f "$installer"
        return 1
    fi
}

instalar_java() {
    command -v javac >/dev/null 2>&1 && return 0
    if ! instalar_apt openjdk-21-jdk; then
        instalar_apt default-jdk || aviso 'JDK não encontrado nos repositórios APT configurados.'
    fi
}

instalar_node() {
    command -v npm >/dev/null 2>&1 && return 0
    log 'Instalando Node.js e NPM pelos repositórios APT configurados.'
    instalar_apt nodejs || { aviso 'Node.js não está disponível nos repositórios APT.'; return 1; }
    instalar_apt npm || { aviso 'NPM não está disponível nos repositórios APT.'; return 1; }
}

instalar_linguagens() {
    if ! command -v dotnet >/dev/null 2>&1; then
        log 'Instalando .NET SDK LTS no perfil do usuário.'
        if curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS; then
            export DOTNET_ROOT="$HOME/.dotnet"
            export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
            if ! grep -qF 'DOTNET_ROOT="$HOME/.dotnet"' "$HOME/.bashrc" 2>/dev/null; then
                printf '\nexport DOTNET_ROOT="$HOME/.dotnet"\nexport PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"\n' >> "$HOME/.bashrc"
            fi
        else
            aviso 'Não foi possível instalar o .NET SDK.'
        fi
    fi
    if command -v dotnet >/dev/null 2>&1; then
        dotnet tool install -g dotnet-repl 2>/dev/null || dotnet tool update -g dotnet-repl || true
    fi
    if ! command -v cs >/dev/null 2>&1 && ! command -v coursier >/dev/null 2>&1; then
        local cs_bin="$HOME/.local/bin/cs" cs_arch
        case "$(uname -m)" in
            x86_64) cs_arch=x86_64-pc-linux ;;
            aarch64|arm64) cs_arch=aarch64-pc-linux ;;
            *) aviso "Coursier não configurado para $(uname -m)."; return 1 ;;
        esac
        mkdir -p "$HOME/.local/bin"
        if curl -fL "https://github.com/coursier/launchers/raw/master/cs-${cs_arch}.gz" | gzip -d > "$cs_bin"; then
            chmod +x "$cs_bin"
            "$cs_bin" setup --yes
        else
            aviso 'Não foi possível instalar Coursier/Scala.'
            return 1
        fi
    fi
}

instalar_bancos() {
    log 'Instalando bancos de dados disponíveis nos repositórios APT configurados.'
    local pacote
    for pacote in mysql-server postgresql; do
        if ! instalar_apt "$pacote"; then
            aviso "$pacote não está disponível nos repositórios APT configurados."
        fi
    done
    if ! instalar_apt mongodb-org; then
        configurar_repo_mongodb && instalar_apt mongodb-org || aviso 'MongoDB não pôde ser instalado neste Ubuntu.'
    fi
}

instalar_visuais() {
    if ! apt_instalado pgadmin4-web && ! instalar_apt pgadmin4-web; then
        configurar_repo_pgadmin && instalar_apt pgadmin4-web || aviso 'pgAdmin não pôde ser instalado neste Ubuntu.'
    fi
    if ! command -v mongodb-compass >/dev/null 2>&1 && ! apt_instalado mongodb-compass; then instalar_compass || aviso 'Não foi possível instalar MongoDB Compass.'; fi
    if ! command -v mysql-workbench-community >/dev/null 2>&1 && ! command -v mysql-workbench >/dev/null 2>&1; then
        instalar_snap_ou_apt mysql-workbench-community || true
    fi
}

instalar_compass() {
    local arch version deb
    case "$(dpkg --print-architecture)" in
        amd64) arch=amd64 ;;
        arm64) arch=arm64 ;;
        *) aviso 'MongoDB Compass não tem pacote .deb para esta arquitetura.'; return 1 ;;
    esac
    version="$(curl -fsSL https://api.github.com/repos/mongodb-js/compass/releases/latest | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([0-9][^"]*\)".*/\1/p' | head -n 1)"
    [[ -n "$version" ]] || { aviso 'Não foi possível descobrir a versão estável do MongoDB Compass.'; return 1; }
    deb="$(mktemp --suffix=.deb)" || return 1
    if curl -fsSL "https://downloads.mongodb.com/compass/mongodb-compass_${version}_${arch}.deb" -o "$deb"; then
        sudo apt-get install -y "$deb"
        local status=$?
        rm -f "$deb"
        return "$status"
    fi
    rm -f "$deb"
    return 1
}

instalar_codex() {
    command -v codex >/dev/null 2>&1 && return 0
    log 'Instalando Codex CLI pelo instalador oficial.'
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
}

instalar_github_cli() {
    if command -v gh >/dev/null 2>&1; then
        log "GitHub CLI já está instalado: $(gh --version | head -n 1)"
        return 0
    fi

    log 'Instalando GitHub CLI pelo repositório oficial.'
    local out status
    (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y
    status=$?
    [[ -n "${out:-}" ]] && rm -f "$out"
    return "$status"
}

instalar_kubernetes() {
    if ! command -v kubectl >/dev/null 2>&1; then instalar_snap_ou_apt kubectl true || true; fi
    if ! command -v minikube >/dev/null 2>&1; then instalar_snap_ou_apt minikube true || true; fi
    if ! command -v kompose >/dev/null 2>&1; then instalar_snap_ou_apt kompose false || true; fi
}

instalar_gcc() {
    if ! command -v gcc >/dev/null 2>&1; then
        sudo apt-get install -y gcc g++ build-essential
    fi
}

case "$MODULE" in
    tudo|all|sistema|conda|java|node|npm|linguagens|scala|dotnet|bancos|database|visuais|gui|codex|github|github-cli|gh|kubernetes|k8s|gcc|c) ;;
    *) aviso "Módulo desconhecido: $MODULE"; exit 2 ;;
esac

if ! command -v apt-get >/dev/null 2>&1; then
    aviso 'Este instalador requer Ubuntu/Debian com APT.'
    exit 1
fi

instalar_base

case "$MODULE" in
    tudo|all)
        instalar_conda
        instalar_java
        instalar_node
        instalar_linguagens
        instalar_bancos
        instalar_visuais
        instalar_codex
        instalar_github_cli
        instalar_kubernetes
        instalar_gcc
        ;;
    sistema) : ;; # A configuração base já foi instalada acima.
    conda) instalar_conda ;;
    java) instalar_java ;;
    node|npm) instalar_node ;;
    linguagens|scala|dotnet) instalar_linguagens ;;
    bancos|database) instalar_bancos ;;
    visuais|gui) instalar_visuais ;;
    codex) instalar_codex ;;
    github|github-cli|gh) instalar_github_cli ;;
    kubernetes|k8s) instalar_kubernetes ;;
    gcc|c) instalar_gcc ;;
    *) exit 2 ;;
esac
