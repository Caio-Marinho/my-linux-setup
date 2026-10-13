# Funções e ferramentas Bash

Esta pasta reúne scripts pessoais para abrir ferramentas de desenvolvimento, criar túneis, exportar ambientes Conda, consultar ajuda, instalar programas e atualizar o sistema.

## Arquivos

| Arquivo | Função |
| --- | --- |
| `.info.sh` | Define `info`, com instruções e comandos detalhados para instalação e atualização. |
| `.instalar.sh` | Instala ferramentas e dependências por módulo. É executado com `bash`. |
| `.atualizar.sh` | Atualiza sistema e ferramentas; quando um módulo necessário não está instalado, tenta instalá-lo com `.instalar.sh`. Define também `recarregar` e o alias `recarga`. |
| `.abrir-dev.sh` | Define `abrir` e `abrir-dev` para iniciar aplicativos de desenvolvimento, principalmente em WSL2. |
| `.tunnels.sh` | Define os comandos `tunnel` e `tunel` para operações de túnel. |
| `.export.sh` | Define `export-env` e o alias `exp` para exportar um ambiente Conda. |

## Carregar os comandos no Bash

Adicione estas linhas ao `~/.bashrc`:

```bash
source "$HOME/.bash_functions/.info.sh"
source "$HOME/.bash_functions/.atualizar.sh"
source "$HOME/.bash_functions/.abrir-dev.sh"
source "$HOME/.bash_functions/.tunnels.sh"
source "$HOME/.bash_functions/.export.sh"
```

Depois, carregue a configuração nesta sessão:

```bash
source ~/.bashrc
```

> `.instalar.sh` é um instalador executável, não uma biblioteca de funções. Use `bash ~/.bash_functions/.instalar.sh ...` para instalar; não é necessário carregá-lo com `source` no `.bashrc`.

## Ajuda

O comando `info` mostra a ajuda disponível:

```bash
info                 # menu geral
info instalar        # módulos e comandos originais de instalação
info atualizar       # etapas e comandos originais de atualização
```

## Instalar ferramentas

Execute o instalador com o módulo desejado:

```bash
bash ~/.bash_functions/.instalar.sh tudo
bash ~/.bash_functions/.instalar.sh sistema
bash ~/.bash_functions/.instalar.sh conda
bash ~/.bash_functions/.instalar.sh java
bash ~/.bash_functions/.instalar.sh node
bash ~/.bash_functions/.instalar.sh linguagens
bash ~/.bash_functions/.instalar.sh bancos
bash ~/.bash_functions/.instalar.sh visuais
bash ~/.bash_functions/.instalar.sh codex
bash ~/.bash_functions/.instalar.sh kubernetes
bash ~/.bash_functions/.instalar.sh gcc
```

O instalador reúne ferramentas de sistema, Conda/Miniforge, Java, Node.js, Scala, .NET, bancos de dados, aplicativos gráficos, Codex CLI, Kubernetes (`kubectl`, Minikube e Kompose) e compiladores C/C++. Consulte `info instalar` para ver os aliases aceitos e os comandos detalhados.

O script foi preparado para Ubuntu/WSL com Bash, APT, `sudo` e acesso à internet. Alguns módulos usam Snap ou repositórios oficiais dos fornecedores. A instalação de ferramentas não faz backup de arquivos, bancos de dados nem ambientes Conda de projetos.

## Atualizar

```bash
atualizar
```

O fluxo exibe dez etapas: sistema, Conda, Java, Node.js, Scala/.NET, bancos de dados, aplicativos gráficos, Codex CLI, Kubernetes e GCC. Para módulos ausentes, tenta chamar o instalador correspondente. Alguns comandos de sistema podem pedir a senha do `sudo`; o Conda pode pedir a aceitação interativa dos termos dos canais configurados. Veja `info atualizar` para a sequência e os comandos subjacentes.

Para recarregar as funções e aliases definidos nesta pasta:

```bash
recarregar
```

## Outros comandos

### Abrir aplicativos

Use `abrir` seguido da ferramenta desejada. Os nomes disponíveis dependem do script e dos aplicativos instalados; consulte `info` e o próprio `.abrir-dev.sh`.

### Túneis

O comando `tunnel tcp` usa Localtonet para expor o serviço TCP do banco de dados. O script lê o token do alias `tokenTunnel` definido no `~/.bashrc`; mantenha o valor configurado nesse arquivo e não publique o token.

```bash
tunnel tcp
tunnel tcp ngrok mysql
tunnel web
```

Para usar Ngrok, configure sua conta e autenticação manualmente conforme as instruções do Ngrok. `tunnel tcp ngrok mysql` inicia o túnel TCP da porta 3306; `tunnel web` inicia o túnel HTTP da porta 3000. O comando `tunnel tcp ngrok` sem `mysql` não é uma forma válida de iniciar o túnel.

Para usar Localtonet, instale/configure o cliente manualmente e defina o alias `tokenTunnel` no `~/.bashrc` com o token da sua conta. Depois, recarregue o shell (`source ~/.bashrc`). O token é uma credencial: não o compartilhe nem o coloque em arquivos públicos. `tunel` apresenta uma mensagem de orientação; os aliases `tcp` e `web` também mostram instruções de uso.

### Exportar ambiente Conda

```bash
export-env nome-do-ambiente
```

O arquivo `environment.yml` é criado no diretório atual e não inclui o caminho local do prefixo do ambiente. `exp` é um alias para `export-env`.

## Erro ao carregar o plugin `repo` do Conda

Se aparecer algo como:

```text
Error while loading conda entry point: repo
cannot import name 'CondaSubcommand' from 'conda.plugins'
```

o plugin opcional `conda-repo-cli` instalado no ambiente `base` está tentando importar uma interface que não está disponível nessa versão do Conda. Se você não usa os comandos `conda repo`, remova o plugin:

```bash
conda remove -n base conda-repo-cli
```

Se você usa `conda repo`, mantenha o plugin e instale uma versão compatível com a versão do Conda. O comando de remoção altera o ambiente `base`; use-o somente se não precisar desse plugin.
