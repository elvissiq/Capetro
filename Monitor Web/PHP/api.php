<?php
// api.php
header('Content-Type: application/json; charset=utf-8');
header("Access-Control-Allow-Origin: *");
header("Cache-Control: no-cache, no-store, must-revalidate");

// Captura a filial via GET. Se não informada, usa 010101 como padrão.
$filial = isset($_GET['filial']) ? $_GET['filial'] : '010101';

// --- CONFIGURAÇÕES DA API TOTVS ---
$urlBase = "https://capetroasfaltos188712.protheus.cloudtotvs.com.br:10207/rest";
$endpoint = "/api/retail/v1/APIOMS01";

// Monta a URL passando a filial como parâmetro para a API ADVPL
$urlCompleta = $urlBase . $endpoint . "?Branch=" . $filial;

$usuario = "admin";
$senha   = "totvs@2025";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $urlCompleta);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30); 
curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
curl_setopt($ch, CURLOPT_USERPWD, "$usuario:$senha");
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);

$resposta = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlErro = curl_error($ch);

if ($curlErro) {
    http_response_code(503);
    echo json_encode(["error" => "Falha de conexão: " . $curlErro]);
    exit;
}

if ($httpCode >= 400) {
    http_response_code($httpCode);
    echo $resposta; // Repassa o erro detalhado do Protheus se houver
    exit;
}

echo $resposta;
?>