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
  O formato da fatura e definido pelo parametro MV_XFATFMT:
    P - gera apenas o PDF (layout original) - padrao;
    W - gera apenas o Word/DOCX editavel (modelo Fatura
        Mercantil do cliente, com impostos calculados);
    A - pergunta ao usuario, na tela HTML embarcada
        (XFAT003FMT), se gera PDF, Word ou ambos.
  Valor vazio ou invalido no parametro e tratado como P.

  @author Raphael Neves (Hubvision)
  @since  18/09/2026
/*/
//----------------------------------------------------------
User Function XFAT003()

    Local nFormato := 0
    Local cParFmt  := Upper(AllTrim(cValToChar(SuperGetMV("MV_XFATFMT", .F., "P"))))

    Private oDadosFat := {}

    If Empty(SC5->C5_NUM)
        MsgAlert("Posicione um Pedido de Venda antes de imprimir a Fatura.", "Fatura de Cobranca")
        Return
    EndIf

    If !XFAT003VAL()
        Return
    EndIf

    Do Case
        Case cParFmt == "W"
            nFormato := 2
        Case cParFmt == "A"
            nFormato := XFAT003FMT()
        Otherwise
            nFormato := 1
    EndCase

    If nFormato < 1
        Return
    EndIf

    FWMsgRun(, {|| XFAT003RUN(nFormato)}, "Aguarde...", "Gerando Fatura de Cobranca...")

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
  durante a criacao do FWMSPrinter. nFormato: 1=PDF, 2=DOCX,
  3=PDF e DOCX.

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003RUN(nFormato)

    oDadosFat := XFAT003MNT()

    If nFormato == 1 .Or. nFormato == 3
        XFAT003PDF(oDadosFat)
    EndIf

    If nFormato == 2 .Or. nFormato == 3
        XFAT003DOC(oDadosFat)
    EndIf

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
  Tambem busca a NF-e vinculada ao pedido (XFAT003NFE) e calcula
  os impostos pelo motor fiscal/Configurador de Tributos
  (XFAT003IMP), usados no DOCX da Fatura Mercantil.

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
        SELECT C6_ITEM, C6_DESCRI, C6_QTDVEN, C6_PRCVEN, C6_VALOR, C6_DESCONT, C6_UM
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
            (cAlias)->C6_VALOR ,;
            (cAlias)->C6_UM    })

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
    XFAT003NFE(oDados)
    XFAT003IMP(oDados)

Return oDados

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003FIL()

  Descricao:
  Busca no cadastro de Filiais (SM0), atraves da classe
  FWSM0Util, o Nome Comercial, o CNPJ, o Bairro e a UF da
  filial corrente (cEmpAnt/cFilAnt) e acopla os valores no
  array de impressao para uso no cabecalho do documento. Para o
  DOCX, busca tambem IE, endereco/cidade/CEP de entrega e o
  caminho da logo da empresa (XFAT003LGO).

  @author Raphael Neves (Hubvision)
  @since  19/09/2026
/*/
//----------------------------------------------------------
Static Function XFAT003FIL(oDados)

    Local aCampos := {"M0_NOMECOM", "M0_CGC", "M0_BAIRENT", "M0_ESTENT", "M0_INSC", "M0_ENDENT", "M0_CIDENT", "M0_CEPENT"}
    Local aDados  := FWSM0Util():GetSM0Data(cEmpAnt, cFilAnt, aCampos)

    XFAT003SET(oDados, "EmitNome", IIf(Len(aDados) >= 1, AllTrim(cValToChar(aDados[1][2])), ""))
    XFAT003SET(oDados, "EmitCgc", IIf(Len(aDados) >= 2, AllTrim(cValToChar(aDados[2][2])), ""))
    XFAT003SET(oDados, "EmitBairro", IIf(Len(aDados) >= 3, AllTrim(cValToChar(aDados[3][2])), ""))
    XFAT003SET(oDados, "EmitUf", IIf(Len(aDados) >= 4, AllTrim(cValToChar(aDados[4][2])), ""))
    XFAT003SET(oDados, "EmitIE", IIf(Len(aDados) >= 5, AllTrim(cValToChar(aDados[5][2])), ""))
    XFAT003SET(oDados, "EmitEndCompl", IIf(Len(aDados) >= 8, XFAT003ENDER(aDados[6][2], aDados[3][2], "", aDados[8][2], aDados[7][2], aDados[4][2]), ""))
    XFAT003SET(oDados, "Logo", XFAT003LGO())

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
  Quando existir a logo da empresa (lgmid*.png na system, ver
  XFAT003LGO), o bloco esquerdo do cabecalho passa a exibir a
  logo (proporcao mantida) no lugar da faixa azul com o nome.

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

    Local cLogo      := cValToChar(XFAT003GET(oDados, "Logo", ""))
    Local aTamLogo   := {}

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

    If !Empty(cLogo)
        // Com logo (lgmid*.png): caixa branca com a logo centralizada, mantendo a proporcao
        aTamLogo := XFAT003FIT(XFAT003PNG(cLogo), nLargNavy - 10, nAltCab - 10)
        oPrint:Box(nLin, nEsq, nLin + nAltCab, nEsq + nLargNavy)
        oPrint:SayBitmap(nLin + Int((nAltCab - aTamLogo[2]) / 2), nEsq + Int((nLargNavy - aTamLogo[1]) / 2), cLogo, aTamLogo[1], aTamLogo[2])
    Else
        oPrint:FillRect({nLin, nEsq, nLin + nAltCab, nEsq + nLargNavy}, oBrushFaixa)
        oPrint:SayAlign(nLin + 20, nEsq + 5, cEmitNome, oFontTit, nLargNavy - 10, 50, CLR_WHITE, 2, 1)
    EndIf

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
  Funcao XFAT003FMT()

  Descricao:
  Tela HTML embarcada (TWebEngine/TWebChannel) para o usuario
  escolher o formato de geracao da fatura: 1=PDF, 2=Word (DOCX)
  ou 3=Ambos. Segue o mesmo padrao das demais telas HTML do
  projeto: o HTML e montado em XFAT003FHT(), gravado em \web
  com o ThreadId no nome (evita conflito entre usuarios),
  publicado via CpyF2Web e, quando a pagina avisa READY, recebe
  os dados do pedido via advplToJS("renderDados"). Aceita
  clique, duplo clique, teclas 1/2/3, setas, Enter (confirma) e
  Esc/X (cancela). Retorna 0 quando o usuario cancela.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003FMT()

    Local oDlg
    Local oWeb
    Local oChannel
    Local jDados
    Local cBarra     := IIf(IsSrvUnix(), "/", "\")
    Local cPathLocal := cBarra + "web" + cBarra + "xfat003fmt_" + cValToChar(ThreadId()) + ".html"
    Local cUrlWeb    := ""
    Local nHandle    := 0

    Private nFmtSel := 0

    If !ExistDir(cBarra + "web")
        MakeDir(cBarra + "web")
    EndIf

    nHandle := FCreate(cPathLocal)

    If nHandle == -1
        MsgStop("Nao foi possivel gravar o arquivo HTML no servidor em: " + cPathLocal, "Fatura de Cobranca")
        Return 0
    EndIf

    FWrite(nHandle, XFAT003FHT())
    FClose(nHandle)

    cUrlWeb := CpyF2Web(cPathLocal)

    If Empty(cUrlWeb)
        MsgStop("Nao foi possivel disponibilizar a pagina HTML via CpyF2Web.", "Fatura de Cobranca")
        FErase(cPathLocal)
        Return 0
    EndIf

    jDados := JsonObject():New()
    jDados["pedido"]  := AllTrim(SC5->C5_NUM)
    jDados["cliente"] := AllTrim(SC5->C5_CLIENTE) + "/" + AllTrim(SC5->C5_LOJACLI) + " - " + AllTrim(Posicione("SA1", 1, xFilial("SA1") + SC5->C5_CLIENTE + SC5->C5_LOJACLI, "A1_NOME"))
    jDados["data"]    := DtoC(Date()) + " " + Left(Time(), 5)
    jDados["usuario"] := AllTrim(cUserName)

    DEFINE MSDIALOG oDlg TITLE "Fatura de Cobranca - Formato da Fatura" ;
        FROM 0, 0 TO 400, 680 PIXEL

        oDlg:lEscClose := .T.

        oChannel := TWebChannel():New()
        oChannel:bJsToAdvpl := { |cSelf, cChave, cValor| XFAT003FHD(cChave, cValor, oDlg, oChannel, jDados) }
        oChannel:connect()

        oWeb := TWebEngine():New(oDlg, 0, 0, 100, 100, , oChannel:nPort)
        oWeb:Align := CONTROL_ALIGN_ALLCLIENT
        oWeb:SetAsMain()

        oWeb:Navigate(cUrlWeb + "?port=" + cValToChar(oChannel:nPort))

    ACTIVATE MSDIALOG oDlg CENTERED

    FErase(cPathLocal)

    FreeObj(jDados)
    jDados := Nil

Return nFmtSel

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003FHD()

  Descricao:
  Trata as mensagens recebidas do HTML de escolha do formato via
  TWebChannel: READY envia os dados do pedido para a pagina
  (renderDados); FORMATO_CONFIRMADO grava o formato escolhido
  (1/2/3) em nFmtSel e fecha a tela; CLOSE_PANEL apenas fecha
  (nFmtSel fica 0 = cancelado).

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003FHD(cChave, cValor, oDlgP, oChanP, jDados)

    Local nFmt := 0

    If cChave == "READY"
        oChanP:advplToJS("renderDados", jDados:ToJson())
        Return .T.
    EndIf

    If cChave == "FORMATO_CONFIRMADO"
        nFmt := Val(AllTrim(cValToChar(cValor)))
        If nFmt >= 1 .And. nFmt <= 3
            nFmtSel := nFmt
        EndIf
        oDlgP:End()
        Return .T.
    EndIf

    If cChave == "CLOSE_PANEL"
        oDlgP:End()
        Return .T.
    EndIf

Return .T.

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003FHT()

  Descricao:
  Monta o conteudo HTML da tela de escolha do formato da
  fatura (Tailwind + Font Awesome), com a mesma biblioteca
  QWebChannel/twebchannel das demais telas HTML do projeto.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003FHT()

    Local cHtml := ""

    cHtml += "<!DOCTYPE html>" + Chr(13) + Chr(10)
    cHtml += "<html lang=" + Chr(34) + "pt-BR" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "<head>" + Chr(13) + Chr(10)
    cHtml += "  <meta charset=" + Chr(34) + "UTF-8" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "  <meta name=" + Chr(34) + "viewport" +;
        Chr(34) + " content=" + Chr(34) +;
        "width=device-width, initial-scale=1.0" + Chr(34) + ">" +;
        Chr(13) + Chr(10)
    cHtml += "  <title>Fatura de Cobranca - Formato da Fatura</title>" + Chr(13) + Chr(10)
    cHtml += "  <script src=" + Chr(34) + "https://cdn.tailwindcss.com" +;
        Chr(34) + "></script>" + Chr(13) +;
        Chr(10)
    cHtml += "  <link rel=" + Chr(34) + "stylesheet" +;
        Chr(34) + " href=" + Chr(34) +;
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" + Chr(34) + ">" +;
        Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <script>" + Chr(13) + Chr(10)
    cHtml += "    " + Chr(34) + "use strict" +;
        Chr(34) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "    /* globals window, document, console, MessageChannel, WebSocket, QWebChannel, CustomEvent */" + Chr(13) + Chr(10)
    cHtml += "    function QObject(e, n, t) { function o(e, n) { var o = e[0], r = e[1]; i[o] = { connect: function(e) { return " + Chr(34) + "function" +;
        Chr(34) + " != typeof e ? void console.error(" + Chr(34) +;
        "Bad callback given to connect to signal " + Chr(34) + " + o) : (i.__objectSignals__[r] = i.__objectSignals__[r] || [], i.__objectSignals__[r].push(e), void (n || " +;
        Chr(34) + "destroyed" + Chr(34) +;
        " === o || t.exec({ type: QWebChannelMessageTypes.connectToSignal, object: i.__id__, signal: r }))) }, disconnect: function(e) { if (" + Chr(34) + "function" +;
        Chr(34) + " != typeof e) return void console.error(" + Chr(34) +;
        "Bad callback given to disconnect from signal " + Chr(34) + " + o); i.__objectSignals__[r] = i.__objectSignals__[r] || []; var a = i.__objectSignals__[r].indexOf(e); return -1 === a ? void console.error(" +;
        Chr(34) + "Cannot find connection of signal " + Chr(34) +;
        " + o + " + Chr(34) + " to " +;
        Chr(34) + " + e.name) : (i.__objectSignals__[r].splice(a, 1), void (n || 0 !== i.__objectSignals__[r].length || t.exec({ type: QWebChannelMessageTypes.disconnectFromSignal, object: i.__id__, signal: r }))) } } } function r(e, n) { var t = i.__objectSignals__[e]; t && t.forEach(function(e) { e.apply(e, n) }) } function a(e) { var n = e[0], o = e[1]; i[n] = function() { for (var e, n = [], r = 0; r < arguments.length; ++r) " + Chr(34) +;
        "function" + Chr(34) + " == typeof arguments[r] ? e = arguments[r] : n.push(arguments[r]); t.exec({ type: QWebChannelMessageTypes.invokeMethod, object: i.__id__, method: o, args: n }, function(n) { if (void 0 !== n) { var t = i.unwrapQObject(n); e && e(t) } }) } } function s(e) { var n = e[0], r = e[1], a = e[2]; i.__propertyCache__[n] = e[3], a && (1 === a[0] && (a[0] = r + " +;
        Chr(34) + "Changed" + Chr(34) +;
        "), o(a, !0)), Object.defineProperty(i, r, { get: function() { var e = i.__propertyCache__[n]; return void 0 === e && console.warn(" + Chr(39) + "Undefined value in property cache for property " +;
        Chr(34) + Chr(39) + " + r + " +;
        Chr(39) + Chr(34) + " in object " +;
        Chr(39) + " + i.__id__), e }, set: function(e) { return void 0 === e ? void console.warn(" + Chr(34) +;
        "Property setter for " + Chr(34) + " + r + " +;
        Chr(34) + " called with undefined value!" + Chr(34) +;
        ") : (i.__propertyCache__[n] = e, void t.exec({ type: QWebChannelMessageTypes.setProperty, object: i.__id__, property: n, value: e })) } }) } this.__id__ = e, t.objects[e] = this, this.__objectSignals__ = {}, this.__propertyCache__ = {}; var i = this; this.unwrapQObject = function(e) { if (e instanceof Array) { for (var n = new Array(e.length), o = 0; o < e.length; ++o) n[o] = i.unwrapQObject(e[o]); return n } if (!e || !e[" + Chr(34) + "__QObject*__" +;
        Chr(34) + "] || void 0 === e.id) return e; var r = e.id; if (t.objects[r]) return t.objects[r]; if (!e.data) return void console.error(" + Chr(34) +;
        "Cannot unwrap unknown QObject " + Chr(34) + " + r + " +;
        Chr(34) + " without data." + Chr(34) +;
        "); var a = new QObject(r, e.data, t); return a.destroyed.connect(function() { if (t.objects[r] === a) { delete t.objects[r]; var e = []; for (var n in a) e.push(n); for (var o in e) delete a[e[o]] } }), a.unwrapProperties(), a }, this.unwrapProperties = function() { for (var e in i.__propertyCache__) i.__propertyCache__[e] = i.unwrapQObject(i.__propertyCache__[e]) }, this.propertyUpdate = function(e, n) { for (var t in n) { var o = n[t], r = t.objects[o.object]; r ? r.propertyUpdate(o.signals, o.properties) : console.warn(" + Chr(34) + "Unhandled property update: " +;
        Chr(34) + " + o.object + " + Chr(34) +;
        "::" + Chr(34) + " + o.signal) } t.exec({ type: QWebChannelMessageTypes.idle }) }, this.signalEmitted = function(e, n) { r(e, n) }, n.methods.forEach(a), n.properties.forEach(s), n.signals.forEach(function(e) { o(e, !1) }); for (var e in n.enums) i[e] = n.enums[e] } var QWebChannelMessageTypes = { signal: 1, propertyUpdate: 2, init: 3, idle: 4, debug: 5, invokeMethod: 6, connectToSignal: 7, disconnectFromSignal: 8, setProperty: 9, response: 10 }, QWebChannel = function(e, n) { if (" +;
        Chr(34) + "object" + Chr(34) +;
        " != typeof e || " + Chr(34) + "function" +;
        Chr(34) + " != typeof e.send) return void console.error(" + Chr(34) +;
        "The QWebChannel expects a transport object with a send function and onmessage callback property. Given is: transport: " + Chr(34) + " + typeof e + " +;
        Chr(34) + ", transport.send: " + Chr(34) +;
        " + typeof e.send); var t = this; this.transport = e, this.send = function(e) { " + Chr(34) + "string" +;
        Chr(34) + " != typeof e && (e = JSON.stringify(e)), t.transport.send(e) }, this.transport.onmessage = function(e) { var n = e.data; switch (" + Chr(34) +;
        "string" + Chr(34) + " == typeof n && (n = JSON.parse(n)), n.type) { case QWebChannelMessageTypes.signal: t.handleSignal(n); break; case QWebChannelMessageTypes.response: t.handleResponse(n); break; case QWebChannelMessageTypes.propertyUpdate: t.handlePropertyUpdate(n); break; default: console.error(" +;
        Chr(34) + "invalid message received:" + Chr(34) +;
        ", e.data) } }, this.execCallbacks = {}, this.execId = 0, this.exec = function(e, n) { return n ? (t.execId === Number.MAX_VALUE && (t.execId = Number.MIN_VALUE), e.hasOwnProperty(" + Chr(34) + "id" +;
        Chr(34) + ") ? void console.error(" + Chr(34) +;
        "Cannot exec message with property id: " + Chr(34) + " + JSON.stringify(e)) : (e.id = t.execId++ , t.execCallbacks[e.id] = n, void t.send(e))) : void t.send(e) }, this.objects = {}, this.handleSignal = function(e) { var n = t.objects[e.object]; n ? n.signalEmitted(e.signal, e.args) : console.warn(" +;
        Chr(34) + "Unhandled signal: " + Chr(34) +;
        " + e.object + " + Chr(34) + "::" +;
        Chr(34) + " + e.signal) }, this.handleResponse = function(e) { return e.hasOwnProperty(" + Chr(34) +;
        "id" + Chr(34) + ") ? (t.execCallbacks[e.id](e.data), void delete t.execCallbacks[e.id]) : void console.error(" +;
        Chr(34) + "Invalid response message received: " + Chr(34) +;
        ", JSON.stringify(e)) }, this.handlePropertyUpdate = function(e) { for (var n in e.data) { var o = e.data[n], r = t.objects[o.object]; r ? r.propertyUpdate(o.signals, o.properties) : console.warn(" + Chr(34) + "Unhandled property update: " +;
        Chr(34) + " + o.object + " + Chr(34) +;
        "::" + Chr(34) + " + o.signal) } t.exec({ type: QWebChannelMessageTypes.idle }) }, this.debug = function(e) { t.send({ type: QWebChannelMessageTypes.debug, data: e }) }, t.exec({ type: QWebChannelMessageTypes.init }, function(e) { for (var o in e) var r = new QObject(o, e[o], t); for (var o in t.objects) t.objects[o].unwrapProperties(); n && n(t), t.exec({ type: QWebChannelMessageTypes.idle }) }) }; " +;
        Chr(34) + "object" + Chr(34) +;
        " == typeof module && (module.exports = { QWebChannel: QWebChannel });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    var getParam = function(queryField) {" + Chr(13) + Chr(10)
    cHtml += "      var url = window.location.href; queryField = queryField.replace(/[\[\]]/g, " + Chr(34) + "\\$&" +;
        Chr(34) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      var regex = new RegExp(" + Chr(34) + "[?&]" +;
        Chr(34) + " + queryField + " + Chr(34) +;
        "(=([^&#]*)|&|#|$)" + Chr(34) + ", " +;
        Chr(34) + "i" + Chr(34) +;
        "), results = regex.exec(url);" + Chr(13) + Chr(10)
    cHtml += "      if (!results) return null; if (!results[2]) return " + Chr(39) + Chr(39) +;
        ";" + Chr(13) + Chr(10)
    cHtml += "      return decodeURIComponent(results[2].replace(/\+/g, " + Chr(34) + " " +;
        Chr(34) + "));" + Chr(13) +;
        Chr(10)
    cHtml += "    };" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    var origin = getParam(" + Chr(39) + "totvstec_remote_origin" +;
        Chr(39) + "); if ((origin === null) || (origin === " + Chr(39) +;
        Chr(39) + ")) origin = " + Chr(39) +;
        "*" + Chr(39) + ";" +;
        Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    window.onmessage = function(event) {" + Chr(13) + Chr(10)
    cHtml += "      var data = event.data; if ((origin !== " + Chr(39) + "*" +;
        Chr(39) + ") && (event.origin !== origin)) return;" + Chr(13) +;
        Chr(10)
    cHtml += "      if ((data.type ? data.type : " + Chr(39) + Chr(39) +;
        ").toUpperCase() !== " + Chr(39) + "MS_WEBENGINERUNJAVASCRIPT" +;
        Chr(39) + ") return;" + Chr(13) +;
        Chr(10)
    cHtml += "      eval(data.value);" + Chr(13) + Chr(10)
    cHtml += "    };" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    var twebchannel = {" + Chr(13) + Chr(10)
    cHtml += "      version: " + Chr(34) + "1.0.4" +;
        Chr(34) + ", internalPort: 0," + Chr(13) +;
        Chr(10)
    cHtml += "      connect: function(callback) {" + Chr(13) + Chr(10)
    cHtml += "        var port = getParam(" + Chr(39) + "port" +;
        Chr(39) + ") || getParam(" + Chr(39) +;
        "totvstec_websocket_port" + Chr(39) + "), remoteType = getParam(" +;
        Chr(39) + "totvstec_remote_type" + Chr(39) +;
        "), threadId = getParam(" + Chr(39) + "totvstec_threadId" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        this.init(port, remoteType, threadId, callback);" + Chr(13) + Chr(10)
    cHtml += "      }," + Chr(13) + Chr(10)
    cHtml += "      init: function(port, remoteType, threadId, callback) {" + Chr(13) + Chr(10)
    cHtml += "        this.internalPort = Number(port); this.remoteType = Number(remoteType); this.threadId = threadId;" + Chr(13) + Chr(10)
    cHtml += "        var fireEvent = function() {" + Chr(13) + Chr(10)
    cHtml += "          var event = new CustomEvent(" + Chr(39) + "twebchannelready" +;
        Chr(39) + "); document.dispatchEvent(event);" + Chr(13) +;
        Chr(10)
    cHtml += "          if (typeof callback === " + Chr(39) + "function" +;
        Chr(39) + ") callback();" + Chr(13) +;
        Chr(10)
    cHtml += "        };" + Chr(13) + Chr(10)
    cHtml += "        if (this.remoteType !== 5) { this.connectWS(fireEvent); } else { this.connectMessageChannel(fireEvent); }" + Chr(13) + Chr(10)
    cHtml += "      }," + Chr(13) + Chr(10)
    cHtml += "      jsToAdvpl: function(key, value) {" + Chr(13) + Chr(10)
    cHtml += "        if (this.remoteType !== 5) { window.dialog.jsToAdvpl(key, value); } else { this.sendMessageChannel(key, value); }" + Chr(13) + Chr(10)
    cHtml += "      }," + Chr(13) + Chr(10)
    cHtml += "      advplToJs: function(key, value) { console.log(" + Chr(39) + "not connected" +;
        Chr(39) + "); }," + Chr(13) +;
        Chr(10)
    cHtml += "      connectWS: function(callback) {" + Chr(13) + Chr(10)
    cHtml += "        var baseUrl = " + Chr(34) + "ws://127.0.0.1:" +;
        Chr(34) + " + this.internalPort, socket = new WebSocket(baseUrl);" + Chr(13) +;
        Chr(10)
    cHtml += "        socket.onclose = function() { console.error(" + Chr(34) + "WebChannel closed" +;
        Chr(34) + "); };" + Chr(13) +;
        Chr(10)
    cHtml += "        socket.onerror = function(error) { console.error(" + Chr(34) + "WebChannel error: " +;
        Chr(34) + " + error); };" + Chr(13) +;
        Chr(10)
    cHtml += "        socket.onopen = function() {" + Chr(13) + Chr(10)
    cHtml += "          new QWebChannel(socket, function(channel) {" + Chr(13) + Chr(10)
    cHtml += "            window.dialog = channel.objects.mainDialog;" + Chr(13) + Chr(10)
    cHtml += "            window.dialog.advplToJs.connect(twebchannel.onReceiveAdvplToJs.bind(twebchannel));" + Chr(13) + Chr(10)
    cHtml += "            if (typeof callback === " + Chr(39) + "function" +;
        Chr(39) + ") callback();" + Chr(13) +;
        Chr(10)
    cHtml += "          });" + Chr(13) + Chr(10)
    cHtml += "        };" + Chr(13) + Chr(10)
    cHtml += "      }," + Chr(13) + Chr(10)
    cHtml += "      onReceiveAdvplToJs: function(key, value) { this.advplToJs(key, value); }," + Chr(13) + Chr(10)
    cHtml += "      connectMessageChannel: function(callback) {" + Chr(13) + Chr(10)
    cHtml += "        this.channel = new MessageChannel();" + Chr(13) + Chr(10)
    cHtml += "        this.channel.port1.onmessage = function(event) {" + Chr(13) + Chr(10)
    cHtml += "          var data = event.data, messageType = (data.type || " + Chr(39) + "UNDEFINED" +;
        Chr(39) + ").toUpperCase();" + Chr(13) +;
        Chr(10)
    cHtml += "          switch (messageType) {" + Chr(13) + Chr(10)
    cHtml += "            case " + Chr(39) + "CONNECTED" +;
        Chr(39) + ":" + Chr(13) +;
        Chr(10)
    cHtml += "              window.dialog = window.dialog || {}; window.dialog.jsToAdvpl = twebchannel.sendMessageChannel.bind(twebchannel);" + Chr(13) + Chr(10)
    cHtml += "              if (typeof callback === " + Chr(39) + "function" +;
        Chr(39) + ") callback(); break;" + Chr(13) +;
        Chr(10)
    cHtml += "            case " + Chr(39) + "EXEC" +;
        Chr(39) + ": twebchannel.onReceiveAdvplToJs(data.value.type, data.value.content); break;" + Chr(13) +;
        Chr(10)
    cHtml += "          }" + Chr(13) + Chr(10)
    cHtml += "        };" + Chr(13) + Chr(10)
    cHtml += "        window.parent.postMessage({ type: " + Chr(39) + "CONNECT" +;
        Chr(39) + ", port: this.internalPort, threadId: this.threadId }, origin, [this.channel.port2]);" + Chr(13) +;
        Chr(10)
    cHtml += "      }," + Chr(13) + Chr(10)
    cHtml += "      sendMessageChannel: function(key, value) {" + Chr(13) + Chr(10)
    cHtml += "        var message = { type: key, content: value, port: this.internalPort }; this.channel.port1.postMessage(message);" + Chr(13) + Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "    };" + Chr(13) + Chr(10)
    cHtml += "  </script>" + Chr(13) + Chr(10)
    cHtml += "  <style>" + Chr(13) + Chr(10)
    cHtml += "    @keyframes pop { 0% { transform: scale(.85); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }" + Chr(13) + Chr(10)
    cHtml += "    .pop { animation: pop .25s ease-out both; }" + Chr(13) + Chr(10)
    cHtml += "  </style>" + Chr(13) + Chr(10)
    cHtml += "</head>" + Chr(13) + Chr(10)
    cHtml += "<body class='bg-slate-100 text-slate-800 font-sans antialiased h-screen flex flex-col select-none'>" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <!-- CABECALHO -->" + Chr(13) + Chr(10)
    cHtml += "  <div class='bg-gradient-to-r from-blue-900 to-sky-600 text-white px-5 py-4 flex items-center gap-4 shadow-md'>" + Chr(13) + Chr(10)
    cHtml += "    <div class='w-12 h-12 shrink-0 rounded-full bg-white/20 ring-4 ring-white/10 flex items-center justify-center text-2xl'><i class='fa-solid fa-file-invoice-dollar'></i></div>" + Chr(13) + Chr(10)
    cHtml += "    <div class='flex-1 min-w-0'>" + Chr(13) + Chr(10)
    cHtml += "      <h1 class='text-lg font-bold leading-tight'>Fatura de Cobran&ccedil;a</h1>" + Chr(13) + Chr(10)
    cHtml += "      <p id='hdrInfo' class='text-xs text-sky-100 mt-0.5 truncate'></p>" + Chr(13) + Chr(10)
    cHtml += "    </div>" + Chr(13) + Chr(10)
    cHtml += "  </div>" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <div class='flex-1 overflow-auto px-4 py-3 flex flex-col gap-3'>" + Chr(13) + Chr(10)
    cHtml += "    <p class='text-xs font-semibold text-slate-500'>Selecione o formato de gera&ccedil;&atilde;o da fatura</p>" + Chr(13) + Chr(10)
    cHtml += "    <div id='cards' class='grid grid-cols-3 gap-3 flex-1'>" + Chr(13) + Chr(10)
    cHtml += "      <button type='button' data-fmt='1' onclick='selecionar(1)' ondblclick='selecionar(1); confirmar();' class='card pop bg-white rounded-lg border-2 border-slate-200 shadow-sm px-3 py-4 flex flex-col items-center justify-center gap-2 transition-all hover:border-blue-400'>" + Chr(13) + Chr(10)
    cHtml += "        <div class='flex gap-1 text-3xl'><i class='fa-solid fa-file-pdf text-red-600'></i></div>" + Chr(13) + Chr(10)
    cHtml += "        <p class='text-sm font-bold text-slate-700'>PDF</p>" + Chr(13) + Chr(10)
    cHtml += "        <p class='text-[11px] text-slate-500 text-center leading-snug'>Layout atual da fatura, para visualizar e imprimir</p>" + Chr(13) + Chr(10)
    cHtml += "        <span class='text-[10px] font-semibold text-slate-400 bg-slate-100 rounded px-2 py-0.5'>Tecla 1</span>" + Chr(13) + Chr(10)
    cHtml += "      </button>" + Chr(13) + Chr(10)
    cHtml += "      <button type='button' data-fmt='2' onclick='selecionar(2)' ondblclick='selecionar(2); confirmar();' class='card pop bg-white rounded-lg border-2 border-slate-200 shadow-sm px-3 py-4 flex flex-col items-center justify-center gap-2 transition-all hover:border-blue-400'>" + Chr(13) + Chr(10)
    cHtml += "        <div class='flex gap-1 text-3xl'><i class='fa-solid fa-file-word text-blue-700'></i></div>" + Chr(13) + Chr(10)
    cHtml += "        <p class='text-sm font-bold text-slate-700'>Word (DOCX)</p>" + Chr(13) + Chr(10)
    cHtml += "        <p class='text-[11px] text-slate-500 text-center leading-snug'>Fatura Mercantil edit&aacute;vel, com impostos calculados</p>" + Chr(13) + Chr(10)
    cHtml += "        <span class='text-[10px] font-semibold text-slate-400 bg-slate-100 rounded px-2 py-0.5'>Tecla 2</span>" + Chr(13) + Chr(10)
    cHtml += "      </button>" + Chr(13) + Chr(10)
    cHtml += "      <button type='button' data-fmt='3' onclick='selecionar(3)' ondblclick='selecionar(3); confirmar();' class='card pop bg-white rounded-lg border-2 border-slate-200 shadow-sm px-3 py-4 flex flex-col items-center justify-center gap-2 transition-all hover:border-blue-400'>" + Chr(13) + Chr(10)
    cHtml += "        <div class='flex gap-1 text-3xl'><i class='fa-solid fa-file-pdf text-red-600'></i><i class='fa-solid fa-file-word text-blue-700'></i></div>" + Chr(13) + Chr(10)
    cHtml += "        <p class='text-sm font-bold text-slate-700'>Ambos</p>" + Chr(13) + Chr(10)
    cHtml += "        <p class='text-[11px] text-slate-500 text-center leading-snug'>Gera o PDF e tamb&eacute;m o Word</p>" + Chr(13) + Chr(10)
    cHtml += "        <span class='text-[10px] font-semibold text-slate-400 bg-slate-100 rounded px-2 py-0.5'>Tecla 3</span>" + Chr(13) + Chr(10)
    cHtml += "      </button>" + Chr(13) + Chr(10)
    cHtml += "    </div>" + Chr(13) + Chr(10)
    cHtml += "  </div>" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <!-- RODAPE -->" + Chr(13) + Chr(10)
    cHtml += "  <div class='bg-white border-t border-slate-200 px-4 py-3 flex items-center gap-3'>" + Chr(13) + Chr(10)
    cHtml += "    <p id='ftInfo' class='flex-1 text-[11px] text-slate-400 truncate'></p>" + Chr(13) + Chr(10)
    cHtml += "    <button id='btnOk' onclick='confirmar()' class='px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-md text-sm shadow-sm transition-all'><i class='fa-solid fa-check mr-1'></i>Confirmar</button>" + Chr(13) + Chr(10)
    cHtml += "    <button onclick='cancelar()' class='px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 font-semibold rounded-md text-sm transition-all'>Cancelar</button>" + Chr(13) + Chr(10)
    cHtml += "  </div>" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <script>" + Chr(13) + Chr(10)
    cHtml += "    var formatoSel = 1;" + Chr(13) + Chr(10)
    cHtml += "    var enviado = false;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function el(id) { return document.getElementById(id); }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function selecionar(nFmt) {" + Chr(13) + Chr(10)
    cHtml += "      formatoSel = nFmt;" + Chr(13) + Chr(10)
    cHtml += "      document.querySelectorAll('#cards .card').forEach(function(c) {" + Chr(13) + Chr(10)
    cHtml += "        var ativo = parseInt(c.getAttribute('data-fmt'), 10) === nFmt;" + Chr(13) + Chr(10)
    cHtml += "        c.classList.toggle('border-blue-600', ativo);" + Chr(13) + Chr(10)
    cHtml += "        c.classList.toggle('bg-blue-50', ativo);" + Chr(13) + Chr(10)
    cHtml += "        c.classList.toggle('ring-2', ativo);" + Chr(13) + Chr(10)
    cHtml += "        c.classList.toggle('ring-blue-200', ativo);" + Chr(13) + Chr(10)
    cHtml += "        c.classList.toggle('border-slate-200', !ativo);" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function confirmar() {" + Chr(13) + Chr(10)
    cHtml += "      if (enviado) return;" + Chr(13) + Chr(10)
    cHtml += "      enviado = true;" + Chr(13) + Chr(10)
    cHtml += "      twebchannel.jsToAdvpl('FORMATO_CONFIRMADO', String(formatoSel));" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function cancelar() {" + Chr(13) + Chr(10)
    cHtml += "      if (enviado) return;" + Chr(13) + Chr(10)
    cHtml += "      enviado = true;" + Chr(13) + Chr(10)
    cHtml += "      twebchannel.jsToAdvpl('CLOSE_PANEL', '');" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function renderDados(value) {" + Chr(13) + Chr(10)
    cHtml += "      var j = typeof value === 'string' ? JSON.parse(value) : value;" + Chr(13) + Chr(10)
    cHtml += "      el('hdrInfo').textContent = 'Pedido ' + j.pedido + '  |  Cliente ' + j.cliente;" + Chr(13) + Chr(10)
    cHtml += "      el('ftInfo').textContent = j.data + '  |  ' + j.usuario;" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    window.onload = function() {" + Chr(13) + Chr(10)
    cHtml += "      selecionar(1);" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      twebchannel.connect(function() {" + Chr(13) + Chr(10)
    cHtml += "        twebchannel.jsToAdvpl('READY', '');" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      twebchannel.advplToJs = function(key, value) {" + Chr(13) + Chr(10)
    cHtml += "        if (key === 'renderDados') renderDados(value);" + Chr(13) + Chr(10)
    cHtml += "      };" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      document.addEventListener('keydown', function(e) {" + Chr(13) + Chr(10)
    cHtml += "        if (e.key === 'Escape') { e.preventDefault(); cancelar(); }" + Chr(13) + Chr(10)
    cHtml += "        else if (e.key === 'Enter') { e.preventDefault(); confirmar(); }" + Chr(13) + Chr(10)
    cHtml += "        else if (e.key === '1' || e.key === '2' || e.key === '3') { selecionar(parseInt(e.key, 10)); }" + Chr(13) + Chr(10)
    cHtml += "        else if (e.key === 'ArrowRight') { selecionar(Math.min(3, formatoSel + 1)); }" + Chr(13) + Chr(10)
    cHtml += "        else if (e.key === 'ArrowLeft') { selecionar(Math.max(1, formatoSel - 1)); }" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      el('btnOk').focus();" + Chr(13) + Chr(10)
    cHtml += "    };" + Chr(13) + Chr(10)
    cHtml += "  </script>" + Chr(13) + Chr(10)
    cHtml += "</body>" + Chr(13) + Chr(10)
    cHtml += "</html>" + Chr(13) + Chr(10)

Return cHtml

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003LGO()

  Descricao:
  Localiza o arquivo de logo da empresa na pasta system do
  Protheus_Data (StartPath do AppServer). Procura, nesta ordem
  de prioridade, o arquivo mais especifico para o mais generico:
    1) lgmid + grupo de empresas + filial (ex.: lgmid01010101.png)
    2) lgmid + grupo de empresas            (ex.: lgmid01.png)
    3) lgmid.png
  Retorna o caminho completo do primeiro arquivo encontrado, ou
  "" quando nenhum dos tres existir (a fatura sai sem logo).

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003LGO()

    Local cBarra := IIf(IsSrvUnix(), "/", "\")
    Local cStart := AllTrim(GetSrvProfString("Startpath", ""))
    Local aNomes := {}
    Local cRet   := ""
    Local nX

    If Empty(cStart)
        cStart := cBarra + "system" + cBarra
    ElseIf Right(cStart, 1) != "\" .And. Right(cStart, 1) != "/"
        cStart += cBarra
    EndIf

    aAdd(aNomes, "lgmid" + AllTrim(cEmpAnt) + AllTrim(cFilAnt) + ".png")
    aAdd(aNomes, "lgmid" + AllTrim(cEmpAnt) + ".png")
    aAdd(aNomes, "lgmid.png")

    For nX := 1 To Len(aNomes)
        If File(cStart + aNomes[nX])
            cRet := cStart + aNomes[nX]
            Exit
        EndIf
    Next nX

    aSize(aNomes, 0)
    aNomes := Nil

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003PNG()

  Descricao:
  Le o cabecalho (chunk IHDR) do arquivo PNG informado e retorna
  {largura, altura} em pixels, usados para manter a proporcao da
  logo no PDF e no DOCX. Retorna {0, 0} se o arquivo nao puder
  ser lido ou nao for um PNG valido.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003PNG(cArq)

    Local aRet   := {0, 0}
    Local cBuf   := Space(24)
    Local nHdl   := FOpen(cArq, 0)

    If nHdl >= 0
        If FRead(nHdl, @cBuf, 24) == 24 .And. SubStr(cBuf, 13, 4) == "IHDR"
            aRet[1] := (Asc(SubStr(cBuf, 17, 1)) * 16777216) + (Asc(SubStr(cBuf, 18, 1)) * 65536) + (Asc(SubStr(cBuf, 19, 1)) * 256) + Asc(SubStr(cBuf, 20, 1))
            aRet[2] := (Asc(SubStr(cBuf, 21, 1)) * 16777216) + (Asc(SubStr(cBuf, 22, 1)) * 65536) + (Asc(SubStr(cBuf, 23, 1)) * 256) + Asc(SubStr(cBuf, 24, 1))
        EndIf
        FClose(nHdl)
    EndIf

Return aRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003FIT()

  Descricao:
  Calcula a largura/altura que a logo deve ocupar dentro de uma
  area maxima (nMaxL x nMaxA), mantendo a proporcao original da
  imagem (aDim = {largura, altura} em pixels). Quando as
  dimensoes nao sao conhecidas, assume proporcao 3:1.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003FIT(aDim, nMaxL, nMaxA)

    Local nLarg  := IIf(aDim[1] > 0, aDim[1], 3)
    Local nAlt   := IIf(aDim[2] > 0, aDim[2], 1)
    Local nFator := Min(nMaxL / nLarg, nMaxA / nAlt)

Return {Int(nLarg * nFator), Int(nAlt * nFator)}

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003IMP()

  Descricao:
  Calcula os impostos do Pedido de Venda posicionado (SC5/SC6)
  pelo motor fiscal (MaFisIni/MaFisAdd/MaFisRet), com calculo
  dos tributos genericos do Configurador de Tributos habilitado
  (33o parametro do MaFisIni), seguindo o mesmo modelo usado na
  impressao do PRE-DANFE. Para cada item, os valores padrao do
  MaFis (IT_VALICM, IT_VALSOL, IT_VALIPI, IT_VALPIS, IT_VALCOF)
  sao sobrepostos pelos tributos genericos (IT_TRIBGEN) quando o
  Configurador de Tributos estiver calculando ICMS/ST/IPI/PIS/
  COFINS, e sao capturados os tributos da Reforma Tributaria:
  CBS, IBS (UF + Municipio) e IS (Imposto Seletivo). Os totais
  sao gravados no array de impressao (chaves Trib*) e o total da
  nota calculado (NF_TOTAL) em "ValorNF". Se ja existir um motor
  fiscal ativo na pilha, ele e salvo e restaurado ao final.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003IMP(oDados)

    Local aArea    := GetArea()
    Local aAreaSC6 := SC6->(GetArea())
    Local aAreaSB1 := SB1->(GetArea())
    Local aAreaSF4 := SF4->(GetArea())
    Local lFisAtv  := MaFisFound("NF")
    Local nQtdIt   := 0
    Local nTotPed  := 0
    Local nItem    := 0
    Local aTrbGen  := {}
    Local aElemTG  := {}
    Local cDescTG  := ""
    Local cChaveTG := ""
    Local nBaseTG  := 0
    Local nValTG   := 0
    Local nX
    Local nY

    Local nItICM   := 0
    Local nItST    := 0
    Local nItIPI   := 0
    Local nItPIS   := 0
    Local nItCOF   := 0

    Local nBasICM  := 0
    Local nTotICM  := 0
    Local nTotST   := 0
    Local nTotIPI  := 0
    Local nTotPIS  := 0
    Local nTotCOF  := 0
    Local nBasCBS  := 0
    Local nTotCBS  := 0
    Local nBasIBS  := 0
    Local nTotIBS  := 0
    Local nTotIBM  := 0
    Local nTotIS   := 0
    Local nValNF   := 0

    If lFisAtv
        MaFisSave()
        MaFisEnd()
    EndIf

    DbSelectArea("SB1")
    SB1->(DbSetOrder(1))
    DbSelectArea("SF4")
    SF4->(DbSetOrder(1))
    DbSelectArea("SC6")
    SC6->(DbSetOrder(1))

    If SC6->(MsSeek(xFilial("SC6") + SC5->C5_NUM))
        While !SC6->(Eof()) .And. SC6->C6_FILIAL == xFilial("SC6") .And. SC6->C6_NUM == SC5->C5_NUM
            nQtdIt++
            nTotPed += SC6->C6_VALOR
            SC6->(DbSkip())
        EndDo
    EndIf

    If nQtdIt > 0

        MaFisIni(SC5->C5_CLIENTE,;                         // 01 - Codigo Cliente/Fornecedor
                 SC5->C5_LOJACLI,;                         // 02 - Loja do Cliente/Fornecedor
                 IIf(SC5->C5_TIPO $ "D/B", "F", "C"),;     // 03 - C:Cliente , F:Fornecedor
                 SC5->C5_TIPO,;                            // 04 - Tipo da NF
                 SC5->C5_TIPOCLI,;                         // 05 - Tipo do Cliente/Fornecedor
                 Nil,;                                     // 06 - Relacao de Impostos suportados
                 Nil,;                                     // 07 - Tipo de complemento
                 Nil,;                                     // 08 - Permite Incluir Impostos no Rodape
                 Nil,;                                     // 09 - Alias do Cadastro de Produtos
                 "MATA461",;                               // 10 - Nome da rotina
                 Nil,;                                     // 11 - Tipo de documento
                 Nil,;                                     // 12 - Especie do documento
                 Nil,;                                     // 13 - Codigo e Loja do Prospect
                 Nil,;                                     // 14 - Grupo Cliente
                 Nil,;                                     // 15 - Recolhe ISS
                 Nil,;                                     // 16 - Cliente de entrega
                 Nil,;                                     // 17 - Loja de entrega
                 Nil,;                                     // 18 - Informacoes do transportador
                 Nil,;                                     // 19 - Emissao de nota ou cupom
                 Nil,;                                     // 20 - Calcula IPI
                 SC5->C5_NUM,;                             // 21 - Pedido de Venda
                 SC5->C5_CLIENTE,;                         // 22 - Cliente do Faturamento
                 SC5->C5_LOJACLI,;                         // 23 - Loja do Cliente do Faturamento
                 nTotPed,;                                 // 24 - Total do Pedido
                 Nil,;                                     // 25 - Data de emissao do documento
                 SC5->C5_TPFRETE,;                         // 26 - Tipo de Frete
                 Nil,;                                     // 27 - Calcula PIS/COFINS/CSLL
                 Nil,;                                     // 28 - Calcula INSS
                 Nil,;                                     // 29 - Calcula IRRF
                 Nil,;                                     // 30 - Tipo de Complemento
                 Nil,;                                     // 31 - Cliente destino transporte
                 Nil,;                                     // 32 - Loja destino transporte
                 .T.,;                                     // 33 - Calcula tributos genericos (Configurador de Tributos)
                 nQtdIt,;                                  // 34 - Quantidade de itens no documento
                 .F.,;                                     // 35 - Planilha financeira
                 Nil)                                      // 36 - Numero da nota

        SC6->(MsSeek(xFilial("SC6") + SC5->C5_NUM))

        While !SC6->(Eof()) .And. SC6->C6_FILIAL == xFilial("SC6") .And. SC6->C6_NUM == SC5->C5_NUM

            SB1->(MsSeek(xFilial("SB1") + SC6->C6_PRODUTO))
            SF4->(MsSeek(xFilial("SF4") + SC6->C6_TES))

            MaFisAdd(SC6->C6_PRODUTO,;   // 01 - Codigo do Produto
                     SC6->C6_TES,;       // 02 - Codigo do TES
                     SC6->C6_QTDVEN,;    // 03 - Quantidade
                     SC6->C6_PRCVEN,;    // 04 - Preco Unitario
                     0,;                 // 05 - Desconto
                     "",;                // 06 - Numero da NF Original
                     "",;                // 07 - Serie da NF Original
                     0,;                 // 08 - RecNo da NF Original
                     0,;                 // 09 - Valor do Frete
                     0,;                 // 10 - Valor da Despesa
                     0,;                 // 11 - Valor do Seguro
                     0,;                 // 12 - Valor do Frete Autonomo
                     SC6->C6_VALOR,;     // 13 - Valor da Mercadoria
                     0,;                 // 14 - Valor da Embalagem
                     SB1->(RecNo()),;    // 15 - RecNo do SB1
                     SF4->(RecNo()))     // 16 - RecNo do SF4

            SC6->(DbSkip())
        EndDo

        MaFisAlt("NF_FRETE", SC5->C5_FRETE)
        MaFisAlt("NF_SEGURO", SC5->C5_SEGURO)
        If SC5->C5_DESCONT > 0
            MaFisAlt("NF_DESCONTO", Min(MaFisRet(, "NF_VALMERC") - 0.01, SC5->C5_DESCONT + MaFisRet(, "NF_DESCONTO")))
        EndIf

        For nItem := 1 To nQtdIt

            nItICM := MaFisRet(nItem, "IT_VALICM")
            nItST  := MaFisRet(nItem, "IT_VALSOL")
            nItIPI := MaFisRet(nItem, "IT_VALIPI")
            nItPIS := MaFisRet(nItem, "IT_VALPIS")
            nItCOF := MaFisRet(nItem, "IT_VALCOF")
            nBasICM += MaFisRet(nItem, "IT_BASEICM")

            aTrbGen := MaFisRet(nItem, "IT_TRIBGEN")

            If ValType(aTrbGen) == "A"
                For nX := 1 To Len(aTrbGen)
                    aElemTG := aTrbGen[nX]

                    If ValType(aElemTG) == "A" .And. Len(aElemTG) >= 5

                        cDescTG := IIf(Len(aElemTG) >= 41 .And. ValType(aElemTG[41]) == "C", FWNoAccento(Upper(AllTrim(aElemTG[41]))), "")
                        nBaseTG := IIf(ValType(aElemTG[3]) == "N", aElemTG[3], 0)
                        nValTG  := IIf(ValType(aElemTG[5]) == "N", aElemTG[5], 0)

                        Do Case
                            Case cDescTG == "ICMS - IMPOSTO SOBRE CIRCULACAO DE MERCADORIAS E SERVICOS"
                                nItICM := nValTG
                            Case cDescTG == "ICMS SUBSTITUICAO TRIBUTARIA"
                                nItST  := nValTG
                            Case cDescTG == "IPI - IMPOSTO SOBRE PRODUTOS INDUSTRIALIZADOS"
                                nItIPI := nValTG
                            Case cDescTG == "PROGRAMA DE INTEGRACAO SOCIAL"
                                nItPIS := nValTG
                            Case cDescTG == "CONTRIBUICAO PARA FINANCIAMENTO DA SEGURIDADE SOCIAL"
                                nItCOF := nValTG
                            Otherwise
                                // A descricao de CBS/IBS/IS varia conforme o cadastro do
                                // Configurador de Tributos, por isso procura a sigla em
                                // todos os campos texto do tributo generico.
                                cChaveTG := ""
                                For nY := 1 To Len(aElemTG)
                                    If ValType(aElemTG[nY]) == "C"
                                        cChaveTG += " " + FWNoAccento(Upper(AllTrim(aElemTG[nY])))
                                    EndIf
                                Next nY

                                Do Case
                                    Case "CBS" $ cChaveTG
                                        nBasCBS += nBaseTG
                                        nTotCBS += nValTG
                                    Case "IBS" $ cChaveTG .And. "MUN" $ cChaveTG
                                        nTotIBM += nValTG
                                    Case "IBS" $ cChaveTG
                                        nBasIBS += nBaseTG
                                        nTotIBS += nValTG
                                    Case "SELETIVO" $ cChaveTG
                                        nTotIS  += nValTG
                                EndCase
                        EndCase
                    EndIf
                Next nX
            EndIf

            nTotICM += nItICM
            nTotST  += nItST
            nTotIPI += nItIPI
            nTotPIS += nItPIS
            nTotCOF += nItCOF

        Next nItem

        nValNF := MaFisRet(, "NF_TOTAL")

        MaFisEnd()

    EndIf

    If lFisAtv
        MaFisRestore()
    EndIf

    XFAT003SET(oDados, "TribBaseICM", nBasICM)
    XFAT003SET(oDados, "TribICM", nTotICM)
    XFAT003SET(oDados, "TribST", nTotST)
    XFAT003SET(oDados, "TribIPI", nTotIPI)
    XFAT003SET(oDados, "TribPIS", nTotPIS)
    XFAT003SET(oDados, "TribCOF", nTotCOF)
    XFAT003SET(oDados, "TribBaseCBS", nBasCBS)
    XFAT003SET(oDados, "TribCBS", nTotCBS)
    XFAT003SET(oDados, "TribBaseIBS", nBasIBS)
    XFAT003SET(oDados, "TribIBS", nTotIBS + nTotIBM)
    XFAT003SET(oDados, "TribIS", nTotIS)
    XFAT003SET(oDados, "ValorNF", nValNF)

    aTrbGen := Nil
    aElemTG := Nil

    RestArea(aAreaSF4)
    RestArea(aAreaSB1)
    RestArea(aAreaSC6)
    RestArea(aArea)

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003NFE()

  Descricao:
  Identifica a NF-e de saida vinculada ao pedido, a partir do
  primeiro item ja faturado (C6_NOTA/C6_SERIE), e busca a chave
  de acesso na SF2 (F2_CHVNFE). Grava NFNumero, NFSerie e
  NFChave no array de impressao. Se o pedido ainda nao foi
  faturado, as chaves ficam vazias e o campo sai em branco no
  DOCX para o usuario completar no Word.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003NFE(oDados)

    Local cAlias := GetNextAlias()
    Local cNota  := ""
    Local cSerie := ""
    Local cChave := ""

    BeginSql Alias cAlias
        SELECT C6_NOTA, C6_SERIE
        FROM %table:SC6% SC6
        WHERE SC6.%notDel%
          AND SC6.C6_FILIAL = %xFilial:SC6%
          AND SC6.C6_NUM    = %exp:SC5->C5_NUM%
          AND SC6.C6_NOTA  <> ' '
        ORDER BY C6_ITEM
    EndSql

    If !(cAlias)->(Eof())
        cNota  := (cAlias)->C6_NOTA
        cSerie := (cAlias)->C6_SERIE
    EndIf

    (cAlias)->(DbCloseArea())

    If !Empty(cNota)

        cAlias := GetNextAlias()

        BeginSql Alias cAlias
            SELECT F2_CHVNFE
            FROM %table:SF2% SF2
            WHERE SF2.%notDel%
              AND SF2.F2_FILIAL = %xFilial:SF2%
              AND SF2.F2_DOC    = %exp:cNota%
              AND SF2.F2_SERIE  = %exp:cSerie%
        EndSql

        If !(cAlias)->(Eof())
            cChave := AllTrim(cValToChar((cAlias)->F2_CHVNFE))
        EndIf

        (cAlias)->(DbCloseArea())

    EndIf

    XFAT003SET(oDados, "NFNumero", AllTrim(cNota))
    XFAT003SET(oDados, "NFSerie", AllTrim(cSerie))
    XFAT003SET(oDados, "NFChave", cChave)

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003PAR()

  Descricao:
  Monta as parcelas/duplicatas da fatura como {numero,
  vencimento, valor}. Se os titulos do pedido ja foram gerados
  por XFAT003BOL() (prefixo FAT, tipo BOL, numero = C5_NUM), usa
  os proprios titulos da SE1; caso contrario, simula as parcelas
  com a mesma regra usada na geracao dos titulos: Condicao() com
  o Valor a Pagar da fatura e a condicao de pagamento do pedido.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003PAR(oDados)

    Local aParc     := {}
    Local aVenc     := {}
    Local cAlias    := GetNextAlias()
    Local cPrefixo  := PadR("FAT", FWTamSX3("E1_PREFIXO")[1])
    Local cTipo     := PadR("BOL", FWTamSX3("E1_TIPO")[1])
    Local nValorPag := XFAT003GET(oDados, "ValorPagar", 0)
    Local dDtBase   := IIf(!Empty(dDataBase), dDataBase, Date())
    Local nX

    BeginSql Alias cAlias
        SELECT E1_NUM, E1_PARCELA, E1_VENCTO, E1_VALOR
        FROM %table:SE1% SE1
        WHERE SE1.%notDel%
          AND SE1.E1_FILIAL  = %xFilial:SE1%
          AND SE1.E1_PREFIXO = %exp:cPrefixo%
          AND SE1.E1_NUM     = %exp:SC5->C5_NUM%
          AND SE1.E1_TIPO    = %exp:cTipo%
        ORDER BY E1_PARCELA
    EndSql

    TCSetField(cAlias, "E1_VENCTO", "D", 8, 0)

    While !(cAlias)->(Eof())
        aAdd(aParc, {AllTrim((cAlias)->E1_NUM) + IIf(!Empty((cAlias)->E1_PARCELA), "/" + AllTrim((cAlias)->E1_PARCELA), ""), (cAlias)->E1_VENCTO, (cAlias)->E1_VALOR})
        (cAlias)->(DbSkip())
    EndDo

    (cAlias)->(DbCloseArea())

    If Len(aParc) == 0 .And. nValorPag > 0
        If !Empty(SC5->C5_CONDPAG)
            aVenc := Condicao(nValorPag, SC5->C5_CONDPAG, , dDtBase)
        EndIf

        If ValType(aVenc) != "A" .Or. Len(aVenc) == 0
            aVenc := {{IIf(!Empty(SC5->C5_DATA1), SC5->C5_DATA1, dDtBase), nValorPag}}
        EndIf

        For nX := 1 To Len(aVenc)
            aAdd(aParc, {AllTrim(SC5->C5_NUM) + "/" + StrZero(nX, FWTamSX3("E1_PARCELA")[1]), aVenc[nX][1], aVenc[nX][2]})
        Next nX
    EndIf

    aVenc := Nil

Return aParc

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003DOC()

  Descricao:
  Gera a Fatura Mercantil em formato Word (.docx) editavel,
  seguindo o modelo enviado pelo cliente (Fatura_Mercantil_
  Simples_Editavel): cabecalho com logo e dados do emitente,
  numero da fatura/NF-e, cliente/sacado, operacao de venda,
  parcelas/duplicatas, quadro de tributos da operacao
  (ICMS/ST/IPI/PIS/COFINS) e da Reforma Tributaria (IBS/CBS/IS),
  todos calculados por XFAT003IMP(). Campos sem informacao saem
  em branco para o usuario completar no Word.

  O .docx e um pacote ZIP (Open XML): os XML sao gravados em uma
  pasta temporaria no servidor, compactados com FZip() e o
  arquivo e copiado para a estacao (CpyS2T + ShellExecute para
  abrir no Word, ou CpyS2TW no SmartClient HTML). Ao final, a
  pasta temporaria e o arquivo no servidor sao apagados.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003DOC(oDados)

    Local cBarra    := IIf(IsSrvUnix(), "/", "\")
    Local cRaiz     := cBarra + "xfat003" + cBarra
    Local cDirBase  := cRaiz + "f" + FWTimeStamp(1) + cValToChar(ThreadId()) + cBarra
    Local cNomeDoc  := "fatura_" + AllTrim(cValToChar(XFAT003GET(oDados, "NumFatura", ""))) + "_" + AllTrim(cValToChar(XFAT003GET(oDados, "Pedido", ""))) + ".docx"
    Local cZipSrv   := cRaiz + StrTran(cNomeDoc, ".docx", ".zip")
    Local cDocSrv   := cRaiz + cNomeDoc
    Local cDirLoc   := ""
    Local aArqs     := {}
    Local aDirs     := {}
    Local cLogo     := cValToChar(XFAT003GET(oDados, "Logo", ""))
    Local lLogo     := .F.
    Local aTamLogo  := {}
    Local cXml      := ""
    Local cRels     := ""
    Local cLinhas   := ""
    Local lOk       := .T.
    Local nX

    Local aItens    := XFAT003GET(oDados, "Itens", {})
    Local aParc     := XFAT003PAR(oDados)
    Local cMerc     := ""
    Local cEmitNome := cValToChar(XFAT003GET(oDados, "EmitNome", ""))
    Local cEmitIE   := cValToChar(XFAT003GET(oDados, "EmitIE", ""))
    Local cEmitEnd  := cValToChar(XFAT003GET(oDados, "EmitEndCompl", ""))
    Local cMsgAdic  := ""
    Local cCabEmit  := ""
    Local cCor1     := "183F59"
    Local cCorFdo   := "EFF3F6"
    Local cCorCab   := "E7EDF2"

    aAdd(aDirs, cRaiz)
    aAdd(aDirs, cDirBase)
    aAdd(aDirs, cDirBase + "_rels" + cBarra)
    aAdd(aDirs, cDirBase + "word" + cBarra)
    aAdd(aDirs, cDirBase + "word" + cBarra + "_rels" + cBarra)
    aAdd(aDirs, cDirBase + "word" + cBarra + "media" + cBarra)

    For nX := 1 To Len(aDirs)
        If !ExistDir(aDirs[nX])
            MakeDir(aDirs[nX])
        EndIf
        If !ExistDir(aDirs[nX])
            lOk := .F.
        EndIf
    Next nX

    If !lOk
        MsgStop("Nao foi possivel criar a pasta temporaria " + cDirBase + " no servidor para gerar o DOCX.", "Fatura de Cobranca")
        Return
    EndIf

    // Logo: copia o PNG para word/media e calcula o tamanho em EMU (914400 por polegada)
    If !Empty(cLogo)
        lLogo := XFAT003CPY(cLogo, cDirBase + "word" + cBarra + "media" + cBarra + "logo.png")
        If lLogo
            aTamLogo := XFAT003FIT(XFAT003PNG(cLogo), 1600200, 777240)
            aAdd(aArqs, cDirBase + "word" + cBarra + "media" + cBarra + "logo.png")
        EndIf
    EndIf

    // ------------------------------------------------------------------
    // Corpo do documento (word/document.xml)
    // ------------------------------------------------------------------
    cXml := "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
    cXml += "<w:document xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main'"
    cXml += " xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'"
    cXml += " xmlns:wp='http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'"
    cXml += " xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main'"
    cXml += " xmlns:pic='http://schemas.openxmlformats.org/drawingml/2006/picture'><w:body>"

    // Emitente
    cCabEmit := XFAT003WP(XFAT003WR(XFAT003XML(cEmitNome), .T., 30, cCor1), 0, 20, "")
    cCabEmit += XFAT003WP(XFAT003WR("CNPJ: " + XFAT003XML(XFAT003MASK(XFAT003GET(oDados, "EmitCgc", ""))) + IIf(!Empty(cEmitIE), "  |  IE: " + XFAT003XML(cEmitIE), ""), .F., 18, ""), 0, 20, "")
    cCabEmit += XFAT003WP(XFAT003WR(XFAT003XML(cEmitEnd), .F., 17, ""), 0, 40, "")

    If lLogo
        cXml += XFAT003WT({2800, 6888},;
                    "<w:tr>" + XFAT003WC(2800, XFAT003WP(XFAT003WIM(aTamLogo[1], aTamLogo[2]), 0, 0, ""), "") +;
                    XFAT003WC(6888, cCabEmit, "") + "</w:tr>")
    Else
        cXml += cCabEmit
    EndIf

    cXml += XFAT003WP(XFAT003WR("FATURA MERCANTIL", .T., 30, "163347"), 200, 160, "center")

    // Identificacao da fatura / NF-e
    cXml += XFAT003WT({4844, 4844},;
        "<w:tr>" +;
        XFAT003WC(4844, XFAT003WLV("Fatura n&#186;", XFAT003GET(oDados, "NumFatura", ""), 19), cCorFdo) +;
        XFAT003WC(4844, XFAT003WLV("Emiss&#227;o", DtoC(XFAT003GET(oDados, "Emissao", Date())), 19), cCorFdo) +;
        "</w:tr><w:tr>" +;
        XFAT003WC(4844, XFAT003WLV("NF-e n&#186;", XFAT003GET(oDados, "NFNumero", ""), 19), cCorFdo) +;
        XFAT003WC(4844, XFAT003WLV("S&#233;rie NF-e", XFAT003GET(oDados, "NFSerie", ""), 19), cCorFdo) +;
        "</w:tr><w:tr>" +;
        XFAT003WC(4844, XFAT003WLV("Pedido de venda", XFAT003GET(oDados, "Pedido", ""), 19), cCorFdo) +;
        XFAT003WC(4844, XFAT003WLV("Condi&#231;&#227;o de pagamento", XFAT003GET(oDados, "Condicao", ""), 19), cCorFdo) +;
        "</w:tr>")

    // Cliente / Sacado
    cXml += XFAT003WSC("CLIENTE / SACADO")
    cXml += XFAT003WT({9688},;
        "<w:tr>" + XFAT003WC(9688, XFAT003WLV("Raz&#227;o social", XFAT003GET(oDados, "ClienteNome", ""), 19), "") + "</w:tr>" +;
        "<w:tr>" + XFAT003WC(9688, XFAT003WLV("CNPJ/CPF", XFAT003MASK(XFAT003GET(oDados, "ClienteCgc", "")), 19), "") + "</w:tr>" +;
        "<w:tr>" + XFAT003WC(9688, XFAT003WLV("Endere&#231;o", AllTrim(cValToChar(XFAT003GET(oDados, "ClienteEnd", ""))) + " - " + AllTrim(cValToChar(XFAT003GET(oDados, "ClienteMun", ""))) + "/" + AllTrim(cValToChar(XFAT003GET(oDados, "ClienteEst", ""))), 19), "") + "</w:tr>")

    // Operacao de venda: uma linha por item (descricao - quantidade UM)
    For nX := 1 To Len(aItens)
        cMerc += IIf(nX > 1, Chr(10), "") + AllTrim(cValToChar(aItens[nX][2])) + " - " +;
                 AllTrim(Transform(aItens[nX][3], "@E 999,999,999.999")) + " " + AllTrim(cValToChar(aItens[nX][7])) +;
                 " - R$ " + XFAT003NUM(aItens[nX][6])
    Next nX

    cXml += XFAT003WSC("OPERA&#199;&#195;O DE VENDA")
    cXml += XFAT003WT({9688},;
        "<w:tr>" + XFAT003WC(9688, XFAT003WLV("Mercadoria", cMerc, 19), "") + "</w:tr>" +;
        "<w:tr>" + XFAT003WC(9688, XFAT003WLV("Chave de acesso da NF-e", XFAT003GET(oDados, "NFChave", ""), 19), "") + "</w:tr>" +;
        "<w:tr>" + XFAT003WC(9688, XFAT003WLV("Valor da fatura", "R$ " + XFAT003NUM(XFAT003GET(oDados, "ValorPagar", 0)), 20), "") + "</w:tr>")

    // Parcelas / Duplicatas
    cXml += XFAT003WSC("PARCELAS / DUPLICATAS A EMITIR")
    cLinhas := "<w:tr>" +;
        XFAT003WC(1950, XFAT003WP(XFAT003WR("Parcela / duplicata n&#186;", .T., 17, ""), 0, 0, ""), cCorCab) +;
        XFAT003WC(3600, XFAT003WP(XFAT003WR("Vencimento", .T., 17, ""), 0, 0, ""), cCorCab) +;
        XFAT003WC(4138, XFAT003WP(XFAT003WR("Valor (R$)", .T., 17, ""), 0, 0, ""), cCorCab) + "</w:tr>"

    If Len(aParc) == 0
        cLinhas += "<w:tr>" +;
            XFAT003WC(1950, XFAT003WP(XFAT003WR("", .F., 18, ""), 0, 0, ""), "") +;
            XFAT003WC(3600, XFAT003WP(XFAT003WR("", .F., 18, ""), 0, 0, ""), "") +;
            XFAT003WC(4138, XFAT003WP(XFAT003WR("", .F., 18, ""), 0, 0, ""), "") + "</w:tr>"
    EndIf

    For nX := 1 To Len(aParc)
        cLinhas += "<w:tr>" +;
            XFAT003WC(1950, XFAT003WP(XFAT003WR(StrZero(nX, 2) + " - " + XFAT003XML(aParc[nX][1]), .F., 18, ""), 0, 0, ""), "") +;
            XFAT003WC(3600, XFAT003WP(XFAT003WR(DtoC(aParc[nX][2]), .F., 18, ""), 0, 0, ""), "") +;
            XFAT003WC(4138, XFAT003WP(XFAT003WR(XFAT003NUM(aParc[nX][3]), .F., 18, ""), 0, 0, ""), "") + "</w:tr>"
    Next nX

    cXml += XFAT003WT({1950, 3600, 4138}, cLinhas)
    cLinhas := ""

    // Tributos da operacao (informativos)
    cXml += XFAT003WP(XFAT003WR("Tributos da opera&#231;&#227;o:", .F., 18, ""), 160, 100, "")
    cXml += XFAT003WT({3229, 3229, 3230},;
        "<w:tr>" +;
        XFAT003WC(3229, XFAT003WLV("ICMS: R$", XFAT003NUM(XFAT003GET(oDados, "TribICM", 0)), 17), "") +;
        XFAT003WC(3229, XFAT003WLV("ICMS ST: R$", XFAT003NUM(XFAT003GET(oDados, "TribST", 0)), 17), "") +;
        XFAT003WC(3230, XFAT003WLV("IPI: R$", XFAT003NUM(XFAT003GET(oDados, "TribIPI", 0)), 17), "") +;
        "</w:tr><w:tr>" +;
        XFAT003WC(3229, XFAT003WLV("PIS: R$", XFAT003NUM(XFAT003GET(oDados, "TribPIS", 0)), 17), "") +;
        XFAT003WC(3229, XFAT003WLV("COFINS: R$", XFAT003NUM(XFAT003GET(oDados, "TribCOF", 0)), 17), "") +;
        XFAT003WC(3230, XFAT003WLV("Total da NF-e: R$", XFAT003NUM(XFAT003GET(oDados, "ValorNF", 0)), 17), "") +;
        "</w:tr>")

    // Tributos da Reforma Tributaria (informativos)
    cXml += XFAT003WP(XFAT003WR("Tributos da Reforma Tribut&#225;ria:", .F., 18, ""), 160, 100, "")
    cXml += XFAT003WT({3229, 3229, 3230},;
        "<w:tr>" +;
        XFAT003WC(3229, XFAT003WLV("IBS: R$", XFAT003NUM(XFAT003GET(oDados, "TribIBS", 0)), 17), "") +;
        XFAT003WC(3229, XFAT003WLV("CBS: R$", XFAT003NUM(XFAT003GET(oDados, "TribCBS", 0)), 17), "") +;
        XFAT003WC(3230, XFAT003WLV("IS: R$", XFAT003NUM(XFAT003GET(oDados, "TribIS", 0)), 17), "") +;
        "</w:tr>")

    // Mensagens do pedido
    cMsgAdic := AllTrim(cValToChar(XFAT003GET(oDados, "ObsMenNota", "")))
    If !Empty(XFAT003GET(oDados, "ObsXMsgI", ""))
        cMsgAdic += IIf(!Empty(cMsgAdic), Chr(10), "") + AllTrim(cValToChar(XFAT003GET(oDados, "ObsXMsgI", "")))
    EndIf
    If !Empty(cMsgAdic)
        cXml += XFAT003WP(XFAT003WR("Mensagem adicional:  ", .T., 17, "") + XFAT003WR(XFAT003XML(cMsgAdic), .F., 17, ""), 160, 100, "")
    EndIf

    cXml += XFAT003WP(XFAT003WR("Esta fatura refere-se &#224; opera&#231;&#227;o documentada pela NF-e indicada. N&#227;o substitui a nota fiscal e n&#227;o gera nova cobran&#231;a de tributos. Os valores de IBS, CBS e IS, quando informados, devem corresponder &#224; NF-e e n&#227;o ser somados novamente ao valor da fatura.", .F., 17, ""), 160, 100, "")
    cXml += XFAT003WP(XFAT003WR(XFAT003XML(cEmitNome), .T., 18, ""), 180, 0, "right")

    cXml += "<w:sectPr><w:pgSz w:w='11906' w:h='16838'/>"
    cXml += "<w:pgMar w:top='936' w:right='1109' w:bottom='936' w:left='1109' w:header='720' w:footer='720' w:gutter='0'/></w:sectPr>"
    cXml += "</w:body></w:document>"

    lOk := XFAT003GRV(cDirBase + "word" + cBarra + "document.xml", cXml)
    aAdd(aArqs, cDirBase + "word" + cBarra + "document.xml")

    // ------------------------------------------------------------------
    // Estilos (word/styles.xml): fonte padrao Arial, tabelas sem borda
    // ------------------------------------------------------------------
    cXml := "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
    cXml += "<w:styles xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main'>"
    cXml += "<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii='Arial' w:hAnsi='Arial' w:eastAsia='Arial' w:cs='Arial'/>"
    cXml += "<w:sz w:val='20'/><w:szCs w:val='20'/><w:lang w:val='pt-BR'/></w:rPr></w:rPrDefault>"
    cXml += "<w:pPrDefault><w:pPr><w:spacing w:after='120' w:line='264' w:lineRule='auto'/></w:pPr></w:pPrDefault></w:docDefaults>"
    cXml += "<w:style w:type='paragraph' w:default='1' w:styleId='Normal'><w:name w:val='Normal'/><w:qFormat/></w:style>"
    cXml += "<w:style w:type='table' w:default='1' w:styleId='TableNormal'><w:name w:val='Normal Table'/><w:uiPriority w:val='99'/>"
    cXml += "<w:semiHidden/><w:unhideWhenUsed/><w:tblPr><w:tblInd w:w='0' w:type='dxa'/><w:tblCellMar>"
    cXml += "<w:top w:w='0' w:type='dxa'/><w:left w:w='108' w:type='dxa'/><w:bottom w:w='0' w:type='dxa'/><w:right w:w='108' w:type='dxa'/>"
    cXml += "</w:tblCellMar></w:tblPr></w:style></w:styles>"

    lOk := lOk .And. XFAT003GRV(cDirBase + "word" + cBarra + "styles.xml", cXml)
    aAdd(aArqs, cDirBase + "word" + cBarra + "styles.xml")

    // ------------------------------------------------------------------
    // Relacionamentos e tipos de conteudo do pacote
    // ------------------------------------------------------------------
    cRels := "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
    cRels += "<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>"
    cRels += "<Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles' Target='styles.xml'/>"
    If lLogo
        cRels += "<Relationship Id='rId2' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/image' Target='media/logo.png'/>"
    EndIf
    cRels += "</Relationships>"

    lOk := lOk .And. XFAT003GRV(cDirBase + "word" + cBarra + "_rels" + cBarra + "document.xml.rels", cRels)
    aAdd(aArqs, cDirBase + "word" + cBarra + "_rels" + cBarra + "document.xml.rels")

    cXml := "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
    cXml += "<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>"
    cXml += "<Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='word/document.xml'/>"
    cXml += "</Relationships>"

    lOk := lOk .And. XFAT003GRV(cDirBase + "_rels" + cBarra + ".rels", cXml)
    aAdd(aArqs, cDirBase + "_rels" + cBarra + ".rels")

    cXml := "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
    cXml += "<Types xmlns='http://schemas.openxmlformats.org/package/2006/content-types'>"
    cXml += "<Default Extension='rels' ContentType='application/vnd.openxmlformats-package.relationships+xml'/>"
    cXml += "<Default Extension='xml' ContentType='application/xml'/>"
    cXml += "<Default Extension='png' ContentType='image/png'/>"
    cXml += "<Override PartName='/word/document.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'/>"
    cXml += "<Override PartName='/word/styles.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml'/>"
    cXml += "</Types>"

    lOk := lOk .And. XFAT003GRV(cDirBase + "[Content_Types].xml", cXml)
    aAdd(aArqs, cDirBase + "[Content_Types].xml")

    cXml  := ""
    cRels := ""

    // ------------------------------------------------------------------
    // Compacta (o .docx e um ZIP) e entrega o arquivo na estacao
    // ------------------------------------------------------------------
    If lOk
        FErase(cZipSrv)
        FErase(cDocSrv)
        lOk := FZip(cZipSrv, aArqs, cDirBase) == 0 .And. FRename(cZipSrv, cDocSrv) == 0
    EndIf

    If !lOk
        MsgStop("Nao foi possivel gerar o arquivo DOCX da fatura no servidor (" + cDocSrv + ").", "Fatura de Cobranca")
    ElseIf GetRemoteType() == 5
        CpyS2TW(cDocSrv, .T.)
    Else
        cDirLoc := GetTempPath()
        If CpyS2T(cDocSrv, cDirLoc, .F.)
            ShellExecute("open", cDirLoc + cNomeDoc, "", cDirLoc, 1)
        Else
            MsgStop("Nao foi possivel copiar o DOCX da fatura para a pasta " + cDirLoc + ".", "Fatura de Cobranca")
        EndIf
    EndIf

    // Limpeza dos temporarios no servidor
    For nX := 1 To Len(aArqs)
        FErase(aArqs[nX])
    Next nX

    For nX := Len(aDirs) To 2 Step -1
        DirRemove(aDirs[nX])
    Next nX

    FErase(cZipSrv)
    FErase(cDocSrv)

    aSize(aArqs, 0)
    aSize(aDirs, 0)
    aArqs := Nil
    aDirs := Nil
    aParc := Nil

Return

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003CPY()

  Descricao:
  Copia um arquivo binario entre duas pastas do servidor
  (usado para levar a logo PNG para word/media do DOCX), lendo
  e gravando em blocos de 64 KB com FOpen/FRead/FCreate/FWrite,
  sem depender da funcao interna __CopyFile(). Retorna .T.
  quando todo o conteudo foi copiado.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003CPY(cOrigem, cDestino)

    Local nHdlOri := FOpen(cOrigem, 0)
    Local nHdlDst := -1
    Local nTamBlo := 65536
    Local nLidos  := 0
    Local cBuffer := ""
    Local lOk     := .T.

    If nHdlOri < 0
        Return .F.
    EndIf

    nHdlDst := FCreate(cDestino)

    If nHdlDst < 0
        FClose(nHdlOri)
        Return .F.
    EndIf

    Do While lOk
        cBuffer := Space(nTamBlo)
        nLidos  := FRead(nHdlOri, @cBuffer, nTamBlo)
        If nLidos <= 0
            Exit
        EndIf
        If FWrite(nHdlDst, Left(cBuffer, nLidos), nLidos) != nLidos
            lOk := .F.
        EndIf
    EndDo

    FClose(nHdlOri)
    FClose(nHdlDst)
    cBuffer := ""

    If !lOk
        FErase(cDestino)
    EndIf

Return lOk

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003GRV()

  Descricao:
  Grava o conteudo informado em um arquivo no servidor,
  retornando .T. quando a gravacao foi concluida.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003GRV(cArq, cConteudo)

    Local nHdl := FCreate(cArq)

    If nHdl == -1
        Return .F.
    EndIf

    FWrite(nHdl, cConteudo)
    FClose(nHdl)

Return .T.

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003XML()

  Descricao:
  Prepara um texto vindo do banco para o XML do Word: escapa
  &, < e >, converte para UTF-8 e transforma quebras de linha
  em <w:br/> dentro do run.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003XML(xTexto)

    Local cRet := AllTrim(cValToChar(xTexto))
    Local cUtf := ""

    cRet := StrTran(cRet, Chr(13) + Chr(10), Chr(10))
    cRet := StrTran(cRet, Chr(13), Chr(10))
    cRet := StrTran(cRet, Chr(9), " ")
    cRet := StrTran(cRet, "&", "&amp;")
    cRet := StrTran(cRet, "<", "&lt;")
    cRet := StrTran(cRet, ">", "&gt;")

    cUtf := EncodeUTF8(cRet)
    If ValType(cUtf) == "C" .And. !Empty(cUtf)
        cRet := cUtf
    Else
        cRet := FWNoAccento(cRet)
    EndIf

    cRet := StrTran(cRet, Chr(10), "</w:t><w:br/><w:t xml:space='preserve'>")

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003NUM()

  Descricao:
  Formata um valor numerico no padrao brasileiro (9.999,99).

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003NUM(nValor)

Return AllTrim(Transform(IIf(ValType(nValor) == "N", nValor, 0), "@E 999,999,999,999.99"))

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WR()

  Descricao:
  Monta um run (w:r) do Word com o texto ja preparado para XML,
  negrito opcional, tamanho em meios-pontos e cor RGB opcional.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WR(cTexto, lNegrito, nTam, cCor)

    Local cRet := "<w:r><w:rPr>"

    If lNegrito
        cRet += "<w:b/>"
    EndIf

    If !Empty(cCor)
        cRet += "<w:color w:val='" + cCor + "'/>"
    EndIf

    cRet += "<w:sz w:val='" + cValToChar(nTam) + "'/><w:szCs w:val='" + cValToChar(nTam) + "'/></w:rPr>"
    cRet += "<w:t xml:space='preserve'>" + cTexto + "</w:t></w:r>"

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WP()

  Descricao:
  Monta um paragrafo (w:p) com os runs informados, espacamento
  antes/depois (em twips) e alinhamento opcional.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WP(cRuns, nAntes, nDepois, cAlinha)

    Local cRet := "<w:p><w:pPr><w:spacing w:before='" + cValToChar(nAntes) + "' w:after='" + cValToChar(nDepois) + "'/>"

    If !Empty(cAlinha)
        cRet += "<w:jc w:val='" + cAlinha + "'/>"
    EndIf

    cRet += "</w:pPr>" + cRuns + "</w:p>"

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WLV()

  Descricao:
  Monta o paragrafo "Rotulo:  valor" usado nos quadros da
  fatura. Quando o valor estiver vazio, o campo fica em branco
  apos o rotulo para o usuario completar no Word.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WLV(cRotulo, xValor, nTam)

    Local cValor := AllTrim(cValToChar(xValor))
    Local cRuns  := XFAT003WR(cRotulo + IIf(Right(cRotulo, 2) == "R$", "  ", ":  "), .T., nTam, "")

    If !Empty(cValor)
        cRuns += XFAT003WR(XFAT003XML(cValor), .F., nTam, "")
    EndIf

Return XFAT003WP(cRuns, 0, 0, "")

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WSC()

  Descricao:
  Monta o titulo de secao da fatura (ex.: CLIENTE / SACADO).

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WSC(cTitulo)

Return XFAT003WP(XFAT003WR(cTitulo, .T., 18, "27526F"), 160, 80, "")

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WC()

  Descricao:
  Monta uma celula de tabela (w:tc) com largura em twips,
  margens internas e cor de fundo opcional.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WC(nLarg, cParags, cFundo)

    Local cRet := "<w:tc><w:tcPr><w:tcW w:w='" + cValToChar(nLarg) + "' w:type='dxa'/>"

    If !Empty(cFundo)
        cRet += "<w:shd w:val='clear' w:color='auto' w:fill='" + cFundo + "'/>"
    EndIf

    cRet += "<w:tcMar><w:top w:w='75' w:type='dxa'/><w:left w:w='100' w:type='dxa'/>"
    cRet += "<w:bottom w:w='75' w:type='dxa'/><w:right w:w='100' w:type='dxa'/></w:tcMar>"
    cRet += "<w:vAlign w:val='center'/></w:tcPr>" + cParags + "</w:tc>"

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WT()

  Descricao:
  Monta uma tabela (w:tbl) de layout fixo com as larguras de
  coluna informadas (twips) e as linhas (w:tr) ja montadas.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WT(aLarg, cLinhas)

    Local cRet := "<w:tbl><w:tblPr><w:tblW w:w='0' w:type='auto'/><w:tblLayout w:type='fixed'/></w:tblPr><w:tblGrid>"
    Local nX

    For nX := 1 To Len(aLarg)
        cRet += "<w:gridCol w:w='" + cValToChar(aLarg[nX]) + "'/>"
    Next nX

    cRet += "</w:tblGrid>" + cLinhas + "</w:tbl>"

Return cRet

//---------------------------------------------------------
/*/ Rotina XFAT003
  Funcao XFAT003WIM()

  Descricao:
  Monta o run com a imagem da logo (word/media/logo.png,
  relacionamento rId2) inline, no tamanho informado em EMU.

  @author Elvis Siqueira
  @since  26/10/2026
/*/
//----------------------------------------------------------
Static Function XFAT003WIM(nCx, nCy)

    Local cCx  := cValToChar(nCx)
    Local cCy  := cValToChar(nCy)
    Local cRet := ""

    cRet := "<w:r><w:drawing><wp:inline distT='0' distB='0' distL='0' distR='0'>"
    cRet += "<wp:extent cx='" + cCx + "' cy='" + cCy + "'/>"
    cRet += "<wp:docPr id='1' name='Logo'/>"
    cRet += "<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect='1'/></wp:cNvGraphicFramePr>"
    cRet += "<a:graphic><a:graphicData uri='http://schemas.openxmlformats.org/drawingml/2006/picture'>"
    cRet += "<pic:pic><pic:nvPicPr><pic:cNvPr id='0' name='logo.png'/><pic:cNvPicPr/></pic:nvPicPr>"
    cRet += "<pic:blipFill><a:blip r:embed='rId2'/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>"
    cRet += "<pic:spPr><a:xfrm><a:off x='0' y='0'/><a:ext cx='" + cCx + "' cy='" + cCy + "'/></a:xfrm>"
    cRet += "<a:prstGeom prst='rect'><a:avLst/></a:prstGeom></pic:spPr></pic:pic>"
    cRet += "</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>"

Return cRet

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
