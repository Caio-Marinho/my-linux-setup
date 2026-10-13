# ==============================================================================
# SISTEMA DE INICIALIZAÇÃO DE APLICATIVOS (WSL2)
# ==============================================================================
# Este arquivo centraliza a função 'abrir' para inicializar de forma seletiva
# e isolada as interfaces gráficas e painéis de desenvolvimento.
# ==============================================================================
# 1. LIMPEZA INICIAL
# 2. FUNÇÃO PRINCIPAL DE INICIALIZAÇÃO (Modularizada por ferramenta)
# ==============================================================================

# 1. LIMPEZA INICIAL
unalias abrir 2>/dev/null
unalias abrir-dev 2>/dev/null

# 2. FUNÇÃO PRINCIPAL DE INICIALIZAÇÃO
abrir() {
    local escolha=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    # Menu de ajuda caso o usuário não passe parâmetros ou digite incorretamente
    if [[ -z "$escolha" || "$escolha" == "help" || "$escolha" == "--help" ]]; then
        echo ""
        echo -e "\e[1;35m============================================================\e[0m"
        echo -e "\e[1;34m        🚀 GERENCIADOR DE INICIALIZAÇÃO DE APPS             \e[0m"
        echo -e "\e[1;35m============================================================\e[0m"
        echo ""
        echo -e "Uso: \e[1;32mabrir [ferramenta]\e[0m"
        echo ""
        echo -e "Opções válidas:"
        echo -e "  \e[1;32mtoolbox\e[0m  - Inicializa o JetBrains Toolbox"
        echo -e "  \e[1;32mmysql\e[0m    - Inicializa o MySQL Workbench"
        echo -e "  \e[1;32mmongo\e[0m    - Inicializa o MongoDB Compass"
        echo -e "  \e[1;32mpgadmin\e[0m   - Abre o painel do pgAdmin 4 no Navegador"
        echo -e "  \e[1;32mcode\e[0m      - Abre o Visual Studio Code"
        echo -e "  \e[1;32mvscode\e[0m    - Alias compatível para o VS Code"
        echo ""
        echo -e "\e[1;35m============================================================\e[0m"
        return 0
    fi

    echo ""
    echo -e "\e[1;35m============================================================\e[0m"
    echo -e "\e[1;34m               🔄 INICIALIZANDO FERRAMENTA                  \e[0m"
    echo -e "\e[1;35m============================================================\e[0m"
    echo ""

    case "$escolha" in
        "toolbox")
            echo -e "➡️ \e[1;32mJetBrains Toolbox\e[0m"
            echo -e "   \e[1;30mDisparando daemon gerenciador de IDEs da JetBrains (Logs ativos)...\e[0m"

            if [ -x ~/.local/bin/bin/jetbrains-toolbox ]; then
                # Primeiro avisa que deu certo...
                echo -e "   \e[1;32m✅ Executável disparado com sucesso.\e[0m"
                # ...e logo em seguida joga o processo na tela liberando o terminal
                ~/.local/bin/bin/jetbrains-toolbox &>/dev/null &
            else
                echo -e "   \e[1;31m[ERRO] Executável do JetBrains Toolbox não encontrado no caminho esperado.\e[0m"
            fi
            ;;

        "mysql")
            echo -e "➡️ \e[1;32mMySQL Workbench\e[0m"
            echo -e "   \e[1;30mIniciando a interface do Workbench (Snap/Nativo)...\e[0m"
            if command -v mysql-workbench-community >/dev/null 2>&1; then
                mysql-workbench-community &>/dev/null &
                echo -e "   \e[1;32m✅ Instância do Snap carregada.\e[0m"
            elif command -v mysql-workbench >/dev/null 2>&1; then
                mysql-workbench &>/dev/null &
                echo -e "   \e[1;32m✅ Instância Nativa carregada.\e[0m"
            else
                echo -e "   \e[1;31m[ERRO] MySQL Workbench não está instalado no sistema.\e[0m"
            fi
            ;;

        "mongo")
            echo -e "➡️ \e[1;32mMongoDB Compass\e[0m"
            echo -e "   \e[1;30mAplicando correções de GPU e subindo o Compass...\e[0m"
            if command -v mongodb-compass >/dev/null 2>&1; then
                mongodb-compass --no-sandbox --disable-gpu &>/dev/null &
                echo -e "   \e[1;32m✅ Sandbox desativada e processo isolado.\e[0m"
            else
                echo -e "   \e[1;31m[ERRO] MongoDB Compass não encontrado.\e[0m"
            fi
            ;;

        "pgadmin")
            echo -e "➡️ \e[1;32mpgAdmin 4 (Web Interno)\e[0m"
            if command -v firefox >/dev/null 2>&1; then
                firefox http://localhost/pgadmin4 &>/dev/null &
                echo -e "   \e[1;32m✅ PgAdmin iniciado. Abra o navegador em: http://localhost/pgadmin4\e[0m"
            else
                echo -e "   \e[1;31m[ERRO] Firefox não encontrado. Instale com: sudo apt install firefox\e[0m"
            fi
            ;;

        "code"|"vscode")
            echo -e "➡️ \e[1;32mVisual Studio Code\e[0m"
            echo -e "   \e[1;30mAbrindo o editor de código no ambiente gráfico...\e[0m"
            if command -v code >/dev/null 2>&1; then
                code &>/dev/null &
                echo -e "   \e[1;32m✅ VS Code aberto com sucesso.\e[0m"
            elif command -v codium >/dev/null 2>&1; then
                codium &>/dev/null &
                echo -e "   \e[1;32m✅ VSCodium aberto com sucesso.\e[0m"
            else
                echo -e "   \e[1;31m[ERRO] VS Code não encontrado. Instale com: sudo snap install code --classic\e[0m"
            fi
            ;;

        *)
            echo -e "   \e[1;31m❌ [OPÇÃO INVÁLIDA] Ferramenta '$1' desconhecida.\e[0m"
            echo -e "   Digite \e[1;32mabrir\e[0m sem parâmetros para consultar as opções válidas."
            ;;
    esac

    echo ""
    echo -e "\e[1;35m============================================================\e[0m"
}

abrir-dev() {
    abrir "$@"
}
