#Include "Protheus.ch"
#Include "TOTVS.ch"

/*/{Protheus.doc} IMPCIAP
Importa o arquivo importacao_CIAP_SF9.txt (separador ";", data dd/mm/aa,
decimal com virgula, sem cabecalho) gravando direto na SF9.
A MATA905 nao aceita MsExecAuto (Function MATA905 sem parametros, inclusao
via Enchoice em A905Inclui). Esta rotina reproduz o que a A905Inclui grava:
inicializadores do dicionario (CriaVar), F9_ROTINA, F9_STATUS e o vinculo
D1_CODCIAP, com a mesma validacao de item/ICMS da A905TudOk.
Nao gera a contabilizacao do LP 770 (A905IncCtb).
Ao final abre uma tela HTML (embutida neste fonte, TWebEngine/TWebChannel)
com o status de cada linha, o motivo dos erros, filtros e exportacao para CSV.
/*/
User Function IMPCIAP()
	Local cArq := ""
	Local aRes := {}

	cArq := cGetFile("Arquivo TXT|*.txt", "Selecione o arquivo do CIAP", 0, "C:\", .T., GETF_LOCALHARD + GETF_NETWORKDRIVE)
	If Empty(cArq)
		Return
	EndIf

	Processa({|| aRes := ImpArq(cArq)}, "Importando CIAP...")

	If !Empty(aRes)
		IMPCIAPTEL(aRes, cArq)
	EndIf
Return

Static Function ImpArq(cArq)
	Local oArq    := FWFileReader():New(cArq)
	Local cLinha  := ""
	Local aCpo    := {}
	Local aRes    := {}
	Local nLinha  := 0
	Local nColArq := 0
	Local cErro   := ""
	Local nI      := 0
	// Ordem das colunas do arquivo (layout CIAP do cfgr600)
	Local aLayout := {"F9_CODIGO", "F9_DESCRI", "F9_FORNECE", "F9_LOJAFOR", "F9_DOCNFE", "F9_SERNFE", ;
	                  "F9_QTDNF", "F9_TPESP", "F9_ITEMNFE", "F9_PROPRIO", "F9_CHAVENF", "F9_NLRE", ;
	                  "F9_DTENTNE", "F9_DTEMINE", "F9_VALICMS"}

	If !oArq:Open()
		MsgStop("Nao foi possivel abrir " + cArq)
		Return {}
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

		aCpo    := StrTokArr2(cLinha, ";", .T.)
		nColArq := Len(aCpo)
		// Completa as colunas que faltarem para o relatorio sempre ter todas
		While Len(aCpo) < Len(aLayout)
			aAdd(aCpo, "")
		EndDo

		cErro := VldLinha(aCpo, nColArq, Len(aLayout))
		If !Empty(cErro)
			aAdd(aRes, {nLinha, .F., cErro, aCpo})
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
		For nI := 1 To Len(aLayout)
			SF9->(FieldPut(FieldPos(aLayout[nI]), ConvCpo(aLayout[nI], aCpo[nI])))
		Next nI
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
		aAdd(aRes, {nLinha, .T., "", aCpo})
	EndDo

	oArq:Close()
Return aRes

// Retorna o motivo da recusa da linha, ou "" se ela pode ser gravada
Static Function VldLinha(aCpo, nColArq, nColLay)
	If nColArq < nColLay
		Return "Esperado " + cValToChar(nColLay) + " colunas, veio " + cValToChar(nColArq)
	EndIf

	If !SA2->(DbSeek(xFilial("SA2") + PadR(aCpo[3], TamSX3("A2_COD")[1]) + PadR(aCpo[4], TamSX3("A2_LOJA")[1])))
		Return "Fornecedor " + aCpo[3] + "/" + aCpo[4] + " nao existe na SA2"
	EndIf

	If SF9->(DbSeek(xFilial("SF9") + PadR(aCpo[1], TamSX3("F9_CODIGO")[1])))
		Return "Ativo " + aCpo[1] + " ja existe na SF9"
	EndIf

	If !Empty(aCpo[9])
		Return VldItem(aCpo)
	EndIf
Return ""

// Mesma regra da A905TudOk: com item informado, a NF/item deve existir na SD1
// e o ICMS deve bater com o total ou com o valor unitario do item
Static Function VldItem(aCpo)
	Local cChave  := xFilial("SD1") + PadR(aCpo[5], TamSX3("D1_DOC")[1]) + PadR(aCpo[6], TamSX3("D1_SERIE")[1]) + ;
	                 PadR(aCpo[3], TamSX3("D1_FORNECE")[1]) + PadR(aCpo[4], TamSX3("D1_LOJA")[1]) + PadR(aCpo[9], TamSX3("D1_ITEM")[1])
	Local nIcms   := ValNum(aCpo[15])
	Local nIcmNF  := 0
	Local cSTCIAP := AllTrim(SuperGetMV("MV_STCIAP", .F., "N"))

	If !SD1->(DbSeek(cChave))
		Return "NF " + aCpo[5] + "/" + aCpo[6] + " item " + aCpo[9] + " nao existe na SD1"
	EndIf

	nIcmNF := SD1->D1_VALICM + SD1->D1_ICMSCOM + IIf(cSTCIAP == "S", SD1->D1_ICMSRET, 0)
	If nIcmNF != nIcms .And. (nIcmNF / SD1->D1_QUANT) != nIcms
		Return "ICMS " + aCpo[15] + " nao confere com o item da NF (" + AllTrim(Transform(nIcmNF, "@E 999,999,999.99")) + ")"
	EndIf
Return ""

// Converte o texto do arquivo conforme o tipo do campo no dicionario (SX3)
Static Function ConvCpo(cCampo, cValor)
	Local cTipo := TamSX3(cCampo)[3]

	If cTipo == "N"
		Return ValNum(cValor)
	ElseIf cTipo == "D"
		Return DataTxt(cValor)
	EndIf
Return PadR(cValor, TamSX3(cCampo)[1])

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

//---------------------------------------------------------
/*/ Funcao: IMPCIAPTEL
  Descricao: Tela HTML (TWebEngine/TWebChannel) com o resultado da importacao.
/*/
//----------------------------------------------------------
Static Function IMPCIAPTEL(aRes, cArq)

	Local oDlg
	Local oWeb
	Local oChannel
	Local cPathLocal
	Local cUrlWeb
	Local cBarra
	Local cHtml
	Local nHandle
	Local nTop
	Local nLeft
	Local nBottom
	Local nRight
	Local nHeight
	Local nWidth

	Private aResImp := aRes
	Private cArqImp := cArq

	cBarra	 := IIf(IsSrvUnix(), "/", "\")
	cPathLocal := cBarra + "web" + cBarra + "impciap.html"

	cHtml := IMPCIAPHTM()

	nHandle := FCreate(cPathLocal)

	If nHandle == -1
		MsgStop("Nao foi possivel gravar o arquivo HTML no servidor em: " + cPathLocal, "Importacao CIAP")
		Return .F.
	EndIf

	FWrite(nHandle, cHtml)
	FClose(nHandle)

	cUrlWeb := CpyF2Web(cPathLocal)

	If Empty(cUrlWeb)
		MsgStop("Nao foi possivel disponibilizar a pagina HTML via CpyF2Web.", "Importacao CIAP")
		Return .F.
	EndIf

	If Type("oMainWnd") == "O" .And. oMainWnd:nClientHeight > 0
		nHeight := oMainWnd:nClientHeight * 0.85
		nWidth  := oMainWnd:nClientWidth  * 0.85
		nTop	:= (oMainWnd:nClientHeight - nHeight) / 2
		nLeft   := (oMainWnd:nClientWidth  - nWidth)  / 2
		nBottom := nTop  + nHeight
		nRight  := nLeft + nWidth
	Else
		nTop	:= 020
		nLeft   := 020
		nBottom := 520
		nRight  := 900
	EndIf

	DEFINE MSDIALOG oDlg TITLE "Resultado da Importacao CIAP" ;
		FROM nTop, nLeft TO nBottom, nRight PIXEL

		oDlg:lEscClose := .T.

		oChannel := TWebChannel():New()
		oChannel:bJsToAdvpl := { |cSelf, cChave, cValor| IMPCIAPHDL(cChave, cValor, oDlg, oChannel) }
		oChannel:connect()

		oWeb := TWebEngine():New(oDlg, 0, 0, 100, 100, , oChannel:nPort)
		oWeb:Align := CONTROL_ALIGN_ALLCLIENT
		oWeb:SetAsMain()

		oWeb:Navigate(cUrlWeb + "?port=" + cValToChar(oChannel:nPort))

	ACTIVATE MSDIALOG oDlg CENTERED ;
		ON INIT SetKey(VK_ESCAPE, { || oDlg:End() })

Return .T.

//---------------------------------------------------------
/*/ Funcao: IMPCIAPHDL
  Descricao: Trata as mensagens recebidas do HTML via TWebChannel.
/*/
//----------------------------------------------------------
Static Function IMPCIAPHDL(cChave, cValor, oDlgP, oChanP)

	If cChave == "READY"
		IMPCIAPDAD(oChanP)
		Return .T.
	EndIf

	If cChave == "EXPORTAR"
		IMPCIAPCSV(cValor)
		Return .T.
	EndIf

	If cChave == "CLOSE_PANEL"
		oDlgP:End()
		Return .T.
	EndIf

Return .T.

//---------------------------------------------------------
/*/ Funcao: IMPCIAPDAD
  Descricao: Envia ao HTML o resultado de cada linha importada.
/*/
//----------------------------------------------------------
Static Function IMPCIAPDAD(oChanP)

	Local jResult := jsonObject():New()
	Local jItem
	Local aDados  := {}
	Local aCpos   := {}
	Local nI	  := 0
	Local nJ	  := 0

	For nI := 1 To Len(aResImp)
		aCpos := {}
		For nJ := 1 To Len(aResImp[nI][4])
			aAdd(aCpos, AllTrim(aResImp[nI][4][nJ]))
		Next nJ

		jItem := jsonObject():New()
		jItem["l"]   := aResImp[nI][1]
		jItem["ok"]  := aResImp[nI][2]
		jItem["msg"] := aResImp[nI][3]
		jItem["c"]   := aCpos
		aAdd(aDados, jItem)
	Next nI

	jResult["dados"]   := aDados
	jResult["arq"]	 := cArqImp
	jResult["data"]	:= DtoC(Date()) + " " + Left(Time(), 5)
	jResult["usuario"] := AllTrim(cUserName)
	jResult["empresa"] := cEmpAnt + "/" + AllTrim(cFilAnt)

	oChanP:advplToJS("renderDados", jResult:ToJson())

Return

//---------------------------------------------------------
/*/ Funcao: IMPCIAPCSV
  Descricao: Grava na maquina do usuario o CSV com os registros filtrados no HTML.
/*/
//----------------------------------------------------------
Static Function IMPCIAPCSV(cValor)

	Local jDados  := jsonObject():New()
	Local cDir	:= ""
	Local cArqCsv := ""
	Local cFiltro := ""
	Local nHandle := 0

	jDados:FromJson(cValor)

	If !jDados:HasProperty("csv")
		Return .F.
	EndIf

	cFiltro := IIf(jDados["filtro"] == "S", "importados", IIf(jDados["filtro"] == "E", "erros", "todos"))

	cDir := cGetFile("", "Selecione a pasta para salvar o CSV", 0, "C:\", .F., GETF_LOCALHARD + GETF_NETWORKDRIVE + GETF_RETDIRECTORY)
	If Empty(cDir)
		Return .F.
	EndIf

	cArqCsv := AllTrim(cDir) + IIf(Right(AllTrim(cDir), 1) == "\", "", "\") + ;
			   "ciap_" + cFiltro + "_" + DtoS(Date()) + "_" + StrTran(Time(), ":", "") + ".csv"

	nHandle := FCreate(cArqCsv)
	If nHandle == -1
		MsgStop("Nao foi possivel gravar o arquivo " + cArqCsv, "Importacao CIAP")
		Return .F.
	EndIf

	// BOM UTF-8 para o Excel abrir com acentuacao correta
	FWrite(nHandle, Chr(239) + Chr(187) + Chr(191) + jDados["csv"])
	FClose(nHandle)

	MsgInfo("Arquivo gerado em:" + CRLF + cArqCsv, "Importacao CIAP")

Return .T.

//---------------------------------------------------------
/*/ Funcao: IMPCIAPHTM
  Descricao: Monta o conteudo HTML da tela de resultado da importacao.
/*/
//----------------------------------------------------------
Static Function IMPCIAPHTM()

	Local cHtml := ""

	cHtml += "<!DOCTYPE html>" + Chr(13) + Chr(10)
	cHtml += "<html lang=" + Chr(34) + "pt-BR" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "<head>" + Chr(13) + Chr(10)
	cHtml += "  <meta charset=" + Chr(34) + "UTF-8" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "  <meta name=" + Chr(34) + "viewport" + Chr(34) + " content=" + Chr(34) + "width=device-width, initial-scale=1.0" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "  <title>Resultado da Importacao CIAP</title>" + Chr(13) + Chr(10)
	cHtml += "  <script src=" + Chr(34) + "https://cdn.tailwindcss.com" + Chr(34) + "></script>" + Chr(13) + Chr(10)
	cHtml += "  <link rel=" + Chr(34) + "stylesheet" + Chr(34) + " href=" + Chr(34) + "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" + Chr(34) + ">" + Chr(13) + Chr(10)
	// Biblioteca twebchannel (mesma do XFAT003)
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
	cHtml += "</head>" + Chr(13) + Chr(10)
	cHtml += "<body class=" + Chr(34) + "bg-slate-100 text-slate-800 font-sans antialiased h-screen flex flex-col p-4 select-none relative" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "  <!-- CABECALHO / RESUMO -->" + Chr(13) + Chr(10)
	cHtml += "  <div class=" + Chr(34) + "bg-white p-3 rounded-lg border border-slate-200 shadow-sm mb-3 flex flex-col gap-3" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "    <div class=" + Chr(34) + "flex items-center justify-between" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "      <div>" + Chr(13) + Chr(10)
	cHtml += "        <h1 class=" + Chr(34) + "text-sm font-bold text-slate-700" + Chr(34) + ">Resultado da Importacao CIAP (SF9)</h1>" + Chr(13) + Chr(10)
	cHtml += "        <p id=" + Chr(34) + "hdrInfo" + Chr(34) + " class=" + Chr(34) + "text-xs text-slate-500 mt-0.5" + Chr(34) + "></p>" + Chr(13) + Chr(10)
	cHtml += "      </div>" + Chr(13) + Chr(10)
	cHtml += "      <button id=" + Chr(34) + "btnFechar" + Chr(34) + " class=" + Chr(34) + "px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 font-semibold rounded-md text-sm transition-all" + Chr(34) + "><i class=" + Chr(34) + "fa-solid fa-xmark mr-1" + Chr(34) + "></i>Fechar</button>" + Chr(13) + Chr(10)
	cHtml += "    </div>" + Chr(13) + Chr(10)
	cHtml += "    <div class=" + Chr(34) + "flex gap-3" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "      <div data-f=" + Chr(34) + "T" + Chr(34) + " class=" + Chr(34) + "card cursor-pointer flex-1 border border-slate-200 rounded-md px-3 py-2" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <div class=" + Chr(34) + "text-xs uppercase text-slate-500" + Chr(34) + ">Total de linhas</div>" + Chr(13) + Chr(10)
	cHtml += "        <div id=" + Chr(34) + "cTot" + Chr(34) + " class=" + Chr(34) + "text-xl font-bold text-slate-700" + Chr(34) + ">0</div>" + Chr(13) + Chr(10)
	cHtml += "      </div>" + Chr(13) + Chr(10)
	cHtml += "      <div data-f=" + Chr(34) + "S" + Chr(34) + " class=" + Chr(34) + "card cursor-pointer flex-1 border border-slate-200 rounded-md px-3 py-2" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <div class=" + Chr(34) + "text-xs uppercase text-slate-500" + Chr(34) + "><i class=" + Chr(34) + "fa-solid fa-circle text-emerald-600 mr-1" + Chr(34) + "></i>Importadas</div>" + Chr(13) + Chr(10)
	cHtml += "        <div id=" + Chr(34) + "cOk" + Chr(34) + " class=" + Chr(34) + "text-xl font-bold text-emerald-600" + Chr(34) + ">0</div>" + Chr(13) + Chr(10)
	cHtml += "      </div>" + Chr(13) + Chr(10)
	cHtml += "      <div data-f=" + Chr(34) + "E" + Chr(34) + " class=" + Chr(34) + "card cursor-pointer flex-1 border border-slate-200 rounded-md px-3 py-2" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <div class=" + Chr(34) + "text-xs uppercase text-slate-500" + Chr(34) + "><i class=" + Chr(34) + "fa-solid fa-circle text-rose-600 mr-1" + Chr(34) + "></i>Com erro</div>" + Chr(13) + Chr(10)
	cHtml += "        <div id=" + Chr(34) + "cErr" + Chr(34) + " class=" + Chr(34) + "text-xl font-bold text-rose-600" + Chr(34) + ">0</div>" + Chr(13) + Chr(10)
	cHtml += "      </div>" + Chr(13) + Chr(10)
	cHtml += "    </div>" + Chr(13) + Chr(10)
	cHtml += "    <div class=" + Chr(34) + "flex items-center gap-3" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "      <select id=" + Chr(34) + "selStatus" + Chr(34) + " class=" + Chr(34) + "py-2 px-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <option value=" + Chr(34) + "T" + Chr(34) + ">TODOS OS STATUS</option>" + Chr(13) + Chr(10)
	cHtml += "        <option value=" + Chr(34) + "S" + Chr(34) + ">IMPORTADO COM SUCESSO</option>" + Chr(13) + Chr(10)
	cHtml += "        <option value=" + Chr(34) + "E" + Chr(34) + ">COM ERRO</option>" + Chr(13) + Chr(10)
	cHtml += "      </select>" + Chr(13) + Chr(10)
	cHtml += "      <div class=" + Chr(34) + "relative flex-1" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <input type=" + Chr(34) + "text" + Chr(34) + " id=" + Chr(34) + "txtSearch" + Chr(34) + " placeholder=" + Chr(34) + "PESQUISAR POR CODIGO, DESCRICAO, NF, FORNECEDOR OU MOTIVO..." + Chr(34) + Chr(13) + Chr(10)
	cHtml += "               class=" + Chr(34) + "w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent uppercase" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <i class=" + Chr(34) + "fa-solid fa-magnifying-glass absolute left-3 top-2.5 text-slate-400 text-sm" + Chr(34) + "></i>" + Chr(13) + Chr(10)
	cHtml += "      </div>" + Chr(13) + Chr(10)
	cHtml += "      <button id=" + Chr(34) + "btnLimpar" + Chr(34) + " class=" + Chr(34) + "px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 font-semibold rounded-md text-sm transition-all" + Chr(34) + ">Limpar</button>" + Chr(13) + Chr(10)
	cHtml += "      <button id=" + Chr(34) + "btnExportar" + Chr(34) + " class=" + Chr(34) + "px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-md text-sm transition-all shadow" + Chr(34) + "><i class=" + Chr(34) + "fa-solid fa-file-csv mr-1" + Chr(34) + "></i>Exportar filtrados</button>" + Chr(13) + Chr(10)
	cHtml += "    </div>" + Chr(13) + Chr(10)
	cHtml += "  </div>" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "  <!-- GRID -->" + Chr(13) + Chr(10)
	cHtml += "  <div class=" + Chr(34) + "bg-white rounded-lg border border-slate-200 shadow-sm flex-1 overflow-auto" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "    <table class=" + Chr(34) + "w-full text-xs whitespace-nowrap" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "      <thead class=" + Chr(34) + "bg-slate-200 text-slate-700 font-bold sticky top-0 border-b border-slate-300" + Chr(34) + ">" + Chr(13) + Chr(10)
	cHtml += "        <tr id=" + Chr(34) + "hdrGrid" + Chr(34) + "></tr>" + Chr(13) + Chr(10)
	cHtml += "      </thead>" + Chr(13) + Chr(10)
	cHtml += "      <tbody id=" + Chr(34) + "tbDados" + Chr(34) + "></tbody>" + Chr(13) + Chr(10)
	cHtml += "    </table>" + Chr(13) + Chr(10)
	cHtml += "    <div id=" + Chr(34) + "divVazio" + Chr(34) + " class=" + Chr(34) + "hidden p-8 text-center text-slate-500 text-sm" + Chr(34) + ">Nenhum registro para o filtro selecionado.</div>" + Chr(13) + Chr(10)
	cHtml += "  </div>" + Chr(13) + Chr(10)
	cHtml += "  <div id=" + Chr(34) + "divRodape" + Chr(34) + " class=" + Chr(34) + "text-xs text-slate-500 mt-2" + Chr(34) + "></div>" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "  <script>" + Chr(13) + Chr(10)
	cHtml += "    var CAMPOS = [" + Chr(34) + "F9_CODIGO" + Chr(34) + "," + Chr(34) + "F9_DESCRI" + Chr(34) + "," + Chr(34) + "F9_FORNECE" + Chr(34) + "," + Chr(34) + "F9_LOJAFOR" + Chr(34) + "," + Chr(34) + "F9_DOCNFE" + Chr(34) + "," + Chr(34) + "F9_SERNFE" + Chr(34) + "," + Chr(34) + "F9_QTDNF" + Chr(34) + "," + Chr(34) + "F9_TPESP" + Chr(34) + "," + Chr(34) + "F9_ITEMNFE" + Chr(34) + "," + Chr(34) + "F9_PROPRIO" + Chr(34) + "," + Chr(34) + "F9_CHAVENF" + Chr(34) + "," + Chr(34) + "F9_NLRE" + Chr(34) + "," + Chr(34) + "F9_DTENTNE" + Chr(34) + "," + Chr(34) + "F9_DTEMINE" + Chr(34) + "," + Chr(34) + "F9_VALICMS" + Chr(34) + "];" + Chr(13) + Chr(10)
	cHtml += "    var dadosList = [];" + Chr(13) + Chr(10)
	cHtml += "    var ord = { i: 1, asc: true };" + Chr(13) + Chr(10)
	cHtml += "    var COLS = [" + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "STATUS" + Chr(34) + ",         k: function(r) { return r.ok ? " + Chr(34) + "IMPORTADO" + Chr(34) + " : " + Chr(34) + "ERRO" + Chr(34) + "; } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "LINHA" + Chr(34) + ",          k: function(r) { return r.l; }, n: 1 }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "COD. ATIVO" + Chr(34) + ",     k: function(r) { return r.c[0]; } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "DESCRICAO" + Chr(34) + ",      k: function(r) { return r.c[1]; } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "FORNECEDOR" + Chr(34) + ",     k: function(r) { return r.c[2] + (r.c[3] ? " + Chr(34) + " / " + Chr(34) + " + r.c[3] : " + Chr(34) + Chr(34) + "); } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "NF / SERIE" + Chr(34) + ",     k: function(r) { return r.c[4] + (r.c[5] ? " + Chr(34) + " / " + Chr(34) + " + r.c[5] : " + Chr(34) + Chr(34) + "); } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "ITEM" + Chr(34) + ",           k: function(r) { return r.c[8]; } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "DT. DIGITACAO" + Chr(34) + ",  k: function(r) { return r.c[12]; } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "DT. EMISSAO" + Chr(34) + ",    k: function(r) { return r.c[13]; } }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "VALOR ICMS" + Chr(34) + ",     k: function(r) { return r.c[14]; }, n: 1 }," + Chr(13) + Chr(10)
	cHtml += "      { t: " + Chr(34) + "MOTIVO DO ERRO" + Chr(34) + ", k: function(r) { return r.msg; } }" + Chr(13) + Chr(10)
	cHtml += "    ];" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function el(id) { return document.getElementById(id); }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function esc(s) {" + Chr(13) + Chr(10)
	cHtml += "      return String(s == null ? " + Chr(34) + Chr(34) + " : s).replace(/[&<>" + Chr(34) + "]/g, function(c) { return { " + Chr(34) + "&" + Chr(34) + ": " + Chr(34) + "&amp;" + Chr(34) + ", " + Chr(34) + "<" + Chr(34) + ": " + Chr(34) + "&lt;" + Chr(34) + ", " + Chr(34) + ">" + Chr(34) + ": " + Chr(34) + "&gt;" + Chr(34) + ", " + Chr(34) + "\" + Chr(34) + Chr(34) + ": " + Chr(34) + "&quot;" + Chr(34) + " }[c]; });" + Chr(13) + Chr(10)
	cHtml += "    }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function numero(v) { return parseFloat(String(v).replace(/\./g, " + Chr(34) + Chr(34) + ").replace(" + Chr(34) + "," + Chr(34) + ", " + Chr(34) + "." + Chr(34) + ")) || 0; }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function filtrados() {" + Chr(13) + Chr(10)
	cHtml += "      var st = el(" + Chr(34) + "selStatus" + Chr(34) + ").value, tx = el(" + Chr(34) + "txtSearch" + Chr(34) + ").value.toLowerCase().trim();" + Chr(13) + Chr(10)
	cHtml += "      var r = dadosList.filter(function(d) {" + Chr(13) + Chr(10)
	cHtml += "        if (st === " + Chr(34) + "S" + Chr(34) + " && !d.ok) return false;" + Chr(13) + Chr(10)
	cHtml += "        if (st === " + Chr(34) + "E" + Chr(34) + " && d.ok) return false;" + Chr(13) + Chr(10)
	cHtml += "        if (tx && (d.c.join(" + Chr(34) + " " + Chr(34) + ") + " + Chr(34) + " " + Chr(34) + " + d.msg).toLowerCase().indexOf(tx) < 0) return false;" + Chr(13) + Chr(10)
	cHtml += "        return true;" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "      var k = COLS[ord.i].k, n = COLS[ord.i].n;" + Chr(13) + Chr(10)
	cHtml += "      r.sort(function(a, b) {" + Chr(13) + Chr(10)
	cHtml += "        var x = k(a), y = k(b);" + Chr(13) + Chr(10)
	cHtml += "        if (n) { x = numero(x); y = numero(y); }" + Chr(13) + Chr(10)
	cHtml += "        return (x < y ? -1 : x > y ? 1 : 0) * (ord.asc ? 1 : -1);" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "      return r;" + Chr(13) + Chr(10)
	cHtml += "    }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function render() {" + Chr(13) + Chr(10)
	cHtml += "      var r = filtrados(), h = " + Chr(34) + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "hdrGrid" + Chr(34) + ").innerHTML = COLS.map(function(c, i) {" + Chr(13) + Chr(10)
	cHtml += "        return " + Chr(34) + "<th data-i=\" + Chr(34) + Chr(34) + " + i + " + Chr(34) + "\" + Chr(34) + " class=\" + Chr(34) + "p-2 text-left cursor-pointer" + Chr(34) + " + (c.n ? " + Chr(34) + " text-right" + Chr(34) + " : " + Chr(34) + Chr(34) + ") + " + Chr(34) + "\" + Chr(34) + ">" + Chr(34) + " + c.t +" + Chr(13) + Chr(10)
	cHtml += "               (i === ord.i ? (ord.asc ? " + Chr(34) + " <i class=\" + Chr(34) + "fa-solid fa-caret-up\" + Chr(34) + "></i>" + Chr(34) + " : " + Chr(34) + " <i class=\" + Chr(34) + "fa-solid fa-caret-down\" + Chr(34) + "></i>" + Chr(34) + ") : " + Chr(34) + Chr(34) + ") + " + Chr(34) + "</th>" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "      }).join(" + Chr(34) + Chr(34) + ");" + Chr(13) + Chr(10)
	cHtml += "      r.forEach(function(d) {" + Chr(13) + Chr(10)
	cHtml += "        h += " + Chr(34) + "<tr class=\" + Chr(34) + "border-b border-slate-100 " + Chr(34) + " + (d.ok ? " + Chr(34) + "hover:bg-slate-50" + Chr(34) + " : " + Chr(34) + "bg-rose-50 hover:bg-rose-100" + Chr(34) + ") + " + Chr(34) + "\" + Chr(34) + ">" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "        COLS.forEach(function(c, i) {" + Chr(13) + Chr(10)
	cHtml += "          var v = c.k(d);" + Chr(13) + Chr(10)
	cHtml += "          if (i === 0) {" + Chr(13) + Chr(10)
	cHtml += "            h += " + Chr(34) + "<td class=\" + Chr(34) + "p-2\" + Chr(34) + "><span class=\" + Chr(34) + "inline-flex items-center gap-1 px-2 py-0.5 rounded-full font-semibold " + Chr(34) + " +" + Chr(13) + Chr(10)
	cHtml += "                 (d.ok ? " + Chr(34) + "bg-emerald-100 text-emerald-700" + Chr(34) + " : " + Chr(34) + "bg-rose-100 text-rose-700" + Chr(34) + ") + " + Chr(34) + "\" + Chr(34) + "><i class=\" + Chr(34) + "fa-solid fa-circle text-[8px]\" + Chr(34) + "></i>" + Chr(34) + " + v + " + Chr(34) + "</span></td>" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "          } else if (i === COLS.length - 1) {" + Chr(13) + Chr(10)
	cHtml += "            h += " + Chr(34) + "<td class=\" + Chr(34) + "p-2 whitespace-normal text-rose-600 font-semibold min-w-[260px]\" + Chr(34) + ">" + Chr(34) + " + esc(v) + " + Chr(34) + "</td>" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "          } else {" + Chr(13) + Chr(10)
	cHtml += "            h += " + Chr(34) + "<td class=\" + Chr(34) + "p-2" + Chr(34) + " + (c.n ? " + Chr(34) + " text-right" + Chr(34) + " : " + Chr(34) + Chr(34) + ") + (i === 2 || i === 5 ? " + Chr(34) + " font-mono" + Chr(34) + " : " + Chr(34) + Chr(34) + ") + " + Chr(34) + "\" + Chr(34) + ">" + Chr(34) + " + esc(v) + " + Chr(34) + "</td>" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "          }" + Chr(13) + Chr(10)
	cHtml += "        });" + Chr(13) + Chr(10)
	cHtml += "        h += " + Chr(34) + "</tr>" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "tbDados" + Chr(34) + ").innerHTML = h;" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "divVazio" + Chr(34) + ").classList.toggle(" + Chr(34) + "hidden" + Chr(34) + ", r.length > 0);" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "divRodape" + Chr(34) + ").textContent = r.length + " + Chr(34) + " de " + Chr(34) + " + dadosList.length + " + Chr(34) + " registro(s)" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "      var st = el(" + Chr(34) + "selStatus" + Chr(34) + ").value;" + Chr(13) + Chr(10)
	cHtml += "      Array.prototype.forEach.call(document.querySelectorAll(" + Chr(34) + ".card" + Chr(34) + "), function(c) {" + Chr(13) + Chr(10)
	cHtml += "        c.classList.toggle(" + Chr(34) + "ring-2" + Chr(34) + ", c.getAttribute(" + Chr(34) + "data-f" + Chr(34) + ") === st);" + Chr(13) + Chr(10)
	cHtml += "        c.classList.toggle(" + Chr(34) + "ring-blue-500" + Chr(34) + ", c.getAttribute(" + Chr(34) + "data-f" + Chr(34) + ") === st);" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "    }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function csv(v) {" + Chr(13) + Chr(10)
	cHtml += "      v = String(v == null ? " + Chr(34) + Chr(34) + " : v);" + Chr(13) + Chr(10)
	cHtml += "      if (/^0\d*$|^\d{12,}$/.test(v)) return " + Chr(34) + "=\" + Chr(34) + Chr(34) + " + v + " + Chr(34) + "\" + Chr(34) + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "      return /[;" + Chr(34) + "\r\n]/.test(v) ? " + Chr(34) + "\" + Chr(34) + Chr(34) + " + v.replace(/" + Chr(34) + "/g, " + Chr(34) + "\" + Chr(34) + "\" + Chr(34) + Chr(34) + ") + " + Chr(34) + "\" + Chr(34) + Chr(34) + " : v;" + Chr(13) + Chr(10)
	cHtml += "    }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function exportar() {" + Chr(13) + Chr(10)
	cHtml += "      var r = filtrados();" + Chr(13) + Chr(10)
	cHtml += "      if (!r.length) { alert(" + Chr(34) + "Nao ha registros para exportar." + Chr(34) + "); return; }" + Chr(13) + Chr(10)
	cHtml += "      var lin = [[" + Chr(34) + "STATUS" + Chr(34) + ", " + Chr(34) + "LINHA" + Chr(34) + "].concat(CAMPOS).concat([" + Chr(34) + "MOTIVO" + Chr(34) + "]).join(" + Chr(34) + ";" + Chr(34) + ")];" + Chr(13) + Chr(10)
	cHtml += "      r.forEach(function(d) { lin.push([d.ok ? " + Chr(34) + "IMPORTADO" + Chr(34) + " : " + Chr(34) + "ERRO" + Chr(34) + ", d.l].concat(d.c).concat([d.msg]).map(csv).join(" + Chr(34) + ";" + Chr(34) + ")); });" + Chr(13) + Chr(10)
	cHtml += "      twebchannel.jsToAdvpl(" + Chr(34) + "EXPORTAR" + Chr(34) + ", JSON.stringify({ filtro: el(" + Chr(34) + "selStatus" + Chr(34) + ").value, csv: lin.join(" + Chr(34) + "\r\n" + Chr(34) + ") }));" + Chr(13) + Chr(10)
	cHtml += "    }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    function renderDados(value) {" + Chr(13) + Chr(10)
	cHtml += "      var j = typeof value === " + Chr(34) + "string" + Chr(34) + " ? JSON.parse(value) : value;" + Chr(13) + Chr(10)
	cHtml += "      dadosList = j.dados || [];" + Chr(13) + Chr(10)
	cHtml += "      var ok = dadosList.filter(function(d) { return d.ok; }).length;" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "cTot" + Chr(34) + ").textContent = dadosList.length;" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "cOk" + Chr(34) + ").textContent = ok;" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "cErr" + Chr(34) + ").textContent = dadosList.length - ok;" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "hdrInfo" + Chr(34) + ").textContent = " + Chr(34) + "Arquivo: " + Chr(34) + " + j.arq + " + Chr(34) + "  |  " + Chr(34) + " + j.data + " + Chr(34) + "  |  Usuario: " + Chr(34) + " + j.usuario + " + Chr(34) + "  |  Empresa/Filial: " + Chr(34) + " + j.empresa;" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "selStatus" + Chr(34) + ").value = ok < dadosList.length ? " + Chr(34) + "E" + Chr(34) + " : " + Chr(34) + "T" + Chr(34) + ";" + Chr(13) + Chr(10)
	cHtml += "      render();" + Chr(13) + Chr(10)
	cHtml += "    }" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "    window.onload = function() {" + Chr(13) + Chr(10)
	cHtml += "      twebchannel.connect(function() {" + Chr(13) + Chr(10)
	cHtml += "        twebchannel.jsToAdvpl(" + Chr(34) + "READY" + Chr(34) + ", " + Chr(34) + Chr(34) + ");" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "      twebchannel.advplToJs = function(key, value) {" + Chr(13) + Chr(10)
	cHtml += "        if (key === " + Chr(34) + "renderDados" + Chr(34) + ") renderDados(value);" + Chr(13) + Chr(10)
	cHtml += "      };" + Chr(13) + Chr(10)
	cHtml += "" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "selStatus" + Chr(34) + ").addEventListener(" + Chr(34) + "change" + Chr(34) + ", render);" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "txtSearch" + Chr(34) + ").addEventListener(" + Chr(34) + "input" + Chr(34) + ", render);" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "btnLimpar" + Chr(34) + ").addEventListener(" + Chr(34) + "click" + Chr(34) + ", function() { el(" + Chr(34) + "selStatus" + Chr(34) + ").value = " + Chr(34) + "T" + Chr(34) + "; el(" + Chr(34) + "txtSearch" + Chr(34) + ").value = " + Chr(34) + Chr(34) + "; render(); });" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "btnExportar" + Chr(34) + ").addEventListener(" + Chr(34) + "click" + Chr(34) + ", exportar);" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "btnFechar" + Chr(34) + ").addEventListener(" + Chr(34) + "click" + Chr(34) + ", function() { twebchannel.jsToAdvpl(" + Chr(34) + "CLOSE_PANEL" + Chr(34) + ", " + Chr(34) + Chr(34) + "); });" + Chr(13) + Chr(10)
	cHtml += "      el(" + Chr(34) + "hdrGrid" + Chr(34) + ").addEventListener(" + Chr(34) + "click" + Chr(34) + ", function(e) {" + Chr(13) + Chr(10)
	cHtml += "        var th = e.target.closest(" + Chr(34) + "th" + Chr(34) + "); if (!th) return;" + Chr(13) + Chr(10)
	cHtml += "        var i = parseInt(th.getAttribute(" + Chr(34) + "data-i" + Chr(34) + "), 10);" + Chr(13) + Chr(10)
	cHtml += "        ord = (ord.i === i) ? { i: i, asc: !ord.asc } : { i: i, asc: true };" + Chr(13) + Chr(10)
	cHtml += "        render();" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "      Array.prototype.forEach.call(document.querySelectorAll(" + Chr(34) + ".card" + Chr(34) + "), function(c) {" + Chr(13) + Chr(10)
	cHtml += "        c.addEventListener(" + Chr(34) + "click" + Chr(34) + ", function() { el(" + Chr(34) + "selStatus" + Chr(34) + ").value = c.getAttribute(" + Chr(34) + "data-f" + Chr(34) + "); render(); });" + Chr(13) + Chr(10)
	cHtml += "      });" + Chr(13) + Chr(10)
	cHtml += "    };" + Chr(13) + Chr(10)
	cHtml += "  </script>" + Chr(13) + Chr(10)
	cHtml += "</body>" + Chr(13) + Chr(10)
	cHtml += "</html>" + Chr(13) + Chr(10)

Return cHtml
