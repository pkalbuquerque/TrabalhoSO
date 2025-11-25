# Define o caminho do banco de dados na mesma pasta deste script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dbPath = "$scriptPath\banco_comandos.json"

# --- FUNÇÕES DO SISTEMA ---

function Carregar-Aliases {
    if (Test-Path $dbPath) {
        try {
            $conteudo = Get-Content $dbPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($conteudo)) {
                $comandos = ConvertFrom-Json $conteudo
                # Garante que seja array, mesmo se for item único
                if ($comandos -isnot [array]) { $comandos = @($comandos) }
                
                foreach ($cmd in $comandos) {
                    if ($cmd.Apelido -and $cmd.Original) {
                        Set-Alias -Name $cmd.Apelido -Value $cmd.Original -Scope Global -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        catch {
            Write-Host "Erro ao carregar aliases: $_" -ForegroundColor Red
        }
    }
}

function Salvar-NovoAlias ($apelido, $original, $descricao) {
    $listaAtual = @()
    
    if (Test-Path $dbPath) {
        try {
            $conteudoArquivo = Get-Content $dbPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($conteudoArquivo)) {
                $dadosLidos = ConvertFrom-Json $conteudoArquivo
                # TRUQUE 1: Converte item único em Array para poder somar
                if ($dadosLidos -isnot [array]) { $listaAtual = @($dadosLidos) }
                else { $listaAtual = $dadosLidos }
            }
        }
        catch {
            Write-Host "Criando novo banco de dados..." -ForegroundColor Yellow
        }
    }
    
    # Verifica duplicidade
    $existe = $listaAtual | Where-Object { $_.Apelido -eq $apelido }
    if ($existe) {
        Write-Host "ERRO: O apelido '$apelido' já existe!" -ForegroundColor Red
        return
    }

    $novoComando = [PSCustomObject]@{
        Apelido   = $apelido
        Original  = $original
        Descricao = $descricao
    }

    $listaAtual += $novoComando

    try {
        # TRUQUE 2: -InputObject @(...) obriga o JSON a ter colchetes [ ]
        # Isso impede que o arquivo quebre quando tem apenas 1 item
        $jsonFinal = ConvertTo-Json -InputObject @($listaAtual) -Depth 10
        $jsonFinal | Set-Content $dbPath -Encoding UTF8 -Force
        
        Set-Alias -Name $apelido -Value $original -Scope Global
        Write-Host "SUCESSO: '$apelido' agora executa '$original'" -ForegroundColor Green
    }
    catch {
        Write-Host "ERRO CRÍTICO AO SALVAR: $_" -ForegroundColor Red
    }
}

# --- PESQUISA INTELIGENTE ---

function Traduzir-ComandoGrafico {
    Clear-Host
    Write-Host "--- BUSCAR NO SISTEMA OPERACIONAL ---" -ForegroundColor Cyan
    Write-Host "Digite uma palavra chave (ex: 'rede', 'process', 'file')."
    
    $termo = Read-Host "O que voce quer fazer?"
    if ([string]::IsNullOrWhiteSpace($termo)) { return }
    
    Write-Host "Pesquisando comandos... (Isso pode levar alguns segundos)" -ForegroundColor Yellow
    
    $comandosEncontrados = Get-Command -Name "*$termo*" -CommandType Cmdlet,Function,Alias
    
    if ($comandosEncontrados) {
        $listaDetalhada = foreach ($cmd in $comandosEncontrados) {
            $ajuda = Get-Help $cmd.Name -ErrorAction SilentlyContinue
            
            $sinopse = if ($ajuda.Synopsis -is [array]) { $ajuda.Synopsis -join " " } else { $ajuda.Synopsis }
            $sinopse = ($sinopse | Out-String).Trim()

            if ([string]::IsNullOrWhiteSpace($sinopse) -or ($sinopse -eq $cmd.Name) -or ($sinopse -match "\[.*\]")) {
                $descricaoFinal = "Descrição indisponível no Windows"
            } else {
                $descricaoFinal = $sinopse -replace "[\r\n]+", " "
            }

            $sintaxeBruta = $ajuda.Syntax | Out-String
            $linhasSintaxe = $sintaxeBruta -split "[\r\n]+"
            $primeiraLinha = $linhasSintaxe | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1
            $comoUsarFinal = $primeiraLinha -replace "\s+", " "
            
            if ([string]::IsNullOrWhiteSpace($comoUsarFinal)) { $comoUsarFinal = "Sintaxe indisponível" }

            [PSCustomObject]@{
                NomeOriginal = $cmd.Name
                O_Que_Faz    = $descricaoFinal
                Como_Usar    = $comoUsarFinal
                Fonte        = $cmd.Source
            }
        }

        $selecionado = $listaDetalhada | Out-GridView -Title "Selecione o comando para traduzir" -PassThru
        
        if ($selecionado) {
            $comandoOriginal = $selecionado.NomeOriginal
            
            Write-Host "`n--- CRIANDO TRADUÇÃO ---" -ForegroundColor Cyan
            Write-Host "Comando: " -NoNewline; Write-Host $comandoOriginal -ForegroundColor Yellow
            
            if ($selecionado.O_Que_Faz -like "*indisponível*") {
                $descSugestao = ""
            } else {
                Write-Host "Função: " -NoNewline; Write-Host $selecionado.O_Que_Faz -ForegroundColor Gray
                $descSugestao = $selecionado.O_Que_Faz
            }
            
            $novoNome = Read-Host "Qual nome em Portugues voce quer dar?"
            if ([string]::IsNullOrWhiteSpace($novoNome)) { return }

            $desc = Read-Host "Descricao curta (Enter para usar sugestão)"
            if ([string]::IsNullOrWhiteSpace($desc)) { $desc = $descSugestao }
            
            Salvar-NovoAlias $novoNome $comandoOriginal $desc
        }
    } else {
        Write-Host "Nenhum comando encontrado." -ForegroundColor Red
    }
}

# --- LISTAGEM DE COMANDOS (Versão Corrigida para GridView Vazia) ---

function Listar-MeusComandos {
    Write-Host "Carregando sua lista..." -ForegroundColor Cyan
    
    if (Test-Path $dbPath) { 
        try {
            $conteudo = Get-Content $dbPath -Raw -Encoding UTF8
            
            if ([string]::IsNullOrWhiteSpace($conteudo)) {
                Write-Host "O arquivo existe mas está vazio." -ForegroundColor Yellow
                return
            }

            $dados = ConvertFrom-Json $conteudo
            
            # CORREÇÃO CRÍTICA: Se for um objeto único, transforma em array manualmente
            if ($dados -isnot [array]) {
                $dados = @($dados)
            }
            
            if ($dados.Count -gt 0) {
                # O Select-Object garante que as colunas existam mesmo se o JSON estiver estranho
                $dados | Select-Object Apelido, Original, Descricao | Out-GridView -Title "Meu Dicionário PT-BR" -Wait
            } else {
                Write-Host "Nenhum comando encontrado no banco de dados." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "ERRO: O arquivo JSON está corrompido. Tente apagar o arquivo .json e começar de novo." -ForegroundColor Red
            Write-Host "Detalhe: $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "Arquivo 'banco_comandos.json' não encontrado. Crie seu primeiro comando!" -ForegroundColor Yellow
    }
}

# --- MENU PRINCIPAL ---

function Menu-Principal {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Magenta
    Write-Host "   POWERSHELL EM PORTUGUÊS (GERENCIADOR)   " -ForegroundColor Magenta
    Write-Host "============================================="
    Write-Host "1. Criar nova tradução (Pesquisa no Windows)"
    Write-Host "2. Ver meus comandos traduzidos (TABELA)"
    Write-Host "3. Recarregar Aliases"
    Write-Host "0. Sair"
    Write-Host "============================================="
}

Carregar-Aliases

do {
    Menu-Principal
    $opcao = Read-Host "Opção"
    switch ($opcao) {
        "1" { Traduzir-ComandoGrafico; Pause }
        "2" { Listar-MeusComandos } 
        "3" { Carregar-Aliases; Write-Host "Recarregado!"; Pause }
        "0" { Write-Host "Saindo..." }
        Default { Write-Host "Opção inválida"; Pause }
    }
} until ($opcao -eq "0")