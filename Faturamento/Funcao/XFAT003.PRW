#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOTVS.CH"
#INCLUDE "TOPCONN.CH"
#INCLUDE "RPTDEF.CH"
#INCLUDE "FWPrintSetup.ch"
#INCLUDE "TBICONN.CH"

//---------------------------------------------------------
/*/ Rotina XFAT003 (Fatura de Cobranca - Capetro)
  Funcao U_XFAT003()

  Descricao:
  Rotina principal disparada pelo usuario a partir da
  consulta de Pedidos de Venda. Valida o pedido e aciona,
  dentro de um FWMsgRun, a montagem dos dados em memoria e a
  geracao do PDF da Fatura (RptStatus foi removido por nao
  exibir nenhuma regua util neste fluxo). Apos a impressao,
  pergunta ao usuario se deseja gerar o boleto deste pedido; em
  caso afirmativo, aciona XFAT003BOL() (geracao dos titulos via
  Condicao()/FINA040) dentro de outro FWMsgRun proprio.

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
User Function XFAT003()

    Private oDadosFat := {}

    If Empty(SC5->C5_NUM)
        MsgAlert("Posicione um Pedido de Venda antes de imprimir a Fatura.", "Fatura de Cobranca")
        Return
    EndIf

    If !XFAT003VAL()
        Return
    EndIf

    FWMsgRun(, {|| XFAT003RUN()}, "Aguarde...", "Gerando Fatura de Cobranca...")

    If MsgYesNo("Deseja gerar o boleto para este pedido?", "Fatura de Cobranca")
        FWMsgRun(, {|| XFAT003BOL(oDadosFat) }, "Aguarde...", "Gerando o(s) Boleto(s)...")
    EndIf

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003RUN()

  Descricao:
  Executa a montagem dos dados e a geracao do PDF dentro de um
  FWMsgRun, garantindo um contexto de dialogo interativo ativo
  durante a criacao do FWMSPrinter.

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003RUN()

    oDadosFat := XFAT003MNT()

    XFAT003PDF(oDadosFat)

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003VAL() - (Antiga XFAT003Valida)

  Descricao:
  Realiza as validacoes previas de integridade antes da 
  emissao. Verifica no banco de dados se o pedido posicionado 
  possui ao menos um item (SC6) e se o cliente (SA1) esta 
  cadastrado e sem bloqueio de faturamento.

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003VAL()

    Local lOk    := .T.
    Local cAlias := GetNextAlias()

    BeginSql Alias cAlias
        SELECT COUNT(*) AS QTDITENS
        FROM %table:SC6% SC6
        WHERE SC6.%notDel%
          AND SC6.C6_NUM = %exp:SC5->C5_NUM%
    EndSql

    If (cAlias)->QTDITENS == 0
        MsgAlert("O pedido " + SC5->C5_NUM + " nao possui itens.", "Fatura de Cobranca")
        lOk := .F.
    EndIf

    (cAlias)->(DbCloseArea())

    If lOk
        DbSelectArea("SA1")
        DbSetOrder(1)
        If !DbSeek(xFilial("SA1") + SC5->C5_CLIENTE + SC5->C5_LOJACLI)
            MsgAlert("Cliente do pedido nao encontrado no cadastro (SA1).", "Fatura de Cobranca")
            lOk := .F.
        ElseIf SA1->A1_MSBLQL == "1"
            MsgAlert("Cliente do pedido esta bloqueado.", "Fatura de Cobranca")
            lOk := .F.
        EndIf
    EndIf

Return lOk

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003MNT() - (Antiga XFAT003MontaDados)

  Descricao:
  Monta a estrutura de dados da Fatura em memoria, em um array
  de pares chave/valor (forma classica, sem uso de Hash Map).
  Coleta e agrupa informacoes do cabecalho do pedido (SC5),
  dados de endereco/documento do cliente (SA1), somatoria
  dos totais e a lista detalhada de itens (SC6) do pedido. O
  endereco do cliente e o local de entrega sao montados via
  XFAT003ENDER(), incluindo bairro, complemento e CEP; o local
  de entrega usa preferencialmente os campos especificos de
  entrega da SA1 (A1_ENDENT/A1_BAIRROE/A1_COMPENT/A1_CEPE/
  A1_MUNE/A1_ESTE) quando existirem e estiverem preenchidos.

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003MNT()

    Local oDados    := {}
    Local aItens    := {}
    Local cAlias    := GetNextAlias()
    Local nTotal    := 0
    Local nDesconto := 0
    Local nDescItem := 0
    Local nValBruto := 0

    Local cCliEnt   := IIf(Type("SC5->C5_CLIENT") != "U" .And. !Empty(SC5->C5_CLIENT), SC5->C5_CLIENT, SC5->C5_CLIENTE) 
    Local cLojEnt   := IIf(Type("SC5->C5_CLIENT") != "U" .And. !Empty(SC5->C5_CLIENT), SC5->C5_LOJAENT, SC5->C5_LOJACLI)
    Local cLocalEnt := ""

    DbSelectArea("SA1")
    DbSetOrder(1)
    DbSeek(xFilial("SA1") + SC5->C5_CLIENTE + SC5->C5_LOJACLI)

    XFAT003SET(oDados, "NumFatura", cValToChar(GetSxeNum("SC5", "C5_XNFAT"))) 
    ConfirmSX8()

    XFAT003SET(oDados, "Pedido", SC5->C5_NUM)
    XFAT003SET(oDados, "Emissao", Date())
    XFAT003SET(oDados, "DtPedido", SC5->C5_EMISSAO)
    XFAT003SET(oDados, "Vencimento", SC5->C5_DATA1)
    XFAT003SET(oDados, "Condicao", Posicione("SE4", 1, xFilial("SE4") + SC5->C5_CONDPAG, "E4_DESCRI"))
    XFAT003SET(oDados, "Placa", AllTrim(cValToChar(SC5->C5_PLACA1)) + IIf(!Empty(SC5->C5_PLACA2), " / " + AllTrim(cValToChar(SC5->C5_PLACA2)), ""))
    XFAT003SET(oDados, "TpCobranca", "BOLETO BANCARIO")
    XFAT003SET(oDados, "NFRelac", "")

    XFAT003SET(oDados, "ObsMenNota", IIf(Type("SC5->C5_MENNOTA") != "U", AllTrim(cValToChar(SC5->C5_MENNOTA)), ""))
    XFAT003SET(oDados, "ObsXMsgI", IIf(Type("SC5->C5_XMSGI") != "U", AllTrim(cValToChar(SC5->C5_XMSGI)), ""))

    cLocalEnt := AllTrim(cValToChar(SC5->C5_DESCMUN))
    If Empty(cLocalEnt)
        DbSelectArea("SA1")
        DbSetOrder(1)
        If DbSeek(xFilial("SA1") + cCliEnt + cLojEnt)
            cLocalEnt := XFAT003ENDER(;
                IIf(Type("SA1->A1_ENDENT") != "U" .And. !Empty(SA1->A1_ENDENT), SA1->A1_ENDENT, SA1->A1_END),;
                IIf(Type("SA1->A1_BAIRROE") != "U" .And. !Empty(SA1->A1_BAIRROE), SA1->A1_BAIRROE, SA1->A1_BAIRRO),;
                IIf(Type("SA1->A1_COMPENT") != "U" .And. !Empty(SA1->A1_COMPENT), SA1->A1_COMPENT, IIf(Type("SA1->A1_COMPLEM") != "U", SA1->A1_COMPLEM, "")),;
                IIf(Type("SA1->A1_CEPE") != "U" .And. !Empty(SA1->A1_CEPE), SA1->A1_CEPE, SA1->A1_CEP),;
                IIf(Type("SA1->A1_MUNE") != "U" .And. !Empty(SA1->A1_MUNE), SA1->A1_MUNE, SA1->A1_MUN),;
                IIf(Type("SA1->A1_ESTE") != "U" .And. !Empty(SA1->A1_ESTE), SA1->A1_ESTE, SA1->A1_EST))
        EndIf
        DbSeek(xFilial("SA1") + SC5->C5_CLIENTE + SC5->C5_LOJACLI)
    EndIf
    XFAT003SET(oDados, "LocalEntr", cLocalEnt)

    XFAT003SET(oDados, "ClienteNome", SA1->A1_NOME)
    XFAT003SET(oDados, "ClienteCgc", SA1->A1_CGC)
    XFAT003SET(oDados, "ClienteEnd", XFAT003ENDER(SA1->A1_END, SA1->A1_BAIRRO, IIf(Type("SA1->A1_COMPLEM") != "U", SA1->A1_COMPLEM, ""), SA1->A1_CEP, "", ""))
    XFAT003SET(oDados, "ClienteMun", AllTrim(cValToChar(SA1->A1_MUN)))
    XFAT003SET(oDados, "ClienteEst", AllTrim(cValToChar(SA1->A1_EST)))

    BeginSql Alias cAlias
        SELECT C6_ITEM, C6_DESCRI, C6_QTDVEN, C6_PRCVEN, C6_VALOR, C6_DESCONT
        FROM %table:SC6% SC6
        WHERE SC6.%notDel%
          AND SC6.C6_NUM = %exp:SC5->C5_NUM%
        ORDER BY C6_ITEM
    EndSql

    While !(cAlias)->(Eof())
        nDescItem := (cAlias)->C6_DESCONT
        nValBruto := IIf(nDescItem > 0, (cAlias)->C6_VALOR / (1 - nDescItem / 100), (cAlias)->C6_VALOR)

        aAdd(aItens, {;
            (cAlias)->C6_ITEM  ,;
            (cAlias)->C6_DESCRI,;
            (cAlias)->C6_QTDVEN,;
            (cAlias)->C6_PRCVEN,;
            nValBruto - (cAlias)->C6_VALOR,;
            (cAlias)->C6_VALOR })

        nTotal    += nValBruto
        nDesconto += (nValBruto - (cAlias)->C6_VALOR)

        (cAlias)->(DbSkip())
    EndDo

    (cAlias)->(DbCloseArea())

    XFAT003SET(oDados, "Itens", aItens)
    XFAT003SET(oDados, "ValorTotal", nTotal)
    XFAT003SET(oDados, "Retencoes", nDesconto)
    XFAT003SET(oDados, "ValorPagar", nTotal - nDesconto)

    XFAT003FIL(oDados)
    XFAT003BCO(oDados)

Return oDados

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003FIL()

  Descricao:
  Busca no cadastro de Filiais (SM0), atraves da classe
  FWSM0Util, o Nome Comercial, o CNPJ, o Bairro e a UF da
  filial corrente (cEmpAnt/cFilAnt) e acopla os valores no
  array de impressao para uso no cabecalho do documento.

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003FIL(oDados)

    Local aCampos := {"M0_NOMECOM", "M0_CGC", "M0_BAIRENT", "M0_ESTENT"}
    Local aDados  := FWSM0Util():GetSM0Data(cEmpAnt, cFilAnt, aCampos)

    XFAT003SET(oDados, "EmitNome", IIf(Len(aDados) >= 1, AllTrim(cValToChar(aDados[1][2])), ""))
    XFAT003SET(oDados, "EmitCgc", IIf(Len(aDados) >= 2, AllTrim(cValToChar(aDados[2][2])), ""))
    XFAT003SET(oDados, "EmitBairro", IIf(Len(aDados) >= 3, AllTrim(cValToChar(aDados[3][2])), ""))
    XFAT003SET(oDados, "EmitUf", IIf(Len(aDados) >= 4, AllTrim(cValToChar(aDados[4][2])), ""))

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003BCO() - (Antiga XFAT003DadosBancarios)

  Descricao:
  Identifica qual a conta bancaria configurada para emissao
  de faturas no Protheus. Nao usa mais o campo A6_XFATUR para
  selecionar o banco; em vez disso, le o banco/agencia/conta do
  parametro MV_XBANKBO (mesmo parametro usado por XFAT003BOR()
  na geracao do bordero/boleto do pedido) e localiza o
  respectivo registro na SA6 via MsSeek, garantindo que a fatura
  impressa mostre exatamente a mesma conta que sera usada para
  emitir o boleto. O Banco e exibido como "codigo - nome"
  (A6_COD + A6_NREDUZ, caindo para A6_NOME quando o reduzido
  estiver vazio). Agencia e Conta so exibem o digito verificador
  (A6_DVAGE/A6_DVCTA) quando ele estiver preenchido.

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003BCO(oDados)

    Local aBankBol := StrTokArr(SuperGetMV("MV_XBANKBO", .F., ""), "/")
    Local lAchou   := .F.

    If Len(aBankBol) >= 3
        DbSelectArea("SA6")
        DbSetOrder(1)
        lAchou := SA6->(MsSeek(xFilial("SA6") + PadR(aBankBol[1], FWTamSX3("A6_COD")[1]) + PadR(aBankBol[2], FWTamSX3("A6_AGENCIA")[1]) + PadR(aBankBol[3], FWTamSX3("A6_NUMCON")[1])))
    EndIf

    If lAchou

        XFAT003SET(oDados, "Banco", AllTrim(cValToChar(SA6->A6_COD)) + " - " + IIf(Empty(SA6->A6_NREDUZ), AllTrim(cValToChar(SA6->A6_NOME)), AllTrim(cValToChar(SA6->A6_NREDUZ))))
        XFAT003SET(oDados, "Agencia", AllTrim(cValToChar(SA6->A6_AGENCIA)) + IIf(!Empty(SA6->A6_DVAGE), "-" + AllTrim(cValToChar(SA6->A6_DVAGE)), ""))
        XFAT003SET(oDados, "Conta", AllTrim(cValToChar(SA6->A6_NUMCON)) + IIf(!Empty(SA6->A6_DVCTA), "-" + AllTrim(cValToChar(SA6->A6_DVCTA)), ""))
        XFAT003SET(oDados, "Favorecido", AllTrim(cValToChar(SA6->A6_CORRENT)))

        XFAT003SET(oDados, "Pix", XFAT003PIX(SA6->A6_COD, SA6->A6_AGENCIA, SA6->A6_NUMCON))

    Else
        XFAT003SET(oDados, "Banco", "")
        XFAT003SET(oDados, "Agencia", "")
        XFAT003SET(oDados, "Conta", "")
        XFAT003SET(oDados, "Favorecido", "CAPETRO ASFALTOS LTDA.")
        XFAT003SET(oDados, "Pix", "")
    EndIf

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003PIX() - (Antiga XFAT003BuscaPix)

  Descricao:
  Recebe os dados do banco localizado e busca na tabela de
  chaves PIX (F70) qual e a chave ativa ('1') vinculada a
  esta conta especifica, retornando-a para a rotina chamadora.

  Obs: a clausula "TOP 1" foi removida da query pois e sintaxe
  exclusiva do T-SQL/Sybase e nao e reconhecida pelo Oracle
  (gera o erro ORA-00923). A rotina chamadora ja le apenas o
  primeiro registro do cursor (If !(cAlias)->(Eof())), sem
  looping, entao a ausencia do limitador de linhas nao altera
  o comportamento e a query passa a ser portavel entre os
  bancos homologados (Oracle e MSSQL).

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003PIX(cCodBco, cAgencia, cNumCon)

    Local cChave := ""
    Local cAlias := GetNextAlias()

    BeginSql Alias cAlias
        SELECT F70_CHVPIX
        FROM %table:F70% F70
        WHERE F70.%notDel%
          AND F70.F70_COD    = %exp:cCodBco%
          AND F70.F70_AGENCI = %exp:cAgencia%
          AND F70.F70_NUMCON = %exp:cNumCon%
          AND F70.F70_ACTIVE = '1'
    EndSql

    If !(cAlias)->(Eof())
        cChave := AllTrim(cValToChar((cAlias)->F70_CHVPIX))
    EndIf

    (cAlias)->(DbCloseArea())

Return cChave

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003SET()

  Descricao:
  Grava uma chave no array de impressao (forma classica, sem
  Hash Map). Caso a chave ja exista, atualiza o valor na mesma
  posicao; caso contrario, acrescenta um novo par {chave,valor}
  ao final do array.

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003SET(oDados, cChave, xValor)

    Local nPos := AScan(oDados, {|aPar| aPar[1] == cChave})

    If nPos > 0
        oDados[nPos][2] := xValor
    Else
        aAdd(oDados, {cChave, xValor})
    EndIf

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003GET()

  Descricao:
  Busca uma chave no array de impressao (forma classica, sem
  Hash Map), percorrendo os pares {chave,valor} com AScan().
  Retorna xDefault somente quando a chave nao for encontrada.

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003GET(oDados, cChave, xDefault)

    Local nPos := AScan(oDados, {|aPar| aPar[1] == cChave})

Return IIf(nPos > 0, oDados[nPos][2], xDefault)

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003MASK()

  Descricao:
  Aplica a mascara de CNPJ (14 digitos) ou CPF (11 digitos) a
  uma string de documento, conforme o layout do modelo Excel
  do cliente (ex.: 52.535.498/0001-90). Documentos com outra
  quantidade de digitos sao retornados sem mascara.

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003MASK(cDoc)

    Local cLimpo := StrTran(StrTran(StrTran(AllTrim(cValToChar(cDoc)), ".", ""), "/", ""), "-", "")
    Local cRet   := cLimpo

    If Len(cLimpo) == 11
        cRet := Transform(cLimpo, "@R 999.999.999-99")
    ElseIf Len(cLimpo) == 14
        cRet := Transform(cLimpo, "@R 99.999.999/9999-99")
    EndIf

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003ENDER()

  Descricao:
  Monta uma string de endereco completa a partir de rua,
  bairro, complemento, CEP e, opcionalmente, municipio/UF
  (passar "" em cMun quando cidade/UF ja forem exibidos em
  outro campo do layout, evitando repeticao). Cada parte so
  entra na string se estiver preenchida.

  @author Raphael Neves (Hubvision)
  @since  20/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003ENDER(cEnd, cBairro, cComplem, cCep, cMun, cEst)

    Local cRet := AllTrim(cValToChar(cEnd))

    If !Empty(cComplem)
        cRet += ", " + AllTrim(cValToChar(cComplem))
    EndIf

    If !Empty(cBairro)
        cRet += " - " + AllTrim(cValToChar(cBairro))
    EndIf

    If !Empty(cMun)
        cRet += " - " + AllTrim(cValToChar(cMun)) + "/" + AllTrim(cValToChar(cEst))
    EndIf

    If !Empty(cCep)
        cRet += " - CEP " + Transform(AllTrim(cValToChar(cCep)), "@R 99999-999")
    EndIf

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003PDF() - (Antiga XFAT003GeraPDF)

  Descricao:
  Motor de geracao de relatorio usando a classe FWMSPrinter.
  Recebe o array de impressao populado com todas as informacoes, tipa
  corretamente as variaveis locais e desenha os componentes
  visuais do PDF (caixas, faixas coloridas e textos), replicando
  o modelo Excel do cliente: bloco azul marinho do nome do
  emitente a esquerda do cabecalho, caixa branca a direita com
  "FATURA DE COBRANCA" e a grade 2x2 de No da Fatura/Emissao/
  Vencimento/Condicao, exibindo o PDF na tela para o usuario ao
  final do processo. Margem direita (nDir) calculada a partir da
  largura da pagina A4 (nLargPag=595) menos uma margem direita
  fixa (nMargDir=40), equivalente ao recuo visual da margem
  esquerda (nEsq=15). Observacoes exibe tambem, quando
  preenchidos, o conteudo dos campos memo C5_MENNOTA/C5_XMSGI,
  com altura de caixa calculada dinamicamente conforme a
  quantidade de linhas necessarias para nao perder texto. Na
  tabela de itens, a Descricao tambem quebra linha (altura por
  item calculada dinamicamente) e as linhas alternam fundo
  branco/cinza claro (zebrado) para diferenciar um item do
  outro. A linha VALOR A PAGAR e destacada com fundo escuro e
  texto branco. IMPORTANTE: o metodo Box() do FWMSPrinter limpa
  para branco toda a area interna do retangulo ao ser
  desenhado (nao e apenas um contorno); por isso Box()/Line()
  sao sempre desenhados ANTES de qualquer conteudo (FillRect ou
  SayAlign) na mesma area - nunca depois, sob pena de apagar
  tudo que foi desenhado antes dele. Quando um FillRect (como o
  zebrado) precisa cobrir uma faixa que ja tem linhas divisorias
  de fundo, essas linhas sao redesenhadas por cima do FillRect
  logo em seguida (Line() e apenas um traco, nao limpa a area).
  Ao final, oPrint e todos os objetos TFont/TBrush criados sao
  liberados explicitamente via FreeObj() (alem de zerados com
  Nil), evitando acumulo de handles de fonte/pincel (recursos de
  GDI) no processo do AppServer a cada fatura gerada.

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003PDF(oDados)

    Local oPrint
    Local oFontTit
    Local oFontFat
    Local oFontSec
    Local oFontLbl
    Local aItens    := XFAT003GET(oDados, "Itens", {})

    Local nCorFaixa := RGB(031, 056, 100)
    Local nCorCinza := RGB(217, 217, 217)
    Local oBrushFaixa
    Local oBrushCinza

    Local nLargPag := 595
    Local nEsq := 15
    Local nMargDir := 40
    Local nDir := nLargPag - nMargDir
    Local nLin := 15
    Local nX
    Local nAltItens

    Local nAltCab    := 90
    Local nLargNavy  := 190
    Local nColDiv    := nEsq + nLargNavy + Int((nDir - nEsq - nLargNavy) / 2)
    Local nAltTpLoc  := 36

    Local nCharsDescr:= Int(200 / 4.5)
    Local nLinDescr
    Local nAltRow
    Local nLinItem
    Local nCorZebra  := RGB(244, 244, 244)
    Local nCorPagar  := RGB(33, 33, 33)
    Local oBrushZebra
    Local oBrushPagar

    Local oFontDest
    Local cTxtDisc
    Local cObsMenNota := cValToChar(XFAT003GET(oDados, "ObsMenNota", ""))
    Local cObsXMsgI   := cValToChar(XFAT003GET(oDados, "ObsXMsgI", ""))
    Local nLargObs
    Local nCharsLinha
    Local nAltDisc   := 34
    Local nAltObs
    Local nLinObs
    Local nLinhas
    Local cTextoDest

    Local cNumFatura := cValToChar(XFAT003GET(oDados, "NumFatura", ""))
    Local dEmissao   := XFAT003GET(oDados, "Emissao", Date())
    Local dVencim    := XFAT003GET(oDados, "Vencimento", Date())
    Local cCondicao  := cValToChar(XFAT003GET(oDados, "Condicao", ""))

    Local cCliNome   := cValToChar(XFAT003GET(oDados, "ClienteNome", ""))
    Local cCliCgc    := cValToChar(XFAT003GET(oDados, "ClienteCgc", ""))
    Local cCliMun    := cValToChar(XFAT003GET(oDados, "ClienteMun", ""))
    Local cCliEst    := cValToChar(XFAT003GET(oDados, "ClienteEst", ""))
    Local cCliEnd    := cValToChar(XFAT003GET(oDados, "ClienteEnd", ""))

    Local cNFRelac   := cValToChar(XFAT003GET(oDados, "NFRelac", ""))
    Local cPedido    := cValToChar(XFAT003GET(oDados, "Pedido", ""))
    Local dDtPedido  := XFAT003GET(oDados, "DtPedido", Date())
    Local cPlaca     := cValToChar(XFAT003GET(oDados, "Placa", ""))
    Local cTpCobr    := cValToChar(XFAT003GET(oDados, "TpCobranca", ""))
    Local cLocalEnt  := cValToChar(XFAT003GET(oDados, "LocalEntr", ""))

    Local cBanco     := cValToChar(XFAT003GET(oDados, "Banco", ""))
    Local cAgencia   := cValToChar(XFAT003GET(oDados, "Agencia", ""))
    Local cConta     := cValToChar(XFAT003GET(oDados, "Conta", ""))
    Local cPix       := cValToChar(XFAT003GET(oDados, "Pix", ""))
    Local cFavorecido:= cValToChar(XFAT003GET(oDados, "Favorecido", ""))

    Local cEmitNome   := cValToChar(XFAT003GET(oDados, "EmitNome", ""))
    Local cEmitCgc    := cValToChar(XFAT003GET(oDados, "EmitCgc", ""))
    Local cEmitBairro := cValToChar(XFAT003GET(oDados, "EmitBairro", ""))
    Local cEmitUf     := cValToChar(XFAT003GET(oDados, "EmitUf", ""))

    Local nValorTot  := XFAT003GET(oDados, "ValorTotal", 0)
    Local nRetencoes := XFAT003GET(oDados, "Retencoes", 0)
    Local nValorPag  := XFAT003GET(oDados, "ValorPagar", 0)

    oFontTit  := TFont():New("Arial", , 16, .T.)
    oFontFat  := TFont():New("Arial", , 13, .T.)
    oFontSec  := TFont():New("Arial", , 10, .T.)
    oFontLbl  := TFont():New("Arial", , 8)
    oFontDest := TFont():New("Arial", , 8, .T.)

    oBrushFaixa := TBrush():New(, nCorFaixa)
    oBrushCinza := TBrush():New(, nCorCinza)
    oBrushZebra := TBrush():New(, nCorZebra)
    oBrushPagar := TBrush():New(, nCorPagar)

    oPrint := FWMSPrinter():New(FWTimeStamp(1), IMP_PDF, .F., , .T.)
    oPrint:SetResolution(72)
    oPrint:SetPortrait()
    oPrint:SetPaperSize(DMPAPER_A4)
    oPrint:SetMargin(40, 40, 40, 40)
    oPrint:cPathPDF := GetTempPath()

    oPrint:StartPage()

    oPrint:FillRect({nLin, nEsq, nLin + nAltCab, nEsq + nLargNavy}, oBrushFaixa)
    oPrint:SayAlign(nLin + 20, nEsq + 5, cEmitNome, oFontTit, nLargNavy - 10, 50, CLR_WHITE, 2, 1)

    oPrint:Box(nLin, nEsq + nLargNavy, nLin + nAltCab, nDir)
    oPrint:Line(nLin + 30, nEsq + nLargNavy, nLin + 30, nDir)
    oPrint:Line(nLin + 60, nEsq + nLargNavy, nLin + 60, nDir)
    oPrint:Line(nLin + 30, nColDiv, nLin + nAltCab, nColDiv)
    oPrint:SayAlign(nLin + 6, nEsq + nLargNavy + 5, "FATURA DE COBRANCA", oFontFat, nDir - nEsq - nLargNavy - 10, 24, CLR_BLACK, 2, 1)
    oPrint:SayAlign(nLin + 34, nEsq + nLargNavy + 5, "No da Fatura: " + cNumFatura, oFontLbl, nColDiv - nEsq - nLargNavy - 10, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 34, nColDiv + 5, "Emissao: " + DtoC(dEmissao), oFontLbl, nDir - nColDiv - 10, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 64, nEsq + nLargNavy + 5, "Vencimento: " + DtoC(dVencim), oFontLbl, nColDiv - nEsq - nLargNavy - 10, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 64, nColDiv + 5, "Condicao: " + cCondicao, oFontLbl, nDir - nColDiv - 10, 15, CLR_BLACK, 0, 1)
    nLin += nAltCab

    oPrint:FillRect({nLin, nEsq, nLin + 15, nDir}, oBrushCinza)
    oPrint:SayAlign(nLin + 2, nEsq + 5, cEmitNome + "  |  CNPJ: " + XFAT003MASK(cEmitCgc) + "  |  " + cEmitBairro + "/" + cEmitUf, oFontLbl, nDir - nEsq - 10, 10, CLR_BLACK, 2, 1)
    nLin += 20

    oPrint:FillRect({nLin, nEsq, nLin + 18, nDir}, oBrushFaixa)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "DESTINATARIO", oFontSec, nDir - nEsq - 10, 12, CLR_WHITE, 0, 1)
    nLin += 18

    oPrint:Box(nLin, nEsq, nLin + 72, nDir)
    oPrint:Line(nLin + 20, nEsq, nLin + 20, nDir)
    oPrint:Line(nLin + 40, nEsq, nLin + 40, nDir)
    oPrint:Line(nLin + 20, nEsq + 248, nLin + 40, nEsq + 248)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "Razao Social: " + cCliNome, oFontLbl, nDir - nEsq - 10, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 22, nEsq + 5, "CNPJ/CPF: " + XFAT003MASK(cCliCgc), oFontLbl, 240, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 22, nEsq + 252, "Cidade/UF: " + cCliMun + "/" + cCliEst, oFontLbl, 240, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 42, nEsq + 5, "Endereco: " + cCliEnd, oFontLbl, nDir - nEsq - 10, 28, CLR_BLACK, 0, 1)
    nLin += 74

    oPrint:FillRect({nLin, nEsq, nLin + 18, nDir}, oBrushFaixa)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "REFERENCIA DA OPERACAO", oFontSec, nDir - nEsq - 10, 12, CLR_WHITE, 0, 1)
    nLin += 18

    oPrint:Box(nLin, nEsq, nLin + 20, nDir)
    oPrint:Line(nLin, nEsq + 125 , nLin + 20, nEsq + 125)
    oPrint:Line(nLin, nEsq + 250, nLin + 20, nEsq + 250)
    oPrint:Line(nLin, nEsq + 362, nLin + 20, nEsq + 362)
    oPrint:SayAlign(nLin + 3, nEsq + 5, "NF relacionada: " + cNFRelac, oFontLbl, 118, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 3, nEsq + 130, "Pedido: " + cPedido, oFontLbl, 118, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 3, nEsq + 255, "Data: " + DtoC(dDtPedido), oFontLbl, 105, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 3, nEsq + 368, "Placa/Conjunto: " + cPlaca, oFontLbl, 112, 15, CLR_BLACK, 0, 1)
    nLin += 20

    oPrint:Box(nLin, nEsq, nLin + nAltTpLoc, nEsq + 245)
    oPrint:Box(nLin, nEsq + 245, nLin + nAltTpLoc, nDir)
    oPrint:SayAlign(nLin + 3, nEsq + 5, "Tipo de cobranca: " + cTpCobr, oFontLbl, 235, nAltTpLoc - 6, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 3, nEsq + 250, "Local de entrega: " + cLocalEnt, oFontLbl, nDir - nEsq - 255, nAltTpLoc - 6, CLR_BLACK, 0, 1)
    nLin += nAltTpLoc

    oPrint:FillRect({nLin, nEsq, nLin + 18, nDir}, oBrushFaixa)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "Item"                 , oFontSec, 30, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 38, "Descricao"            , oFontSec, 200, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 248, "Qtd."                 , oFontSec, 47, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 303, "Valor Unitario (R$)"  , oFontSec, 92, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 403, "Valor Total (R$)"     , oFontSec, 92, 12, CLR_WHITE, 0, 1)
    nLin += 18

    nAltItens := 0
    For nX := 1 To Len(aItens)
        nLinDescr := Int((Len(cValToChar(aItens[nX, 2])) - 1) / nCharsDescr) + 1
        nAltRow   := Max(15, (nLinDescr * 12) + 3)
        nAltItens += nAltRow
    Next nX
    If Len(aItens) == 0
        nAltItens := 15
    EndIf

    oPrint:Box(nLin, nEsq, nLin + nAltItens, nDir)
    oPrint:Line(nLin, nEsq + 35 , nLin + nAltItens, nEsq + 35)
    oPrint:Line(nLin, nEsq + 245, nLin + nAltItens, nEsq + 245)
    oPrint:Line(nLin, nEsq + 300, nLin + nAltItens, nEsq + 300)
    oPrint:Line(nLin, nEsq + 400, nLin + nAltItens, nEsq + 400)

    nLinItem := nLin

    For nX := 1 To Len(aItens)
        nLinDescr := Int((Len(cValToChar(aItens[nX, 2])) - 1) / nCharsDescr) + 1
        nAltRow   := Max(15, (nLinDescr * 12) + 3)

        If nX % 2 == 0
            oPrint:FillRect({nLinItem, nEsq, nLinItem + nAltRow, nDir}, oBrushZebra)
            oPrint:Line(nLinItem, nEsq + 35 , nLinItem + nAltRow, nEsq + 35)
            oPrint:Line(nLinItem, nEsq + 245, nLinItem + nAltRow, nEsq + 245)
            oPrint:Line(nLinItem, nEsq + 300, nLinItem + nAltRow, nEsq + 300)
            oPrint:Line(nLinItem, nEsq + 400, nLinItem + nAltRow, nEsq + 400)
        EndIf

        oPrint:SayAlign(nLinItem + 2, nEsq + 5, cValToChar(aItens[nX, 1]), oFontLbl, 30, nAltRow - 3, CLR_BLACK, 0, 1)
        oPrint:SayAlign(nLinItem + 2, nEsq + 38, cValToChar(aItens[nX, 2]), oFontLbl, 200, nAltRow - 3, CLR_BLACK, 0, 1)
        oPrint:SayAlign(nLinItem + 2, nEsq + 248, Transform(aItens[nX, 3], "@E 999,999.99"), oFontLbl, 47, nAltRow - 3, CLR_BLACK, 0, 1)
        oPrint:SayAlign(nLinItem + 2, nEsq + 303, Transform(aItens[nX, 4], "@E 999,999.99"), oFontLbl, 92, nAltRow - 3, CLR_BLACK, 0, 1)
        oPrint:SayAlign(nLinItem + 2, nEsq + 403, Transform(aItens[nX, 6], "@E 999,999.99"), oFontLbl, 92, nAltRow - 3, CLR_BLACK, 0, 1)

        nLinItem += nAltRow
    Next nX

    nLin += nAltItens
    nLin += 5

    oPrint:Box(nLin, nEsq + 250, nLin + 45, nDir)
    oPrint:Line(nLin + 15, nEsq + 250, nLin + 15, nDir)
    oPrint:SayAlign(nLin + 2, nEsq + 255, "Valor total: ", oFontLbl, 155, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 430, "R$ " + Transform(nValorTot, "@E 999,999.99"), oFontLbl, 100, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 18, nEsq + 255, "Retencoes/descontos: ", oFontLbl, 155, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 18, nEsq + 430, "R$ " + Transform(nRetencoes, "@E 999,999.99"), oFontLbl, 100, 12, CLR_BLACK, 0, 1)

    oPrint:FillRect({nLin + 30, nEsq + 250, nLin + 45, nDir}, oBrushPagar)
    oPrint:SayAlign(nLin + 32, nEsq + 255, "VALOR A PAGAR: ", oFontSec, 155, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 32, nEsq + 430, "R$ " + Transform(nValorPag, "@E 999,999.99"), oFontSec, 100, 12, CLR_WHITE, 0, 1)
    oPrint:Line(nLin + 45, nEsq + 250, nLin + 45, nDir)
    oPrint:Line(nLin + 30, nEsq + 250, nLin + 45, nEsq + 250)
    oPrint:Line(nLin + 30, nDir, nLin + 45, nDir)
    nLin += 50

    oPrint:FillRect({nLin, nEsq, nLin + 18, nDir}, oBrushFaixa)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "DADOS PARA PAGAMENTO", oFontSec, nDir - nEsq - 10, 12, CLR_WHITE, 0, 1)
    nLin += 18

    oPrint:Box(nLin, nEsq, nLin + 55, nDir)
    oPrint:Line(nLin + 18, nEsq, nLin + 18, nDir)
    oPrint:Line(nLin + 35, nEsq, nLin + 35, nDir)
    oPrint:Line(nLin, nEsq + 175 , nLin + 18, nEsq + 175)
    oPrint:Line(nLin, nEsq + 338, nLin + 18, nEsq + 338)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "Banco: " + cBanco, oFontLbl, 168, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 180, "Agencia: " + cAgencia, oFontLbl, 155, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 342, "Conta: " + cConta, oFontLbl, 155, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 20, nEsq + 5, "PIX: " + cPix, oFontLbl, nDir - nEsq - 10, 12, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 38, nEsq + 5, "Favorecido: " + cFavorecido, oFontLbl, nDir - nEsq - 10, 12, CLR_BLACK, 0, 1)
    nLin += 58

    oPrint:FillRect({nLin, nEsq, nLin + 18, nDir}, oBrushFaixa)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "OBSERVACOES", oFontSec, nDir - nEsq - 10, 12, CLR_WHITE, 0, 1)
    nLin += 18

    cTxtDisc  := "Documento emitido exclusivamente para fins de cobranca comercial. Esta fatura nao possui valor fiscal e nao substitui Nota Fiscal, CT-e ou qualquer outro documento fiscal."
    nLargObs  := nDir - nEsq - 10
    nCharsLinha := Int(nLargObs / 4.5)
    nAltObs   := nAltDisc

    If !Empty(cObsMenNota)
        cTextoDest := "Mensagem: " + cObsMenNota
        nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
        nAltObs    += (nLinhas * 12) + 4
    EndIf

    If !Empty(cObsXMsgI)
        cTextoDest := "Obs. Adicional: " + cObsXMsgI
        nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
        nAltObs    += (nLinhas * 12) + 4
    EndIf

    oPrint:Box(nLin, nEsq, nLin + nAltObs, nDir)
    oPrint:SayAlign(nLin + 3, nEsq + 5, cTxtDisc, oFontLbl, nLargObs, nAltDisc - 4, CLR_BLACK, 0, 1)
    nLinObs := nLin + nAltDisc

    If !Empty(cObsMenNota)
        cTextoDest := "Mensagem: " + cObsMenNota
        nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
        oPrint:SayAlign(nLinObs + 2, nEsq + 5, cTextoDest, oFontDest, nLargObs, nLinhas * 12, CLR_BLACK, 0, 1)
        nLinObs    += (nLinhas * 12) + 4
    EndIf

    If !Empty(cObsXMsgI)
        cTextoDest := "Obs. Adicional: " + cObsXMsgI
        nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
        oPrint:SayAlign(nLinObs + 2, nEsq + 5, cTextoDest, oFontDest, nLargObs, nLinhas * 12, CLR_BLACK, 0, 1)
        nLinObs    += (nLinhas * 12) + 4
    EndIf

    nLin += nAltObs

    oPrint:EndPage()
    oPrint:Preview()
    ms_flush()

    FreeObj(oPrint)
    FreeObj(oFontTit)
    FreeObj(oFontFat)
    FreeObj(oFontSec)
    FreeObj(oFontLbl)
    FreeObj(oFontDest)
    FreeObj(oBrushFaixa)
    FreeObj(oBrushCinza)
    FreeObj(oBrushZebra)
    FreeObj(oBrushPagar)

    oPrint      := Nil
    oFontTit    := Nil
    oFontFat    := Nil
    oFontSec    := Nil
    oFontLbl    := Nil
    oFontDest   := Nil
    oBrushFaixa := Nil
    oBrushCinza := Nil
    oBrushZebra := Nil
    oBrushPagar := Nil

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003BOL()

  Descricao:
  Gera o(s) titulo(s) financeiro(s) (SE1) do pedido para
  possibilitar a emissao do boleto, apos o usuario confirmar
  em U_XFAT003(). Antes de gerar qualquer coisa, verifica se ja
  existe titulo (E1_PREFIXO=FAT/E1_NUM=pedido) para este pedido
  e, se existir, aborta sem duplicar. O valor a receber
  (ValorPagar da fatura) e
  desdobrado em parcelas atraves da funcao padrao Condicao(),
  conforme a condicao de pagamento do pedido (SC5->C5_CONDPAG),
  com data base dDataBase tanto para a emissao quanto para o
  calculo das parcelas. Cada parcela retornada por Condicao()
  gera um titulo via FINA040 (MsExecAuto), com E1_PREFIXO fixo
  "FAT", E1_NUM igual ao numero do pedido (SC5->C5_NUM) e
  E1_TIPO "BOL". O codigo do campo de natureza financeira a
  gravar (E1_NATUREZ) e definido dinamicamente pelo parametro
  MV_1DUPNAT, que contem a expressao completa do campo a ser
  lido, ja com o alias (por exemplo SC5->C5_NATUREZ ou
  SA1->A1_NATUREZ), resolvida em tempo de execucao via
  substituicao de macro; o codigo resolvido e conferido contra o
  cadastro de Natureza Financeira (SED) antes de acionar o
  FINA040, evitando repassar uma natureza inexistente/invalida
  para dentro do ExecAuto. E1_EMISSAO usa dDtBase (dDataBase do
  sistema, com fallback para Date() quando vazia, evitando um
  valor de tipo indefinido no array do MsExecAuto). Tambem sao
  gravados E1_MOEDA (fixo 1) e E1_HIST (historico com o numero
  do pedido), presentes nos exemplos oficiais de ExecAuto do
  FINA040. Sao tambem gravados E1_PORTADO/E1_AGEDEP/E1_CONTA
  (banco/agencia/conta), obtidos do mesmo parametro MV_XBANKBO
  usado por XFAT003BOR() para o bordero - sem esses campos ja
  preenchidos no titulo, o FINA060 nao localiza o titulo entre
  os elegiveis para o bordero (erro AJUDA:RECNO "Nao existem
  registros no arquivo em pauta"). Cada chave gravada em aTitBord
  (E1_FILIAL/E1_PREFIXO/E1_NUM/E1_PARCELA/E1_TIPO) e preenchida
  com PadR() no tamanho exato do respectivo campo da SE1, ja que
  E1_NUM (C5_NUM do pedido) pode vir mais curto que o tamanho
  cadastrado do campo (ex.: 9), e o FINA060 e o MsSeek na SEA em
  XFAT003BXB() dependem da chave com o tamanho fixo exato para
  localizar o titulo. Ao final, aciona XFAT003BOR() para gerar o
  bordero e o download automatico do(s) boleto(s).

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003BOL(oDados)

    Local nValorPag := XFAT003GET(oDados, "ValorPagar", 0)
    Local cCondPag  := AllTrim(cValToChar(SC5->C5_CONDPAG))
    Local cCampoNat := AllTrim(SuperGetMV("MV_1DUPNAT", .F., "SC5->C5_NATUREZ"))
    Local cNatureza := ""
    Local dDtBase   := IIf(!Empty(dDataBase), dDataBase, Date())
    Local aVenc     := {}
    Local aTitBord  := {}
    Local aArray    := {}
    Local cPrefixo  := PadR("FAT", FWTamSX3("E1_PREFIXO")[1])
    Local cTipo     := PadR("BOL", FWTamSX3("E1_TIPO")[1])
    Local cHist     := SubStr("Fatura de Cobranca - Pedido " + AllTrim(SC5->C5_NUM), 1, FWTamSX3("E1_HIST")[1])
    Local cParcela  := ""
    Local cAlias    := ""
    Local aBankBol  := {}
    Local cBankTit  := ""
    Local cAgenTit  := ""
    Local cContTit  := ""
    Local nX

    Private lMsErroAuto    := .F.
    Private lMsHelpAuto    := .T.
    Private lAutoErrNoFile := .T.

    aBankBol := StrTokArr(SuperGetMV("MV_XBANKBO", .F., ""), "/")

    If Len(aBankBol) < 4
        MsgAlert("Parametro MV_XBANKBO nao configurado corretamente (banco/agencia/conta/subconta). Boleto nao gerado.", "Fatura de Cobranca")
        Return
    EndIf

    cBankTit := PadR(aBankBol[1], FWTamSX3("E1_PORTADO")[1])
    cAgenTit := PadR(aBankBol[2], FWTamSX3("E1_AGEDEP")[1])
    cContTit := PadR(aBankBol[3], FWTamSX3("E1_CONTA")[1])

    cAlias := GetNextAlias()

    BeginSql Alias cAlias
        SELECT COUNT(*) AS QTDTIT
        FROM %table:SE1% SE1
        WHERE SE1.%notDel%
          AND SE1.E1_FILIAL  = %exp:xFilial("SE1")%
          AND SE1.E1_PREFIXO = %exp:cPrefixo%
          AND SE1.E1_NUM     = %exp:SC5->C5_NUM%
    EndSql

    If (cAlias)->QTDTIT > 0
        (cAlias)->(DbCloseArea())
        MsgAlert("Ja existe titulo gerado para o pedido " + AllTrim(SC5->C5_NUM) + ". Boleto nao sera gerado novamente.", "Fatura de Cobranca")
        Return
    EndIf

    (cAlias)->(DbCloseArea())

    If Empty(cCampoNat)
        cCampoNat := "SC5->C5_NATUREZ"
    EndIf

    If Type(cCampoNat) != "U"
        cNatureza := AllTrim(cValToChar(&cCampoNat))
    EndIf

    If Empty(cNatureza)
        MsgAlert("Natureza financeira nao encontrada na expressao " + cCampoNat + " (parametro MV_1DUPNAT). Boleto nao gerado.", "Fatura de Cobranca")
        Return
    EndIf

    DbSelectArea("SED")
    DbSetOrder(1)
    If !DbSeek(xFilial("SED") + cNatureza)
        MsgAlert("A natureza financeira " + cNatureza + " (resolvida via MV_1DUPNAT) nao foi encontrada no cadastro de Natureza Financeira (SED). Verifique o cadastro antes de gerar o boleto.", "Fatura de Cobranca")
        Return
    EndIf

    If Empty(cCondPag)
        MsgAlert("Pedido sem condicao de pagamento (C5_CONDPAG). Boleto nao gerado.", "Fatura de Cobranca")
        Return
    EndIf

    aVenc := Condicao(nValorPag, cCondPag, , dDtBase)

    If Len(aVenc) == 0
        MsgAlert("Nao foi possivel calcular as parcelas para a condicao de pagamento " + cCondPag + ".", "Fatura de Cobranca")
        Return
    EndIf

    For nX := 1 To Len(aVenc)

        cParcela := StrZero(nX, FWTamSX3("E1_PARCELA")[1])

        aArray := { ;
            {"E1_FILIAL"  , xFilial("SE1")   , NIL},;
            {"E1_PREFIXO" , cPrefixo         , NIL},;
            {"E1_NUM"     , SC5->C5_NUM      , NIL},;
            {"E1_PARCELA" , cParcela         , NIL},;
            {"E1_TIPO"    , cTipo            , NIL},;
            {"E1_NATUREZ" , cNatureza        , NIL},;
            {"E1_CLIENTE" , SC5->C5_CLIENTE  , NIL},;
            {"E1_LOJA"    , SC5->C5_LOJACLI  , NIL},;
            {"E1_EMISSAO" , dDtBase          , NIL},;
            {"E1_VENCTO"  , aVenc[nX][1]     , NIL},;
            {"E1_VENCREA" , aVenc[nX][1]     , NIL},;
            {"E1_VALOR"   , aVenc[nX][2]     , NIL},;
            {"E1_MOEDA"   , 1                , NIL},;
            {"E1_HIST"    , cHist            , NIL},;
            {"E1_PORTADO" , cBankTit         , NIL},;
            {"E1_AGEDEP"  , cAgenTit         , NIL},;
            {"E1_CONTA"   , cContTit         , NIL}}

        lMsErroAuto := .F.

        MsExecAuto({|x,y| FINA040(x,y)}, aArray, 3)

        If lMsErroAuto
            XFAT003LOG()
            Return
        EndIf

        aAdd(aTitBord, {{"E1_FILIAL" , PadR(xFilial("SE1"), FWTamSX3("E1_FILIAL")[1])},;
                        {"E1_PREFIXO", PadR(cPrefixo, FWTamSX3("E1_PREFIXO")[1])},;
                        {"E1_NUM"    , PadR(SC5->C5_NUM, FWTamSX3("E1_NUM")[1])},;
                        {"E1_PARCELA", PadR(cParcela, FWTamSX3("E1_PARCELA")[1])},;
                        {"E1_TIPO"   , PadR(cTipo, FWTamSX3("E1_TIPO")[1])} })

    Next nX

    If Len(aTitBord) > 0
        XFAT003BOR(aTitBord)
    EndIf

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003BOR() - (Baseada na fnGerBor do XFAT001)

  Descricao:
  Gera o bordero automaticamente para o(s) titulo(s) recem
  criados pela XFAT003BOL(), usando o banco/agencia/conta/
  subconta configurados no parametro MV_XBANKBO - o mesmo
  parametro que o XFAT001 usa para a emissao do boleto a
  partir da Nota Fiscal, dispensando nova busca de banco na
  SA6 por A6_XFATUR. Banco, agencia e conta sao preenchidos com
  PadR() no tamanho dos campos correspondentes da SEA
  (EA_PORTADO/EA_AGEDEP/EA_NUMCON), da mesma forma que a
  subconta (EA_SUBCTA), evitando gravar no aRegBor/bordero uma
  string de tamanho divergente do cadastro. Ao final, aciona
  XFAT003BXB() para o download automatico do(s) boleto(s), sem
  exibir nenhuma tela ao usuario.

  @author Raphael Neves (Hubvision)
  @since  20/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003BOR(aTitBord)

    Local aBankBol := StrTokArr(SuperGetMV("MV_XBANKBO", .F., ""), "/")
    Local cBank    := ""
    Local cAgenc   := ""
    Local cContCC  := ""
    Local cSubCC   := ""
    Local cEspec   := ""
    Local aRegBor  := {}
    Local cNumBor  := ""

    Private lMsErroAuto    := .F.
    Private lMsHelpAuto    := .T.
    Private lAutoErrNoFile := .T.

    If Len(aBankBol) < 4
        MsgAlert("Parametro MV_XBANKBO nao configurado corretamente (banco/agencia/conta/subconta). Bordero nao gerado.", "Fatura de Cobranca")
        Return
    EndIf

    cBank   := PadR(aBankBol[1], FWTamSX3("EA_PORTADO")[1])
    cAgenc  := PadR(aBankBol[2], FWTamSX3("EA_AGEDEP")[1])
    cContCC := PadR(aBankBol[3], FWTamSX3("EA_NUMCON")[1])
    cSubCC  := PadR(aBankBol[4], FWTamSX3("EA_SUBCTA")[1])

    DbSelectArea("F77")
    If F77->(MsSeek(FWxFilial("F77") + cBank))
        While !F77->(Eof()) .And. F77->F77_BANCO == cBank
            If F77->F77_SIGLA == PadR("DM", FWTamSX3("F77_SIGLA")[1])
                cEspec := F77->F77_ESPECI
                Exit
            EndIf
            F77->(DbSkip())
        End
    EndIf

    aAdd(aRegBor, {"AUTBANCO"   , cBank})
    aAdd(aRegBor, {"AUTAGENCIA" , cAgenc})
    aAdd(aRegBor, {"AUTCONTA"   , cContCC})
    aAdd(aRegBor, {"AUTSITUACA" , PadR("1", FWTamSX3("E1_SITUACA")[1])})
    aAdd(aRegBor, {"AUTNUMBOR"  , PadR("", FWTamSX3("E1_NUMBOR")[1])})
    aAdd(aRegBor, {"AUTSUBCONTA", cSubCC})
    aAdd(aRegBor, {"AUTESPECIE" , cEspec})
    aAdd(aRegBor, {"AUTBOLAPI"  , .T.})

    lMsErroAuto := .F.

    MsExecAuto({|a,b| FINA060(a,b)}, 3, {aRegBor, aTitBord})

    If lMsErroAuto
        XFAT003LOG()
    Else
        cNumBor := SE1->E1_NUMBOR
        F713Transf()
        Sleep(10000)
        XFAT003BXB(aTitBord, cNumBor)
    EndIf

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003LOG() - Exibe log de erro da rotina automatica

  Descricao:
  Substitui a chamada padrao a MostraErro() apos um MsExecAuto()
  retornar com erro (FINA040/FINA060). Como as funcoes XFAT003BOL()
  e XFAT003BOR() declaram lAutoErrNoFile := .T. (para nao gravar o
  log de erro em arquivo), o texto do erro fica retido no buffer
  interno da rotina automatica e MostraErro() e exibida em branco,
  conforme o KB e o TDN informados pelo usuario. Recupera o log via
  GetAutoGRLog(), remove os caracteres de formatacao ("<" e "-") de
  cada linha e apresenta o resultado consolidado atraves de
  FWAlertError(), estilizado com CSS embutido no HTML da mensagem.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003LOG()

    Local aErro    := {}
    Local cLogErro := ""
    Local cHtmlMsg := ""
    Local nCErro

    aErro := GetAutoGRLog()

    For nCErro := 1 To Len(aErro)
        cLogErro += StrTran(StrTran(aErro[nCErro], "<", ""), "-", "") + CRLF
    Next nCErro

    If Empty(cLogErro)
        cLogErro := "Erro na rotina automatica, sem detalhes retornados pelo log (GetAutoGRLog)."
    EndIf

    cHtmlMsg := '<div style="font-family:Arial,sans-serif; font-size:12px; ' + ;
                'color:#B00000; background-color:#FBEAEA; border:1px solid ' + ;
                '#E57373; padding:8px; white-space:pre-wrap;">' + cLogErro + '</div>'

    FWAlertError(cHtmlMsg, "Erro na Rotina Automatica")

    aErro := Nil

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003BXB() - (Baseada na BxBoleto do XFAT001)

  Descricao:
  Realiza o download automatico do(s) boleto(s) gerado(s) pela
  XFAT003BOR(), sem exibir nenhuma tela de selecao ao usuario
  (ao contrario do XFAT002, que exibe uma tela para o usuario
  escolher e imprimir manualmente). Confere na SEA se cada
  titulo foi transmitido/autorizado (EA_TRANSF = "S") antes de
  incluir no pedido de download do PDF.

  @author Raphael Neves (Hubvision)
  @since  20/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003BXB(aTitBord, cNumBor)

    Local aBolAut  := {}
    Local cBody    := ""
    Local oService := Nil
    Local cDirLoc  := GetTempPath(.T., .F.)
    Local cBarra   := IIf(IsSrvUnix(), "/", "\")
    Local cDirSer  := cBarra + "spool" + cBarra + "boletos" + cBarra + cEmpAnt + cBarra
    Local nBolNot  := 0
    Local nY

    DbSelectArea("SEA")
    SEA->(DbSetOrder(1))

    For nY := 1 To Len(aTitBord)
        If SEA->(MsSeek(xFilial("SEA") + cNumBor + aTitBord[nY][2][2] + aTitBord[nY][3][2] + aTitBord[nY][4][2] + aTitBord[nY][5][2]))
            If SEA->EA_TRANSF == "S"
                aAdd(aBolAut, {aTitBord[nY][1][2],;
                               aTitBord[nY][2][2],;
                               aTitBord[nY][3][2],;
                               aTitBord[nY][4][2],;
                               aTitBord[nY][5][2]})
            Else
                ++nBolNot
            EndIf
        EndIf
    Next nY

    If nBolNot == Len(aTitBord)
        MsgAlert('Nenhum boleto foi autorizado, por favor verificar o status do(s) boleto(s) na opcao "Outras Acoes -> Boleto".', "Boleto nao autorizado")
        Return
    ElseIf nBolNot > 0
        MsgAlert('Existe boleto(s) nao autorizado(s), por favor verificar o status do boleto na opcao "Outras Acoes -> Boleto".', "Boleto nao autorizado")
    EndIf

    oService := gfin.api.banks.bills.BanksBillsService():New()

    cBody := '{ "bills": [ '
    For nY := 1 To Len(aBolAut)
        cBody += '{' +;
              '"ea_filial": "'  + aBolAut[nY][1] + '",' + ;
              '"ea_numbor": "'  + cNumBor        + '",' + ;
              '"ea_prefixo": "' + aBolAut[nY][2] + '",' + ;
              '"ea_num": "'     + aBolAut[nY][3] + '",' + ;
              '"ea_parcela": "' + aBolAut[nY][4] + '",' + ;
              '"ea_tipo": "'    + aBolAut[nY][5] + '"'  + ;
              IIf(nY < Len(aBolAut), '},', '}')
    Next nY
    cBody += ']}'

    oService:downloadPdf(cBody, .T.)
    If oService:lOk
        If !(CopyFile(cDirSer + oService:cPathPDF, cDirLoc + "\" + oService:cPathPDF))
            MsgStop("Erro na criacao do arquivo " + oService:cPathPDF + ", por favor tente novamente!", "Atencao")
        Else
            ShellExecute("Open", cDirLoc + "\" + oService:cPathPDF, "/RUN /TN SPARK", cDirLoc, 1)
            FErase(cDirSer + oService:cPathPDF)
        EndIf
    Else
        MsgStop('Ocorreu um erro na impressao automatica do(s) boleto(s), por favor realize a impressao atraves da opcao "Outras Acoes -> Boleto".', "Impressao de Boleto")
    EndIf

    FreeObj(oService)
    oService := Nil

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFATBOL() - Reimpressao/Download de Boleto

  Descricao:
  Tela de reimpressao/download de boleto(s) gerados por
  XFAT003BOL()/XFAT003BOR(), no mesmo padrao (FWTemporaryTable +
  FWMarkBrowse + FWDialogModal) da tela de boleto do XFAT002
  (referencia XFAT002.prw). Acionada pela opcao "Outras Acoes ->
  Fatura -> Imprimir Boleto" do Pedido de Venda (Ponto de
  Entrada MA410MNU, que chama U_XFATBOL). Nao solicita nenhum
  parametro ao usuario (ParamBox); considera diretamente o
  Pedido de Venda posicionado (SC5->C5_NUM). A tabela temporaria
  (alias em Private cAliasBrw) e populada por XFAT003TAB() a
  partir da SEA (mesmos filtros do XFAT002: EA_CART="R" e
  EA_BORAPI="S"), restrita a EA_PREFIXO="FAT" e EA_NUM igual ao
  pedido posicionado. O usuario marca um ou mais boletos e aciona
  "Reimprimir" (XFAT003BX2, mesma logica da BxBoleto do XFAT002,
  usando o numero de bordero de cada linha marcada). As colunas
  de status (verde/azul/vermelho) e o detalhe do erro usam
  XFAT003STA()/XFAT003ERR() (equivalentes a BrwStatus/BrwVisErr
  do XFAT002).

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
User Function XFATBOL()

    Local oDialog, oPanel
    Local cMarca   := "X"
    Local aColsBrw := {}
    Local aColsSX3 := {}
    Local aFields  := {}
    Local aSeek    := {}
    Local nY

    Private oTabTMP, oMarkBrowse
    Private cAliasBrw := GetNextAlias()

    If Empty(SC5->C5_NUM)
        MsgAlert("Posicione um Pedido de Venda antes de reimprimir o Boleto.", "Reimpressao de Boleto")
        Return
    EndIf

    oTabTMP := FWTemporaryTable():New(cAliasBrw)

    AAdd(aColsBrw, {BuscarSX3('EA_FILIAL' ,,aColsSX3), "TP_FILIAL" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.F.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_NUMBOR' ,,aColsSX3), "TP_NUMBOR" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_PORTADO',,aColsSX3), "TP_PORTADO",'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_AGEDEP' ,,aColsSX3), "TP_AGEDEP" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_NUMCON' ,,aColsSX3), "TP_NUMCON" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_PREFIXO',,aColsSX3), "TP_PREFIXO",'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.F.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_NUM'    ,,aColsSX3), "TP_NUM"    ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_PARCELA',,aColsSX3), "TP_PARCELA",'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_TIPO'   ,,aColsSX3), "TP_TIPO"   ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})
    AAdd(aColsBrw, {BuscarSX3('EA_TRANSF' ,,aColsSX3), "TP_TRANSF" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1})

    aAdd(aFields, {"TP_MARK"   ,"C",1,0})
    aAdd(aFields, {'TP_FILIAL' ,"C",FWTamSX3("EA_FILIAL")[1] ,FWTamSX3("EA_FILIAL")[2] ,"Filial"      ,"",""})
    aAdd(aFields, {'TP_NUMBOR' ,"C",FWTamSX3("EA_NUMBOR")[1] ,FWTamSX3("EA_NUMBOR")[2] ,"Bordero"     ,"",""})
    aAdd(aFields, {'TP_PORTADO',"C",FWTamSX3("EA_PORTADO")[1],FWTamSX3("EA_PORTADO")[2],"Banco"       ,"",""})
    aAdd(aFields, {'TP_AGEDEP' ,"C",FWTamSX3("EA_AGEDEP")[1] ,FWTamSX3("EA_AGEDEP")[2] ,"Nro Agencia" ,"",""})
    aAdd(aFields, {'TP_NUMCON' ,"C",FWTamSX3("EA_NUMCON")[1] ,FWTamSX3("EA_NUMCON")[2] ,"Nro Conta"   ,"",""})
    aAdd(aFields, {'TP_PREFIXO',"C",FWTamSX3("EA_PREFIXO")[1],FWTamSX3("EA_PREFIXO")[2],"Prefixo"     ,"",""})
    aAdd(aFields, {'TP_NUM'    ,"C",FWTamSX3("EA_NUM")[1]    ,FWTamSX3("EA_NUM")[2]    ,"No. Titulo"  ,"",""})
    aAdd(aFields, {'TP_PARCELA',"C",FWTamSX3("EA_PARCELA")[1],FWTamSX3("EA_PARCELA")[2],"Parcela"     ,"",""})
    aAdd(aFields, {'TP_TIPO'   ,"C",FWTamSX3("EA_TIPO")[1]   ,FWTamSX3("EA_TIPO")[2]   ,"Tipo"        ,"",""})
    aAdd(aFields, {'TP_TRANSF' ,"C",FWTamSX3("EA_TRANSF")[1] ,FWTamSX3("EA_TRANSF")[2] ,"Status Trans","",""})

    oTabTMP:SetFields(aFields)
    oTabTMP:AddIndex("1", {"TP_FILIAL","TP_PREFIXO","TP_NUM","TP_PARCELA","TP_TIPO"} )
    oTabTMP:AddIndex("2", {"TP_FILIAL","TP_NUMBOR","TP_PORTADO","TP_AGEDEP","TP_NUMCON"} )
    oTabTMP:AddIndex("3", {"TP_FILIAL","TP_NUMBOR","TP_PREFIXO","TP_NUM","TP_PARCELA","TP_TIPO"} )
    oTabTMP:AddIndex("4", {"TP_FILIAL","TP_NUMBOR","TP_PORTADO","TP_AGEDEP","TP_NUMCON","TP_PREFIXO","TP_NUM","TP_PARCELA","TP_TIPO"} )
    oTabTMP:AddIndex("5", {"TP_TRANSF"} )
    oTabTMP:Create()

    For nY := 3 To Len(aFields)
        aAdd(aSeek, {GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"),"X3_TITULO"), ;
                    { {"", GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_TIPO"), ;
                           GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_TAMANHO"), ;
                           GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_DECIMAL"), ;
                           AllTrim(GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_TITULO")), ;
                           AllTrim(GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_PICTURE"))};
                     } } )
    Next nY

    XFAT003TAB()

    oDialog := FWDialogModal():New()
    oDialog:SetBackground( .T. )
    oDialog:SetTitle( 'Boleto Bancario - Pedido ' + AllTrim(SC5->C5_NUM) )
    oDialog:SetSize( 280, 800 )
    oDialog:EnableFormBar( .T. )
    oDialog:SetCloseButton( .T. )
    oDialog:SetEscClose( .T. )
    oDialog:CreateDialog()
    oDialog:CreateFormBar()
    oDialog:AddButton('Reimprimir', { || FWMsgRun(Nil, {|| XFAT003BX2()}, "Aguarde...", "Reimprimindo Boleto...") },,2,0)

    oPanel := oDialog:GetPanelMain()
        oMarkBrowse := FWMarkBrowse():New()
        oMarkBrowse:SetDescription("")
        oMarkBrowse:SetFields(aColsBrw)
        oMarkBrowse:SetTemporary(.T.)
        oMarkBrowse:SetAlias(cAliasBrw)
        oMarkBrowse:AddFilter("Autorizado", 'TP_TRANSF == "S"',,.F.,,.T.)
        oMarkBrowse:AddFilter("Aguardando Transmissao", 'TP_TRANSF == ""',,.F.,,.T.)
        oMarkBrowse:AddFilter("Com Erro", 'TP_TRANSF == "F"',,.F.,,.T.)
        oMarkBrowse:AddStatusColumns( { || XFAT003STA() }, { || XFAT003ERR() } )
        oMarkBrowse:SetFieldMark("TP_MARK")
        oMarkBrowse:SetMark(cMarca,cAliasBrw,"TP_MARK")
        oMarkBrowse:SetAllMark({ || XFAT003MRK() })
        oMarkBrowse:SetValid({ || XFAT003VLM() })
        oMarkBrowse:SetWalkThru(.F.)
        oMarkBrowse:SetSeek(.T.,aSeek)
        oMarkBrowse:SetAmbiente(.F.)
        oMarkBrowse:SetUseFilter(.T.)
        oMarkBrowse:SetMenuDef("XFAT003")
        oMarkBrowse:SetOwner(oPanel)
        oMarkBrowse:DisableReport()
        oMarkBrowse:DisableDetails()
        oMarkBrowse:Activate()
    oDialog:Activate()

    oTabTMP:Delete()
    oMarkBrowse:DeActivate()

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao MenuDef() - Menu MVC da tela XFATBOL

  Descricao:
  Menu da tela de reimpressao de boleto (mesma convencao MVC do
  XFAT002), sem opcoes adicionais: a geracao do boleto ja e feita
  por XFAT003BOL()/XFAT003BOR() a partir da fatura, entao esta
  tela e usada apenas para reimprimir/baixar o PDF (botao
  "Reimprimir" da FWDialogModal).

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function MenuDef()

    Local aRotina := {}

Return aRotina

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003TAB() - Monta a tabela temporaria da XFATBOL

  Descricao:
  Popula a tabela temporaria (cAliasBrw) da tela de reimpressao
  de boleto a partir da SEA, nos mesmos moldes da fDadosTab() do
  XFAT002 (mesmos filtros EA_CART="R" e EA_BORAPI="S"), restrita
  aos boletos gerados por XFAT003BOL() (EA_PREFIXO="FAT") para o
  Pedido de Venda posicionado (SC5->C5_NUM).

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003TAB()

    Local cAliasQry := GetNextAlias()
    Local cQry       := ""

    cQry := " SELECT SEA.EA_FILIAL,SEA.EA_PREFIXO,SEA.EA_NUM,SEA.EA_PARCELA,SEA.EA_TIPO,SEA.EA_PORTADO,SEA.EA_AGEDEP, "
    cQry += "        SEA.EA_NUMCON,SEA.EA_NUMBOR,SEA.EA_TRANSF,SEA.EA_APIMSG "
    cQry += " FROM " + RetSqlName("SEA") + " SEA "
    cQry += " WHERE SEA.D_E_L_E_T_ <> '*' "
    cQry += "   AND SEA.EA_FILIAL  = '" + xFilial("SEA") + "' "
    cQry += "   AND SEA.EA_PREFIXO = '" + PadR("FAT", FWTamSX3("EA_PREFIXO")[1]) + "' "
    cQry += "   AND SEA.EA_NUM     = '" + SC5->C5_NUM + "' "
    cQry += "   AND SEA.EA_CART    = 'R' "
    cQry += "   AND SEA.EA_BORAPI  = 'S' "
    cQry += " ORDER BY SEA.EA_PREFIXO, SEA.EA_NUM, SEA.EA_PARCELA "

    cQry := ChangeQuery(cQry)
    If Select(cAliasQry) <> 0
        (cAliasQry)->(DbCloseArea())
    EndIf
    DbUseArea(.T., "TOPCONN", TcGenQry(,,cQry), cAliasQry, .T., .T.)
    (cAliasQry)->(DbGoTop())

    oTabTMP:Zap()

    While !(cAliasQry)->(Eof())
        RecLock(cAliasBrw, .T.)
            (cAliasBrw)->TP_FILIAL  := (cAliasQry)->EA_FILIAL
            (cAliasBrw)->TP_NUMBOR  := (cAliasQry)->EA_NUMBOR
            (cAliasBrw)->TP_PORTADO := (cAliasQry)->EA_PORTADO
            (cAliasBrw)->TP_AGEDEP  := (cAliasQry)->EA_AGEDEP
            (cAliasBrw)->TP_NUMCON  := (cAliasQry)->EA_NUMCON
            (cAliasBrw)->TP_PREFIXO := (cAliasQry)->EA_PREFIXO
            (cAliasBrw)->TP_NUM     := (cAliasQry)->EA_NUM
            (cAliasBrw)->TP_PARCELA := (cAliasQry)->EA_PARCELA
            (cAliasBrw)->TP_TIPO    := (cAliasQry)->EA_TIPO
            (cAliasBrw)->TP_TRANSF  := (cAliasQry)->EA_TRANSF
        MsUnlock(cAliasBrw)
        (cAliasQry)->(DbSkip())
    EndDo
    (cAliasQry)->(DbCloseArea())
    (cAliasBrw)->(DbGoTop())

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003MRK() - Marca/desmarca todos (equivalente AllMark)

  Descricao:
  Marca ou desmarca todos os boletos autorizados (TP_TRANSF="S")
  da tela de reimpressao de boleto, mesma logica da AllMark() do
  XFAT002.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003MRK()

    DbSelectArea(cAliasBrw)
    (cAliasBrw)->(DbGoTop())
    While (cAliasBrw)->(!Eof())
        If (cAliasBrw)->TP_TRANSF == "S"
            RecLock(cAliasBrw, .F.)
                (cAliasBrw)->TP_MARK := IIf(Empty((cAliasBrw)->TP_MARK), "X", "")
            (cAliasBrw)->(MsUnlock())
        EndIf
    (cAliasBrw)->(DbSkip())
    End

    oMarkBrowse:Refresh(.T.)

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003VLM() - Valida se a linha pode ser marcada (equivalente ValidMark)

  Descricao:
  Impede a marcacao de um boleto ainda nao autorizado
  (TP_TRANSF diferente de "S"), mesma logica da ValidMark() do
  XFAT002.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003VLM()

    Local lRet := .F.

    If (cAliasBrw)->TP_TRANSF == "S"
        lRet := .T.
    EndIf

Return lRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003STA() - Status do registro (equivalente BrwStatus)

  Descricao:
  Retorna a cor da linha da tela de reimpressao de boleto
  conforme SEA.EA_TRANSF (verde=autorizado, azul=aguardando,
  vermelho=erro), mesma logica da BrwStatus() do XFAT002.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003STA()

    Local aArea    := FWGetArea()
    Local aAreaSEA := SEA->(FWGetArea())
    Local cRet     := ""

    DbSelectArea("SEA")
    If SEA->(MsSeek( (cAliasBrw)->TP_FILIAL + (cAliasBrw)->TP_NUMBOR + (cAliasBrw)->TP_PREFIXO + ;
                     (cAliasBrw)->TP_NUM + (cAliasBrw)->TP_PARCELA + (cAliasBrw)->TP_TIPO ))

        Do Case
            Case SEA->EA_TRANSF == "S"
                cRet := "BR_VERDE"
            Case Empty(SEA->EA_TRANSF)
                cRet := "BR_AZUL"
            Case SEA->EA_TRANSF == "F"
                cRet := "BR_VERMELHO"
        EndCase

    EndIf

    FWRestArea(aAreaSEA)
    FWRestArea(aArea)

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003ERR() - Mensagem de erro (equivalente BrwVisErr)

  Descricao:
  Exibe o log de erro (SEA.EA_APILOG) do boleto atualmente
  posicionado na tela de reimpressao, quando SEA.EA_TRANSF="F",
  mesma logica da BrwVisErr() do XFAT002.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003ERR()

    Local aArea    := FWGetArea()
    Local aAreaSEA := SEA->(FWGetArea())

    DbSelectArea("SEA")
    If SEA->(MsSeek( (cAliasBrw)->TP_FILIAL + (cAliasBrw)->TP_NUMBOR + (cAliasBrw)->TP_PREFIXO + ;
                     (cAliasBrw)->TP_NUM + (cAliasBrw)->TP_PARCELA + (cAliasBrw)->TP_TIPO ))

        If SEA->EA_TRANSF == "F"
            FWAlertInfo(AllTrim(SEA->EA_APILOG), "Erro Boleto")
        EndIf

    EndIf

    FWRestArea(aAreaSEA)
    FWRestArea(aArea)

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003BX2() - Reimpressao/download dos boletos marcados (equivalente BxBoleto)

  Descricao:
  Percorre a tabela temporaria da tela de reimpressao de boleto
  e, para cada linha marcada (TP_MARK), monta o corpo da
  requisicao de download usando o numero de bordero da propria
  linha (TP_NUMBOR), permitindo reimprimir boletos de borderos
  diferentes em uma unica chamada. Mesma logica da BxBoleto() do
  XFAT002, usando CopyFile() (nao __CopyFile()) para a copia do
  PDF gerado.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003BX2()

    Local aAreaSEA := SEA->(FWGetArea())
    Local cBody    := ""
    Local oService := Nil
    Local cDirLoc  := GetTempPath(.T., .F.)
    Local cBarra   := IIf(IsSrvUnix(), "/", "\")
    Local cDirSer  := cBarra + "spool" + cBarra + "boletos" + cBarra + cEmpAnt + cBarra
    Local aBoletos := {}
    Local nY

    DbSelectArea(cAliasBrw)

    (cAliasBrw)->(DbGoTop())
    While (cAliasBrw)->(!Eof())
        If !Empty((cAliasBrw)->TP_MARK)
            aAdd( aBoletos, { AllTrim((cAliasBrw)->TP_FILIAL),;
                              AllTrim((cAliasBrw)->TP_NUMBOR),;
                              AllTrim((cAliasBrw)->TP_PREFIXO),;
                              AllTrim((cAliasBrw)->TP_NUM),;
                              AllTrim((cAliasBrw)->TP_PARCELA),;
                              AllTrim((cAliasBrw)->TP_TIPO)  })
        EndIf
    (cAliasBrw)->(DbSkip())
    End

    If Len(aBoletos) == 0
        MsgAlert("Nenhum boleto selecionado.", "Reimpressao de Boleto")
        FWRestArea(aAreaSEA)
        Return
    EndIf

    oService := gfin.api.banks.bills.BanksBillsService():New()

    cBody := '{ "bills": [ '
    For nY := 1 To Len(aBoletos)
        cBody += '{' +;
        '"ea_filial": "'  + aBoletos[nY][1] + '",' + ;
        '"ea_numbor": "'  + aBoletos[nY][2] + '",' + ;
        '"ea_prefixo": "' + aBoletos[nY][3] + '",' + ;
        '"ea_num": "'     + aBoletos[nY][4] + '",' + ;
        '"ea_parcela": "' + aBoletos[nY][5] + '",' + ;
        '"ea_tipo": "'    + aBoletos[nY][6] + '"'  + ;
        IIf(nY < Len(aBoletos), '},', '}')
    Next nY
    cBody += ']}'

    oService:downloadPdf(cBody, .T.)
    If oService:lOk
        If !(CopyFile(cDirSer + oService:cPathPDF, cDirLoc + "\" + oService:cPathPDF))
            MsgStop("Erro na criacao do arquivo " + oService:cPathPDF + ", por favor tente novamente!", "Atencao")
        Else
            ShellExecute("Open", cDirLoc + "\" + oService:cPathPDF, "/RUN /TN SPARK", cDirLoc, 1)
            FErase(cDirSer + oService:cPathPDF)
        EndIf
    Else
        MsgStop('Ocorreu um erro na reimpressao do(s) boleto(s) selecionado(s).', "Impressao de Boleto")
    EndIf

    FreeObj(oService)
    oService := Nil

    FWRestArea(aAreaSEA)

Return
