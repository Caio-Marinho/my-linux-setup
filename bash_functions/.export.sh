# ==============================================================================
# FUNÇÃO DE EXPORTAÇÃO NO CONDA
# ==============================================================================
# Este arquivo centraliza a função 'export-env' para exportar ambientes do Conda.
# ==============================================================================
# 1. LIMPEZA INICIAL
# 2. FUNÇÃO PRINCIPAL DE EXPORTAÇÃO
# 3. ALIASES DE REDIRECIONAMENTO
# ==============================================================================

# 1. LIMPEZA INICIAL
unalias export-env 2>/dev/null
unalias exp 2>/dev/null

# ==============================================================================
# FUNÇÃO INTELIGENTE DE EXPORTAÇÃO DO CONDA (ESTRUTURA IF / ELSE IF MULTI-ARGUMENTO)
# ==============================================================================
export-env() {
    echo -e " 💡 Dica: passe o nome do ambiente como argumento, ex: \e[1;36mexport-env <nome-do-ambiente>\e[0m"

    # [IF]: Caso o primeiro argumento ($1) tenha sido preenchido
    if [ -n "${1:-}" ]; then
        echo -e "🔄 \e[1;32m[Conda] Inicializando o ambiente e exportando '$1'...\e[0m"
        sleep 1

        # Garante que o hook do conda está disponível dentro da função
        eval "$(conda shell.bash hook)"

        # Executa a exportação filtrando as linhas de prefixo
        conda env export --name "$1" --no-builds | grep -v "^prefix:" > environment.yml

        echo -e "✨ \e[1;32mAmbiente exportado com sucesso para 'environment.yml'!\e[0m"

    # [ELSE]: Caso o comando seja chamado sem parâmetros válidos
    else
        echo -e "❌ Nome do ambiente ausente na lista!"
        echo -e "💡 Uso correto:"
        echo -e "   -> \e[1;32mexport-env <nome-do-ambiente>\e[0m (Exporta o ambiente especificado)"
        echo -e "📘 Exemplo: \e[1;36mexport-env Back-Cadastro-InteresseIntercambio\e[0m"
        return 1
    fi
}

# ==============================================================================
# 3. ALIASES DE REDIRECIONAMENTO
# ==============================================================================
alias exp='echo "❌ Comando incorreto! Use: export-env <nome-do-ambiente>"'
