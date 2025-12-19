<?php
// api.php

// Define que o retorno será JSON e permite acesso
header('Content-Type: application/json; charset=utf-8');
header("Access-Control-Allow-Origin: *");

// --- CONFIGURAÇÕES DA API TOTVS ---
// Certifique-se que o IP e Porta estão corretos
$url = "http://127.0.0.1:83/rest/api/retail/v1/APIOMS01";
$usuario = "admin";
$senha   = "admin";

// Inicia o cURL
$ch = curl_init();

// Configurações da requisição
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10); // Aguarda no máximo 10 segundos
curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
curl_setopt($ch, CURLOPT_USERPWD, "$usuario:$senha");
// curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Descomente se usar HTTPS local

// Executa
$resposta = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlErro = curl_error($ch);
$curlErrno = curl_errno($ch); // Pega o número do erro para identificarmos se é Timeout

curl_close($ch);

// --- TRATAMENTO DE ERROS AMIGÁVEL ---

// 1. Erros de Conexão do PHP com o Servidor (Timeout, DNS, Porta fechada)
if ($curlErro) {
    http_response_code(503); // Código 503 = Serviço Indisponível
    
    $mensagemAmigavel = "Erro desconhecido de conexão.";

    // Verifica se é Timeout (Erro 28) ou Falha de Conexão (Erro 7)
    if ($curlErrno == 28) {
        $mensagemAmigavel = "O servidor demorou muito para responder. Tentando novamente...";
    } elseif ($curlErrno == 7) {
        $mensagemAmigavel = "Não foi possível conectar ao servidor. Verifique se a API do Protheus está online.";
    } else {
        $mensagemAmigavel = "Falha de comunicação com o sistema. (Cód: $curlErrno)";
    }

    // Retorna apenas a mensagem limpa para o usuário
    echo json_encode(["error" => $mensagemAmigavel]);
    exit;
}

// 2. Erros retornados pela própria API (Ex: 401 Senha errada, 500 Erro interno)
if ($httpCode >= 400) {
    http_response_code($httpCode);
    
    // Tenta ler se a API mandou uma mensagem específica
    $jsonErro = json_decode($resposta);
    
    if ($httpCode == 401 || $httpCode == 403) {
        $msgFinal = "Acesso negado: Usuário ou senha incorretos na configuração.";
    } elseif ($httpCode == 404) {
        $msgFinal = "Endereço da API não encontrado.";
    } elseif ($httpCode == 500) {
        $msgFinal = "Erro interno no servidor do sistema.";
    } else {
        // Se a API mandou erro, usa ele, senão usa mensagem genérica
        $msgFinal = $jsonErro ? "Erro do Sistema: " . json_encode($jsonErro) : "O servidor retornou um erro ($httpCode).";
    }

    echo json_encode(["error" => $msgFinal]);
    exit;
}

// Se deu tudo certo, imprime os dados originais
echo $resposta;
?>