#!/usr/bin/env bash
# Lista consumidores de RAM e permite encerrar aplicativos do usuário
# de forma interativa. Não desinstala, não usa sudo e nunca envia SIGKILL.

_ram_ajuda() {
    cat <<'EOF'
Uso:
  reduzir-ram          Mostra o uso de memória e oferece encerramento seletivo.
  reduzir-ram --listar Mostra os maiores processos do WSL e do Windows.
  reduzir-ram --windows Abre apenas o relatório/controle do Windows hospedeiro.
  reduzir-ram --wsl     Limita o relatório/controle à sessão Linux.
  reduzir-ram --ajuda  Mostra esta ajuda.

O encerramento é feito com SIGTERM após escolher um PID. Processos do sistema,
esta sessão de shell e processos Microsoft durante atualização são protegidos.
EOF
}

_ram_atualizacao_ativa() {
    local proc comm cmd lower
    for proc in /proc/[0-9]*; do
        [[ -r "$proc/comm" && -r "$proc/cmdline" ]] || continue
        comm="$(<"$proc/comm")"
        cmd="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null)"
        lower="${comm,,} ${cmd,,}"
        case "$lower" in
            *microsoftedgeupdate*|*msedgeupdate*|*code-updater*) return 0 ;;
            *apt-get\ *upgrade*|*apt\ *upgrade*|*apt-get\ *install*|*apt\ *install*|*dist-upgrade*|*full-upgrade*) return 0 ;;
            *dpkg\ *--configure*|*dpkg\ *--unpack*|*dpkg\ *--install*) return 0 ;;
            *snap\ refresh*|*snap\ install*|*snap\ update*) return 0 ;;
        esac
    done
    return 1
}

_ram_e_microsoft() {
    case "${1,,}" in
        code|code-insiders|msedge|msedge_*|microsoft-edge|microsoftedgeupdate|msedgeupdate|teams|ms-teams)
            return 0 ;;
        *) return 1 ;;
    esac
}

_ram_processo_protegido() {
    case "${1,,}" in
        systemd|init|bash|sh|dash|zsh|fish|sshd|dbus-daemon|gnome-shell|kwin_wayland|xorg|xwayland|weston|pipewire|wireplumber|pulseaudio|networkmanager|snapd|apt|apt-get|dpkg|unattended-upgr|codex)
            return 0 ;;
        *) return 1 ;;
    esac
}

_ram_mostrar() {
    printf '\nUso atual de memória:\n'
    free -h
    printf '\nMaiores processos por RAM (RSS em KiB):\n'
    ps -eo pid,user,comm,%mem,rss --sort=-rss | head -n 16
}

_ram_interativo() {
    local update_active=0 pid ppid uid comm rss choice answer parent
    local -A ancestors=()

    _ram_mostrar
    if _ram_atualizacao_ativa; then
        update_active=1
        printf '\nAtualização em andamento detectada; processos Microsoft ficarão protegidos.\n'
    else
        printf '\nNenhuma atualização Microsoft/sistema foi detectada.\n'
    fi

    # Não permitir que a função encerre este shell, o próprio script ou um ancestral.
    parent="$$"
    while [[ "$parent" =~ ^[0-9]+$ ]] && (( parent > 1 )); do
        ancestors["$parent"]=1
        parent="$(ps -o ppid= -p "$parent" 2>/dev/null | tr -d ' ')"
    done

    printf '\nProcessos do seu usuário com pelo menos 100 MiB de RAM:\n'
    printf '%-8s %-9s %-24s %-10s %s\n' 'PID' 'MiB' 'PROCESSO' 'TIPO' 'AÇÃO'
    while read -r pid ppid uid comm rss; do
        [[ "$uid" == "$EUID" ]] || continue
        (( rss >= 102400 )) || continue
        [[ -z "${ancestors[$pid]+x}" ]] || continue
        _ram_processo_protegido "$comm" && continue
        if _ram_e_microsoft "$comm"; then
            if (( update_active )); then
                printf '%-8s %-9s %-24.24s %-10s %s\n' "$pid" "$((rss / 1024))" "$comm" 'Microsoft' 'protegido: atualização ativa'
                continue
            fi
            printf '%-8s %-9s %-24.24s %-10s %s\n' "$pid" "$((rss / 1024))" "$comm" 'Microsoft' 'pode encerrar'
        else
            printf '%-8s %-9s %-24.24s %-10s %s\n' "$pid" "$((rss / 1024))" "$comm" 'usuário' 'pode encerrar'
        fi
    done < <(ps -eo pid=,ppid=,uid=,comm=,rss= --sort=-rss)

    while :; do
        printf '\nDigite o PID de um processo para pedir encerramento, ou q para sair: '
        IFS= read -r choice || return 0
        [[ "$choice" == q || "$choice" == Q ]] && return 0
        [[ "$choice" =~ ^[0-9]+$ ]] || { printf 'PID inválido.\n'; continue; }
        pid="$choice"

        read -r uid comm rss < <(ps -o uid=,comm=,rss= -p "$pid" 2>/dev/null) || {
            printf 'O processo %s não está mais em execução.\n' "$pid"
            continue
        }
        [[ "$uid" == "$EUID" ]] || { printf 'Por segurança, só é possível encerrar processos do seu usuário.\n'; continue; }
        [[ -z "${ancestors[$pid]+x}" ]] || { printf 'Esse processo pertence à sessão atual e está protegido.\n'; continue; }
        _ram_processo_protegido "$comm" && { printf 'Esse processo essencial está protegido.\n'; continue; }
        if (( update_active )) && _ram_e_microsoft "$comm"; then
            printf 'Processo Microsoft protegido enquanto a atualização estiver ativa.\n'
            continue
        fi
        (( rss >= 102400 )) || { printf 'O processo está abaixo do limite de 100 MiB.\n'; continue; }

        printf 'Enviar SIGTERM para %s (PID %s, %s MiB)? Feche/salve seu trabalho antes. [s/N] ' \
            "$comm" "$pid" "$((rss / 1024))"
        IFS= read -r answer || return 0
        [[ "$answer" == s || "$answer" == S ]] || continue
        if kill -TERM "$pid" 2>/dev/null; then
            printf 'Solicitado encerramento normal. Nenhum encerramento forçado será feito.\n'
            sleep 2
            kill -0 "$pid" 2>/dev/null && printf 'O processo continua ativo; feche-o pelo próprio aplicativo se necessário.\n'
            _ram_mostrar
        else
            printf 'Não foi possível enviar SIGTERM para esse processo.\n'
        fi
    done
}

_ram_windows() {
    local script="$HOME/projetos/my-linux-setup/windows/reduzir-ram.ps1"
    local script_windows

    if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
        printf 'PowerShell/interop do Windows não está disponível nesta sessão.\n'
        return 1
    fi
    if [[ ! -f "$script" ]]; then
        printf 'Complemento Windows não encontrado: %s\n' "$script"
        return 1
    fi

    script_windows="$(wslpath -w "$script" 2>/dev/null | tr -d '\r')"
    if [[ "${1:-}" == --listar ]]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script_windows" -ListOnly
    else
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script_windows"
    fi
}

reduzir_ram() {
    case "${1:-}" in
        --ajuda|-h|--help)
            _ram_ajuda
            printf '\nNo WSL, --windows abre o controle do Windows; --wsl limita a sessão Linux.\n'
            ;;
        --listar|-l)
            _ram_mostrar
            printf '\n'
            _ram_windows --listar
            ;;
        --wsl) _ram_interativo ;;
        --windows) _ram_windows ;;
        "")
            _ram_interativo
            printf '\n===== Windows hospedeiro =====\n'
            _ram_windows
            ;;
        *) _ram_ajuda; return 2 ;;
    esac
}

alias reduzir-ram='reduzir_ram'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    reduzir_ram "$@"
fi
