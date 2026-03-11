#Include "PROTHEUS.ch"
#Include "FWMVCDef.ch"
#Include "TBICONN.CH"
#Include "TopConn.ch"

// ---------------------------------------------------------------------------
/*/ Rotina fnGerBol
  Função responsável por selecionar banco para geração do borderô automatico.
  Retorno
  @historia
  10/03/2026 - Desenvolvimento da Rotina.
/*/
// ---------------------------------------------------------------------------
User Function fnGerBol(cSerieNF,cIdsNfe)
Local aArea       := FWGetArea()
Local cNotasIN    := {}
Local aTitAux     := {}
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

Default cSerieNF  := ""
Default cIdsNfe   := ""

  aParam    := Array(5)
  aParam[1] := cSerieNF
  aParam[2] := SubSTR(cIdsNfe,1,9)
  aParam[3] := SubSTR(cIdsNfe,Len(cIdsNfe)-9)
  aParam[4] := MonthSub(dDataBase, 1)
  aParam[5] := MonthSum(dDataBase, 1)
    
  For nY := 1 To 5
    aRetMonit := procMonitorDoc(cIdent,cURLTSS,aParam,nTpMonitor,"0" + cModelo,lCte,@cError)
    If Len(aRetMonit) > 0
      If Left(Alltrim(aRetMonit[Len(aRetMonit)][9]), 3) == '001'
          Exit
      EndIf
    EndIf
    //Aguarda 3 segundos antes da próxima tentativa
    Sleep(3000)
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
          
    If Len(cNotasIN) > 0
      DBSelectArea("SA6")
      SA6->(DBSetOrder(1))
      If SA6->(MSSeek(xFilial("SA6") + PadR(aBankBol[1],FWTamSX3("A6_COD")[1]) + PadR(aBankBol[2],FWTamSX3("A6_AGENCIA")[1]) + PadR(aBankBol[3],FWTamSX3("A6_NUMCON")[1])))
        If AllTrim(SA6->A6_CFGAPI) $ ('1,3')
          cBank   := SA6->A6_COD
          cAgenc  := SA6->A6_AGENCIA
          cContCC := SA6->A6_NUMCON
          cSubCC  := PadR(aBankBol[4],FWTamSX3("EA_SUBCTA")[1])
                
          _cAlias := FWTimeStamp()

          cQry := "SELECT E1_FILIAL, E1_PREFIXO, E1_NUM, E1_PARCELA, E1_TIPO FROM " + RetSQLName('SE1') + " "
          cQry += "WHERE D_E_L_E_T_ <> '*' "  
          cQry += "AND E1_FILIAL  = '" + xFilial("SE1") + "' "
          cQry += "AND E1_PREFIXO = '" + cSerieNF + "' "
          cQry += "AND E1_NUMERO  IN " + cNotasIN + " "
          IF Select(_cAlias) <> 0
            (_cAlias)->(DbCloseArea())
          EndIf
          dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.T.,.T.)
          While (_cAlias)->(!EoF())
            aTitAux := {}
            aAdd(aTitAux ,{ {"E1_FILIAL" , (_cAlias)->E1_FILIAL},;
                            {"E1_PREFIXO", (_cAlias)->E1_PREFIXO},;
                            {"E1_NUM"    , (_cAlias)->E1_NUM},;
                            {"E1_PARCELA", (_cAlias)->E1_PARCELA},;
                            {"E1_TIPO"   , (_cAlias)->E1_TIPO} })
            aAdd(aTitBord,aTitAux)
          (_cAlias)->(DbSkip())
          End
          IF Select(_cAlias) <> 0
            (_cAlias)->(DbCloseArea())
          EndIf
        EndIF

        //--------------------------------------------------------------------------------
        //Gera o borderô automaticamente para emissão do boleto online
        If Len(aTitBord) > 0
          FWMsgRun(, {|oSay| fnGerBor(oSay) }, "Aguarde...", "Gerando o(s) Boleto(s)")
        EndIF 
        //--------------------------------------------------------------------------------
      EndIF
    EndIF
  EndIF
  
  FWRestArea(aArea)
Return

// -----------------------------------------
/*/ Função fnGerBor

   Gerar Bordero.

  @author Totvs Nordeste
  Return
/*/
// -----------------------------------------
Static Function fnGerBor(nY)
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
    cNumBor := SEA->EA_NUMBOR
    F713Transf()
    Sleep(5000)
    BxBoleto()
  EndIf

Return

/*---------------------------------------------------------------------*
 | Func:  BxBoleto                                                     |
 | Desc:  Realiza o Download dos boletos selecionados                  |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function BxBoleto()
Local cBody    := ""
Local oService := Nil
Local cBase64  := ""
Local cDirLoc  := GetTempPath(.T.,.F.)
Local cBarra   := IIF(IsSrvUnix(),"/","\")
Local cDirSer  := cBarra+"spool"+cBarra+"boletos"+cBarra+cEmpAnt+cBarra
Local aBoletos := {}
Local nY

  oService := gfin.api.banks.bills.BanksBillsService():New()

  cBody := '{ "bills": [ '

  For nY := 1 To Len(aTitBord)
    cBody += '{' +;
      '"ea_filial": "'  + aTitBord[nY][1] +'",' + ;
      '"ea_numbor": "'  + cNumBor         +'",' + ;
      '"ea_prefixo": "' + aTitBord[nY][2] +'",' + ;
      '"ea_num": "'     + aTitBord[nY][3] +'",' + ;
      '"ea_parcela": "' + aTitBord[nY][4] +'",' + ;
      '"ea_tipo": "'    + aTitBord[nY][5] +'"'  + ;
      IIF(nY < Len(aBoletos),'},','}')
  Next nY

  cBody += ']}'

  oService:downloadPdf(cBody, .T.)
  If oService:lOk
    cBase64 := oService:cFilePDF
    If !(__CopyFile(cDirSer+oService:cPathPDF, cDirLoc+"\"+oService:cPathPDF))
      MsgStop("Erro na criação do arquivo " + oService:cPathPDF + ", por favor tente novamente!", "Atenção")
    Else
      ShellExecute( "Open", cDirLoc+"\"+oService:cPathPDF , "/RUN /TN SPARK", cDirLoc , 1 )
      FErase(cDirSer+oService:cPathPDF)
    EndIF
  End

Return
