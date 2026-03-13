//Bibliotecas
#Include 'Protheus.ch'
#Include 'Totvs.ch'
#Include "TOPCONN.ch"
#Include 'FWMVCDef.ch'
#Include "FWPrintSetup.ch" 

//----------------------------------------------------------------------
/*/{PROTHEUS.DOC} XFAT002
FUNÇÃO XFAT002 - Tela para impressão dos boletos
@VERSION PROTHEUS 12
@SINCE 13/03/2026
/*/
//----------------------------------------------------------------------

User Function XFAT002()
Local oDialog, oPanel
Local cMarca    := "X"
Local aColsBrw  := {}
Local aColsSX3  := {}
Local aFields   := {}
Local aPergs    := {}
Local aSeek     := {}
Local aBkpParam := NgSalvaMvPa()
Local cCarga    := Space(FWTamSX3("DAK_COD")[1])
Local cSerieNF  := Space(FWTamSX3("F2_SERIE")[1])
Local cNotaDe   := Space(FWTamSX3("F2_DOC")[1])
Local cNotaAte  := Space(FWTamSX3("F2_DOC")[1])
Local dDtDe     := CtoD("//")
Local dDtAte    := CtoD("//")
Local nY

Private oTabTMP, oMarkBrowse
Private cAliasBrw := GetNextAlias()
Private aRotina := {}

    oTabTMP := FWTemporaryTable():New(cAliasBrw)

    aAdd(aPergs, {1, "Carga"    , cCarga   , "", ".T.", "DAK", ".T.", 80, .F.})
    aAdd(aPergs, {1, "Serie"    , cSerieNF , "", ".T.", ""   , ".T.", 80, .F.})
    aAdd(aPergs, {1, "Nota de " , cNotaDe  , "", ".T.", ""   , ".T.", 80, .F.})
    aAdd(aPergs, {1, "Nota ate" , cNotaAte , "", ".T.", ""   , ".T.", 80, .F.})
    aAdd(aPergs, {1, "Data de"  , dDtDe    , "", ".T.", ""   , ".T.", 80, .F.})
    aAdd(aPergs, {1, "Data ate" , dDtAte   , "", ".T.", ""   , ".T.", 80, .F.})
    
    If ParamBox(aPergs, "Informe as Perguntas")
        If Empty(MV_PAR01) .And. ( (Empty(MV_PAR02) .And. Empty(MV_PAR04)) )
            ApMsgAlert("Filtro incorreto", "Aviso")
            NgRetAuMVPa(aBkpParam)
            Return
        EndIF
    Else
        NgRetAuMVPa(aBkpParam)
        Return
    EndIf

    AAdd(aColsBrw,{BuscarSX3('EA_FILIAL' ,,aColsSX3), "TP_FILIAL" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.F.,,,,,,,,1}) // Filial do Sistema
	AAdd(aColsBrw,{BuscarSX3('EA_NUMBOR' ,,aColsSX3), "TP_NUMBOR" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Numero do bordero
    AAdd(aColsBrw,{BuscarSX3('EA_PORTADO',,aColsSX3), "TP_PORTADO",'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Codigo do portador
    AAdd(aColsBrw,{BuscarSX3('EA_AGEDEP' ,,aColsSX3), "TP_AGEDEP" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Agencia Depositaria
    AAdd(aColsBrw,{BuscarSX3('EA_NUMCON' ,,aColsSX3), "TP_NUMCON" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Numero Conta
    AAdd(aColsBrw,{BuscarSX3('EA_PREFIXO',,aColsSX3), "TP_PREFIXO",'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.F.,,,,,,,,1}) // Prefixo do titulo
	AAdd(aColsBrw,{BuscarSX3('EA_NUM'    ,,aColsSX3), "TP_NUM"    ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Numero do Titulo
	AAdd(aColsBrw,{BuscarSX3('EA_PARCELA',,aColsSX3), "TP_PARCELA",'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Parcela do Titulo
    AAdd(aColsBrw,{BuscarSX3('EA_TIPO'   ,,aColsSX3), "TP_TIPO"   ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Tipo do Titulo
    AAdd(aColsBrw,{BuscarSX3('EA_TRANSF' ,,aColsSX3), "TP_TRANSF" ,'C',aColsSX3[3],aColsSX3[4],aColsSX3[2],1,,.T.,,,,,,,,1}) // Status Trans

    aAdd(aFields, {"TP_MARK"   ,"C",1,0})
    aAdd(aFields, {'TP_FILIAL' ,"C",FWTamSX3("EA_FILIAL")[1]    ,FWTamSX3("EA_FILIAL")[2]	,"Filial"		,"",""})
    aAdd(aFields, {'TP_NUMBOR' ,"C",FWTamSX3("EA_NUMBOR")[1]    ,FWTamSX3("EA_NUMBOR")[2]	,"Bordero"		,"",""})
    aAdd(aFields, {'TP_PORTADO',"C",FWTamSX3("EA_PORTADO")[1]   ,FWTamSX3("EA_PORTADO")[2]	,"Banco"	    ,"",""})
    aAdd(aFields, {'TP_AGEDEP' ,"C",FWTamSX3("EA_AGEDEP")[1]    ,FWTamSX3("EA_AGEDEP")[2]	,"Nro Agencia"	,"",""})
	aAdd(aFields, {'TP_NUMCON' ,"C",FWTamSX3("EA_NUMCON")[1]    ,FWTamSX3("EA_NUMCON")[2]	,"Nro Conta"	,"",""})
    aAdd(aFields, {'TP_PREFIXO',"C",FWTamSX3("EA_PREFIXO")[1]   ,FWTamSX3("EA_PREFIXO")[2]	,"Prefixo"	    ,"",""})
    aAdd(aFields, {'TP_NUM'    ,"C",FWTamSX3("EA_NUM")[1]       ,FWTamSX3("EA_NUM")[2]	    ,"No. Titulo"	,"",""})
	aAdd(aFields, {'TP_PARCELA',"C",FWTamSX3("EA_PARCELA")[1]   ,FWTamSX3("EA_PARCELA")[2]	,"Parcela"	    ,"",""})
    aAdd(aFields, {'TP_TIPO'   ,"C",FWTamSX3("EA_TIPO")[1]      ,FWTamSX3("EA_TIPO")[2]		,"Tipo"         ,"",""})
    aAdd(aFields, {'TP_TRANSF' ,"C",FWTamSX3("EA_TRANSF")[1]    ,FWTamSX3("EA_TRANSF")[2]	,"Status Trans"	,"",""})

    oTabTMP:SetFields(aFields)
    oTabTMP:AddIndex("1", {"TP_FILIAL","TP_PREFIXO","TP_NUM","TP_PARCELA","TP_TIPO"} )
    oTabTMP:AddIndex("2", {"TP_FILIAL","TP_NUMBOR","TP_PORTADO","TP_AGEDEP","TP_NUMCON"} )
    oTabTMP:AddIndex("3", {"TP_FILIAL","TP_NUMBOR","TP_PREFIXO","TP_NUM","TP_PARCELA","TP_TIPO"} )
    oTabTMP:AddIndex("4", {"TP_FILIAL","TP_NUMBOR","TP_PORTADO","TP_AGEDEP","TP_NUMCON","TP_PREFIXO","TP_NUM","TP_PARCELA","TP_TIPO"} )
    oTabTMP:AddIndex("5", {"TP_TRANSF"} )
    oTabTMP:Create()

    For nY := 3 To Len(aFields)
        aAdd(aSeek,{GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"),"X3_TITULO"), ;
                   { {"", GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_TIPO"), ;
                          GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_TAMANHO"), ;
                          GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_DECIMAL"), ;
                          AllTrim(GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_TITULO")), ;
                          AllTrim(GetSX3Cache(StrTran(aFields[nY,1],"TP","EA"), "X3_PICTURE"))};
                    } } )
    Next 

    U_fDadosTab() //Função que irá alimentar os dados da tabela temporaria

    oDialog := FWDialogModal():New()
    oDialog:SetBackground( .T. ) 
    oDialog:SetTitle( 'Boleto Bancario' )
    oDialog:SetSize( 280, 800 )
    oDialog:EnableFormBar( .T. )
    oDialog:SetCloseButton( .T. )
    oDialog:SetEscClose( .T. )
    oDialog:CreateDialog()
    oDialog:CreateFormBar()
    oDialog:AddButton('Imprimir' , { || FWMsgRun(Nil, {|| BxBoleto()}, "Aguarde...", "Imprimindo Boleto...") },,2,0)

    oPanel := oDialog:GetPanelMain()
        oMarkBrowse:= FWMarkBrowse():New()
        oMarkBrowse:SetDescription("")
        oMarkBrowse:SetFields(aColsBrw)
        oMarkBrowse:SetTemporary(.T.)
        oMarkBrowse:SetAlias(cAliasBrw)
        oMarkBrowse:AddFilter("Autorizado", 'TP_TRANSF == "S"',,.F.,,.T.)
        oMarkBrowse:AddFilter("Aguardando Transmissão", 'TP_TRANSF == ""',,.F.,,.T.)
        oMarkBrowse:AddFilter("Com Erro", 'TP_TRANSF == "F"',,.F.,,.T.)
        oMarkBrowse:AddStatusColumns( { || BrwStatus() }, { || BrwVisErr() } )
        oMarkBrowse:SetFieldMark("TP_MARK")
        oMarkBrowse:SetMark(cMarca,cAliasBrw,"TP_MARK")
        oMarkBrowse:SetAllMark({ || U_AllMark() })
        oMarkBrowse:SetValid({ || U_ValidMark() })
        oMarkBrowse:SetWalkThru(.F.)
        oMarkBrowse:SetSeek(.T.,aSeek)
        oMarkBrowse:SetAmbiente(.F.)
        oMarkBrowse:SetUseFilter(.T.)
        oMarkBrowse:SetMenuDef("XFAT002")
        oMarkBrowse:SetOwner(oPanel)
        oMarkBrowse:DisableReport()
        oMarkBrowse:DisableDetails()
        oMarkBrowse:Activate()
    oDialog:Activate()

	oTabTMP:Delete()
    oMarkBrowse:DeActivate()
    NgRetAuMVPa(aBkpParam)

Return

/*---------------------------------------------------------------------*
 | Func:  MenuDef                                                      |
 | Desc:  Criação do menu MVC                                          |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function MenuDef()
Local aRotina := {}

ADD OPTION aRotina TITLE 'Gerar Boleto' ACTION 'U_GeraBol()' OPERATION 3 ACCESS 0 //OPERATION 3
    
Return aRotina

/*---------------------------------------------------------------------*
 | Func:  fDadosTab                                                    |
 | Desc:  Função que irá alimentar os dados da tabela temporaria       |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
User Function fDadosTab()
Local _cQry     := ""
Local cAliasQry := GetNextAlias()

    IF !Empty(MV_PAR01)
        _cQry := " SELECT SEA.EA_FILIAL,SEA.EA_PREFIXO,SEA.EA_NUM,SEA.EA_PARCELA,SEA.EA_TIPO,SEA.EA_PORTADO,SEA.EA_AGEDEP, "
        _cQry += "        SEA.EA_NUMCON,SEA.EA_NUMBOR,SEA.EA_TRANSF,SEA.EA_APIMSG "
        _cQry += " FROM "+ RetSqlName("SF2") + " SF2 "
        _cQry += " INNER JOIN " + RetSqlName("SEA") + " SEA On SEA.EA_PREFIXO = SF2.F2_SERIE AND SEA.EA_NUM = SF2.F2_DOC "
        _cQry += " INNER JOIN " + RetSqlName("DAK") + " DAK On DAK.DAK_COD = SF2.F2_CARGA "
        _cQry += " WHERE   SF2.D_E_L_E_T_ <> '*'"
        _cQry += "     AND DAK.D_E_L_E_T_ <> '*'"
        _cQry += "     AND SEA.D_E_L_E_T_ <> '*'"
        _cQry += "     AND SF2.F2_FILIAL  = '" + xFilial("SF2") + "'"
        _cQry += "     AND DAK.DAK_FILIAL = '" + xFilial("DAK") + "'"
        _cQry += "     AND SEA.EA_FILIAL  = '" + xFilial("SEA") + "'"
        _cQry += "     AND SEA.EA_CART    = 'R'"
        _cQry += "     AND SEA.EA_BORAPI  = 'S'"
        If !Empty(MV_PAR05) .And. !Empty(MV_PAR06)
        _cQry += "     AND SEA.EA_DATABOR BETWEEN '" + DToS(MV_PAR05) + "' AND '" + DToS(MV_PAR06) + "' "
        EndIF 
        _cQry += "     AND DAK.DAK_COD    = '" + MV_PAR01 + "'"
        _cQry += " ORDER BY SEA.EA_PREFIXO, SEA.EA_NUM, SEA.EA_PARCELA "
    ElseIF !Empty(MV_PAR02) .And. !Empty(MV_PAR04)
        _cQry := " SELECT SEA.EA_FILIAL,SEA.EA_PREFIXO,SEA.EA_NUM,SEA.EA_PARCELA,SEA.EA_TIPO,SEA.EA_PORTADO,SEA.EA_AGEDEP, "
        _cQry += "        SEA.EA_NUMCON,SEA.EA_NUMBOR,SEA.EA_TRANSF,SEA.EA_APIMSG "
        _cQry += " FROM "+ RetSqlName("SEA") + " SEA "
        _cQry += " WHERE SEA.D_E_L_E_T_ <> '*' "
        _cQry += "   AND SEA.EA_FILIAL  = '"+xFilial('SEA')+"' "
        _cQry += "   AND SEA.EA_PREFIXO = '"+MV_PAR02+"' "
        _cQry += "   AND SEA.EA_NUM BETWEEN '"+MV_PAR03+"' AND '"+MV_PAR04+"' "
        _cQry += "   AND SEA.EA_CART    = 'R'"
        _cQry += "   AND SEA.EA_BORAPI  = 'S'"
        If !Empty(MV_PAR05) .And. !Empty(MV_PAR06)
        _cQry += "     AND SEA.EA_DATABOR BETWEEN '" + DToS(MV_PAR05) + "' AND '" + DToS(MV_PAR06) + "' "
        EndIF
        _cQry += " ORDER BY SEA.EA_PREFIXO, SEA.EA_NUM, SEA.EA_PARCELA "
    EndIF
    _cQry := ChangeQuery(_cQry)
    IF Select(cAliasQry) <> 0
        (cAliasQry)->(DbCloseArea())
    EndIf
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,_cQry),cAliasQry,.T.,.T.)
    (cAliasQry)->(DBGoTop())
    
    oTabTMP:Zap() //Limpa todos os registros da tabela temporária cAliasBrw.
    
    While !(cAliasQry)->(Eof())
        RecLock(cAliasBrw,.T.)
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

/*---------------------------------------------------------------------*
 | Func:  AllMark                                                      |
 | Desc:  Marca os registro do Brownser                                |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
User Function AllMark()

    DBSelectArea(cAliasBrw)
    (cAliasBrw)->(DBGoTop())
    While (cAliasBrw)->(!Eof())
        If (cAliasBrw)->TP_TRANSF == "S"
            RecLock(cAliasBrw, .F.)
                (cAliasBrw)->TP_MARK := IIF(Empty((cAliasBrw)->TP_MARK),"X","")
            (cAliasBrw)->(MsUnlock())
        EndIF 
    (cAliasBrw)->(DbSkip())
    End

    oMarkBrowse:Refresh(.T.)

Return

/*---------------------------------------------------------------------*
 | Func:  ValidMark                                                    |
 | Desc:  Valida se registro do Brownser poderá ser marcado            |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
User Function ValidMark()
Local lRet := .F.
    
    If (cAliasBrw)->TP_TRANSF == "S"
        lRet := .T.
    EndIf 

Return lRet

/*---------------------------------------------------------------------*
 | Func:  BxBoleto                                                     |
 | Desc:  Realiza o Download dos boletos selecionados                  |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function BxBoleto()
Local aAreaSEA := SEA->(FWGetArea())
Local cBody    := ""
Local oService := Nil
Local cDirLoc  := GetTempPath(.T.,.F.)
Local cBarra   := IIF(IsSrvUnix(),"/","\")
Local cDirSer  := cBarra+"spool"+cBarra+"boletos"+cBarra+cEmpAnt+cBarra
Local aBoletos := {}
Local nY

    DBSelectArea(cAliasBrw)

    (cAliasBrw)->(DBGoTop())
    While (cAliasBrw)->(!Eof())
        If !Empty((cAliasBrw)->TP_MARK)
            aAdd( aBoletos, { Alltrim((cAliasBrw)->TP_FILIAL),;
                              Alltrim((cAliasBrw)->TP_NUMBOR),;
                              Alltrim((cAliasBrw)->TP_PREFIXO),;
                              Alltrim((cAliasBrw)->TP_NUM),;
                              Alltrim((cAliasBrw)->TP_PARCELA),;
                              Alltrim((cAliasBrw)->TP_TIPO)  })
        EndIF 
    (cAliasBrw)->(DbSkip())
    End

    oService := gfin.api.banks.bills.BanksBillsService():New()

    cBody := '{ "bills": [ '
    For nY := 1 To Len(aBoletos)            
        cBody += '{' +;
        '"ea_filial": "'  + aBoletos[nY][1] +'",' + ;
        '"ea_numbor": "'  + aBoletos[nY][2] +'",' + ;
        '"ea_prefixo": "' + aBoletos[nY][3] +'",' + ;
        '"ea_num": "'     + aBoletos[nY][4] +'",' + ;
        '"ea_parcela": "' + aBoletos[nY][5] +'",' + ;
        '"ea_tipo": "'    + aBoletos[nY][6] +'"'  + ;
        IIF(nY < Len(aBoletos),'},','}')
    Next   
    cBody += ']}'

    oService:downloadPdf(cBody, .T.)
    If oService:lOk
        If !(__CopyFile(cDirSer+oService:cPathPDF, cDirLoc+"\"+oService:cPathPDF))
            MsgStop("Erro na criação do arquivo " + oService:cPathPDF + ", por favor tente novamente!", "Atenção")
        Else
            ShellExecute( "Open", cDirLoc+"\"+oService:cPathPDF , "/RUN /TN SPARK", cDirLoc , 1 )
            FErase(cDirSer+oService:cPathPDF)
        EndIF
    EndIF

    FWRestArea(aAreaSEA)

Return

/*---------------------------------------------------------------------*
 | Func:  BrwStatus                                                    |
 | Desc:  Status do Registro                                           |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function BrwStatus()
Local aArea := FWGetArea()
Local aAreaSEA := SEA->(FWGetArea())
Local cRet := ""
    
    DBSelectArea('SEA')
    IF SEA->(MSSeek( (cAliasBrw)->TP_FILIAL + (cAliasBrw)->TP_NUMBOR + (cAliasBrw)->TP_PREFIXO + ;
                     (cAliasBrw)->TP_NUM + (cAliasBrw)->TP_PARCELA + (cAliasBrw)->TP_TIPO ))
        
        Do Case
            Case SEA->EA_TRANSF == 'S'
                cRet := "BR_VERDE"
            Case Empty(SEA->EA_TRANSF)
                cRet := "BR_AZUL"
            Case SEA->EA_TRANSF == 'F'
                cRet := "BR_VERMELHO"
        EndCase

    EndIF 

    FWRestArea(aAreaSEA)
    FWRestArea(aArea)

Return (cRet)

/*---------------------------------------------------------------------*
 | Func:  BrwVisErr                                                    |
 | Desc:  Mensagem de Erro                                             |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function BrwVisErr()
Local aArea := FWGetArea()
Local aAreaSEA := SEA->(FWGetArea())
    
    DBSelectArea('SEA')
    IF SEA->(MSSeek( (cAliasBrw)->TP_FILIAL + (cAliasBrw)->TP_NUMBOR + (cAliasBrw)->TP_PREFIXO + ;
                     (cAliasBrw)->TP_NUM + (cAliasBrw)->TP_PARCELA + (cAliasBrw)->TP_TIPO ))
        
        If SEA->EA_TRANSF == 'F'
            FWAlertInfo(Alltrim(SEA->EA_APILOG),"Erro Boleto ")
        EndIF 

    EndIF 

    FWRestArea(aAreaSEA)
    FWRestArea(aArea)

Return

/*---------------------------------------------------------------------*
 | Func:  GeraBol                                                      |
 | Desc:  Realiza a geração dos boletos                                |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
User Function GeraBol()
Local _cQry     := ""
Local cAliasQry := GetNextAlias()
Local aIdNfe    := {}
Local aBkpParGr := NgSalvaMvPa()
Local cIdsNfe   := ""
Local nY

    _cQry := "SELECT SF2.F2_SERIE, SF2.F2_DOC FROM "+ RetSqlName("SF2") + " SF2 "
    _cQry += "WHERE  SF2.D_E_L_E_T_ <> '*'"
    _cQry += "   AND SF2.F2_FILIAL  = '" + xFilial("SF2") + "'"
    If !Empty(MV_PAR01)
        _cQry += "   AND SF2.F2_CARGA = '" + MV_PAR01 + "'"
    Else
        _cQry += "   AND SF2.F2_SERIE = '" + MV_PAR02 + "'"
        _cQry += "   AND SF2.F2_DOC BETWEEN '" + MV_PAR03 + "' AND '" + MV_PAR04 + "'"
    EndIF
    If !Empty(MV_PAR05) .AND. !Empty(MV_PAR06)
        _cQry += "   AND SF2.F2_EMISSAO BETWEEN '" + DToS(MV_PAR05) + "' AND '" + DToS(MV_PAR06) + "'"
    EndIF
    _cQry := ChangeQuery(_cQry)
    IF Select(cAliasQry) <> 0
        (cAliasQry)->(DbCloseArea())
    EndIf
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,_cQry),cAliasQry,.T.,.T.)

    While !(cAliasQry)->(Eof())
        aAdd(aIdNfe,(cAliasQry)->F2_SERIE + (cAliasQry)->F2_DOC)
		(cAliasQry)->(DbSkip())
	EndDo
	(cAliasQry)->(DbCloseArea())
    
    If !Empty(aIdNfe)
        For nY := 1 To Len(aIdNfe)
            If Empty(cIdsNfe)
                cSerieNF := SubSTR(aIdNfe[nY],1,3)
                cIdsNfe  += SubSTR(aIdNfe[nY],4)
            Else
                cIdsNfe += "/"+SubSTR(aIdNfe[nY],4)
            EndIF
        Next nY
        If ExistBlock("XFAT001")
            FWMsgRun(, {|| U_XFAT001(cSerieNF,cIdsNfe) }, "Aguarde...", "Gerando o(s) Boleto(s)") //Função que irá gerar os boletos
            NgRetAuMVPa(aBkpParGr)
            U_fDadosTab()
            oMarkBrowse:Refresh(.T.)
        Else
            MsgAlert("A função U_XFAT001 não está compilada no RPO - Repositorio de Objetos","Função XFAT001")
        EndIF
    EndIF

Return
