#Include "PROTHEUS.ch"
#Include "FWMVCDef.ch"
#Include "TBICONN.CH"
#Include "TopConn.ch"
#Include "Colors.ch"
#Include "RPTDef.ch"
#Include "FWPrintSetup.ch"

// ---------------------------------------------------------------------------
/*/ Rotina XFAT001
  Função responsável por gerar a DANFE e o Boleto da Nota Fiscal.
  Retorno
  @historia
  13/03/2026 - Desenvolvimento da Rotina.
/*/
// ---------------------------------------------------------------------------
User Function XFAT001(cSerieNF,cIdsNfe)
Local aArea       := FWGetArea()
Local aBankBol    := StrTokArr(SuperGetMV("MV_XBANKBO",.F.,""),"/")
Local cFormPag    := SuperGetMV("MV_XFORMBO",.F.,"BOL")
Local cNotasIN    := ""
Local cQry        := ""
Local _cAlias     := ""
Local nY

//Monitoramento
Local aRetMonit   := {}
Local cURLTSS     := PadR(GetNewPar("MV_SPEDURL", "http://"), 250)
Local aParam      := {}
Local nTpMonitor  := 1
Local cModelo     := "55"
Local lCte        := .F.
Local cError      := ""

Private aTitBord  := {}
Private cBank     := ""
Private cAgenc    := ""
Private cContCC   := ""
Private cSubCC    := ""
Private cNotaIni  := ""
Private cNotaFin  := ""
Private cSerDanfe := ""

Default cSerieNF  := ""
Default cIdsNfe   := ""

  aParam    := Array(5)
  aParam[1] := cSerieNF
  aParam[2] := SubSTR(cIdsNfe,1,9)
  aParam[3] := SubSTR(cIdsNfe,Len(cIdsNfe)-8)
  aParam[4] := MonthSub(dDataBase, 1)
  aParam[5] := MonthSum(dDataBase, 1)

  cSerDanfe := aParam[1]
  cNotaIni  := aParam[2]
  cNotaFin  := aParam[3]
    
  For nY := 1 To 5
    aRetMonit := procMonitorDoc(cIdent,cURLTSS,aParam,nTpMonitor,"0" + cModelo,lCte,@cError)
    If Len(aRetMonit) > 0
      If Left(Alltrim(aRetMonit[Len(aRetMonit)][9]), 3) == '001'
          Exit
      EndIf
    EndIf
    //Aguarda 2 segundos antes da próxima tentativa
    Sleep(2000)
  Next nY
        
  If Len(aRetMonit) > 0
    For nY := 1 To Len(aRetMonit)
      If SubSTR(aRetMonit[nY][9],1,3) == "001"
        If Empty(cNotasIN)
          cNotasIN += aRetMonit[nY][3]
        Else
          cNotasIN += "/"+aRetMonit[nY][3]
        EndIF
      EndIF
    Next nY
    cNotasIN := FormatIN(cNotasIN,"/")

    If !FWIsInCallStack("U_GeraBol")
      zGerDanfe() //Gera a DANFE da Nota Fiscal          
    EndIF

    If Len(cNotasIN) > 0 .AND. Len(aBankBol) >= 4
      DBSelectArea("SA6")
      SA6->(DBSetOrder(1))
      If SA6->(MSSeek(xFilial("SA6") + PadR(aBankBol[1],FWTamSX3("A6_COD")[1]) + PadR(aBankBol[2],FWTamSX3("A6_AGENCIA")[1]) + PadR(aBankBol[3],FWTamSX3("A6_NUMCON")[1])))
        If AllTrim(SA6->A6_CFGAPI) $ ('1,3')
          cBank   := SA6->A6_COD
          cAgenc  := SA6->A6_AGENCIA
          cContCC := SA6->A6_NUMCON
          cSubCC  := PadR(aBankBol[4],FWTamSX3("EA_SUBCTA")[1])
                
          _cAlias := FWTimeStamp()

          cQry := " SELECT SE1.E1_FILIAL, SE1.E1_PREFIXO, SE1.E1_NUM, SE1.E1_PARCELA, SE1.E1_TIPO, SE4.E4_FORMA FROM " + RetSQLName('SE1') + " SE1 "
          cQry += " LEFT JOIN " + RetSQLName('SF2') + " SF2 ON SF2.F2_FILIAL = SE1.E1_FILIAL AND SF2.F2_SERIE = SE1.E1_PREFIXO AND SF2.F2_DOC = SE1.E1_NUM "
          cQry += " AND SF2.F2_CLIENTE = SE1.E1_CLIENTE AND SF2.F2_LOJA = SE1.E1_LOJA AND SF2.D_E_L_E_T_ <> '*' "
          cQry += " LEFT JOIN " + RetSQLName('SE4') + " SE4 ON SE4.E4_FILIAL = '" + xFilial("SE4") + "' AND SE4.E4_CODIGO = SF2.F2_COND AND SE4.D_E_L_E_T_ <> '*' "
          cQry += " WHERE SE1.D_E_L_E_T_ <> '*'"
          cQry += " AND SE1.E1_FILIAL  = '" + xFilial("SE1") + "'"
          cQry += " AND SE1.E1_PREFIXO = '" + cSerieNF + "'"
          cQry += " AND SE1.E1_NUM IN " + cNotasIN + " "
          cQry += " AND SE1.E1_NUMBOR = '' "
          IF Select(_cAlias) <> 0
            (_cAlias)->(DbCloseArea())
          EndIf
          dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)
          While (_cAlias)->(!EoF())
            If Alltrim((_cAlias)->E4_FORMA) $ (cFormPag)
            aAdd(aTitBord ,{{"E1_FILIAL" , (_cAlias)->E1_FILIAL},;
                            {"E1_PREFIXO", (_cAlias)->E1_PREFIXO},;
                            {"E1_NUM"    , (_cAlias)->E1_NUM},;
                            {"E1_PARCELA", (_cAlias)->E1_PARCELA},;
                            {"E1_TIPO"   , (_cAlias)->E1_TIPO} })
            EndIF
          (_cAlias)->(DbSkip())
          End
          IF Select(_cAlias) <> 0
            (_cAlias)->(DbCloseArea())
          EndIf
        EndIF

        //--------------------------------------------------------------------------------
        //Gera o borderô automaticamente para emissão do boleto online
        If Len(aTitBord) > 0
          FWMsgRun(, {|| fnGerBor() }, "Aguarde...", "Gerando o(s) Boleto(s)")
        EndIF 
        //--------------------------------------------------------------------------------
      EndIF
    EndIF
  EndIF
  
  FWRestArea(aArea)
Return

// -----------------------------------------
/*/ Função zGerDanfe

  Gera a DANFE da Nota Fiscal.

  @author Totvs Nordeste
  Return
/*/
// -----------------------------------------
Static Function zGerDanfe()
Local aArea     := FWGetArea()
Local cArquivo  := ""
Local cArqPDF   := ""
Local oDanfe    := Nil
Local lExistNFe := .F.
Local nTamNota  := TamSX3('F2_DOC')[1]
Local nTamSerie := TamSX3('F2_SERIE')[1]
Local cBarra    := IIF(IsSrvUnix(),"/","\")
Local cDirSer   := cBarra+"spool"+cBarra
Local cDirLoc   := GetTempPath(.T.,.F.)
Local cProg		  := IIF(ExistBlock("DANFEProc"),"U_DANFEProc","DANFEProc")

Private PixelX
Private PixelY
Private nConsNeg
Private nConsTex
Private oRetNF
Private nColAux
       
  //Se existir nota
  If !Empty(cNotaIni) .AND. !Empty(cNotaFin)
           
    cArquivo := cNotaIni+cNotaFin + "_" + FWTimeStamp()
           
    //Define as perguntas da DANFE
    Pergunte("NFSIGW",.F.)
    MV_PAR01 := PadR(cNotaIni,  nTamNota)   //Nota Inicial
    MV_PAR02 := PadR(cNotaFin,  nTamNota)   //Nota Final
    MV_PAR03 := PadR(cSerDanfe, nTamSerie)  //Série da Nota
    MV_PAR04 := 2                           //NF de Saida
    MV_PAR05 := 1                           //Frente e Verso = Sim
    MV_PAR06 := 2                           //DANFE simplificado = Nao
    MV_PAR07 := MonthSub(dDataBase, 1)      //Data De
    MV_PAR08 := MonthSum(dDataBase, 1)      //Data Até
           
    oDanfe := FWMSPrinter():New(cArquivo, IMP_PDF, .F., , .T.)
           
    oDanfe:SetResolution(78)
    oDanfe:SetPortrait()
    oDanfe:SetPaperSize(DMPAPER_A4)
    oDanfe:SetMargin(40, 40, 40, 40)
           
    //Força a impressão em PDF
    oDanfe:nDevice  := 6
    oDanfe:cPathPDF := cDirSer
    oDanfe:lServer  := .F.
    oDanfe:lViewPDF := .F.
           
    PixelX    := oDanfe:nLogPixelX()
    PixelY    := oDanfe:nLogPixelY()
    nConsNeg  := 0.4
    nConsTex  := 0.5
    oRetNF    := Nil
    nColAux   := 0
    
    oDanfe:lInJob := .T.

    //Chamando a impressão da danfe no RDMAKE
    &cProg.(@oDanfe, , cIDEnt, Nil, Nil, @lExistNFe, .F./*lIsLoja*/)
		If lExistNFe
      oDanfe:Preview()
      cArqPDF := cArquivo+".pdf"
		  If !(__CopyFile(cDirSer+cArqPDF, cDirLoc+cArqPDF))
        MsgStop("Erro na criação do arquivo " + cArqPDF + ", por favor tente novamente!", "Atenção")
      Else
        ShellExecute( "Open", cDirLoc+cArqPDF , "/RUN /TN SPARK", cDirLoc , 1 )
        FErase(cDirSer+cArqPDF)
      EndIF
    EndIF
  EndIf
       
  FWRestArea(aArea)
Return

// -----------------------------------------
/*/ Função fnGerBor

   Gerar Bordero.

  @author Totvs Nordeste
  Return
/*/
// -----------------------------------------
Static Function fnGerBor()
Local cEspec  := ""
Local aRegBor := {}
  
Private lMsErroAuto    := .F.
Private lMsHelpAuto    := .T.
Private lAutoErrNoFile := .T.
Private cNumBor        := ""

 // -- Informações bancárias para o borderô
 // ---------------------------------------

  DBSelectArea("F77")
  IF F77->(MsSeek(FWxFilial("F77")+cBank))
    While ! F77->(Eof()) .AND. F77->F77_BANCO == cBank
      If F77->F77_SIGLA == PadR('DM',FWTamSX3("F77_SIGLA")[1]) 
        cEspec := F77->F77_ESPECI
        Exit
      EndIF 
      F77->(DBSkip())
    End 
  EndIf 

  aAdd(aRegBor, {"AUTBANCO"   , cBank})
  aAdd(aRegBor, {"AUTAGENCIA" , cAgenc})
  aAdd(aRegBor, {"AUTCONTA"   , cContCC})
  aAdd(aRegBor, {"AUTSITUACA" , PadR("1",FWTamSX3("E1_SITUACA")[1])})
  aAdd(aRegBor, {"AUTNUMBOR"  , PadR("",FWTamSX3("E1_NUMBOR")[1])})   //Caso não seja passado o número será obtido o próximo pelo padrão do sistema
  aAdd(aRegBor, {"AUTSUBCONTA", cSubCC})
  aAdd(aRegBor, {"AUTESPECIE" , cEspec})
  aAdd(aRegBor, {"AUTBOLAPI"  , .T.})

  MsExecAuto({|a,b| FINA060(a,b)},3,{aRegBor, aTitBord})

  If lMsErroAuto
    MostraErro()
  Else
    cNumBor := SE1->E1_NUMBOR
    F713Transf()
    Sleep(10000) //Aguarda 10 segundos antes de iniciar a impressão dos boletos
    If !FWIsInCallStack("U_GeraBol")
      BxBoleto()
    EndIF
  EndIf

Return

/*---------------------------------------------------------------------*
 | Func:  BxBoleto                                                     |
 | Desc:  Realiza o Download dos boletos selecionados                  |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function BxBoleto()
Local aBolAut  := {}
Local cBody    := ""
Local oService := Nil
Local cDirLoc  := GetTempPath(.T.,.F.)
Local cBarra   := IIF(IsSrvUnix(),"/","\")
Local cDirSer  := cBarra+"spool"+cBarra+"boletos"+cBarra+cEmpAnt+cBarra
Local nBolNot  := 0
Local nY

  oService := gfin.api.banks.bills.BanksBillsService():New()

  DBSelectArea("SEA")
  SEA->(DBSetOrder(1))
  For nY := 1 To Len(aTitBord)
    If SEA->(MSSeek(xFilial("SEA") + cNumBor + aTitBord[nY][2][2] + aTitBord[nY][3][2] + aTitBord[nY][4][2] + aTitBord[nY][5][2]))
      If SEA->EA_TRANSF == "S"
        aAdd(aBolAut,{aTitBord[nY][1][2],;
                      aTitBord[nY][2][2],;
                      aTitBord[nY][3][2],;
                      aTitBord[nY][4][2],;
                      aTitBord[nY][5][2]})
      Else
        ++nBolNot
      EndIF
    EndIF
  Next nY

  If nBolNot == Len(aTitBord)
    MsgAlert('Nenhum boleto foi autorizado, por favor verificar o status do(s) boleto(s) na opção "Outras Ações -> Boleto" ', "Boleto não autorizado")
    Return
  ElseIF nBolNot > 0
    MsgAlert('Existe boleto(s) não autorizado(s), por favor verificar o status do boleto na opção "Outras Ações -> Boleto" ', "Boleto não autorizado")
  EndIF
  
  cBody := '{ "bills": [ '
  For nY := 1 To Len(aBolAut)
    cBody += '{' +;
          '"ea_filial": "'  + aBolAut[nY][1] +'",' + ;
          '"ea_numbor": "'  + cNumBor        +'",' + ;
          '"ea_prefixo": "' + aBolAut[nY][2] +'",' + ;
          '"ea_num": "'     + aBolAut[nY][3] +'",' + ;
          '"ea_parcela": "' + aBolAut[nY][4] +'",' + ;
          '"ea_tipo": "'    + aBolAut[nY][5] +'"'  + ;
          IIF(nY < Len(aBolAut),'},','}')
  Next nY
  cBody += ']}'

  oService:downloadPdf(cBody, .T.)
  If oService:lOk
    If !(__CopyFile(cDirSer+oService:cPathPDF, cDirLoc+"\"+oService:cPathPDF))
      MsgStop("Erro na criação do arquivo " + oService:cPathPDF + ", por favor tente novamente!", "Atenção")
    Else
      ShellExecute( "Open", cDirLoc+"\"+oService:cPathPDF , "/RUN /TN SPARK", cDirLoc , 1 )
      FErase(cDirSer+oService:cPathPDF)
    EndIF
  Else
    MsgStop('Ocorreu um erro na impressão automatica do(s) boleto(s), por favor realize a impressão através da opção "Outras Ações -> Boleto" ', "Impressão de Boleto")
  End

Return
