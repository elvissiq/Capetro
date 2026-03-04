<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Painel CAPETRO - Monitor</title>
    <link rel="icon" href="icon.png" type="image/png">

    <style>
        /* Estilos base mantidos do seu original */
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; background-color: #f0f0f0; display: flex; flex-direction: column; align-items: center; }
        .header { width: 100%; height: 120px; background: linear-gradient(135deg, #2c3e50 0%, #1e2a38 100%); display: flex; justify-content: center; align-items: center; box-shadow: 0 4px 8px rgba(0,0,0,0.3); }
        .logo-img { max-height: 80px; width: auto; filter: brightness(0) invert(1); }
        
        /* --- ESTILO DOS BOTÕES DE FILIAL --- */
        .selector-container { margin-top: 20px; display: flex; gap: 10px; }
        .btn-filial { 
            padding: 12px 25px; 
            border: none; 
            border-radius: 5px; 
            cursor: pointer; 
            font-weight: bold; 
            font-size: 14px; 
            transition: 0.3s;
            background-color: #cfd8dc;
            color: #37474f;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .btn-filial.active {
            background-color: #2c3e50;
            color: white;
            box-shadow: 0 4px 10px rgba(0,0,0,0.3);
            transform: translateY(-2px);
        }
        .btn-filial:hover:not(.active) { background-color: #b0bec5; }

        /* Tabela e Container */
        .container { width: 95%; max-width: 1400px; margin-top: 15px; background-color: white; box-shadow: 0 2px 15px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .title-bar { background-color: #cfd8dc; color: #37474f; text-align: center; padding: 12px; font-size: 1.3em; font-weight: 800; text-transform: uppercase; border-bottom: 2px solid #b0bec5; }
        table { width: 100%; border-collapse: collapse; font-size: 0.95em; }
        thead { background-color: #263238; color: white; }
        th { padding: 14px 8px; text-align: center; border-right: 1px solid #455a64; }
        td { padding: 12px 8px; text-align: center; border-bottom: 1px solid #ddd; border-right: 1px solid #eee; color: #333; }
        tbody tr:nth-child(even) { background-color: #f9f9f9; }
        
        .badge { display: inline-block; width: 90%; padding: 8px 0; border-radius: 2px; font-weight: bold; text-transform: uppercase; font-size: 0.85em; }
        .status-aguardando   { background-color: #fdd835; color: #333; }
        .status-faturamento  { background-color: #ff9800; color: white; }
        .status-liberado     { background-color: #4caf50; color: white; }
        .status-pesado       { background-color: #0288d1; color: white; }
        .status-baia         { background-color: #7b1fa2; color: white; }
        .status-finalizado   { background-color: #546e7a; color: white; }
        .status-padrao       { background-color: #9e9e9e; color: white; }

        .footer-info { margin-top: 15px; font-size: 0.85em; color: #777; text-align: center; margin-bottom: 40px; }
        
        /* Responsividade Mobile */
        @media screen and (max-width: 768px) {
            .selector-container { flex-direction: column; width: 90%; }
            .btn-filial { width: 100%; }
            thead { display: none; }
            table, tbody, tr, td { display: block; }
            tbody tr { margin-bottom: 15px; border: 1px solid #ddd; border-radius: 8px; }
            tbody td { text-align: right; padding: 10px 15px; position: relative; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #f0f0f0; }
            tbody td::before { content: attr(data-label); font-weight: bold; color: #555; font-size: 0.8em; }
            .badge { width: auto; padding: 5px 15px; }
        }
    </style>
</head>
<body>

    <div class="header">
        <img src="logo.png" alt="Logo CAPETRO" class="logo-img">
    </div>

    <!-- BOTÕES DE SELEÇÃO DE FILIAL -->
    <div class="selector-container">
        <button class="btn-filial active" id="btn-010101" onclick="alterarFilial('010101')">010101 - CAPETRO ASFALTOS</button>
        <button class="btn-filial" id="btn-010102" onclick="alterarFilial('010102')">010102 - CAPETRO PALMARES</button>
    </div>

    <div class="container">
        <div class="title-bar" id="painel-nome">ORDEM DE CARREGAMENTO (FILIAL 010101)</div>
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
                <tr><td colspan="10">Aguardando seleção...</td></tr>
            </tbody>
        </table>
    </div>

    <div class="footer-info" id="status-sistema">Iniciando sistema...</div>

    <script>
        const TEMPO_ATUALIZACAO = 900000; // 15 minutos (15 * 60 * 1000)
        let filialSelecionada = '010101'; // Filial padrão inicial

        // Função para trocar a filial
        function alterarFilial(codigo) {
            filialSelecionada = codigo;
            
            // Atualiza visual dos botões
            document.querySelectorAll('.btn-filial').forEach(btn => btn.classList.remove('active'));
            document.getElementById('btn-' + codigo).classList.add('active');
            
            // Atualiza o título visual
            document.getElementById('painel-nome').innerText = `ORDEM DE CARREGAMENTO (FILIAL ${codigo})`;

            // Dispara a busca imediata
            buscarDados();
        }

        async function buscarDados() {
            const tbody = document.querySelector('#gridOrdens tbody');
            const footer = document.getElementById('status-sistema');

            try {
                footer.innerText = `Sincronizando Filial ${filialSelecionada}...`;
                
                // Faz a requisição enviando a filial escolhida
                const response = await fetch(`api.php?filial=${filialSelecionada}&t=${new Date().getTime()}`);

                if (!response.ok) {
                    const errorJson = await response.json();
                    throw new Error(errorJson.error || `Erro HTTP ${response.status}`);
                }

                let dados = await response.json();

                // Normalização dos dados da TOTVS
                if (dados.items && Array.isArray(dados.items)) {
                    dados = dados.items;
                } else if (!Array.isArray(dados)) {
                    dados = dados ? [dados] : []; 
                }

                tbody.innerHTML = '';

                if (dados.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="10">Nenhuma ordem encontrada para esta filial.</td></tr>';
                    return;
                }

                dados.forEach(item => {
                    const valorStatus = item.status || item.Status || item.STATUS || '';
                    const statusNorm = valorStatus.toUpperCase().trim();
                    
                    let classeCor = 'status-padrao';
                    if (statusNorm === 'AGUARDANDO') classeCor = 'status-aguardando';
                    else if (statusNorm.includes('FATURAMENTO')) classeCor = 'status-faturamento';
                    else if (statusNorm === 'LIBERADO') classeCor = 'status-liberado';
                    else if (statusNorm.includes('PESADO')) classeCor = 'status-pesado';
                    else if (statusNorm.includes('BAIA')) classeCor = 'status-baia';
                    else if (statusNorm === 'FINALIZADO') classeCor = 'status-finalizado';

                    tbody.innerHTML += `
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
                });

                footer.innerHTML = `Última atualização (Filial ${filialSelecionada}): ${new Date().toLocaleTimeString()}`;

            } catch (erro) {
                console.error(erro);
                footer.innerHTML = `<span style="color:red">FALHA NA FILIAL ${filialSelecionada}: ${erro.message}</span>`;
                tbody.innerHTML = `<tr><td colspan="10" style="padding: 20px;">Erro ao carregar dados. Verifique a conexão.</td></tr>`;
            }
        }

        // Inicia a primeira carga
        buscarDados();

        // Loop automático que respeita a última filial selecionada
        setInterval(() => {
            console.log("Atualização automática disparada para filial: " + filialSelecionada);
            buscarDados();
        }, TEMPO_ATUALIZACAO);
    </script>
</body>
</html>