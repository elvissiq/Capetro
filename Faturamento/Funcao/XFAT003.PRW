#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOTVS.CH"
#INCLUDE "TOPCONN.CH"
#INCLUDE "RPTDEF.CH"
#INCLUDE "FWPrintSetup.ch"
#INCLUDE "TBICONN.CH"

//---------------------------------------------------------
/*/ Funcao: U_XFAT003
  Descricao: Gera a fatura do pedido e pergunta se deve emitir o boleto.
  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
User Function XFAT003()

    Local aPedAtu := XFAT003GPC()
    Local cNota   := aPedAtu[1]
    Local cSerie  := aPedAtu[2]
    Private oDadosFat := {}

    If Empty(SC5->C5_NUM)
        MsgAlert("Posicione um Pedido de Venda antes de imprimir a Fatura.", "Fatura de Cobranca")
        Return
    EndIf

    XFAT003NFS(@cNota, @cSerie)

    If !XFAT003GNF(cNota, cSerie)
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
/*/ Funcao: XFAT003GPC
  Descricao: Separa NF/Serie gravadas em C5_PEDECOM.
  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function XFAT003GPC()

    Local cPedeCom := AllTrim(cValToChar(SC5->C5_PEDECOM))
    Local nPos     := At("/", cPedeCom)
    Local cNF      := ""
    Local cSrs     := ""

    If nPos > 0
        cNF  := SubStr(cPedeCom, 1, nPos - 1)
        cSrs := SubStr(cPedeCom, nPos + 1)
    EndIf

Return {cNF, cSrs}

//---------------------------------------------------------
/*/ Funcao: XFAT003RUN
  Descricao: Monta os dados da fatura e gera o PDF em tela.

  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function XFAT003RUN()

    oDadosFat := XFAT003MNT()

    XFAT003PDF(oDadosFat)

Return

//---------------------------------------------------------
/*/ Funcao: XFAT003VAL
  Descricao: Valida o pedido antes de emitir a fatura.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003NFS
  Descricao: Tela HTML (TWebEngine/TWebChannel) para selecionar a NF da fatura.
  @author Elvis Siqueira
/*/
//----------------------------------------------------------
Static Function XFAT003NFS(cNota, cSerie)

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

    Private lNfsConf := .F.
    Private cNfsDoc  := ""
    Private cNfsSrs  := ""
    Private cNfsNota := cNota
    Private cNfsSrie := cSerie

    cBarra     := IIf(IsSrvUnix(), "/", "\")
    cPathLocal := cBarra + "web" + cBarra + "xfat003nfs.html"

    cHtml := XFAT003HTM()

    nHandle := FCreate(cPathLocal)

    If nHandle == -1
        MsgStop("Nao foi possivel gravar o arquivo HTML no servidor em: " + cPathLocal, "Fatura de Cobranca")
        Return .T.
    EndIf

    FWrite(nHandle, cHtml)
    FClose(nHandle)

    cUrlWeb := CpyF2Web(cPathLocal)

    If Empty(cUrlWeb)
        MsgStop("Nao foi possivel disponibilizar a pagina HTML via CpyF2Web.", "Fatura de Cobranca")
        Return .T.
    EndIf

    If Type("oMainWnd") == "O" .And. oMainWnd:nClientHeight > 0
        nHeight := oMainWnd:nClientHeight * 0.75
        nWidth  := oMainWnd:nClientWidth  * 0.75
        nTop    := (oMainWnd:nClientHeight - nHeight) / 2
        nLeft   := (oMainWnd:nClientWidth  - nWidth)  / 2
        nBottom := nTop  + nHeight
        nRight  := nLeft + nWidth
    Else
        nTop    := 020
        nLeft   := 020
        nBottom := 520
        nRight  := 900
    EndIf

    DEFINE MSDIALOG oDlg TITLE "Selecione a Nota Fiscal - Pedido " + AllTrim(SC5->C5_NUM) ;
        FROM nTop, nLeft TO nBottom, nRight PIXEL

        oDlg:lEscClose := .T.

        oChannel := TWebChannel():New()
        oChannel:bJsToAdvpl := { |cSelf, cChave, cValor| XFAT003HDL(cChave, cValor, oDlg, oChannel) }
        oChannel:connect()

        oWeb := TWebEngine():New(oDlg, 0, 0, 100, 100, , oChannel:nPort)
        oWeb:Align := CONTROL_ALIGN_ALLCLIENT
        oWeb:SetAsMain()

        oWeb:Navigate(cUrlWeb + "?port=" + cValToChar(oChannel:nPort))

    ACTIVATE MSDIALOG oDlg CENTERED ;
        ON INIT SetKey(VK_ESCAPE, { || oDlg:End() })

    If lNfsConf
        cNota  := cNfsDoc
        cSerie := cNfsSrs
    EndIf

Return .T.

//---------------------------------------------------------
/*/ Funcao: XFAT003HDL
  Descricao: Trata as mensagens recebidas do HTML via TWebChannel.
/*/
//----------------------------------------------------------
Static Function XFAT003HDL(cChave, cValor, oDlgP, oChanP)

    Local jDados

    If cChave == "READY"
        XFAT003NFT(oChanP)
        Return .T.
    EndIf

    If cChave == "SELECAO_CONFIRMADA"
        jDados := jsonObject():New()
        jDados:FromJson(cValor)

        If jDados:HasProperty("doc")
            cNfsDoc  := AllTrim(jDados["doc"])
            cNfsSrs  := AllTrim(jDados["serie"])
            lNfsConf := .T.
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
/*/ Funcao: XFAT003HTM
  Descricao: Monta o conteudo HTML da tela de selecao de NF.
/*/
//----------------------------------------------------------
Static Function XFAT003HTM()

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
    cHtml += "  <title>Fatura de Cobranca - Selecao de Nota Fiscal</title>" + Chr(13) + Chr(10)
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
    cHtml += "</head>" + Chr(13) + Chr(10)
    cHtml += "<body class=" + Chr(34) + "bg-slate-100 text-slate-800 font-sans antialiased h-screen flex flex-col p-4 select-none relative" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <!-- CABECALHO / TITULO / CAMPO DE PESQUISA -->" + Chr(13) + Chr(10)
    cHtml += "  <div class=" + Chr(34) + "bg-white p-3 rounded-lg border border-slate-200 shadow-sm mb-3 flex flex-col gap-2" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "    <h1 id=" + Chr(34) + "hdrTitulo" +;
        Chr(34) + " class=" + Chr(34) +;
        "text-sm font-bold text-slate-700" + Chr(34) + ">Selecione a Nota Fiscal</h1>" +;
        Chr(13) + Chr(10)
    cHtml += "    <div class=" + Chr(34) + "flex items-center gap-3" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "      <div class=" + Chr(34) + "relative flex-1" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "        <input type=" + Chr(34) + "text" +;
        Chr(34) + " id=" + Chr(34) +;
        "txtSearch" + Chr(34) + " placeholder=" +;
        Chr(34) + "PESQUISAR POR NF, SERIE, EMISSAO OU CLIENTE..." + Chr(34) +;
        Chr(13) + Chr(10)
    cHtml += "               class=" + Chr(34) + "w-full pl-9 pr-4 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent uppercase" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "        <i class=" + Chr(34) + "fa-solid fa-magnifying-glass absolute left-3 top-2.5 text-slate-400 text-sm" +;
        Chr(34) + "></i>" + Chr(13) +;
        Chr(10)
    cHtml += "      </div>" + Chr(13) + Chr(10)
    cHtml += "      <button onclick=" + Chr(34) + "confirmarSelecao()" +;
        Chr(34) + " class=" + Chr(34) +;
        "px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-md text-sm transition-all shadow" + Chr(34) + ">" +;
        Chr(13) + Chr(10)
    cHtml += "        Confirmar" + Chr(13) + Chr(10)
    cHtml += "      </button>" + Chr(13) + Chr(10)
    cHtml += "      <button onclick=" + Chr(34) + "cancelarSelecao()" +;
        Chr(34) + " class=" + Chr(34) +;
        "px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 font-semibold rounded-md text-sm transition-all" + Chr(34) + ">" +;
        Chr(13) + Chr(10)
    cHtml += "        Cancelar" + Chr(13) + Chr(10)
    cHtml += "      </button>" + Chr(13) + Chr(10)
    cHtml += "    </div>" + Chr(13) + Chr(10)
    cHtml += "  </div>" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <!-- GRID DE NOTAS FISCAIS -->" + Chr(13) + Chr(10)
    cHtml += "  <div class=" + Chr(34) + "flex-1 bg-white rounded-lg border border-slate-200 shadow-sm flex flex-col overflow-hidden min-h-0" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "    <div class=" + Chr(34) + "overflow-y-auto flex-1" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "      <table class=" + Chr(34) + "w-full text-left border-collapse text-xs" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "        <thead class=" + Chr(34) + "bg-slate-200 text-slate-700 font-bold sticky top-0 border-b border-slate-300" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "          <tr>" + Chr(13) + Chr(10)
    cHtml += "            <th class=" + Chr(34) + "p-2 w-32" +;
        Chr(34) + ">Nota Fiscal</th>" + Chr(13) +;
        Chr(10)
    cHtml += "            <th class=" + Chr(34) + "p-2 w-20" +;
        Chr(34) + ">Serie</th>" + Chr(13) +;
        Chr(10)
    cHtml += "            <th class=" + Chr(34) + "p-2 w-28" +;
        Chr(34) + ">Emissao</th>" + Chr(13) +;
        Chr(10)
    cHtml += "            <th class=" + Chr(34) + "p-2" +;
        Chr(34) + ">Cliente</th>" + Chr(13) +;
        Chr(10)
    cHtml += "          </tr>" + Chr(13) + Chr(10)
    cHtml += "        </thead>" + Chr(13) + Chr(10)
    cHtml += "        <tbody id=" + Chr(34) + "tbNotas" +;
        Chr(34) + ">" + Chr(13) +;
        Chr(10)
    cHtml += "          <tr>" + Chr(13) + Chr(10)
    cHtml += "            <td colspan=" + Chr(34) + "4" +;
        Chr(34) + " class=" + Chr(34) +;
        "p-4 text-center text-slate-400" + Chr(34) + ">Carregando...</td>" +;
        Chr(13) + Chr(10)
    cHtml += "          </tr>" + Chr(13) + Chr(10)
    cHtml += "        </tbody>" + Chr(13) + Chr(10)
    cHtml += "      </table>" + Chr(13) + Chr(10)
    cHtml += "    </div>" + Chr(13) + Chr(10)
    cHtml += "  </div>" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "  <script>" + Chr(13) + Chr(10)
    cHtml += "    var notasList = [];" + Chr(13) + Chr(10)
    cHtml += "    var selectedIndex = -1;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    window.onload = function() {" + Chr(13) + Chr(10)
    cHtml += "      twebchannel.connect(function() {" + Chr(13) + Chr(10)
    cHtml += "        twebchannel.jsToAdvpl(" + Chr(34) + "READY" +;
        Chr(34) + ", " + Chr(34) +;
        Chr(34) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      twebchannel.advplToJs = function(key, value) {" + Chr(13) + Chr(10)
    cHtml += "        if (key === " + Chr(39) + "renderNFs" +;
        Chr(39) + ") renderNFs(value);" + Chr(13) +;
        Chr(10)
    cHtml += "      };" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      document.getElementById(" + Chr(39) + "txtSearch" +;
        Chr(39) + ").addEventListener(" + Chr(39) +;
        "keydown" + Chr(39) + ", function(e) {" +;
        Chr(13) + Chr(10)
    cHtml += "        if (e.key === " + Chr(39) + "Enter" +;
        Chr(39) + ") {" + Chr(13) +;
        Chr(10)
    cHtml += "          e.preventDefault();" + Chr(13) + Chr(10)
    cHtml += "        }" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      document.getElementById(" + Chr(39) + "txtSearch" +;
        Chr(39) + ").addEventListener(" + Chr(39) +;
        "input" + Chr(39) + ", function() {" +;
        Chr(13) + Chr(10)
    cHtml += "        aplicarFiltro();" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "    };" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function renderNFs(jsonStr) {" + Chr(13) + Chr(10)
    cHtml += "      var data = typeof jsonStr === " + Chr(39) + "string" +;
        Chr(39) + " ? JSON.parse(jsonStr) : jsonStr;" + Chr(13) +;
        Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (data.titulo) {" + Chr(13) + Chr(10)
    cHtml += "        document.getElementById(" + Chr(39) + "hdrTitulo" +;
        Chr(39) + ").textContent = data.titulo;" + Chr(13) +;
        Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      var aNulo = { doc: " + Chr(39) + Chr(39) +;
        ", serie: " + Chr(39) + Chr(39) +;
        ", emissao: " + Chr(39) + Chr(39) +;
        ", cliente: " + Chr(39) + "(Nao associar Nota Fiscal)" +;
        Chr(39) + ", naoAssociar: true };" + Chr(13) +;
        Chr(10)
    cHtml += "      notasList = [aNulo].concat(data.notas || []);" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      var docSel   = (data.selecionado && data.selecionado.doc)   ? data.selecionado.doc   : " + Chr(39) + Chr(39) +;
        ";" + Chr(13) + Chr(10)
    cHtml += "      var serieSel = (data.selecionado && data.selecionado.serie) ? data.selecionado.serie : " + Chr(39) + Chr(39) +;
        ";" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      notasList.forEach(function(n) {" + Chr(13) + Chr(10)
    cHtml += "        n.selecionado = (!n.naoAssociar && n.doc === docSel && n.serie === serieSel) ||" + Chr(13) + Chr(10)
    cHtml += "                        (n.naoAssociar && docSel === " + Chr(39) + Chr(39) +;
        " && serieSel === " + Chr(39) + Chr(39) +;
        ");" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      document.getElementById(" + Chr(39) + "txtSearch" +;
        Chr(39) + ").value = " + Chr(39) +;
        Chr(39) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "      aplicarFiltro();" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function aplicarFiltro() {" + Chr(13) + Chr(10)
    cHtml += "      var termo = document.getElementById(" + Chr(39) + "txtSearch" +;
        Chr(39) + ").value.toUpperCase();" + Chr(13) +;
        Chr(10)
    cHtml += "      var tbody = document.getElementById(" + Chr(39) + "tbNotas" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      tbody.innerHTML = " + Chr(39) + Chr(39) +;
        ";" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      var visiveis = [];" + Chr(13) + Chr(10)
    cHtml += "      var idxSelInicial = -1;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      notasList.forEach(function(n, idx) {" + Chr(13) + Chr(10)
    cHtml += "        var bate = n.naoAssociar ||" + Chr(13) + Chr(10)
    cHtml += "                   termo === " + Chr(39) + Chr(39) +;
        " ||" + Chr(13) + Chr(10)
    cHtml += "                   (n.doc     && n.doc.toUpperCase().indexOf(termo)     !== -1) ||" + Chr(13) + Chr(10)
    cHtml += "                   (n.serie   && n.serie.toUpperCase().indexOf(termo)   !== -1) ||" + Chr(13) + Chr(10)
    cHtml += "                   (n.emissao && n.emissao.toUpperCase().indexOf(termo) !== -1) ||" + Chr(13) + Chr(10)
    cHtml += "                   (n.cliente && n.cliente.toUpperCase().indexOf(termo) !== -1);" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        if (!bate) return;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        visiveis.push(idx);" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        var tr = document.createElement(" + Chr(39) + "tr" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        tr.className = " + Chr(34) + "border-b border-slate-100 hover:bg-blue-50 cursor-pointer transition-colors" +;
        Chr(34) + " +" + Chr(13) +;
        Chr(10)
    cHtml += "                        (n.naoAssociar ? " + Chr(34) + " text-rose-600 font-semibold" +;
        Chr(34) + " : " + Chr(34) +;
        Chr(34) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        tr.setAttribute(" + Chr(39) + "data-idx" +;
        Chr(39) + ", idx);" + Chr(13) +;
        Chr(10)
    cHtml += "        tr.onclick = function() { selecionarNota(idx, tr); };" + Chr(13) + Chr(10)
    cHtml += "        tr.ondblclick = function() { selecionarNota(idx, tr); confirmarSelecao(); };" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        var tdDoc = document.createElement(" + Chr(39) + "td" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        tdDoc.className = " + Chr(34) + "p-2 font-mono font-bold" +;
        Chr(34) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "        tdDoc.textContent = n.naoAssociar ? " + Chr(39) + Chr(39) +;
        " : n.doc;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        var tdSerie = document.createElement(" + Chr(39) + "td" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        tdSerie.className = " + Chr(34) + "p-2 font-mono" +;
        Chr(34) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "        tdSerie.textContent = n.naoAssociar ? " + Chr(39) + Chr(39) +;
        " : n.serie;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        var tdEmis = document.createElement(" + Chr(39) + "td" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        tdEmis.className = " + Chr(34) + "p-2" +;
        Chr(34) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "        tdEmis.textContent = n.naoAssociar ? " + Chr(39) + Chr(39) +;
        " : n.emissao;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        var tdCli = document.createElement(" + Chr(39) + "td" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        tdCli.className = " + Chr(34) + "p-2" +;
        Chr(34) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "        tdCli.colSpan = n.naoAssociar ? 4 : 1;" + Chr(13) + Chr(10)
    cHtml += "        tdCli.textContent = n.cliente;" + Chr(13) + Chr(10)
    cHtml += "        if (n.naoAssociar) {" + Chr(13) + Chr(10)
    cHtml += "          tdDoc.remove ? null : null;" + Chr(13) + Chr(10)
    cHtml += "        }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        tr.appendChild(tdDoc);" + Chr(13) + Chr(10)
    cHtml += "        tr.appendChild(tdSerie);" + Chr(13) + Chr(10)
    cHtml += "        tr.appendChild(tdEmis);" + Chr(13) + Chr(10)
    cHtml += "        tr.appendChild(tdCli);" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        if (n.naoAssociar) {" + Chr(13) + Chr(10)
    cHtml += "          tr.innerHTML = " + Chr(39) + Chr(39) +;
        ";" + Chr(13) + Chr(10)
    cHtml += "          var tdUnica = document.createElement(" + Chr(39) + "td" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "          tdUnica.className = " + Chr(34) + "p-2" +;
        Chr(34) + ";" + Chr(13) +;
        Chr(10)
    cHtml += "          tdUnica.colSpan = 4;" + Chr(13) + Chr(10)
    cHtml += "          tdUnica.textContent = n.cliente;" + Chr(13) + Chr(10)
    cHtml += "          tr.appendChild(tdUnica);" + Chr(13) + Chr(10)
    cHtml += "        }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        tbody.appendChild(tr);" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        if (n.selecionado) {" + Chr(13) + Chr(10)
    cHtml += "          idxSelInicial = idx;" + Chr(13) + Chr(10)
    cHtml += "        }" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (tbody.children.length === 0) {" + Chr(13) + Chr(10)
    cHtml += "        tbody.innerHTML = " + Chr(39) + "<tr><td colspan=" +;
        Chr(34) + "4" + Chr(34) +;
        " class=" + Chr(34) + "p-4 text-center text-slate-400" +;
        Chr(34) + ">Nenhuma nota fiscal localizada.</td></tr>" + Chr(39) +;
        ";" + Chr(13) + Chr(10)
    cHtml += "        selectedIndex = -1;" + Chr(13) + Chr(10)
    cHtml += "        return;" + Chr(13) + Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (idxSelInicial === -1) {" + Chr(13) + Chr(10)
    cHtml += "        idxSelInicial = visiveis[0];" + Chr(13) + Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      var trSel = document.querySelector(" + Chr(39) + "#tbNotas tr[data-idx=" +;
        Chr(34) + Chr(39) + " + idxSelInicial + " +;
        Chr(39) + Chr(34) + "]" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      selecionarNota(idxSelInicial, trSel);" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function selecionarNota(idx, trElement) {" + Chr(13) + Chr(10)
    cHtml += "      if (idx < 0 || idx >= notasList.length) return;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      selectedIndex = idx;" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      var rows = document.querySelectorAll(" + Chr(39) + "#tbNotas tr" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      rows.forEach(function(r) { r.classList.remove(" + Chr(39) + "bg-blue-100" +;
        Chr(39) + "); });" + Chr(13) +;
        Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (!trElement) {" + Chr(13) + Chr(10)
    cHtml += "        trElement = document.querySelector(" + Chr(39) + "#tbNotas tr[data-idx=" +;
        Chr(34) + Chr(39) + " + idx + " +;
        Chr(39) + Chr(34) + "]" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (trElement) {" + Chr(13) + Chr(10)
    cHtml += "        trElement.classList.add(" + Chr(39) + "bg-blue-100" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        trElement.scrollIntoView({ block: " + Chr(39) + "nearest" +;
        Chr(39) + ", behavior: " + Chr(39) +;
        "smooth" + Chr(39) + " });" +;
        Chr(13) + Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function confirmarSelecao() {" + Chr(13) + Chr(10)
    cHtml += "      var nota = (selectedIndex >= 0 && selectedIndex < notasList.length) ? notasList[selectedIndex] : notasList[0];" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      var payload = JSON.stringify({" + Chr(13) + Chr(10)
    cHtml += "        doc:   nota.naoAssociar ? " + Chr(39) + Chr(39) +;
        " : nota.doc," + Chr(13) + Chr(10)
    cHtml += "        serie: nota.naoAssociar ? " + Chr(39) + Chr(39) +;
        " : nota.serie" + Chr(13) + Chr(10)
    cHtml += "      });" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (twebchannel) {" + Chr(13) + Chr(10)
    cHtml += "        twebchannel.jsToAdvpl(" + Chr(34) + "SELECAO_CONFIRMADA" +;
        Chr(34) + ", payload);" + Chr(13) +;
        Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    function cancelarSelecao() {" + Chr(13) + Chr(10)
    cHtml += "      if (twebchannel) {" + Chr(13) + Chr(10)
    cHtml += "        twebchannel.jsToAdvpl(" + Chr(39) + "CLOSE_PANEL" +;
        Chr(39) + ", " + Chr(39) +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "    }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "    document.addEventListener(" + Chr(39) + "keydown" +;
        Chr(39) + ", function(event) {" + Chr(13) +;
        Chr(10)
    cHtml += "      if (event.key === " + Chr(39) + "Escape" +;
        Chr(39) + ") {" + Chr(13) +;
        Chr(10)
    cHtml += "        cancelarSelecao();" + Chr(13) + Chr(10)
    cHtml += "        return;" + Chr(13) + Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "      if (document.activeElement.id !== " + Chr(39) + "txtSearch" +;
        Chr(39) + ") {" + Chr(13) +;
        Chr(10)
    cHtml += "        var rows = document.querySelectorAll(" + Chr(39) + "#tbNotas tr[data-idx]" +;
        Chr(39) + ");" + Chr(13) +;
        Chr(10)
    cHtml += "        var idxAtual = -1;" + Chr(13) + Chr(10)
    cHtml += "        rows.forEach(function(r, pos) { if (parseInt(r.getAttribute(" + Chr(39) + "data-idx" +;
        Chr(39) + "), 10) === selectedIndex) idxAtual = pos; });" + Chr(13) +;
        Chr(10)
    cHtml += "" + Chr(13) + Chr(10)
    cHtml += "        if (event.key === " + Chr(39) + "Enter" +;
        Chr(39) + ") {" + Chr(13) +;
        Chr(10)
    cHtml += "          event.preventDefault();" + Chr(13) + Chr(10)
    cHtml += "          confirmarSelecao();" + Chr(13) + Chr(10)
    cHtml += "        } else if (event.key === " + Chr(39) + "ArrowDown" +;
        Chr(39) + ") {" + Chr(13) +;
        Chr(10)
    cHtml += "          event.preventDefault();" + Chr(13) + Chr(10)
    cHtml += "          if (idxAtual >= 0 && idxAtual < rows.length - 1) {" + Chr(13) + Chr(10)
    cHtml += "            var prox = rows[idxAtual + 1];" + Chr(13) + Chr(10)
    cHtml += "            selecionarNota(parseInt(prox.getAttribute(" + Chr(39) + "data-idx" +;
        Chr(39) + "), 10), prox);" + Chr(13) +;
        Chr(10)
    cHtml += "          }" + Chr(13) + Chr(10)
    cHtml += "        } else if (event.key === " + Chr(39) + "ArrowUp" +;
        Chr(39) + ") {" + Chr(13) +;
        Chr(10)
    cHtml += "          event.preventDefault();" + Chr(13) + Chr(10)
    cHtml += "          if (idxAtual > 0) {" + Chr(13) + Chr(10)
    cHtml += "            var ant = rows[idxAtual - 1];" + Chr(13) + Chr(10)
    cHtml += "            selecionarNota(parseInt(ant.getAttribute(" + Chr(39) + "data-idx" +;
        Chr(39) + "), 10), ant);" + Chr(13) +;
        Chr(10)
    cHtml += "          }" + Chr(13) + Chr(10)
    cHtml += "        }" + Chr(13) + Chr(10)
    cHtml += "      }" + Chr(13) + Chr(10)
    cHtml += "    });" + Chr(13) + Chr(10)
    cHtml += "  </script>" + Chr(13) + Chr(10)
    cHtml += "</body>" + Chr(13) + Chr(10)
    cHtml += "</html>" + Chr(13) + Chr(10)

Return cHtml

//---------------------------------------------------------
/*/ Funcao: XFAT003NFT
  Descricao: Consulta as NF da SF2/SA1 e envia a lista ao HTML.
/*/
//----------------------------------------------------------
Static Function XFAT003NFT(oChanP)

    Local cAliasQry := GetNextAlias()
    Local cQry      := ""
    Local jResult   := jsonObject():New()
    Local jSelec    := jsonObject():New()
    Local jItem
    Local aNotas    := {}

    cQry := " SELECT SF2.F2_FILIAL,SF2.F2_DOC,SF2.F2_SERIE,SF2.F2_EMISSAO,SF2.F2_CLIENTE,SF2.F2_LOJA,SA1.A1_NOME AS XA1NOME "
    cQry += " FROM " + RetSqlName("SF2") + " SF2 "
    cQry += " LEFT JOIN " + RetSqlName("SA1") + " SA1 "
    cQry += "        ON SA1.A1_FILIAL = '" + xFilial("SA1") + "' "
    cQry += "       AND SA1.A1_COD    = SF2.F2_CLIENTE "
    cQry += "       AND SA1.A1_LOJA   = SF2.F2_LOJA "
    cQry += "       AND SA1.D_E_L_E_T_ <> '*' "
    cQry += " WHERE SF2.D_E_L_E_T_ <> '*' "
    cQry += "   AND SF2.F2_FILIAL  = '" + xFilial("SF2") + "' "
    cQry += "   AND ( ( SF2.F2_CLIENTE = '" + SC5->C5_CLIENTE + "' AND SF2.F2_LOJA = '" + SC5->C5_LOJACLI + "' ) "

    If !Empty(cNfsNota)
        cQry += "        OR ( SF2.F2_DOC = '" + cNfsNota + "' AND SF2.F2_SERIE = '" + cNfsSrie + "' ) "
    EndIf

    cQry += "       ) "
    cQry += " ORDER BY SF2.F2_EMISSAO DESC, SF2.F2_DOC DESC "

    cQry := ChangeQuery(cQry)
    If Select(cAliasQry) <> 0
        (cAliasQry)->(DbCloseArea())
    EndIf
    DbUseArea(.T., "TOPCONN", TcGenQry(,,cQry), cAliasQry, .T., .T.)
    (cAliasQry)->(DbGoTop())

    While !(cAliasQry)->(Eof())
        jItem := jsonObject():New()
        jItem["doc"]     := AllTrim((cAliasQry)->F2_DOC)
        jItem["serie"]   := AllTrim((cAliasQry)->F2_SERIE)
        jItem["emissao"] := DtoC(IIf(ValType((cAliasQry)->F2_EMISSAO) == "D", (cAliasQry)->F2_EMISSAO, STOD((cAliasQry)->F2_EMISSAO)))
        jItem["cliente"] := DecodeUTF8(AllTrim((cAliasQry)->XA1NOME))
        aAdd(aNotas, jItem)
        (cAliasQry)->(DbSkip())
    EndDo
    (cAliasQry)->(DbCloseArea())

    jSelec["doc"]   := AllTrim(cNfsNota)
    jSelec["serie"] := AllTrim(cNfsSrie)

    jResult["notas"]       := aNotas
    jResult["selecionado"] := jSelec
    jResult["titulo"]      := DecodeUTF8("Selecione a Nota Fiscal - Pedido " + AllTrim(SC5->C5_NUM))

    oChanP:advplToJS("renderNFs", jResult:ToJson())

Return

//---------------------------------------------------------
/*/ Funcao: XFAT003GNF
  Descricao: Grava NF/Serie em C5_PEDECOM.
/*/
//----------------------------------------------------------
Static Function XFAT003GNF(cNota, cSerie)

    Local cPedeCom := IIf(!Empty(cNota), AllTrim(cNota) + IIf(!Empty(cSerie), "/" + AllTrim(cSerie), ""), "")

    If !RecLock("SC5", .F.)
        MsgAlert("Nao foi possivel atualizar o pedido para gravar a NF.", "Fatura de Cobranca")
        Return .F.
    EndIf

    SC5->C5_PEDECOM := cPedeCom

    MsUnlock()

Return .T.

//---------------------------------------------------------
/*/ Funcao: XFAT003MNT
  Descricao: Monta os dados da fatura e os itens do pedido.

  @author Raphael Neves (Hubvision)
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
    XFAT003SET(oDados, "NFRelac", AllTrim(cValToChar(SC5->C5_PEDECOM)))

    XFAT003SET(oDados, "ObsMenNota", IIf(Type("SC5->C5_MENNOTA") != "U", AllTrim(cValToChar(SC5->C5_MENNOTA)), ""))
    XFAT003SET(oDados, "ObsXMsgI", IIf(Type("SC5->C5_XMSGI") != "U", AllTrim(cValToChar(SC5->C5_XMSGI)), ""))
    XFAT003SET(oDados, "ObsXMpObs", IIf(Type("SC5->C5_XMPOBS") != "U", AllTrim(cValToChar(SC5->C5_XMPOBS)), ""))
    XFAT003SET(oDados, "ObsXMpMOb", IIf(Type("SC5->C5_XMPMOBS") != "U", AllTrim(cValToChar(SC5->C5_XMPMOBS)), ""))

    cLocalEnt := AllTrim(cValToChar(SC5->C5_DESCMUN))
    If Empty(cLocalEnt)
        DbSelectArea("SA1")
        DbSetOrder(1)
        If DbSeek(xFilial("SA1") + cCliEnt + cLojEnt)
            cLocalEnt := XFAT003ADR(;
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
    XFAT003SET(oDados, "ClienteEnd", XFAT003ADR(SA1->A1_END, SA1->A1_BAIRRO, IIf(Type("SA1->A1_COMPLEM") != "U", SA1->A1_COMPLEM, ""), SA1->A1_CEP, "", ""))
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
/*/ Funcao: XFAT003FIL
  Descricao: Busca os dados da filial para o cabecalho da fatura.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003BCO
  Descricao: Busca os dados bancarios utilizados na fatura.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003PIX
  Descricao: Retorna a chave PIX associada a conta bancaria.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003SET
  Descricao: Salva um valor no array de dados da fatura.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003GET
  Descricao: Le um valor do array de dados da fatura.

  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function XFAT003GET(oDados, cChave, xDefault)

    Local nPos := AScan(oDados, {|aPar| aPar[1] == cChave})

Return IIf(nPos > 0, oDados[nPos][2], xDefault)

//---------------------------------------------------------
/*/ Funcao: XFAT003MSK
  Descricao: Formata CPF/CNPJ para exibicao.

  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function XFAT003MSK(cDoc)

    Local cLimpo := StrTran(StrTran(StrTran(AllTrim(cValToChar(cDoc)), ".", ""), "/", ""), "-", "")
    Local cRet   := cLimpo

    If Len(cLimpo) == 11
        cRet := Transform(cLimpo, "@R 999.999.999-99")
    ElseIf Len(cLimpo) == 14
        cRet := Transform(cLimpo, "@R 99.999.999/9999-99")
    EndIf

Return cRet

//---------------------------------------------------------
/*/ Funcao: XFAT003ADR
  Descricao: Monta a descricao do endereco para a fatura.

  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function XFAT003ADR(cEnd, cBairro, cComplem, cCep, cMun, cEst)

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
/*/ Funcao: XFAT003PDF
  Descricao: Gera o PDF da fatura com cabecalho, itens e valores.

  @author Raphael Neves (Hubvision)
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
    Local cObsXMpObs  := cValToChar(XFAT003GET(oDados, "ObsXMpObs", ""))
    Local cObsXMpMOb  := cValToChar(XFAT003GET(oDados, "ObsXMpMOb", ""))
    Local aMsgsAdic   := {}
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
    oPrint:SayAlign(nLin + 2, nEsq + 5, cEmitNome + "  |  CNPJ: " + XFAT003MSK(cEmitCgc) + "  |  " + cEmitBairro + "/" + cEmitUf, oFontLbl, nDir - nEsq - 10, 10, CLR_BLACK, 2, 1)
    nLin += 20

    oPrint:FillRect({nLin, nEsq, nLin + 18, nDir}, oBrushFaixa)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "DESTINATARIO", oFontSec, nDir - nEsq - 10, 12, CLR_WHITE, 0, 1)
    nLin += 18

    oPrint:Box(nLin, nEsq, nLin + 72, nDir)
    oPrint:Line(nLin + 20, nEsq, nLin + 20, nDir)
    oPrint:Line(nLin + 40, nEsq, nLin + 40, nDir)
    oPrint:Line(nLin + 20, nEsq + 248, nLin + 40, nEsq + 248)
    oPrint:SayAlign(nLin + 2, nEsq + 5, "Razao Social: " + cCliNome, oFontLbl, nDir - nEsq - 10, 15, CLR_BLACK, 0, 1)
    oPrint:SayAlign(nLin + 22, nEsq + 5, "CNPJ/CPF: " + XFAT003MSK(cCliCgc), oFontLbl, 240, 15, CLR_BLACK, 0, 1)
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
    oPrint:SayAlign(nLin + 2, nEsq + 5, "Item"                    , oFontSec, 30, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 38, "Descricao"               , oFontSec, 200, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 248, "Qtd horas"              , oFontSec, 47, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 303, "Valor/Hora(R$)"         , oFontSec, 92, 12, CLR_WHITE, 0, 1)
    oPrint:SayAlign(nLin + 2, nEsq + 403, "Valor Total Horas(R$)"  , oFontSec, 92, 12, CLR_WHITE, 0, 1)
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

    aMsgsAdic := {}

    If !Empty(cObsMenNota)
        aAdd(aMsgsAdic, cObsMenNota)
    EndIf

    If !Empty(cObsXMsgI)
        aAdd(aMsgsAdic, cObsXMsgI)
    EndIf

    If !Empty(cObsXMpObs)
        aAdd(aMsgsAdic, cObsXMpObs)
    EndIf

    If !Empty(cObsXMpMOb)
        aAdd(aMsgsAdic, cObsXMpMOb)
    EndIf

    If Len(aMsgsAdic) > 0
        cTextoDest := "Mensagem adicional: " + aMsgsAdic[1]
        nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
        nAltObs    += (nLinhas * 12) + 4

        For nX := 2 To Len(aMsgsAdic)
            cTextoDest := aMsgsAdic[nX]
            nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
            nAltObs    += (nLinhas * 12) + 4
        Next nX
    EndIf

    oPrint:Box(nLin, nEsq, nLin + nAltObs, nDir)
    oPrint:SayAlign(nLin + 3, nEsq + 5, cTxtDisc, oFontLbl, nLargObs, nAltDisc - 4, CLR_BLACK, 0, 1)
    nLinObs := nLin + nAltDisc

    If Len(aMsgsAdic) > 0
        cTextoDest := "Mensagem adicional: " + aMsgsAdic[1]
        nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
        oPrint:SayAlign(nLinObs + 2, nEsq + 5, cTextoDest, oFontDest, nLargObs, nLinhas * 12, CLR_BLACK, 0, 1)
        nLinObs    += (nLinhas * 12) + 4

        For nX := 2 To Len(aMsgsAdic)
            cTextoDest := aMsgsAdic[nX]
            nLinhas    := Int((Len(cTextoDest) - 1) / nCharsLinha) + 1
            oPrint:SayAlign(nLinObs + 2, nEsq + 5, cTextoDest, oFontDest, nLargObs, nLinhas * 12, CLR_BLACK, 0, 1)
            nLinObs    += (nLinhas * 12) + 4
        Next nX
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
/*/ Funcao: XFAT003BOL
  Descricao: Gera o(s) titulo(s) (SE1) e aciona o bordero/boleto.
  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003BOR
  Descricao: Gera o bordero para os titulos da fatura.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003LOG
  Descricao: Exibe o erro da rotina automatica.

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003BXB
  Descricao: Faz o download do(s) boleto(s) gerado(s).

  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFATBOL
  Descricao: Reimprime boletos do pedido.

  @author Raphael Neves (Hubvision)
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

    oTabTMP     := Nil
    oMarkBrowse := Nil
    cAliasBrw   := Nil

Return

//---------------------------------------------------------
/*/ Funcao: MenuDef
  Descricao: Menu MVC da tela XFATBOL.
  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function MenuDef()

    Local aRotina := {}

Return aRotina

//---------------------------------------------------------
/*/ Funcao: XFAT003TAB
  Descricao: Popula a tabela temporaria da tela XFATBOL.
  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003MRK
  Descricao: Marca/desmarca todos os boletos autorizados.
  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003VLM
  Descricao: Impede marcar boleto ainda nao autorizado.
  @author Raphael Neves (Hubvision)
/*/
//----------------------------------------------------------
Static Function XFAT003VLM()

    Local lRet := .F.

    If (cAliasBrw)->TP_TRANSF == "S"
        lRet := .T.
    EndIf

Return lRet

//---------------------------------------------------------
/*/ Funcao: XFAT003STA
  Descricao: Retorna a cor da linha conforme EA_TRANSF.
  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003ERR
  Descricao: Exibe o log de erro do boleto posicionado.
  @author Raphael Neves (Hubvision)
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
/*/ Funcao: XFAT003BX2
  Descricao: Reimprime/baixa os boletos marcados.
  @author Raphael Neves (Hubvision)
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
