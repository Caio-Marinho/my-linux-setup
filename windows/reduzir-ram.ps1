param(
    [switch]$ListOnly,
    [switch]$Help
)

$ErrorActionPreference = 'SilentlyContinue'

function Show-Help {
    @'
Uso no Windows:
  powershell.exe -NoProfile -File .\reduzir-ram.ps1
  powershell.exe -NoProfile -File .\reduzir-ram.ps1 -ListOnly

O modo interativo lista os maiores processos e permite fechar janelas escolhidas
com um pedido normal de fechamento. Não encerra processos à força.
'@ | Write-Output
}

function Test-WindowsUpdateActive {
    $updateNames = @(
        'TiWorker', 'TrustedInstaller', 'MoUsoCoreWorker', 'UsoClient',
        'WindowsUpdateBox', 'wuauclt', 'MicrosoftEdgeUpdate', 'msedgeupdate'
    )
    $active = @(Get-Process | Where-Object { $updateNames -contains $_.ProcessName })
    if ($active.Count -gt 0) { return $true }

    $officeUpdate = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(OfficeC2RClient|OfficeClickToRun)\.exe$' -and
        $_.CommandLine -match '(?i)(scenario=update|/update|\bupdate\b)'
    })
    return ($officeUpdate.Count -gt 0)
}

function Get-ProcessRows {
    param([bool]$UpdateActive)

    $protectedNames = @(
        'System', 'Idle', 'Registry', 'Memory Compression', 'smss', 'csrss',
        'wininit', 'services', 'lsass', 'winlogon', 'dwm', 'explorer', 'sihost',
        'StartMenuExperienceHost', 'ShellExperienceHost', 'RuntimeBroker',
        'SearchHost', 'MsMpEng', 'SecurityHealthService', 'audiodg',
        'OfficeClickToRun', 'TrustedInstaller', 'TiWorker', 'MoUsoCoreWorker',
        'UsoClient', 'WindowsUpdateBox', 'wuauclt', 'MicrosoftEdgeUpdate',
        'msedgeupdate'
    )
    $microsoftNames = @(
        'Code', 'Code - Insiders', 'msedge', 'MicrosoftEdge', 'Teams',
        'ms-teams', 'OneDrive', 'Outlook', 'WINWORD', 'EXCEL', 'POWERPNT',
        'MSPCManager'
    )
    $sessionId = (Get-Process -Id $PID).SessionId

    foreach ($process in @(Get-Process | Sort-Object WorkingSet64 -Descending)) {
        if ($process.Id -eq $PID) { continue }

        $company = ''
        try {
            if ($process.Path) {
                $company = (Get-Item -LiteralPath $process.Path -ErrorAction Stop).VersionInfo.CompanyName
            }
        } catch { }

        $isMicrosoft = ($company -match '(?i)microsoft') -or ($microsoftNames -contains $process.ProcessName)
        $reason = ''
        if ($protectedNames -contains $process.ProcessName) {
            $reason = 'protegido: Windows, segurança ou serviço'
        } elseif ($process.ProcessName -eq 'vmmemWSL') {
            $reason = 'VM do WSL; fechar exige desligar todas as distros'
        } elseif ($UpdateActive -and $isMicrosoft) {
            $reason = 'Microsoft protegido durante atualização'
        } elseif ($process.SessionId -ne $sessionId) {
            $reason = 'outra sessão do Windows'
        } elseif ($process.MainWindowHandle -eq 0) {
            $reason = 'sem janela; encerramento normal indisponível'
        } else {
            $reason = 'pode fechar com solicitação normal'
        }

        [pscustomobject]@{
            Process       = $process
            Name          = $process.ProcessName
            Id            = $process.Id
            RAM_MiB       = [math]::Round($process.WorkingSet64 / 1MB, 1)
            Vendor        = $company
            IsMicrosoft   = $isMicrosoft
            HasWindow     = ($process.MainWindowHandle -ne 0)
            Selectable    = ($reason -eq 'pode fechar com solicitação normal')
            Reason        = $reason
        }
    }
}

function Show-MemoryReport {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGiB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGiB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    Write-Host ("Memória física do Windows: {0} GiB total; {1} GiB disponível." -f $totalGiB, $freeGiB)

    $updateActive = Test-WindowsUpdateActive
    if ($updateActive) {
        Write-Host 'Atualização do Windows/Microsoft detectada: processos Microsoft serão protegidos.'
    } else {
        Write-Host 'Nenhuma atualização do Windows/Microsoft foi detectada neste momento.'
    }

    $rows = @(Get-ProcessRows -UpdateActive $updateActive | Sort-Object RAM_MiB -Descending)
    Write-Host "`nMaiores processos (MiB de RAM):"
    Write-Host ($rows | Select-Object -First 25 Name, Id, RAM_MiB, Vendor, Reason | Format-Table -Wrap -AutoSize | Out-String -Width 180)
    return $rows
}

if ($Help) {
    Show-Help
    exit 0
}

if ($ListOnly) {
    Show-MemoryReport | Out-Null
    exit 0
}

while ($true) {
    $rows = @(Show-MemoryReport)
    $choice = Read-Host "Digite o PID de uma janela para pedir fechamento normal, ou q para sair"
    if ($choice -match '^(q|quit|sair)$') { break }
    if ($choice -notmatch '^\d+$') {
        Write-Output 'PID inválido.'
        continue
    }

    $target = $rows | Where-Object { $_.Id -eq [int]$choice } | Select-Object -First 1
    if (-not $target) {
        Write-Output 'PID não encontrado na lista atual; atualize a lista e tente novamente.'
        continue
    }
    if (-not $target.Selectable) {
        Write-Output ("PID {0} não pode ser fechado por este script: {1}." -f $target.Id, $target.Reason)
        continue
    }

    $confirm = Read-Host ("Fechar {0} (PID {1}, {2} MiB)? Salve seu trabalho antes [s/N]" -f $target.Name, $target.Id, $target.RAM_MiB)
    if ($confirm -notmatch '^(s|sim)$') { continue }

    try {
        $current = Get-Process -Id $target.Id -ErrorAction Stop
        if ($current.StartTime -ne $target.Process.StartTime) {
            Write-Output 'O PID foi reutilizado; nenhuma ação foi feita.'
            continue
        }
        if (-not $current.CloseMainWindow()) {
            Write-Output 'O aplicativo não aceitou o pedido de fechamento normal; nenhum encerramento forçado foi feito.'
            continue
        }
        if (-not $current.WaitForExit(8000)) {
            Write-Output 'O aplicativo continua aberto. Feche-o pela própria janela; o script não vai forçá-lo.'
        } else {
            Write-Output 'Janela fechada normalmente.'
        }
    } catch {
        Write-Output 'O processo encerrou ou mudou antes de receber o pedido.'
    }
}
