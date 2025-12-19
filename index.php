<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Painel CAPETRO - Monitor</title>
    
    <link rel="icon" href="icon.png" type="image/png">

    <style>
        /* --- ESTILOS GERAIS (DESKTOP) --- */
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; background-color: #f0f0f0; display: flex; flex-direction: column; align-items: center; }
        
        /* Header */
        .header { width: 100%; height: 160px; background: linear-gradient(135deg, #2c3e50 0%, #1e2a38 100%); display: flex; justify-content: center; align-items: center; position: relative; overflow: hidden; box-shadow: 0 4px 8px rgba(0,0,0,0.3); transition: height 0.3s; }
        .header::after { content: ''; position: absolute; bottom: -50px; right: -10%; width: 120%; height: 100px; background: rgba(255,255,255,0.08); transform: rotate(-3deg); z-index: 0; }
        
        .logo-container { z-index: 10; display: flex; justify-content: center; align-items: center; height: 100%; }
        .logo-img { max-height: 100px; width: auto; filter: brightness(0) invert(1) drop-shadow(0 2px 4px rgba(0,0,0,0.5)); transition: max-height 0.3s; }
        
        .container { width: 95%; max-width: 1400px; margin-top: 20px; background-color: white; box-shadow: 0 2px 15px rgba(0,0,0,0.1); margin-bottom: 20px; }
        
        .title-bar { background-color: #cfd8dc; color: #37474f; text-align: center; padding: 12px; font-size: 1.3em; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; border-bottom: 2px solid #b0bec5; }
        
        /* Tabela Padrão */
        table { width: 100%; border-collapse: collapse; font-size: 0.95em; }
        thead { background-color: #263238; color: white; }
        th { padding: 14px 8px; text-align: center; font-weight: 600; border-right: 1px solid #455a64; }
        th:last-child { border-right: none; }
        td { padding: 12px 8px; text-align: center; border-bottom: 1px solid #ddd; border-right: 1px solid #eee; color: #333; font-weight: 500; }
        tbody tr:nth-child(even) { background-color: #f9f9f9; }
        
        .badge { display: inline-block; width: 90%; padding: 8px 0; border-radius: 2px; font-weight: bold; text-transform: uppercase; font-size: 0.9em; box-shadow: 0 1px 3px rgba(0,0,0,0.2); }

        /* Cores dos Status */
        .status-aguardando   { background-color: #fdd835; color: #333; }
        .status-faturamento  { background-color: #ff9800; color: #3e2723; }
        .status-liberado     { background-color: #4caf50; color: white; }
        .status-pesado       { background-color: #0288d1; color: white; }
        .status-baia         { background-color: #7b1fa2; color: white; }
        .status-finalizado   { background-color: #546e7a; color: white; }
        .status-padrao       { background-color: #9e9e9e; color: white; }

        .footer-info { margin-top: 15px; font-size: 0.85em; color: #777; text-align: center; margin-bottom: 20px; }
        .error-msg { color: red; font-weight: bold; }

        /* ==========================================================================
           RESPONSIVIDADE (MOBILE)
           ========================================================================== */
        @media screen and (max-width: 768px) {
            .header { height: 100px; }
            .logo-img { max-height: 60px; }
            .title-bar { font-size: 1.1em; padding: 10px; }

            /* Transforma a Tabela em Cards */
            table, thead, tbody, th, td, tr { display: block; }
            
            thead { display: none; }

            tbody tr {
                margin-bottom: 15px;
                background-color: #fff;
                border: 1px solid #ddd;
                border-radius: 8px;
                box-shadow: 0 2px 5px rgba(0,0,0,0.05);
                overflow: hidden;
            }

            tbody td {
                padding: 10px 15px;
                text-align: right; 
                border-bottom: 1px solid #f0f0f0;
                border-right: none;
                position: relative;
                display: flex;
                justify-content: space-between;
                align-items: center;
                font-size: 0.95em;
            }
            
            tbody td:last-child { border-bottom: none; }

            tbody td::before {
                content: attr(data-label);
                font-weight: 700;
                color: #555;
                text-transform: uppercase;
                font-size: 0.85em;
                text-align: left;
                margin-right: 15px;
            }

            .badge { width: auto; padding: 5px 15px; font-size: 0.8em; }
        }
    </style>
</head>
<body>

    <div class="header">
        <div class="logo-container">
            <img src="logo.png" alt="Logo CAPETRO" class="logo-img">
        </div>
    </div>

    <div class="container">
        <div class="title-bar">ORDEM DE CARREGAMENTO</div>
        <table id="gridOrdens">
            <thead>
                <tr>
                    <th>N° OC</th>
                    <th>N° Pedido</th>
                    <th>Data</th>
                    <th>Cliente</th>
                    <th>Motorista</th>
                    <th>Produto</th>
                    <th>Placa</th>
                    <th style="min-width: 120px;">Status</th>
                    <th>Peso Final (kg)</th>
                    <th>N° dos Lacres</th>
                </tr>
            </thead>
            <tbody>
                <tr><td colspan="10">Iniciando sistema...</td></tr>
            </tbody>
        </table>
    </div>

    <div class="footer-info" id="status-sistema">Aguarde...</div>

    <script>
        const TEMPO_ATUALIZACAO = 180000; 

        async function buscarDados() {
            const tbody = document.querySelector('#gridOrdens tbody');
            const footer = document.getElementById('status-sistema');

            try {
                footer.innerText = "Sincronizando dados...";
                
                const response = await fetch('api.php?t=' + new Date().getTime());

                if (!response.ok) {
                    const errorJson = await response.json();
                    throw new Error(errorJson.error || `Erro HTTP ${response.status}`);
                }

                let dados = await response.json();

                if (dados.items && Array.isArray(dados.items)) {
                    dados = dados.items;
                } else if (!Array.isArray(dados)) {
                    dados = [dados]; 
                }

                tbody.innerHTML = '';

                if (dados.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="10">Nenhuma ordem encontrada.</td></tr>';
                    return;
                }

                dados.forEach(item => {
                    const valorStatus = item.status || item.Status || item.STATUS || '';
                    const statusNorm = valorStatus.toUpperCase().trim();
                    
                    let classeCor = 'status-padrao';
                    if (statusNorm === 'AGUARDANDO') classeCor = 'status-aguardando';
                    else if (statusNorm === 'AGUARDANDO FATURAMENTO') classeCor = 'status-faturamento';
                    else if (statusNorm === 'LIBERADO') classeCor = 'status-liberado';
                    else if (statusNorm === 'VEICULO PESADO' || statusNorm === 'VEÍCULO PESADO') classeCor = 'status-pesado';
                    else if (statusNorm === 'ENTRADA NA BAIA') classeCor = 'status-baia';
                    else if (statusNorm === 'FINALIZADO') classeCor = 'status-finalizado';

                    const linha = `
                        <tr>
                            <td data-label="N° OC">${item.oc || item.OC || '-'}</td>
                            <td data-label="N° Pedido">${item.pedido || item.Pedido || '-'}</td>
                            <td data-label="Data">${item.data || item.Data || '-'}</td>
                            <td data-label="Cliente">${item.cliente || item.Cliente || '-'}</td>
                            <td data-label="Motorista">${item.motorista || item.Motorista || '-'}</td>
                            <td data-label="Produto">${item.produto || item.Produto || '-'}</td>
                            <td data-label="Placa">${item.placa || item.Placa || '-'}</td>
                            <td data-label="Status"><span class="badge ${classeCor}">${valorStatus || 'ND'}</span></td>
                            <td data-label="Peso Final">${item.peso || item.Peso || '-'}</td>
                            <td data-label="N° Lacres">${item.lacres || item.Lacres || '-'}</td>
                        </tr>
                    `;
                    tbody.innerHTML += linha;
                });

                const agora = new Date();
                footer.innerHTML = `Última atualização: ${agora.toLocaleTimeString()}`;
                footer.style.color = "#777";

            } catch (erro) {
                console.error("Erro no painel:", erro);
                footer.innerHTML = `<span class="error-msg">FALHA: ${erro.message}</span>`;
                
                if(tbody.children.length <= 1) {
                     tbody.innerHTML = `<tr><td colspan="10" style="color:red; padding: 20px;">
                        <strong>Erro ao carregar dados:</strong><br>
                        ${erro.message}
                    </td></tr>`;
                }
            }
        }

        buscarDados();
        setInterval(buscarDados, TEMPO_ATUALIZACAO);
    </script>
</body>
</html>