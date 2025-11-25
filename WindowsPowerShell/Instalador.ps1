# ============================================================
# SCRIPT DE INSTALAÇÃO AUTOMÁTICA - PORTBASH
# ============================================================

# 1. Detecta onde esta pasta está salva NESTE computador agora
$caminhoAtual = $PSScriptRoot
$caminhoModulo = "$caminhoAtual\Modules\PortBash"

Write-Host "Instalando PortBash..." -ForegroundColor Cyan
Write-Host "Caminho detectado: $caminhoModulo" -ForegroundColor Gray

# Verifica se a pasta do módulo realmente existe
if (-not (Test-Path $caminhoModulo)) {
    Write-Host "ERRO: Pasta 'Modules\PortBash' não encontrada!" -ForegroundColor Red
    Write-Host "Certifique-se de rodar este arquivo de dentro da pasta extraída."
    Pause
    Exit
}

# 2. Verifica/Cria o arquivo de perfil do PowerShell do usuário
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -Type File -Force | Out-Null
    Write-Host "Perfil do PowerShell criado." -ForegroundColor Green
}

# 3. O conteúdo que será injetado no perfil
# Note: Usamos crase (`) antes de $ para variáveis que devem ser literais no arquivo final
# A variável $caminhoModulo (sem crase) será substituída pelo valor real agora.
$configuracao = @"

# --- INICIO CONFIGURAÇÃO PORTBASH ---
`$pastaRaiz = "$caminhoModulo"
`$caminhoBanco = "`$pastaRaiz\banco_comandos.json"
`$caminhoGerenciador = "`$pastaRaiz\Gerenciador.ps1"
 
if (Test-Path `$caminhoBanco) {
    `$comandos = Get-Content `$caminhoBanco -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach (`$cmd in `$comandos) {
        Set-Alias -Name `$cmd.Apelido -Value `$cmd.Original -Scope Global -ErrorAction SilentlyContinue
    }
}
 
function portbash {
    & `$caminhoGerenciador
}
 
Write-Host "PowerShell traduzido ativo!" -ForegroundColor Cyan
Write-Host "Dica: Digite 'portbash' para abrir o menu de tradução." -ForegroundColor Yellow
# --- FIM CONFIGURAÇÃO PORTBASH ---
"@

# 4. Escreve no final do arquivo de perfil
try {
    Add-Content -Path $PROFILE -Value $configuracao -Encoding UTF8
    Write-Host "SUCESSO! O PortBash foi configurado neste computador." -ForegroundColor Green
    Write-Host "Por favor, feche esta janela e abra o PowerShell novamente para testar." -ForegroundColor Yellow
}
catch {
    Write-Host "ERRO ao gravar no perfil: $_" -ForegroundColor Red
}