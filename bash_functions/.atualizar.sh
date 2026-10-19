# ==============================================================================
# SISTEMA DE MANUTENÇÃO E ATUALIZAÇÃO (WSL2)
# ==============================================================================
# Este arquivo centraliza as funções 'recarregar' e 'atualizar' para
# recarregar o shell e executar a manutenção do sistema.
# ==============================================================================
# 1. LIMPEZA INICIAL
# 2. FUNÇÃO DE RECARREGAMENTO DO SHELL
# 3. FUNÇÃO PRINCIPAL DE ATUALIZAÇÃO (Modularizada para eficiência)
# ==============================================================================

# 1. LIMPEZA INICIAL
unalias recarregar 2>/dev/null
unalias recarga 2>/dev/null
unalias atualizar 2>/dev/null

# 2. FUNÇÃO PARA RECARREGAR O SHELL
recarregar() {
    echo ""
    echo -e "\e[1;35m============================================================\e[0m"
    echo -e "\e[1;34m     🔄 RECARREGANDO AS CONFIGURAÇÕES DO SHELL      \e[0m"
    echo -e "\e[1;35m============================================================\e[0m"
    echo ""
    source ~/.bashrc
    echo ""
    echo -e "\e[1;32m✅ Configurações do shell recarregadas com sucesso!\e[0m"
    echo ""
}

# Instala sob demanda o módulo que faltar durante a atualização.
_atualizar_instalar_modulo() {
    local script_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/.instalar.sh" ]]; then
        bash "$script_dir/.instalar.sh" "$1"
    else
        echo -e "   \e[1;33m[AVISO] Instalador não encontrado: $script_dir/.instalar.sh\e[0m"
        return 1
    fi
}

# 3. FUNÇÃO PRINCIPAL DE ATUALIZAÇÃO
atualizar() {
    local conda_prefix
    echo ""
    echo -e "\e[1;35m============================================================\e[0m"
    echo -e "\e[1;34m    🔄 INICIANDO MANUTENÇÃO CRÍTICA DO SISTEMA (10 ETAPAS)   \e[0m"
    echo -e "\e[1;35m============================================================\e[0m"
    echo ""

    echo -e "   \e[1;30mEste fluxo é seguro de repetir e foi pensado para manter o ambiente atualizado sem apagar dados.\e[0m"
    echo ""

    # ETAPA 1: Sistema (APT e Snaps)
    echo -e "➡️ \e[1;32m[1/10] Sistema (APT & Snap)\e[0m"
    echo -e "   \e[1;30mAtualizando repositórios, pacotes do sistema e pacotes Snap...\e[0m"
    if ! command -v snap >/dev/null 2>&1; then _atualizar_instalar_modulo sistema || true; fi
    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean
    # Atualiza o GitHub CLI pelo repositório oficial.
    if ! command -v gh >/dev/null 2>&1; then
        _atualizar_instalar_modulo gh || true
    fi
    if dpkg-query -W -f='${db:Status-Status}' gh 2>/dev/null | grep -q installed; then
        echo -e "   \e[1;30mAtualizando GitHub CLI via APT...\e[0m"
        sudo apt install -y --only-upgrade gh || echo -e "   \e[1;33m[AVISO] Não foi possível atualizar o GitHub CLI.\e[0m"
    elif command -v gh >/dev/null 2>&1; then
        echo -e "   \e[1;30mGitHub CLI encontrado fora do APT; atualização automática ignorada.\e[0m"
    else
        echo -e "   \e[1;33m[AVISO] GitHub CLI não encontrado.\e[0m"
    fi
    if command -v snap >/dev/null 2>&1; then
        sudo snap refresh
    fi
    echo ""

    # ETAPA 2: Python no Conda
    echo -e "➡️ \e[1;32m[2/10] Python / Conda\e[0m"
    if ! command -v conda >/dev/null 2>&1; then
        echo -e "   \e[1;30mConda ausente; instalando o módulo...\e[0m"
        _atualizar_instalar_modulo conda || true
        conda_prefix="${CONDA_PREFIX_BASE:-$HOME/miniforge3}"
        if [[ -f "$conda_prefix/etc/profile.d/conda.sh" ]]; then
            source "$conda_prefix/etc/profile.d/conda.sh"
        fi
    fi
    if command -v conda >/dev/null 2>&1; then
        echo -e "   \e[1;30mAtualizando ambientes Python...\e[0m"
        if conda update --all -y; then
            conda clean --all -y
        elif [[ -t 0 ]]; then
            echo -e "   \e[1;33mA atualização do Conda falhou. Se o erro indicar termos pendentes, aceite os termos dos canais Anaconda? [s/N]\e[0m"
            read -r aceitar_conda_tos
            if [[ "$aceitar_conda_tos" =~ ^[sS]$ ]]; then
                conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
                conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
                conda update --all -y && conda clean --all -y
            else
                echo -e "   \e[1;33m[AVISO] Conda ignorado. Para aceitar os termos depois, execute os comandos 'conda tos accept' informados pelo Conda.\e[0m"
            fi
        else
            echo -e "   \e[1;33m[AVISO] Atualização do Conda falhou. Execute 'atualizar' em um terminal interativo para resolver uma eventual aceitação de termos.\e[0m"
        fi
    else
        echo -e "   \e[1;33m[AVISO] Conda não encontrado. Pulando.\e[0m"
    fi
    echo ""

    # ETAPA 3: Java
    echo -e "➡️ \e[1;32m[3/10] Java\e[0m"
    echo -e "   \e[1;30mAtualizando JDKs instalados e dependências Java...\e[0m"
    if ! command -v javac >/dev/null 2>&1; then _atualizar_instalar_modulo java || true; fi
    sudo apt install -y --only-upgrade openjdk-21-jdk 2>/dev/null || true
    echo ""

    # ETAPA 4: Node.js (NPM)
    echo -e "➡️ \e[1;32m[4/10] Node.js (NPM)\e[0m"
    if ! command -v npm >/dev/null 2>&1; then _atualizar_instalar_modulo node || true; fi
    if command -v npm >/dev/null 2>&1; then
        echo -e "   \e[1;30mAtualizando Node.js, pacotes globais e cache do NPM...\e[0m"
        npm install -g npm@latest 2>/dev/null || true
        npm -g update 2>/dev/null || true
        npm cache clean --force 2>/dev/null || true
    else
        echo -e "   \e[1;33m[AVISO] NPM não encontrado. Pulando.\e[0m"
    fi
    echo ""

    # ETAPA 5: Scala e C#
    echo -e "➡️ \e[1;32m[5/10] Scala e C#\e[0m"
    echo -e "   \e[1;30mVerificando atualizações de Scala, .NET e ferramentas auxiliares...\e[0m"
    if ! command -v dotnet >/dev/null 2>&1 || { ! command -v cs >/dev/null 2>&1 && ! command -v coursier >/dev/null 2>&1; }; then
        _atualizar_instalar_modulo linguagens || true
        export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$HOME/.local/bin:$HOME/.local/share/coursier/bin:$PATH"
        if [[ -x "$HOME/.dotnet/dotnet" ]]; then export DOTNET_ROOT="$HOME/.dotnet"; fi
    fi
    dotnet tool update -g dotnet-repl 2>/dev/null || true
    coursier update scala 2>/dev/null || true
    echo ""

    # ETAPA 6: Bancos de Dados (MySQL, PostgreSQL e MongoDB)
    echo -e "➡️ \e[1;32m[6/10] Bancos de Dados\e[0m"
    echo -e "   \e[1;30mAplicando upgrades para MySQL, PostgreSQL e MongoDB...\e[0m"
    if ! command -v mysql >/dev/null 2>&1 || ! command -v psql >/dev/null 2>&1 || ! command -v mongod >/dev/null 2>&1; then
        _atualizar_instalar_modulo bancos || true
    fi
    sudo apt install -y --only-upgrade mysql-server postgresql mongodb-org 2>/dev/null || true
    echo ""

    # ETAPA 7: Ferramentas visuais e interfaces
    echo -e "➡️ \e[1;32m[7/10] Ferramentas Visuais\e[0m"
    echo -e "   \e[1;30mAtualizando ferramentas gráficas como MySQL Workbench, pgAdmin, MongoDB Compass...\e[0m"
    if ! command -v mongodb-compass >/dev/null 2>&1 || ! dpkg-query -W -f='${db:Status-Status}' pgadmin4-web 2>/dev/null | grep -q installed || { ! command -v mysql-workbench-community >/dev/null 2>&1 && ! command -v mysql-workbench >/dev/null 2>&1; }; then
        _atualizar_instalar_modulo visuais || true
    fi
    sudo apt install -y --only-upgrade pgadmin4-web mongodb-compass 2>/dev/null || true
    if command -v snap >/dev/null 2>&1 && snap list mysql-workbench-community >/dev/null 2>&1; then
        sudo snap refresh mysql-workbench-community
    fi
    echo ""

    # ETAPA 8: Codex
    echo -e "➡️ \e[1;32m[8/10] Codex CLI\e[0m"

    if ! command -v codex >/dev/null 2>&1; then
        _atualizar_instalar_modulo codex || true
        export PATH="$HOME/.local/bin:$PATH"
    fi
    if command -v codex >/dev/null 2>&1; then
        echo -e "   \e[1;30mAtualizando Codex CLI...\e[0m"
        codex update || echo -e "   \e[1;33m[AVISO] Não foi possível atualizar o Codex.\e[0m"
    else
        echo -e "   \e[1;30mCodex CLI não instalado. Pulando atualização.\e[0m"
    fi

    echo ""

    # ETAPA 9: Kubernetes, Minikube e Kompose
    echo -e "➡️ \e[1;32m[9/10] Kubernetes (kubectl, Minikube e Kompose)\e[0m"
    if ! command -v kubectl >/dev/null 2>&1 || ! command -v minikube >/dev/null 2>&1 || ! command -v kompose >/dev/null 2>&1; then
        _atualizar_instalar_modulo kubernetes || true
    fi
    if command -v snap >/dev/null 2>&1 && snap list kubectl >/dev/null 2>&1; then
        echo -e "   \e[1;30mAtualizando kubectl via Snap...\e[0m"
        sudo snap refresh kubectl
    elif dpkg-query -W -f='${db:Status-Status}' kubectl 2>/dev/null | grep -q installed; then
        echo -e "   \e[1;30mAtualizando kubectl via APT...\e[0m"
        sudo apt install -y --only-upgrade kubectl
    elif command -v kubectl >/dev/null 2>&1; then
        echo -e "   \e[1;30mkubectl encontrado fora do APT/Snap; atualização automática ignorada.\e[0m"
    else
        echo -e "   \e[1;30mkubectl não instalado. Pulando atualização.\e[0m"
    fi
    if command -v snap >/dev/null 2>&1 && snap list minikube >/dev/null 2>&1; then
        echo -e "   \e[1;30mAtualizando Minikube via Snap...\e[0m"
        sudo snap refresh minikube
    elif dpkg-query -W -f='${db:Status-Status}' minikube 2>/dev/null | grep -q installed; then
        echo -e "   \e[1;30mAtualizando Minikube via APT...\e[0m"
        sudo apt install -y --only-upgrade minikube
    elif command -v minikube >/dev/null 2>&1; then
        echo -e "   \e[1;30mMinikube encontrado fora do APT/Snap; atualização automática ignorada.\e[0m"
    fi

    if command -v snap >/dev/null 2>&1 && snap list kompose >/dev/null 2>&1; then
        echo -e "   \e[1;30mAtualizando Kompose via Snap...\e[0m"
        sudo snap refresh kompose
    elif dpkg-query -W -f='${db:Status-Status}' kompose 2>/dev/null | grep -q installed; then
        echo -e "   \e[1;30mAtualizando Kompose via APT...\e[0m"
        sudo apt install -y --only-upgrade kompose
    elif command -v kompose >/dev/null 2>&1; then
        echo -e "   \e[1;30mKompose encontrado fora do APT/Snap; atualização automática ignorada.\e[0m"
    else
        echo -e "   \e[1;30mKompose não instalado. Pulando atualização.\e[0m"
    fi

    echo ""

    # ETAPA 10: GCC para C e C++
    echo -e "➡️ \e[1;32m[10/10] GCC (C e C++)\e[0m"
    if ! command -v gcc >/dev/null 2>&1; then _atualizar_instalar_modulo gcc || true; fi
    if dpkg-query -W -f='${db:Status-Status}' gcc 2>/dev/null | grep -q installed; then
        echo -e "   \e[1;30mAtualizando GCC e G++ via APT...\e[0m"
        sudo apt install -y --only-upgrade gcc g++
    elif command -v gcc >/dev/null 2>&1; then
        echo -e "   \e[1;30mGCC encontrado fora do APT; atualização automática ignorada.\e[0m"
    else
        echo -e "   \e[1;33m[AVISO] GCC não encontrado. Pulando.\e[0m"
    fi
    echo ""

    # Conclusão
    echo -e "\e[1;35m============================================================\e[0m"
    echo -e "\e[1;32m    ✅ SISTEMA 100% ATUALIZADO E PRONTO PARA USO!    \e[0m"
    echo -e "\e[1;35m============================================================\e[0m"

    recarregar
}

# ALIAS DE ATALHO / CORREÇÃO
alias recarga='echo -e "❌ \e[1;31mComando incorreto! Digite:\e[0m \e[1;32mrecarregar\e[0m"'
