<?php
// api.php

// Define cabeçalhos para evitar cache e permitir acesso
header('Content-Type: application/json; charset=utf-8');
header("Access-Control-Allow-Origin: *");
header("Cache-Control: no-cache, no-store, must-revalidate");

// --- CONFIGURAÇÕES DA API TOTVS ---
// URL Base fornecida + Endpoint do serviço
$urlBase = "https://capetroasfaltos188713.protheus.cloudtotvs.com.br:10260/rest";
$endpoint = "/api/retail/v1/APIOMS01";
$urlCompleta = $urlBase . $endpoint;

$usuario = "admin";
$senha   = "totvs@2025";

// Inicia o cURL
$ch = curl_init();

// Configurações da requisição
curl_setopt($ch, CURLOPT_URL, $urlCompleta);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 15); // Aumentei um pouco o tempo limite para Cloud
curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
curl_setopt($ch, CURLOPT_USERPWD, "$usuario:$senha");

// --- CORREÇÃO DO ERRO HTTPS/SSL ---
// Estas duas linhas ignoram erros de certificado SSL.
// Isso permite que o PHP leia o "Erro 500" ao invés de falhar na conexão.
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);

// Executa
$resposta = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlErro = curl_error($ch);
$curlErrno = curl_errno($ch);

curl_close($ch);

// --- TRATAMENTO DE ERROS ---

// 1. Erros de Conexão REAL (Internet caiu, DNS falhou, Timeout)
if ($curlErro) {
    http_response_code(503);
    
    // Tratamento específico para Timeout
    if ($curlErrno == 28) {
        $msg = "O servidor demorou muito para responder (Timeout).";
    } else {
        $msg = "Falha de conexão com a API: " . $curlErro;
    }
    
    echo json_encode(["error" => $msg]);
    exit;
}

// 2. Erros HTTP (O servidor respondeu, mas deu erro: 404, 500, 401)
if ($httpCode >= 400) {
    http_response_code($httpCode);
    
    // Tenta ler a mensagem de erro original da TOTVS
    $jsonErro = json_decode($resposta);
    $msgDetalhada = "";

    // Se o retorno for um JSON válido com mensagem, usamos ele
    if ($jsonErro && (isset($jsonErro->errorMessage) || isset($jsonErro->message))) {
        $msgDetalhada = isset($jsonErro->errorMessage) ? $jsonErro->errorMessage : $jsonErro->message;
    }

    // Mensagens amigáveis para o painel
    if ($httpCode == 401 || $httpCode == 403) {
        $msgFinal = "Acesso negado (401/403): Verifique usuário e senha.";
    } elseif ($httpCode == 404) {
        $msgFinal = "Recurso não encontrado (404). Verifique a URL.";
    } elseif ($httpCode == 500) {
        // Aqui mostramos que é erro interno, e se tiver detalhe, mostra também
        $msgFinal = "Erro Interno do Servidor (500)";
        if ($msgDetalhada) {
            $msgFinal .= ": " . $msgDetalhada;
        } else {
            $msgFinal .= ". Verifique o log do Protheus (Console).";
        }
    } else {
        $msgFinal = "Erro na API ($httpCode)" . ($msgDetalhada ? ": $msgDetalhada" : "");
    }

    echo json_encode(["error" => $msgFinal]);
    exit;
}

// Se deu tudo certo (200 OK), retorna os dados
echo $resposta;
?>