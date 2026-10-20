#Include "Protheus.ch"

/*/{Protheus.doc} IMPCIAP
Importa o arquivo importacao_CIAP_SF9.txt (separador ";", data dd/mm/aa,
decimal com virgula, sem cabecalho) gravando direto na SF9.
Alternativa para quando a MATA905 nao aceita MsExecAuto.
A MATA905 nao aceita MsExecAuto (Function MATA905 sem parametros, inclusao
via Enchoice em A905Inclui). Esta rotina reproduz o que a A905Inclui grava:
inicializadores do dicionario (CriaVar), F9_ROTINA, F9_STATUS e o vinculo
D1_CODCIAP, com a mesma validacao de item/ICMS da A905TudOk.
Nao gera a contabilizacao do LP 770 (A905IncCtb).
/*/
User Function IMPCIAP()
	Local cArq := ""

	cArq := cGetFile("Arquivo TXT|*.txt", "Selecione o arquivo do CIAP", 0, "C:\", .T., GETF_LOCALHARD + GETF_NETWORKDRIVE)
	If Empty(cArq)
		Return
	EndIf

	Processa({|| ImpArq(cArq)}, "Importando CIAP...")
Return

Static Function ImpArq(cArq)
	Local oArq    := FWFileReader():New(cArq)
	Local cLinha  := ""
	Local aCpo    := {}
	Local aErros  := {}
	Local nLinha  := 0
	Local nOk     := 0
	Local cMsg    := ""
	Local nI      := 0

	If !oArq:Open()
		MsgStop("Nao foi possivel abrir " + cArq)
		Return
	EndIf

	DbSelectArea("SA2")
	SA2->(DbSetOrder(1))
	DbSelectArea("SF9")
	SF9->(DbSetOrder(1))
	DbSelectArea("SD1")
	SD1->(DbSetOrder(1))

	While oArq:HasLine()
		cLinha := oArq:GetLine()
		nLinha++
		IncProc("Linha " + cValToChar(nLinha))

		If Empty(cLinha)
			Loop
		EndIf

		aCpo := StrTokArr2(cLinha, ";", .T.)
		If Len(aCpo) < 15
			aAdd(aErros, "Linha " + cValToChar(nLinha) + ": esperado 15 colunas, veio " + cValToChar(Len(aCpo)))
			Loop
		EndIf

		If !SA2->(DbSeek(xFilial("SA2") + PadR(aCpo[3], TamSX3("A2_COD")[1]) + PadR(aCpo[4], TamSX3("A2_LOJA")[1])))
			aAdd(aErros, "Linha " + cValToChar(nLinha) + ": fornecedor " + aCpo[3] + "/" + aCpo[4] + " nao existe na SA2")
			Loop
		EndIf

		If SF9->(DbSeek(xFilial("SF9") + PadR(aCpo[1], TamSX3("F9_CODIGO")[1])))
			aAdd(aErros, "Linha " + cValToChar(nLinha) + ": ativo " + aCpo[1] + " ja existe na SF9")
			Loop
		EndIf

		If !Empty(aCpo[9]) .And. !VldItem(aCpo, @aErros, nLinha)
			Loop
		EndIf

		Begin Transaction
		RecLock("SF9", .T.)
		For nI := 1 To SF9->(FCount())
			SF9->(FieldPut(nI, CriaVar(SF9->(FieldName(nI)), .T.)))
		Next nI
		SF9->F9_FILIAL  := xFilial("SF9")
		SF9->F9_ROTINA  := "MATA905"
		If SF9->(FieldPos("F9_STATUS")) > 0
			SF9->F9_STATUS := "1"
		EndIf
		SF9->F9_CODIGO  := aCpo[1]
		SF9->F9_DESCRI  := aCpo[2]
		SF9->F9_FORNECE := aCpo[3]
		SF9->F9_LOJAFOR := aCpo[4]
		SF9->F9_DOCNFE  := aCpo[5]
		SF9->F9_SERNFE  := aCpo[6]
		SF9->F9_QTDNF   := ValNum(aCpo[7])
		SF9->F9_TPESP   := aCpo[8]
		SF9->F9_ITEMNFE := aCpo[9]
		SF9->F9_PROPRIO := aCpo[10]
		SF9->F9_CHAVENF := aCpo[11]
		SF9->F9_NLRE    := aCpo[12]
		SF9->F9_DTENTNE := DataTxt(aCpo[13])
		SF9->F9_DTEMINE := DataTxt(aCpo[14])
		SF9->F9_VALICMS := ValNum(aCpo[15])
		SF9->(MsUnlock())

		If !Empty(SF9->F9_ITEMNFE) .And. SD1->(DbSeek(xFilial("SD1") + SF9->(F9_DOCNFE + F9_SERNFE + F9_FORNECE + F9_LOJAFOR + F9_ITEMNFE)))
			RecLock("SD1", .F.)
			SD1->D1_CODCIAP := SF9->F9_CODIGO
			SD1->(MsUnlock())
		EndIf
		If __lSX8
			ConfirmSX8()
		EndIf
		End Transaction
		nOk++
	EndDo

	oArq:Close()

	cMsg := cValToChar(nOk) + " registro(s) incluido(s)." + CRLF
	For nI := 1 To Len(aErros)
		cMsg += CRLF + aErros[nI]
	Next nI
	MsgInfo(cMsg, "IMPCIAP")
Return

// Mesma regra da A905TudOk: com item informado, a NF/item deve existir na SD1
// e o ICMS deve bater com o total ou com o valor unitario do item
Static Function VldItem(aCpo, aErros, nLinha)
	Local cChave  := xFilial("SD1") + PadR(aCpo[5], TamSX3("D1_DOC")[1]) + PadR(aCpo[6], TamSX3("D1_SERIE")[1]) + ;
	                 PadR(aCpo[3], TamSX3("D1_FORNECE")[1]) + PadR(aCpo[4], TamSX3("D1_LOJA")[1]) + PadR(aCpo[9], TamSX3("D1_ITEM")[1])
	Local nIcms   := ValNum(aCpo[15])
	Local nIcmNF  := 0
	Local cSTCIAP := AllTrim(SuperGetMV("MV_STCIAP", .F., "N"))

	If !SD1->(DbSeek(cChave))
		aAdd(aErros, "Linha " + cValToChar(nLinha) + ": NF " + aCpo[5] + "/" + aCpo[6] + " item " + aCpo[9] + " nao existe na SD1")
		Return .F.
	EndIf

	nIcmNF := SD1->D1_VALICM + SD1->D1_ICMSCOM + IIf(cSTCIAP == "S", SD1->D1_ICMSRET, 0)
	If nIcmNF != nIcms .And. (nIcmNF / SD1->D1_QUANT) != nIcms
		aAdd(aErros, "Linha " + cValToChar(nLinha) + ": ICMS " + aCpo[15] + " nao confere com o item da NF")
		Return .F.
	EndIf
Return .T.

// dd/mm/aa ou dd/mm/aaaa, independente do SET DATE/SET CENTURY da sessao
Static Function DataTxt(cData)
	Local aPartes := StrTokArr2(AllTrim(cData), "/", .T.)
	Local cAno    := ""

	If Len(aPartes) <> 3
		Return CToD("")
	EndIf
	cAno := aPartes[3]
	If Len(cAno) == 2
		cAno := "20" + cAno
	EndIf
Return SToD(cAno + StrZero(Val(aPartes[2]), 2) + StrZero(Val(aPartes[1]), 2))

// "48.500,00" ou "48500,00" -> 48500
Static Function ValNum(cValor)
Return Val(StrTran(StrTran(AllTrim(cValor), ".", ""), ",", "."))
