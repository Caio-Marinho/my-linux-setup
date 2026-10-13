# ==============================================================================
# SISTEMA DE TÚNEIS LOCALTONET E NGROK (WSL2)
# ==============================================================================
# Este arquivo centraliza a função 'tunnel' para abrir túneis TCP e HTTP.
# ==============================================================================
# 1. LIMPEZA INICIAL
# 2. FUNÇÃO PRINCIPAL DE TÚNEL
# 3. ALIASES DE REDIRECIONAMENTO
# ==============================================================================

# 1. LIMPEZA INICIAL
unalias tcp 2>/dev/null
unalias tunnel 2>/dev/null
unalias web 2>/dev/null
unalias tunel 2>/dev/null

# ==============================================================================
# FUNÇÃO INTELIGENTE DO CLIENTE DE TUNELAMENTO (ESTRUTURA IF / ELSE IF MULTI-ARGUMENTO)
# ==============================================================================
tunnel() {
    echo -e "   💡 Dica: use \e[1;36mtunnel tcp\e[0m para bancos e \e[1;36mtunnel web\e[0m para aplicações HTTP."

    # [IF]: Caso a primeira posição do array ($1) seja rigorosamente "tcp"
    if [ "$1" = "tcp" ]; then

        # [ARRAY POSIÇÃO 2]: Checa se você adicionou o espaço e a palavra "ngrok"
        if [ "$2" = "ngrok" ]; then

            # [ARRAY POSIÇÃO 3]: Se o terceiro argumento for "mysql", força o fluxo via ngrok
            if [ -n "${3:-}" ]; then
                if [ "$3" = "mysql" ]; then
                    echo -e "🔄 \e[1;33m[ngrok] Iniciando túnel TCP para o MySQL (Porta 3306)...\e[0m"
                    sleep 1
                    ngrok tcp 3306
                else
                    echo -e "❌ Valor inválido para o terceiro argumento."
                    echo -e "💡 Use: \e[1;33mtunnel tcp ngrok mysql\e[0m"
                    return 1
                fi
            else
                echo -e "❌ Valor inválido para o terceiro argumento."
                echo -e "💡 Use: \e[1;33mtunnel tcp ngrok mysql\e[0m"
                return 1
            fi

        # Caso a segunda posição do array esteja vazia, executa o Localtonet padrão
        else
            echo -e "🔄 \e[1;32m[Localtonet] Iniciando no modo [TCP] para Banco de Dados...\e[0m"
            sleep 1
            # tokenTunnel é definido como alias no ~/.bashrc. Alias não expande
            # dentro dos argumentos de uma função, então extraímos seu valor.
            localtonet_alias="$(alias tokenTunnel 2>/dev/null)"
            localtonet_token="${localtonet_alias#*=}"
            localtonet_token="${localtonet_token#\'}"
            localtonet_token="${localtonet_token%\'}"
            if [ -z "$localtonet_alias" ] || [ -z "$localtonet_token" ]; then
                echo -e "❌ Alias tokenTunnel não encontrado ou vazio. Configure-o no ~/.bashrc e recarregue o Bash."
                return 1
            fi
            ~/localtonet/localtonet --authtoken "$localtonet_token"
        fi

    # [ELSE IF]: Caso a primeira posição do array ($1) seja rigorosamente "web"
    elif [ "$1" = "web" ]; then
        echo -e "🔄 \e[1;36m[ngrok] Iniciando túnel HTTP para Servidores Web (Porta 3000)...\e[0m"
        sleep 1
        ngrok http 3000 --url https://default.internal

    # [ELSE]: Caso o comando seja chamado sem parâmetros válidos no array
    else
        echo -e "❌ Parâmetro inválido ou ausente na lista!"
        echo -e "💡 Uso correto:"
        echo -e "   -> \e[1;32mtunel tcp\e[0m          (Abre o MySQL via Localtonet)"
        echo -e "   -> \e[1;33mtunel tcp ngrok mysql\e[0m (Abre o MySQL via ngrok)"
        echo -e "   -> \e[1;36mtunel web\e[0m          (Abre o servidor Web via ngrok)"
        echo -e "📘 Dica extra: mantenha o serviço local rodando antes de expor a porta."
    fi
}

tunel() {
    echo -e "❌ Comando incorreto: \e[1;33mtunel\e[0m"
    echo -e "💡 Use: \e[1;36mtunnel tcp\e[0m, \e[1;36mtunnel tcp ngrok mysql\e[0m ou \e[1;36mtunnel web\e[0m"
    echo -e "📘 Para ajuda, execute: \e[1;36minfo tcp\e[0m ou \e[1;36minfo web\e[0m"
    return 1
}

# ==============================================================================
# 3. ALIASES DE REDIRECIONAMENTO
# ==============================================================================
alias tcp='echo "❌ Comando incorreto! Digite: info"'
alias web='echo "❌ Comando incorreto! Digite: info"'
