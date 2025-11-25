@echo off
:: ============================================================
:: LANÇADOR INTELIGENTE - PORTBASH (V2 com Update-Help)
:: ============================================================

echo Buscando arquivo de instalacao...

:: 1. Encontra o script (funciona mesmo se o nome tiver .txt oculto)
for %%f in (Instalador*.ps1 Instalador*.txt) do (
    set "ARQUIVO_ENCONTRADO=%%f"
    goto :ACHOU
)

:NAO_ACHOU
echo [ERRO] Nao encontrei o arquivo 'Instalador.ps1'.
pause
exit /b

:ACHOU
echo Arquivo encontrado: "%ARQUIVO_ENCONTRADO%"
echo.
echo ============================================================
echo ETAPA 1: CONFIGURANDO PERMISSOES E INSTALANDO
echo ============================================================

:: Libera a politica e roda o instalador
PowerShell.exe -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force" 2>nul
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0%ARQUIVO_ENCONTRADO%"

echo.
echo ============================================================
echo ETAPA 2: BAIXANDO O MANUAL DO WINDOWS (UPDATE-HELP)
echo ============================================================
echo.
echo ATENCAO: Isso e necessario para aparecer as descricoes dos comandos.
echo Pode demorar alguns minutos dependendo da sua internet...
echo.

:: O comando abaixo atualiza a ajuda. O 'SilentlyContinue' esconde erros de modulos bloqueados.
PowerShell.exe -NoProfile -Command "Update-Help -Force -ErrorAction SilentlyContinue"

echo.
echo ============================================================
echo TUDO PRONTO! 
echo Pode fechar esta janela.
echo ============================================================
pause