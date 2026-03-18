//Bibliotecas
#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'
#Include "TBICONN.CH"
#Include "TopConn.ch"

#Define ENTER Chr(13)+Chr(10)

//--------------------------------------------------------------------------
/*/{PROTHEUS.DOC} XBCON
FUNÇÃO XBCON - Função para visualização do Banco de Conhecimento generido
@OWNER TOTVS Nordeste (Elvis Siqueira)
@VERSION PROTHEUS 12
@SINCE 20/01/2026
/*/
//--------------------------------------------------------------------------

User Function XBCON(pCampo1, pCampo2, pCampo3, pCampo4, pCampo5, pCampo6)
Local aArea  := GetArea()
Local aButtons := {;
                    {.F.,Nil},;         // Copiar
                    {.F.,Nil},;         // Recortar
                    {.F.,Nil},;         // Colar
                    {.F.,Nil},;         // Calculadora
                    {.F.,Nil},;         // Spool
                    {.F.,Nil},;         // Imprimir
                    {.T.,"Confirmar"},; // Confirmar
                    {.T.,"Cancelar"},;  // Cancelar
                    {.F.,Nil},;         // WalkTrhough
                    {.F.,Nil},;         // Ambiente
                    {.F.,Nil},;         // Mashup
                    {.F.,Nil},;         // Help
                    {.F.,Nil},;         // Formulário HTML
                    {.F.,Nil};          // ECM
                  }

Private cCampo1  := pCampo1
Private cCampo2  := pCampo2
Private cCampo3  := pCampo3
Private cCampo4  := pCampo4
Private cCampo5  := pCampo5
Private cCampo6  := pCampo6
Private oTabTMP1 := FWTemporaryTable():New("TMP1")
Private oTabTMP2 := FWTemporaryTable():New("TMP2")
Private oTabTMP3 := FWTemporaryTable():New("TMP3")
Private oTabTMP4 := FWTemporaryTable():New("TMP4")
Private oTabTMP5 := FWTemporaryTable():New("TMP5")
Private oTabTMP6 := FWTemporaryTable():New("TMP6")
Private aFields1 := {}
Private aFields2 := {}
Private aFields3 := {}
Private aFields4 := {}
Private aFields5 := {}
Private aFields6 := {}

aAdd(aFields1, {"T1_CODSOL" ,"C",6,0 ,"Cod. Solicitante","@!"})
aAdd(aFields1, {"T1_NOMSOL" ,"C",60,0,"Nome Solicitante","@!"})

oTabTMP1:SetFields(aFields1)
oTabTMP1:Create()

aAdd(aFields2, {"T2_FILENT",GetSx3Cache("AC9_FILENT","X3_TIPO"),GetSx3Cache("AC9_FILENT","X3_TAMANHO"),GetSx3Cache("AC9_FILENT","X3_DECIMAL"),GetSx3Cache("AC9_FILENT","X3_TITULO"),GetSx3Cache("AC9_FILENT","X3_PICTURE")})
aAdd(aFields2, {"T2_ENTIDA",GetSx3Cache("AC9_ENTIDA","X3_TIPO"),GetSx3Cache("AC9_ENTIDA","X3_TAMANHO"),GetSx3Cache("AC9_ENTIDA","X3_DECIMAL"),GetSx3Cache("AC9_ENTIDA","X3_TITULO"),GetSx3Cache("AC9_ENTIDA","X3_PICTURE")})
aAdd(aFields2, {"T2_CODENT",GetSx3Cache("AC9_CODENT","X3_TIPO"),GetSx3Cache("AC9_CODENT","X3_TAMANHO"),GetSx3Cache("AC9_CODENT","X3_DECIMAL"),GetSx3Cache("AC9_CODENT","X3_TITULO"),GetSx3Cache("AC9_CODENT","X3_PICTURE")})
aAdd(aFields2, {"T2_CODOBJ",GetSx3Cache("AC9_CODOBJ","X3_TIPO"),GetSx3Cache("AC9_CODOBJ","X3_TAMANHO"),GetSx3Cache("AC9_CODOBJ","X3_DECIMAL"),GetSx3Cache("AC9_CODOBJ","X3_TITULO"),GetSx3Cache("AC9_CODOBJ","X3_PICTURE")})
aAdd(aFields2, {"T2_OBJETO",GetSx3Cache("ACB_OBJETO","X3_TIPO"),GetSx3Cache("ACB_OBJETO","X3_TAMANHO"),GetSx3Cache("ACB_OBJETO","X3_DECIMAL"),GetSx3Cache("ACB_OBJETO","X3_TITULO"),GetSx3Cache("ACB_OBJETO","X3_PICTURE")})
aAdd(aFields2, {"T2_DESCRI",GetSx3Cache("ACB_DESCRI","X3_TIPO"),GetSx3Cache("ACB_DESCRI","X3_TAMANHO"),GetSx3Cache("ACB_DESCRI","X3_DECIMAL"),GetSx3Cache("ACB_DESCRI","X3_TITULO"),GetSx3Cache("ACB_DESCRI","X3_PICTURE")})
aAdd(aFields2, {"T2_RECNO","N",8,0,"Recno WT",""})

oTabTMP2:SetFields(aFields2)
oTabTMP2:Create()

aAdd(aFields3, {"T3_FILENT",GetSx3Cache("AC9_FILENT","X3_TIPO"),GetSx3Cache("AC9_FILENT","X3_TAMANHO"),GetSx3Cache("AC9_FILENT","X3_DECIMAL"),GetSx3Cache("AC9_FILENT","X3_TITULO"),GetSx3Cache("AC9_FILENT","X3_PICTURE")})
aAdd(aFields3, {"T3_ENTIDA",GetSx3Cache("AC9_ENTIDA","X3_TIPO"),GetSx3Cache("AC9_ENTIDA","X3_TAMANHO"),GetSx3Cache("AC9_ENTIDA","X3_DECIMAL"),GetSx3Cache("AC9_ENTIDA","X3_TITULO"),GetSx3Cache("AC9_ENTIDA","X3_PICTURE")})
aAdd(aFields3, {"T3_CODENT",GetSx3Cache("AC9_CODENT","X3_TIPO"),GetSx3Cache("AC9_CODENT","X3_TAMANHO"),GetSx3Cache("AC9_CODENT","X3_DECIMAL"),GetSx3Cache("AC9_CODENT","X3_TITULO"),GetSx3Cache("AC9_CODENT","X3_PICTURE")})
aAdd(aFields3, {"T3_CODOBJ",GetSx3Cache("AC9_CODOBJ","X3_TIPO"),GetSx3Cache("AC9_CODOBJ","X3_TAMANHO"),GetSx3Cache("AC9_CODOBJ","X3_DECIMAL"),GetSx3Cache("AC9_CODOBJ","X3_TITULO"),GetSx3Cache("AC9_CODOBJ","X3_PICTURE")})
aAdd(aFields3, {"T3_OBJETO",GetSx3Cache("ACB_OBJETO","X3_TIPO"),GetSx3Cache("ACB_OBJETO","X3_TAMANHO"),GetSx3Cache("ACB_OBJETO","X3_DECIMAL"),GetSx3Cache("ACB_OBJETO","X3_TITULO"),GetSx3Cache("ACB_OBJETO","X3_PICTURE")})
aAdd(aFields3, {"T3_DESCRI",GetSx3Cache("ACB_DESCRI","X3_TIPO"),GetSx3Cache("ACB_DESCRI","X3_TAMANHO"),GetSx3Cache("ACB_DESCRI","X3_DECIMAL"),GetSx3Cache("ACB_DESCRI","X3_TITULO"),GetSx3Cache("ACB_DESCRI","X3_PICTURE")})
aAdd(aFields3, {"T3_RECNO","N",8,0,"Recno WT",""})

oTabTMP3:SetFields(aFields3)
oTabTMP3:Create()

aAdd(aFields4, {"T4_FILENT",GetSx3Cache("AC9_FILENT","X3_TIPO"),GetSx3Cache("AC9_FILENT","X3_TAMANHO"),GetSx3Cache("AC9_FILENT","X3_DECIMAL"),GetSx3Cache("AC9_FILENT","X3_TITULO"),GetSx3Cache("AC9_FILENT","X3_PICTURE")})
aAdd(aFields4, {"T4_ENTIDA",GetSx3Cache("AC9_ENTIDA","X3_TIPO"),GetSx3Cache("AC9_ENTIDA","X3_TAMANHO"),GetSx3Cache("AC9_ENTIDA","X3_DECIMAL"),GetSx3Cache("AC9_ENTIDA","X3_TITULO"),GetSx3Cache("AC9_ENTIDA","X3_PICTURE")})
aAdd(aFields4, {"T4_CODENT",GetSx3Cache("AC9_CODENT","X3_TIPO"),GetSx3Cache("AC9_CODENT","X3_TAMANHO"),GetSx3Cache("AC9_CODENT","X3_DECIMAL"),GetSx3Cache("AC9_CODENT","X3_TITULO"),GetSx3Cache("AC9_CODENT","X3_PICTURE")})
aAdd(aFields4, {"T4_CODOBJ",GetSx3Cache("AC9_CODOBJ","X3_TIPO"),GetSx3Cache("AC9_CODOBJ","X3_TAMANHO"),GetSx3Cache("AC9_CODOBJ","X3_DECIMAL"),GetSx3Cache("AC9_CODOBJ","X3_TITULO"),GetSx3Cache("AC9_CODOBJ","X3_PICTURE")})
aAdd(aFields4, {"T4_OBJETO",GetSx3Cache("ACB_OBJETO","X3_TIPO"),GetSx3Cache("ACB_OBJETO","X3_TAMANHO"),GetSx3Cache("ACB_OBJETO","X3_DECIMAL"),GetSx3Cache("ACB_OBJETO","X3_TITULO"),GetSx3Cache("ACB_OBJETO","X3_PICTURE")})
aAdd(aFields4, {"T4_DESCRI",GetSx3Cache("ACB_DESCRI","X3_TIPO"),GetSx3Cache("ACB_DESCRI","X3_TAMANHO"),GetSx3Cache("ACB_DESCRI","X3_DECIMAL"),GetSx3Cache("ACB_DESCRI","X3_TITULO"),GetSx3Cache("ACB_DESCRI","X3_PICTURE")})
aAdd(aFields4, {"T4_RECNO","N",8,0,"Recno WT",""})

oTabTMP4:SetFields(aFields4)
oTabTMP4:Create()

aAdd(aFields5, {"T5_FILENT",GetSx3Cache("AC9_FILENT","X3_TIPO"),GetSx3Cache("AC9_FILENT","X3_TAMANHO"),GetSx3Cache("AC9_FILENT","X3_DECIMAL"),GetSx3Cache("AC9_FILENT","X3_TITULO"),GetSx3Cache("AC9_FILENT","X3_PICTURE")})
aAdd(aFields5, {"T5_ENTIDA",GetSx3Cache("AC9_ENTIDA","X3_TIPO"),GetSx3Cache("AC9_ENTIDA","X3_TAMANHO"),GetSx3Cache("AC9_ENTIDA","X3_DECIMAL"),GetSx3Cache("AC9_ENTIDA","X3_TITULO"),GetSx3Cache("AC9_ENTIDA","X3_PICTURE")})
aAdd(aFields5, {"T5_CODENT",GetSx3Cache("AC9_CODENT","X3_TIPO"),GetSx3Cache("AC9_CODENT","X3_TAMANHO"),GetSx3Cache("AC9_CODENT","X3_DECIMAL"),GetSx3Cache("AC9_CODENT","X3_TITULO"),GetSx3Cache("AC9_CODENT","X3_PICTURE")})
aAdd(aFields5, {"T5_CODOBJ",GetSx3Cache("AC9_CODOBJ","X3_TIPO"),GetSx3Cache("AC9_CODOBJ","X3_TAMANHO"),GetSx3Cache("AC9_CODOBJ","X3_DECIMAL"),GetSx3Cache("AC9_CODOBJ","X3_TITULO"),GetSx3Cache("AC9_CODOBJ","X3_PICTURE")})
aAdd(aFields5, {"T5_OBJETO",GetSx3Cache("ACB_OBJETO","X3_TIPO"),GetSx3Cache("ACB_OBJETO","X3_TAMANHO"),GetSx3Cache("ACB_OBJETO","X3_DECIMAL"),GetSx3Cache("ACB_OBJETO","X3_TITULO"),GetSx3Cache("ACB_OBJETO","X3_PICTURE")})
aAdd(aFields5, {"T5_DESCRI",GetSx3Cache("ACB_DESCRI","X3_TIPO"),GetSx3Cache("ACB_DESCRI","X3_TAMANHO"),GetSx3Cache("ACB_DESCRI","X3_DECIMAL"),GetSx3Cache("ACB_DESCRI","X3_TITULO"),GetSx3Cache("ACB_DESCRI","X3_PICTURE")})
aAdd(aFields5, {"T5_RECNO","N",8,0,"Recno WT",""})

oTabTMP5:SetFields(aFields5)
oTabTMP5:Create()

aAdd(aFields6, {"T6_FILENT",GetSx3Cache("AC9_FILENT","X3_TIPO"),GetSx3Cache("AC9_FILENT","X3_TAMANHO"),GetSx3Cache("AC9_FILENT","X3_DECIMAL"),GetSx3Cache("AC9_FILENT","X3_TITULO"),GetSx3Cache("AC9_FILENT","X3_PICTURE")})
aAdd(aFields6, {"T6_ENTIDA",GetSx3Cache("AC9_ENTIDA","X3_TIPO"),GetSx3Cache("AC9_ENTIDA","X3_TAMANHO"),GetSx3Cache("AC9_ENTIDA","X3_DECIMAL"),GetSx3Cache("AC9_ENTIDA","X3_TITULO"),GetSx3Cache("AC9_ENTIDA","X3_PICTURE")})
aAdd(aFields6, {"T6_CODENT",GetSx3Cache("AC9_CODENT","X3_TIPO"),GetSx3Cache("AC9_CODENT","X3_TAMANHO"),GetSx3Cache("AC9_CODENT","X3_DECIMAL"),GetSx3Cache("AC9_CODENT","X3_TITULO"),GetSx3Cache("AC9_CODENT","X3_PICTURE")})
aAdd(aFields6, {"T6_CODOBJ",GetSx3Cache("AC9_CODOBJ","X3_TIPO"),GetSx3Cache("AC9_CODOBJ","X3_TAMANHO"),GetSx3Cache("AC9_CODOBJ","X3_DECIMAL"),GetSx3Cache("AC9_CODOBJ","X3_TITULO"),GetSx3Cache("AC9_CODOBJ","X3_PICTURE")})
aAdd(aFields6, {"T6_OBJETO",GetSx3Cache("ACB_OBJETO","X3_TIPO"),GetSx3Cache("ACB_OBJETO","X3_TAMANHO"),GetSx3Cache("ACB_OBJETO","X3_DECIMAL"),GetSx3Cache("ACB_OBJETO","X3_TITULO"),GetSx3Cache("ACB_OBJETO","X3_PICTURE")})
aAdd(aFields6, {"T6_DESCRI",GetSx3Cache("ACB_DESCRI","X3_TIPO"),GetSx3Cache("ACB_DESCRI","X3_TAMANHO"),GetSx3Cache("ACB_DESCRI","X3_DECIMAL"),GetSx3Cache("ACB_DESCRI","X3_TITULO"),GetSx3Cache("ACB_DESCRI","X3_PICTURE")})
aAdd(aFields6, {"T6_RECNO","N",8,0,"Recno WT",""})

oTabTMP6:SetFields(aFields6)
oTabTMP6:Create()

FWExecView("_","XBCON",MODEL_OPERATION_UPDATE,,{|| .T.},,,aButtons)

oTabTMP1:Delete()
oTabTMP2:Delete()
oTabTMP3:Delete()
oTabTMP4:Delete()
oTabTMP5:Delete()
oTabTMP6:Delete()

RestArea(aArea)

Return 

/*---------------------------------------------------------------------*
 | Func:  ModelDef                                                     |
 | Desc:  Criação do modelo de dados MVC                               |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ModelDef()
Local oModel as object
Local oStrTMP1 := fnM01TMP("1")
Local oStrTMP2 := fnM01TMP("2")
Local oStrTMP3 := fnM01TMP("3")
Local oStrTMP4 := fnM01TMP("4")
Local oStrTMP5 := fnM01TMP("5")
Local oStrTMP6 := fnM01TMP("6")
Local bCommit  := {|oModel|fSave(oModel)}

oModel := MPFormModel():New('XBCONM',/*bPre*/,/*bPost*/,bCommit,/*bCancel*/)
oModel:AddFields('TABTMP1',/*cOwner*/,oStrTMP1/*bPre*/,/*bPos*/,/*bLoad*/)
oModel:AddGrid('TABTMP2','TABTMP1',oStrTMP2,/*bLinePre*/,/*bLinePost*/,/*bPre - Grid Inteiro*/,/*bPos - Grid Inteiro*/,/*bLoad - Carga do modelo manualmente*/)
oModel:AddGrid('TABTMP3','TABTMP1',oStrTMP3,/*bLinePre*/,/*bLinePost*/,/*bPre - Grid Inteiro*/,/*bPos - Grid Inteiro*/,/*bLoad - Carga do modelo manualmente*/)
oModel:AddGrid('TABTMP4','TABTMP1',oStrTMP4,/*bLinePre*/,/*bLinePost*/,/*bPre - Grid Inteiro*/,/*bPos - Grid Inteiro*/,/*bLoad - Carga do modelo manualmente*/)
oModel:AddGrid('TABTMP5','TABTMP1',oStrTMP5,/*bLinePre*/,/*bLinePost*/,/*bPre - Grid Inteiro*/,/*bPos - Grid Inteiro*/,/*bLoad - Carga do modelo manualmente*/)
oModel:AddGrid('TABTMP6','TABTMP1',oStrTMP6,/*bLinePre*/,/*bLinePost*/,/*bPre - Grid Inteiro*/,/*bPos - Grid Inteiro*/,/*bLoad - Carga do modelo manualmente*/)
oModel:SetPrimaryKey({})

oModel:SetDescription("Banco de Conhecimeto - Generico")

oModel:GetModel('TABTMP2'):SetOptional(.T.)
oModel:GetModel('TABTMP3'):SetOptional(.T.)
oModel:GetModel('TABTMP4'):SetOptional(.T.)
oModel:GetModel('TABTMP5'):SetOptional(.T.)
oModel:GetModel('TABTMP6'):SetOptional(.T.)

Return oModel

//-----------------------------------------
/*/ fnM01TMP
  Estrutura (Model)							  
/*/
//-----------------------------------------
Static Function fnM01TMP(cTab)
Local oStruct := FWFormModelStruct():New()
Local cField := "aFields"+cTab
Local nId  

oStruct:AddTable("TMP"+cTab,{},"Tabela "+cTab)

For nId := 1 To Len(&(cField))
    oStruct:AddField(&(cField)[nId][5]; 
                    ,&(cField)[nId][5]; 
                    ,&(cField)[nId][1]; 
                    ,&(cField)[nId][2];
                    ,&(cField)[nId][3];
                    ,&(cField)[nId][4];
                    ,Nil,Nil,{},.F.,,.F.,.F.,.F.)
Next nId

Return oStruct

/*---------------------------------------------------------------------*
 | Func:  ViewDef                                                      |
 | Desc:  Criação da visão MVC                                         |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
 
Static Function ViewDef()
Local oView as object
Local oModel as object
Local oStrTMP1 := fnV01TMP("1")
Local oStrTMP2 := fnV01TMP("2")
Local oStrTMP3 := fnV01TMP("3")
Local oStrTMP4 := fnV01TMP("4")
Local oStrTMP5 := fnV01TMP("5")
Local oStrTMP6 := fnV01TMP("6")

oModel := FWLoadModel("XBCON")

oView := FwFormView():New()
oView:SetModel(oModel)
oView:SetProgressBar(.T.)
oView:AddField("VIEW_TABTMP1", oStrTMP1 , "TABTMP1")
oView:AddGrid("VIEW_TABTMP2" , oStrTMP2 , "TABTMP2")
oView:AddGrid("VIEW_TABTMP3" , oStrTMP3 , "TABTMP3")
oView:AddGrid("VIEW_TABTMP4" , oStrTMP4 , "TABTMP4")
oView:AddGrid("VIEW_TABTMP5" , oStrTMP5 , "TABTMP5")
oView:AddGrid("VIEW_TABTMP6" , oStrTMP6 , "TABTMP6")

oView:CreateHorizontalBox("BOX_SUPERIOR", 10 )
oView:CreateHorizontalBox("BOX_INFERIOR", 90 )

oView:CreateFolder('1FOLDER','BOX_INFERIOR')

oView:AddSheet('1FOLDER', '1SHEET', 'Solicitação de Compras')
oView:AddSheet('1FOLDER', '2SHEET', 'Pedido de Compras')
oView:AddSheet('1FOLDER', '3SHEET', 'Documento de Entrada')
oView:AddSheet('1FOLDER', '4SHEET', 'Título a Pagar')
oView:AddSheet('1FOLDER', '5SHEET', 'Nota Fiscal Manual de Entrada')

oView:CreateHorizontalBox("BOX_1INF", 100, /*cIdOwner*/, /*lUsePixel*/, '1FOLDER', '1SHEET')
oView:CreateHorizontalBox("BOX_2INF", 100, /*cIdOwner*/, /*lUsePixel*/, '1FOLDER', '2SHEET')
oView:CreateHorizontalBox("BOX_3INF", 100, /*cIdOwner*/, /*lUsePixel*/, '1FOLDER', '3SHEET')
oView:CreateHorizontalBox("BOX_4INF", 100, /*cIdOwner*/, /*lUsePixel*/, '1FOLDER', '4SHEET')
oView:CreateHorizontalBox("BOX_5INF", 100, /*cIdOwner*/, /*lUsePixel*/, '1FOLDER', '5SHEET')


//BOX_SUPERIOR
oView:setOwnerView("VIEW_TABTMP1" , "BOX_SUPERIOR")

//BOX_INFERIOR
oView:setOwnerView("VIEW_TABTMP2" , "BOX_1INF")
oView:setOwnerView("VIEW_TABTMP3" , "BOX_2INF")
oView:setOwnerView("VIEW_TABTMP4" , "BOX_3INF")
oView:setOwnerView("VIEW_TABTMP5" , "BOX_4INF")
oView:setOwnerView("VIEW_TABTMP6" , "BOX_5INF")

oView:SetAfterViewActivate({|oView| ViewActv(oView)})

oView:AddUserButton( 'Importar', 'MAGIC_BMP',;
                        {|| fnImportArq(oView)},;
                         /*cToolTip  | Comentário do botão*/,;
                         /*nShortCut | Codigo da Tecla para criação de Tecla de Atalho*/,;
                         /*aOptions  | */,;
                         /*lShowBar */ .T.)

oView:AddUserButton( 'Abrir', 'MAGIC_BMP',;
                        {|| fnOpenArq(oView)},;
                         /*cToolTip  | Comentário do botão*/,;
                         /*nShortCut | Codigo da Tecla para criação de Tecla de Atalho*/,;
                         /*aOptions  | */,;
                         /*lShowBar */ .T.)

oView:SetCloseOnOk({||.T.})

Return oView

//-------------------------------------------------------------------
/*/ Função fnV01TMP()
  Estrutura (View)	
/*/
//-------------------------------------------------------------------
Static Function fnV01TMP(cTab)
Local oViewTMP := FWFormViewStruct():New() 
Local cField := "aFields"+cTab
Local nId

For nId := 1 To Len(&(cField))
    oViewTMP:AddField(&(cField)[nId][1],;     // 01 = Nome do Campo
                      StrZero(nId,2),;        // 02 = Ordem
                      &(cField)[nId][5],;     // 03 = Título do campo
                      &(cField)[nId][5],;     // 04 = Descrição do campo
                      Nil,;                   // 05 = Array com Help
                      &(cField)[nId][2],;     // 06 = Tipo do campo
                      &(cField)[nId][6],;     // 07 = Picture
                      Nil,;                   // 08 = Bloco de PictTre Var
                      Nil,;                   // 09 = Consulta F3
                      .F.,;                   // 10 = Indica se o campo é alterável
                      Nil,;                   // 11 = Pasta do Campo
                      Nil,;                   // 12 = Agrupamnento do campo
                      Nil,;                   // 13 = Lista de valores permitido do campo (Combo)
                      Nil,;                   // 14 = Tamanho máximo da opção do combo
                      Nil,;                   // 15 = Inicializador de Browse
                      .F.,;                   // 16 = Indica se o campo é virtual (.T. ou .F.)
                      Nil,;                   // 17 = Picture Variavel
                      Nil)                    // 18 = Indica pulo de linha após o campo (.T. ou .F.)
Next nId

Return oViewTMP

/*---------------------------------------------------------------------*
 | Func:  ViewActv                                                     |
 | Desc:  Carrega os arquivos nos Grids da tabela correspondente       |
 | Obs.:  /                                                            |
 *---------------------------------------------------------------------*/
Static Function ViewActv(oView)
  Local aArea := FWGetArea()
  Local oModel := FWModelActive() 
  Local oModelTMP1 := oModel:GetModel("TABTMP1")
  Local oModelTMP2 := oModel:GetModel("TABTMP2")
  Local oModelTMP3 := oModel:GetModel("TABTMP3")
  Local oModelTMP4 := oModel:GetModel("TABTMP4")
  Local oModelTMP5 := oModel:GetModel("TABTMP5")
  Local oModelTMP6 := oModel:GetModel("TABTMP6")
  Local nY

  Private aRegSC1 := {}
  Private aRegSC7 := {}
  Private aRegSF1 := {}
  Private aRegSE2 := {}

    Do Case 
      Case Alltrim(FunName()) == "MATA110"
          oModelTMP1:LoadValue("T1_CODSOL" , Posicione("SC1",1,SC1->C1_FILIAL+SC1->C1_NUM,"C1_USER") )
          oModelTMP1:LoadValue("T1_NOMSOL" , FwGetUserName(FWFldGet("T1_CODSOL")) )
          PesqMATA110()
      Case Alltrim(FunName()) == "MATA121"
          PesqMATA121()
      Case Alltrim(FunName()) $ ("MATA140/MATA103/MATA910")
          PesqMATA103()
      Case Alltrim(FunName()) $ ("FINA050/FINA750")
          PesqFINA050()
    End Case 

    IF !Empty(aRegSC1)
      
      IF (Empty(FWFldGet("T1_CODSOL")) .AND. Empty(FWFldGet("T1_NOMSOL")))
        oModelTMP1:LoadValue("T1_CODSOL" , Posicione("SC1",1,aRegSC1[1,3],"C1_USER") )
        oModelTMP1:LoadValue("T1_NOMSOL" , FwGetUserName(FWFldGet("T1_CODSOL")) )
      EndIF 
      
      For nY := 1 To Len(aRegSC1)
        If nY > 1
            oModelTMP2:AddLine()
        EndIF
        oModelTMP2:LoadValue("T2_FILENT" , aRegSC1[nY,1])
        oModelTMP2:LoadValue("T2_ENTIDA" , aRegSC1[nY,2])
        oModelTMP2:LoadValue("T2_CODENT" , aRegSC1[nY,3])
        oModelTMP2:LoadValue("T2_CODOBJ" , aRegSC1[nY,4])
        oModelTMP2:LoadValue("T2_OBJETO" , aRegSC1[nY,5])
        oModelTMP2:LoadValue("T2_DESCRI" , aRegSC1[nY,6])
        oModelTMP2:LoadValue("T2_RECNO"  , aRegSC1[nY,7])
        oView:Refresh("VIEW_TABTMP2")
      Next nY 
    EndIF 

    IF !Empty(aRegSC7)
      For nY := 1 To Len(aRegSC7)
        If nY > 1
            oModelTMP3:AddLine()
        EndIF
        oModelTMP3:LoadValue("T3_FILENT" , aRegSC7[nY,1])
        oModelTMP3:LoadValue("T3_ENTIDA" , aRegSC7[nY,2])
        oModelTMP3:LoadValue("T3_CODENT" , aRegSC7[nY,3])
        oModelTMP3:LoadValue("T3_CODOBJ" , aRegSC7[nY,4])
        oModelTMP3:LoadValue("T3_OBJETO" , aRegSC7[nY,5])
        oModelTMP3:LoadValue("T3_DESCRI" , aRegSC7[nY,6])
        oModelTMP3:LoadValue("T3_RECNO"  , aRegSC7[nY,7])
        oView:Refresh("VIEW_TABTMP3")
      Next nY
    EndIF

    IF !Empty(aRegSF1)
      For nY := 1 To Len(aRegSF1)
        If nY > 1
            oModelTMP4:AddLine()
            oModelTMP6:AddLine()
        EndIF
        oModelTMP4:LoadValue("T4_FILENT" , aRegSF1[nY,1])
        oModelTMP4:LoadValue("T4_ENTIDA" , aRegSF1[nY,2])
        oModelTMP4:LoadValue("T4_CODENT" , aRegSF1[nY,3])
        oModelTMP4:LoadValue("T4_CODOBJ" , aRegSF1[nY,4])
        oModelTMP4:LoadValue("T4_OBJETO" , aRegSF1[nY,5])
        oModelTMP4:LoadValue("T4_DESCRI" , aRegSF1[nY,6])
        oModelTMP4:LoadValue("T4_RECNO"  , aRegSF1[nY,7])
        oView:Refresh("VIEW_TABTMP4")
          
        oModelTMP6:LoadValue("T6_FILENT" , aRegSF1[nY,1])
        oModelTMP6:LoadValue("T6_ENTIDA" , aRegSF1[nY,2])
        oModelTMP6:LoadValue("T6_CODENT" , aRegSF1[nY,3])
        oModelTMP6:LoadValue("T6_CODOBJ" , aRegSF1[nY,4])
        oModelTMP6:LoadValue("T6_OBJETO" , aRegSF1[nY,5])
        oModelTMP6:LoadValue("T6_DESCRI" , aRegSF1[nY,6])
        oModelTMP6:LoadValue("T6_RECNO"  , aRegSF1[nY,7])
        oView:Refresh("VIEW_TABTMP6")
      Next nY
    EndIF

    IF !Empty(aRegSE2)
      For nY := 1 To Len(aRegSE2)
        If nY > 1
            oModelTMP5:AddLine()
        EndIF
        oModelTMP5:LoadValue("T5_FILENT" , aRegSE2[nY,1])
        oModelTMP5:LoadValue("T5_ENTIDA" , aRegSE2[nY,2])
        oModelTMP5:LoadValue("T5_CODENT" , aRegSE2[nY,3])
        oModelTMP5:LoadValue("T5_CODOBJ" , aRegSE2[nY,4])
        oModelTMP5:LoadValue("T5_OBJETO" , aRegSE2[nY,5])
        oModelTMP5:LoadValue("T5_DESCRI" , aRegSE2[nY,6])
        oModelTMP5:LoadValue("T5_RECNO"  , aRegSE2[nY,7])
        oView:Refresh("VIEW_TABTMP5")
      Next nY
    EndIF

  oModelTMP2:GoLine(1)
  oModelTMP3:GoLine(1)
  oModelTMP4:GoLine(1)
  oModelTMP5:GoLine(1)
  oModelTMP6:GoLine(1)
  oView:Refresh()

  FWRestArea(aArea)
Return

/*------------------------------------------------------------------*
 | Func:  PesqMATA110                                               |
 | Desc:  Pesquisa os documentos pela Solicitação de Compras        |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/

Static Function PesqMATA110()
  Local cQry := ""
  Local _cAlias := GetNextAlias()
  Local _cAliasAC9 := "TMPAC9"+STrTran(Time(),":","")
  Local cDoc := ""
  Local cSerie := ""
  Local cFornece := ""
  Local cLoja := ""

  cQry := " SELECT DISTINCT SC1.C1_NUM "
  cQry += " FROM " + RetSqlName('SC1') + " SC1 "
  cQry += " WHERE "
  cQry += "       SC1.D_E_L_E_T_ <> '*' "
  cQry += "   AND SC1.C1_FILIAL =  '" + xFilial('SC1') + "' "
  cQry += "   AND SC1.C1_NUM    =  '" + cCampo1 + "' "
  
  cQry := ChangeQuery(cQry)
  dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

  While ! (_cAlias)->(Eof())

      cQry := " SELECT * "
      cQry += " FROM " + RetSqlName('AC9') + " AC9 "
      cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
      cQry += " WHERE "
      cQry += "       AC9.D_E_L_E_T_ <> '*' "
      cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
      cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC1") + "' "
      cQry += "   AND AC9.AC9_ENTIDA  =  'SC1' "
      cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC1")+(_cAlias)->C1_NUM+"%')"
      cQry := ChangeQuery(cQry)
      dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

      While ! (_cAliasAC9)->(Eof())          
          aAdd(aRegSC1,{(_cAliasAC9)->(AC9_FILENT),;
                        (_cAliasAC9)->(AC9_ENTIDA),;
                        (_cAliasAC9)->(AC9_CODENT),;
                        (_cAliasAC9)->(AC9_CODOBJ),;
                        (_cAliasAC9)->(ACB_OBJETO),;
                        (_cAliasAC9)->(ACB_DESCRI),;
                        (_cAliasAC9)->(R_E_C_N_O_)})
        (_cAliasAC9)->(dbSkip())
      EndDo
    
    (_cAliasAC9)->(dbCloseArea())
    (_cAlias)->(dbSkip())
  EndDo 

  (_cAlias)->(dbCloseArea())

  cQry := " SELECT DISTINCT SC7.C7_NUM "
  cQry += " FROM " + RetSqlName('SC7') + " SC7 "
  cQry += " WHERE "
  cQry += "       SC7.D_E_L_E_T_ <> '*' "
  cQry += "   AND SC7.C7_FILIAL =  '" + xFilial('SC7') + "' "
  cQry += "   AND SC7.C7_NUMSC  =  '" + cCampo1 + "' "
  
  cQry := ChangeQuery(cQry)
  dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

  While ! (_cAlias)->(Eof())

      cDoc := (_cAlias)->C7_NUM

      cQry := " SELECT * "
      cQry += " FROM " + RetSqlName('AC9') + " AC9 "
      cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
      cQry += " WHERE "
      cQry += "       AC9.D_E_L_E_T_ <> '*' "
      cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
      cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC7") + "' "
      cQry += "   AND AC9.AC9_ENTIDA  =  'SC7' "
      cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC7")+cDoc+"%')"
      cQry := ChangeQuery(cQry)
      dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

      While ! (_cAliasAC9)->(Eof())          
          aAdd(aRegSC7,{(_cAliasAC9)->(AC9_FILENT),;
                        (_cAliasAC9)->(AC9_ENTIDA),;
                        (_cAliasAC9)->(AC9_CODENT),;
                        (_cAliasAC9)->(AC9_CODOBJ),;
                        (_cAliasAC9)->(ACB_OBJETO),;
                        (_cAliasAC9)->(ACB_DESCRI),;
                        (_cAliasAC9)->(R_E_C_N_O_)})
        (_cAliasAC9)->(dbSkip())
      EndDo
    
    (_cAliasAC9)->(dbCloseArea())
    (_cAlias)->(dbSkip())
  EndDo 

  (_cAlias)->(dbCloseArea())

  If !Empty(cDoc)
    cQry := " SELECT DISTINCT D1_DOC, D1_SERIE, D1_FORNECE, D1_LOJA "
    cQry += " FROM " + RetSqlName('SD1') + " SD1 "
    cQry += " WHERE "
    cQry += "       SD1.D_E_L_E_T_ <> '*' "
    cQry += "   AND SD1.D1_FILIAL =  '" + xFilial('SD1') + "' "
    cQry += "   AND SD1.D1_PEDIDO =  '" + cDoc + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->D1_DOC
        cSerie := (_cAlias)->D1_SERIE
        cFornece := (_cAlias)->D1_FORNECE
        cLoja := (_cAlias)->D1_LOJA

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SF1") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SF1' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cDoc+cSerie+cFornece+cLoja+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())
            aAdd(aRegSF1,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF    
  
  If !Empty(cDoc) .AND. !Empty(cFornece) .AND. !Empty(cLoja)
    
    cQry := " SELECT DISTINCT E2_PREFIXO, E2_NUM, E2_TIPO, E2_FORNECE, E2_LOJA "
    cQry += " FROM " + RetSqlName('SE2') + " SE2 "
    cQry += " WHERE "
    cQry += "       SE2.D_E_L_E_T_ <> '*' "
    cQry += "   AND SE2.E2_FILIAL  =  '" + xFilial('SE2') + "' "
    cQry += "   AND SE2.E2_PREFIXO =  '" + cSerie + "' "
    cQry += "   AND SE2.E2_NUM     =  '" + cDoc + "' "
    cQry += "   AND SE2.E2_FORNECE =  '" + cFornece + "' "
    cQry += "   AND SE2.E2_LOJA    =  '" + cLoja + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->E2_NUM
        cSerie := (_cAlias)->E2_PREFIXO
        cFornece := (_cAlias)->E2_FORNECE
        cLoja := (_cAlias)->E2_LOJA

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SE2") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SE2' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cSerie+cDoc+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())
            If Alltrim(cFornece+cLoja) == Alltrim(SubStr((_cAliasAC9)->(AC9_CODENT), 18))
            aAdd(aRegSE2,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
            EndIF 
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF

Return

/*------------------------------------------------------------------*
 | Func:  PesqMATA121                                               |
 | Desc:  Pesquisa os documentos pelo Pedido de Compra              |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/

Static Function PesqMATA121()
  Local cQry := ""
  Local _cAlias := GetNextAlias()
  Local _cAliasAC9 := "TMPAC9"+STrTran(Time(),":","")
  Local cDoc := ""
  Local cSerie := ""
  Local cFornece := ""
  Local cLoja := ""

  cQry := " SELECT DISTINCT SC1.C1_NUM "
  cQry += " FROM " + RetSqlName('SC1') + " SC1 "
  cQry += " WHERE "
  cQry += "       SC1.D_E_L_E_T_ <> '*' "
  cQry += "   AND SC1.C1_FILIAL =  '" + xFilial('SC1') + "' "
  cQry += "   AND SC1.C1_PEDIDO =  '" + cCampo1 + "' "
  
  cQry := ChangeQuery(cQry)
  dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

  While ! (_cAlias)->(Eof())

      cQry := " SELECT * "
      cQry += " FROM " + RetSqlName('AC9') + " AC9 "
      cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
      cQry += " WHERE "
      cQry += "       AC9.D_E_L_E_T_ <> '*' "
      cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
      cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC1") + "' "
      cQry += "   AND AC9.AC9_ENTIDA  =  'SC1' "
      cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC1")+(_cAlias)->C1_NUM+"%')"
      cQry := ChangeQuery(cQry)
      dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

      While ! (_cAliasAC9)->(Eof())          
          aAdd(aRegSC1,{(_cAliasAC9)->(AC9_FILENT),;
                        (_cAliasAC9)->(AC9_ENTIDA),;
                        (_cAliasAC9)->(AC9_CODENT),;
                        (_cAliasAC9)->(AC9_CODOBJ),;
                        (_cAliasAC9)->(ACB_OBJETO),;
                        (_cAliasAC9)->(ACB_DESCRI),;
                        (_cAliasAC9)->(R_E_C_N_O_)})
        (_cAliasAC9)->(dbSkip())
      EndDo
    
    (_cAliasAC9)->(dbCloseArea())
    (_cAlias)->(dbSkip())
  EndDo 

  (_cAlias)->(dbCloseArea())

  cQry := " SELECT DISTINCT SC7.C7_NUM "
  cQry += " FROM " + RetSqlName('SC7') + " SC7 "
  cQry += " WHERE "
  cQry += "       SC7.D_E_L_E_T_ <> '*' "
  cQry += "   AND SC7.C7_FILIAL =  '" + xFilial('SC7') + "' "
  cQry += "   AND SC7.C7_NUM    =  '" + cCampo1 + "' "
  
  cQry := ChangeQuery(cQry)
  dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

  While ! (_cAlias)->(Eof())

      cDoc := (_cAlias)->C7_NUM

      cQry := " SELECT * "
      cQry += " FROM " + RetSqlName('AC9') + " AC9 "
      cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
      cQry += " WHERE "
      cQry += "       AC9.D_E_L_E_T_ <> '*' "
      cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
      cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC7") + "' "
      cQry += "   AND AC9.AC9_ENTIDA  =  'SC7' "
      cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC7")+cDoc+"%')"
      cQry := ChangeQuery(cQry)
      dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

      While ! (_cAliasAC9)->(Eof())          
          aAdd(aRegSC7,{(_cAliasAC9)->(AC9_FILENT),;
                        (_cAliasAC9)->(AC9_ENTIDA),;
                        (_cAliasAC9)->(AC9_CODENT),;
                        (_cAliasAC9)->(AC9_CODOBJ),;
                        (_cAliasAC9)->(ACB_OBJETO),;
                        (_cAliasAC9)->(ACB_DESCRI),;
                        (_cAliasAC9)->(R_E_C_N_O_)})
        (_cAliasAC9)->(dbSkip())
      EndDo
    
    (_cAliasAC9)->(dbCloseArea())
    (_cAlias)->(dbSkip())
  EndDo 

  (_cAlias)->(dbCloseArea())

  If !Empty(cDoc)
    cQry := " SELECT DISTINCT D1_DOC, D1_SERIE, D1_FORNECE, D1_LOJA "
    cQry += " FROM " + RetSqlName('SD1') + " SD1 "
    cQry += " WHERE "
    cQry += "       SD1.D_E_L_E_T_ <> '*' "
    cQry += "   AND SD1.D1_FILIAL =  '" + xFilial('SD1') + "' "
    cQry += "   AND SD1.D1_PEDIDO =  '" + cDoc + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->D1_DOC
        cSerie := (_cAlias)->D1_SERIE
        cFornece := (_cAlias)->D1_FORNECE
        cLoja := (_cAlias)->D1_LOJA

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SF1") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SF1' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cDoc+cSerie+cFornece+cLoja+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())
            aAdd(aRegSF1,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF    
  
  If !Empty(cDoc) .AND. !Empty(cFornece) .AND. !Empty(cLoja)
    
    cQry := " SELECT DISTINCT E2_PREFIXO, E2_NUM, E2_TIPO, E2_FORNECE, E2_LOJA "
    cQry += " FROM " + RetSqlName('SE2') + " SE2 "
    cQry += " WHERE "
    cQry += "       SE2.D_E_L_E_T_ <> '*' "
    cQry += "   AND SE2.E2_FILIAL  =  '" + xFilial('SE2') + "' "
    cQry += "   AND SE2.E2_PREFIXO =  '" + cSerie + "' "
    cQry += "   AND SE2.E2_NUM     =  '" + cDoc + "' "
    cQry += "   AND SE2.E2_FORNECE =  '" + cFornece + "' "
    cQry += "   AND SE2.E2_LOJA    =  '" + cLoja + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->E2_NUM
        cSerie := (_cAlias)->E2_PREFIXO
        cFornece := (_cAlias)->E2_FORNECE
        cLoja := (_cAlias)->E2_LOJA

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SE2") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SE2' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cSerie+cDoc+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())
            If Alltrim(cFornece+cLoja) == Alltrim(SubStr((_cAliasAC9)->(AC9_CODENT), 18))
            aAdd(aRegSE2,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
            EndIF 
          (_cAliasAC9)->(dbSkip())
        EndDo
        (_cAliasAC9)->(dbCloseArea())
      
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF

Return

/*------------------------------------------------------------------*
 | Func:  PesqMATA103                                               |
 | Desc:  Pesquisa os documentos através do Documento de Entrada    |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/

Static Function PesqMATA103()
  Local cQry := ""
  Local _cAlias := GetNextAlias()
  Local _cAliasAC9 := "TMPAC9"+STrTran(Time(),":","")
  Local cPedido := ""
  Local cDoc := ""
  Local cSerie := ""
  Local cFornece := ""
  Local cLoja := ""

  cQry := " SELECT DISTINCT D1_DOC, D1_SERIE, D1_FORNECE, D1_LOJA, D1_PEDIDO "
  cQry += " FROM " + RetSqlName('SD1') + " SD1 "
  cQry += " WHERE "
  cQry += "       SD1.D_E_L_E_T_ <> '*' "
  cQry += "   AND SD1.D1_FILIAL =  '" + xFilial('SD1') + "' "
  cQry += "   AND SD1.D1_DOC     =  '" + cCampo1 + "' "
  cQry += "   AND SD1.D1_SERIE   =  '" + cCampo2 + "' "
  cQry += "   AND SD1.D1_FORNECE =  '" + cCampo3 + "' "
  cQry += "   AND SD1.D1_LOJA    =  '" + cCampo4 + "' "
    
  cQry := ChangeQuery(cQry)
  dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

  While ! (_cAlias)->(Eof())

      cDoc := (_cAlias)->D1_DOC
      cSerie := (_cAlias)->D1_SERIE
      cFornece := (_cAlias)->D1_FORNECE
      cLoja := (_cAlias)->D1_LOJA
      cPedido := (_cAlias)->D1_PEDIDO

      cQry := " SELECT * "
      cQry += " FROM " + RetSqlName('AC9') + " AC9 "
      cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
      cQry += " WHERE "
      cQry += "       AC9.D_E_L_E_T_ <> '*' "
      cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
      cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SF1") + "' "
      cQry += "   AND AC9.AC9_ENTIDA  =  'SF1' "
      cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cDoc+cSerie+cFornece+cLoja+"%')"
      cQry := ChangeQuery(cQry)
      dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

      While ! (_cAliasAC9)->(Eof())
          aAdd(aRegSF1,{(_cAliasAC9)->(AC9_FILENT),;
                        (_cAliasAC9)->(AC9_ENTIDA),;
                        (_cAliasAC9)->(AC9_CODENT),;
                        (_cAliasAC9)->(AC9_CODOBJ),;
                        (_cAliasAC9)->(ACB_OBJETO),;
                        (_cAliasAC9)->(ACB_DESCRI),;
                        (_cAliasAC9)->(R_E_C_N_O_)})
        (_cAliasAC9)->(dbSkip())
      EndDo
    
    (_cAliasAC9)->(dbCloseArea())  
    (_cAlias)->(dbSkip())
  EndDo 

  (_cAlias)->(dbCloseArea())
  
  If !Empty(cDoc) .AND. !Empty(cFornece) .AND. !Empty(cLoja)
    
    cQry := " SELECT DISTINCT E2_PREFIXO, E2_NUM, E2_TIPO, E2_FORNECE, E2_LOJA "
    cQry += " FROM " + RetSqlName('SE2') + " SE2 "
    cQry += " WHERE "
    cQry += "       SE2.D_E_L_E_T_ <> '*' "
    cQry += "   AND SE2.E2_FILIAL  =  '" + xFilial('SE2') + "' "
    cQry += "   AND SE2.E2_PREFIXO =  '" + cSerie + "' "
    cQry += "   AND SE2.E2_NUM     =  '" + cDoc + "' "
    cQry += "   AND SE2.E2_FORNECE =  '" + cFornece + "' "
    cQry += "   AND SE2.E2_LOJA    =  '" + cLoja + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->E2_NUM
        cSerie := (_cAlias)->E2_PREFIXO
        cFornece := (_cAlias)->E2_FORNECE
        cLoja := (_cAlias)->E2_LOJA

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SE2") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SE2' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cSerie+cDoc+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())
            If Alltrim(cFornece+cLoja) == Alltrim(SubStr((_cAliasAC9)->(AC9_CODENT), 18))
            aAdd(aRegSE2,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
            EndIF 
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())  
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF
  

  If !Empty(cPedido)

    cQry := " SELECT DISTINCT SC7.C7_NUM "
    cQry += " FROM " + RetSqlName('SC7') + " SC7 "
    cQry += " WHERE "
    cQry += "       SC7.D_E_L_E_T_ <> '*' "
    cQry += "   AND SC7.C7_FILIAL =  '" + xFilial('SC7') + "' "
    cQry += "   AND SC7.C7_NUM    =  '" + cPedido + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->C7_NUM

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC7") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SC7' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC7")+cDoc+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())          
            aAdd(aRegSC7,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())  
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF 

  If !Empty(cDoc)

    cQry := " SELECT DISTINCT SC1.C1_NUM "
    cQry += " FROM " + RetSqlName('SC1') + " SC1 "
    cQry += " WHERE "
    cQry += "       SC1.D_E_L_E_T_ <> '*' "
    cQry += "   AND SC1.C1_FILIAL =  '" + xFilial('SC1') + "' "
    cQry += "   AND SC1.C1_PEDIDO =  '" + cDoc + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC1") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SC1' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC1")+(_cAlias)->C1_NUM+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())          
            aAdd(aRegSC1,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF 

Return

/*------------------------------------------------------------------*
 | Func:  PesqFINA050                                               |
 | Desc:  Pesquisa os documentos através do Título a Pagar          |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/

Static Function PesqFINA050()
  Local cQry := ""
  Local _cAlias := GetNextAlias()
  Local _cAliasAC9 := "TMPAC9"+STrTran(Time(),":","")
  Local cPedido := ""
  Local cDoc := ""
  Local cSerie := ""
  Local cFornece := ""
  Local cLoja := ""  
  
  cQry := " SELECT DISTINCT E2_PREFIXO, E2_NUM, E2_TIPO, E2_FORNECE, E2_LOJA "
  cQry += " FROM " + RetSqlName('SE2') + " SE2 "
  cQry += " WHERE "
  cQry += "       SE2.D_E_L_E_T_ <> '*' "
  cQry += "   AND SE2.E2_FILIAL  =  '" + xFilial('SE2') + "' "
  cQry += "   AND SE2.E2_PREFIXO =  '" + cCampo1 + "' "
  cQry += "   AND SE2.E2_NUM     =  '" + cCampo2 + "' "
  cQry += "   AND SE2.E2_TIPO    =  '" + cCampo4 + "' "
  cQry += "   AND SE2.E2_FORNECE =  '" + cCampo5 + "' "
  cQry += "   AND SE2.E2_LOJA    =  '" + cCampo6 + "' "
    
  cQry := ChangeQuery(cQry)
  dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

  While ! (_cAlias)->(Eof())

      cDoc := (_cAlias)->E2_NUM
      cSerie := (_cAlias)->E2_PREFIXO
      cFornece := (_cAlias)->E2_FORNECE
      cLoja := (_cAlias)->E2_LOJA

      cQry := " SELECT * "
      cQry += " FROM " + RetSqlName('AC9') + " AC9 "
      cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
      cQry += " WHERE "
      cQry += "       AC9.D_E_L_E_T_ <> '*' "
      cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
      cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SE2") + "' "
      cQry += "   AND AC9.AC9_ENTIDA  =  'SE2' "
      cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cSerie+cDoc+"%')"
      cQry := ChangeQuery(cQry)
      dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

      While ! (_cAliasAC9)->(Eof())
          If Alltrim(cFornece+cLoja) == Alltrim(SubStr((_cAliasAC9)->(AC9_CODENT), 18))
          aAdd(aRegSE2,{(_cAliasAC9)->(AC9_FILENT),;
                        (_cAliasAC9)->(AC9_ENTIDA),;
                        (_cAliasAC9)->(AC9_CODENT),;
                        (_cAliasAC9)->(AC9_CODOBJ),;
                        (_cAliasAC9)->(ACB_OBJETO),;
                        (_cAliasAC9)->(ACB_DESCRI),;
                        (_cAliasAC9)->(R_E_C_N_O_)})
          EndIF 
        (_cAliasAC9)->(dbSkip())
      EndDo
    
    (_cAliasAC9)->(dbCloseArea()) 
    (_cAlias)->(dbSkip())
  EndDo 

  (_cAlias)->(dbCloseArea())


  If !Empty(cDoc) .AND. !Empty(cFornece) .AND. !Empty(cLoja)
    
    cQry := " SELECT DISTINCT D1_DOC, D1_SERIE, D1_FORNECE, D1_LOJA, D1_PEDIDO "
    cQry += " FROM " + RetSqlName('SD1') + " SD1 "
    cQry += " WHERE "
    cQry += "       SD1.D_E_L_E_T_ <> '*' "
    cQry += "   AND SD1.D1_FILIAL =  '" + xFilial('SD1') + "' "
    cQry += "   AND SD1.D1_DOC     =  '" + cDoc + "' "
    cQry += "   AND SD1.D1_SERIE   =  '" + cSerie + "' "
    cQry += "   AND SD1.D1_FORNECE =  '" + cFornece + "' "
    cQry += "   AND SD1.D1_LOJA    =  '" + cLoja + "' "
      
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->D1_DOC
        cSerie := (_cAlias)->D1_SERIE
        cFornece := (_cAlias)->D1_FORNECE
        cLoja := (_cAlias)->D1_LOJA
        cPedido := (_cAlias)->D1_PEDIDO

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SF1") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SF1' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+cDoc+cSerie+cFornece+cLoja+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())
            aAdd(aRegSF1,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF
  

  If !Empty(cPedido)

    cQry := " SELECT DISTINCT SC7.C7_NUM "
    cQry += " FROM " + RetSqlName('SC7') + " SC7 "
    cQry += " WHERE "
    cQry += "       SC7.D_E_L_E_T_ <> '*' "
    cQry += "   AND SC7.C7_FILIAL =  '" + xFilial('SC7') + "' "
    cQry += "   AND SC7.C7_NUM    =  '" + cPedido + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cDoc := (_cAlias)->C7_NUM

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC7") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SC7' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC7")+cDoc+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())          
            aAdd(aRegSC7,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF 


  If !Empty(cDoc)

    cQry := " SELECT DISTINCT SC1.C1_NUM "
    cQry += " FROM " + RetSqlName('SC1') + " SC1 "
    cQry += " WHERE "
    cQry += "       SC1.D_E_L_E_T_ <> '*' "
    cQry += "   AND SC1.C1_FILIAL =  '" + xFilial('SC1') + "' "
    cQry += "   AND SC1.C1_PEDIDO =  '" + cDoc + "' "
    
    cQry := ChangeQuery(cQry)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAlias,.F.,.T.)

    While ! (_cAlias)->(Eof())

        cQry := " SELECT * "
        cQry += " FROM " + RetSqlName('AC9') + " AC9 "
        cQry += " INNER JOIN " + RetSqlName('ACB') + " ACB ON ACB.ACB_CODOBJ = AC9.AC9_CODOBJ "
        cQry += " WHERE "
        cQry += "       AC9.D_E_L_E_T_ <> '*' "
        cQry += "   AND ACB.D_E_L_E_T_ <> '*' "
        cQry += "   AND AC9.AC9_FILENT  =  '" + xFilial("SC1") + "' "
        cQry += "   AND AC9.AC9_ENTIDA  =  'SC1' "
        cQry += "   AND AC9.AC9_CODENT LIKE ('%"+xFilial("SC1")+(_cAlias)->C1_NUM+"%')"
        cQry := ChangeQuery(cQry)
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQry),_cAliasAC9,.F.,.T.)

        While ! (_cAliasAC9)->(Eof())          
            aAdd(aRegSC1,{(_cAliasAC9)->(AC9_FILENT),;
                          (_cAliasAC9)->(AC9_ENTIDA),;
                          (_cAliasAC9)->(AC9_CODENT),;
                          (_cAliasAC9)->(AC9_CODOBJ),;
                          (_cAliasAC9)->(ACB_OBJETO),;
                          (_cAliasAC9)->(ACB_DESCRI),;
                          (_cAliasAC9)->(R_E_C_N_O_)})
          (_cAliasAC9)->(dbSkip())
        EndDo
      
      (_cAliasAC9)->(dbCloseArea())
      (_cAlias)->(dbSkip())
    EndDo 

    (_cAlias)->(dbCloseArea())
  EndIF

Return

/*------------------------------------------------------------------*
 | Func:  fnOpenArq                                                 |
 | Desc:  Abre o documento selecionado                              |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/

Static Function fnOpenArq(oView)
Local aArea := FWGetArea()
Local cBarra  := IIF(IsSrvUnix(),"/","\")
Local cDirSer := StrTran(SuperGetMV("MV_DIRDOC")+"co"+cEmpAnt+"\shared\","\",cBarra)
Local cDirLoc := GetTempPath(.T.,.F.)
Local cNomArq := ""
Local cTabPos := SubSTR(oView:AcurrentSelect[1],At("_",oView:AcurrentSelect[1])+1)
Local nRet

    Do Case
      Case cTabPos == "TABTMP2"
        cNomArq := Lower(Alltrim(FWFldGet("T2_OBJETO")))
      Case cTabPos == "TABTMP3"
        cNomArq := Lower(Alltrim(FWFldGet("T3_OBJETO")))
      Case cTabPos == "TABTMP4"
        cNomArq := Lower(Alltrim(FWFldGet("T4_OBJETO")))
      Case cTabPos == "TABTMP5"
        cNomArq := Lower(Alltrim(FWFldGet("T5_OBJETO")))
      Case cTabPos == "TABTMP6"
        cNomArq := Lower(Alltrim(FWFldGet("T6_OBJETO")))
    End Case

    If !CpyS2t(cDirSer+cNomArq, cDirLoc,.T.)
      MsgStop("O arquivo não pode ser copiado! " +cDirSer+cNomArq, "Atenção")
    EndIf  

    nRet := ShellExecute("open", Lower(cNomArq), "", Alltrim(Lower(cDirLoc)), 1)
    
    If nRet <= 32
      MsgStop("Não foi possível abrir o arquivo " +cDirLoc+cNomArq+ "!", "Atenção")
    EndIf 
     
  FWRestArea(aArea)
Return

/*------------------------------------------------------------------*
 | Func:  fnImportArq                                               |
 | Desc:  Importa documento para o banco de conhecimento.           |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/

Static Function fnImportArq(oView)
  Local aArea := FWGetArea()
  Local oModel := FWModelActive() 
  Local oModelTMP2 := oModel:GetModel("TABTMP2")
  Local oModelTMP3 := oModel:GetModel("TABTMP3")
  Local oModelTMP4 := oModel:GetModel("TABTMP4")
  Local oModelTMP5 := oModel:GetModel("TABTMP5")
  Local oModelTMP6 := oModel:GetModel("TABTMP6")
  Local cTabPos := SubSTR(oView:AcurrentSelect[1],At("_",oView:AcurrentSelect[1])+1)
  Local lLinux  := IsSrvUnix()
  Local cBarra  := IIF(IsSrvUnix(),"/","\")
  Local cDirSer := SuperGetMV("MV_DIRDOC")+"\co"+cEmpAnt+"\shared\"
  Local aFile   := {}
  Local cFile   := ""
  Local cNomArq := ""
  Local cSeqACB := ""
  Local nY 

    If lLinux
      cDirSer := STrTran(cDirSer,"\","/")
    EndIf 

    Do Case 
      Case Alltrim(FunName()) == "MATA110"

          If cTabPos == "TABTMP2"
            cFile := TFileDialog("All types (*.*)",'Informe onde será gravado o arquivo.',,,.F.,GETF_MULTISELECT)
            aFile := Separa(Alltrim(cFile),";",.T.)
            If !Empty(aFile)              
              For nY := 1 To Len(aFile)

                If !lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,aFile[nY])+1)))
                ElseIf lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,STrTran(aFile[nY],"\","/"))+1)))
                EndIf
                
                If File(cDirSer+cNomArq)
                  FWAlertHelp('O arquivo '+cNomArq+', já existe no servidor, por este motivo não será importado.',"Altere o nome do arquivo e importe novamente.")
                Else
                  cSeqACB := u_proxIdACB()

                  If oModelTMP2:Length() > 1 .OR. !Empty(oModelTMP2:GetValue("T2_OBJETO"))
                    oModelTMP2:AddLine()
                  EndIF  
                  oModelTMP2:LoadValue("T2_FILENT" , xFilial("SC1"))
                  oModelTMP2:LoadValue("T2_ENTIDA" , "SC1")
                  oModelTMP2:LoadValue("T2_CODENT" , xFilial("SC1")+cCampo1+cCampo2)
                  oModelTMP2:LoadValue("T2_CODOBJ" , cSeqACB )
                  oModelTMP2:LoadValue("T2_OBJETO" , cNomArq)
                  oModelTMP2:LoadValue("T2_DESCRI" , AllTrim(SubSTR(cNomArq,1,FWTamSX3("ACB_DESCRI")[1])))
                  oModelTMP2:LoadValue("T2_RECNO"  , 0)
                  oView:Refresh("VIEW_TABTMP2")
                EndIF
              Next
              oModelTMP2:GoLine(1)
              oView:Refresh("VIEW_TABTMP2")
            EndIF 
          Else
            ApMsgInfo('Importação de arquivo através da rotina Solicitação de Compras deve-se ser realizado exclusivamente na aba "Solicitação de Compras"!',"ATENÇÃO")
          EndIF
      
      Case Alltrim(FunName()) == "MATA121"

          If cTabPos == "TABTMP3"
            cFile := TFileDialog("All types (*.*)",'Informe onde será gravado o arquivo.',,,.F.,GETF_MULTISELECT)
            aFile := Separa(Alltrim(cFile),";",.T.)
            If !Empty(aFile)  
              For nY := 1 To Len(aFile)

                If !lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,aFile[nY])+1)))
                ElseIf lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,STrTran(aFile[nY],"\","/"))+1)))
                EndIf
                
                If File(cDirSer+cNomArq)
                  FWAlertHelp('O arquivo '+cNomArq+', já existe no servidor, por este motivo não será importado.',"Altere o nome do arquivo e importe novamente.")
                Else
                  cSeqACB := u_proxIdACB()

                  If oModelTMP3:Length() > 1 .OR. !Empty(oModelTMP3:GetValue("T3_OBJETO"))
                    oModelTMP3:AddLine()
                  EndIF  
                  oModelTMP3:LoadValue("T3_FILENT" , xFilial("SC7"))
                  oModelTMP3:LoadValue("T3_ENTIDA" , "SC7")
                  oModelTMP3:LoadValue("T3_CODENT" , xFilial("SC7")+cCampo1+cCampo2)
                  oModelTMP3:LoadValue("T3_CODOBJ" , cSeqACB)
                  oModelTMP3:LoadValue("T3_OBJETO" , cNomArq)
                  oModelTMP3:LoadValue("T3_DESCRI" , AllTrim(SubSTR(cNomArq,1,FWTamSX3("ACB_DESCRI")[1])))
                  oModelTMP3:LoadValue("T3_RECNO"  , 0)
                  oView:Refresh("VIEW_TABTMP3")
                EndIF
              Next
              oModelTMP3:GoLine(1)
              oView:Refresh("VIEW_TABTMP3")
            EndIF 
          Else
            ApMsgInfo('Importação de arquivo através da rotina Pedido de Compras deve-se ser realizado exclusivamente na aba "Pedido de Compras"!',"ATENÇÃO")
          EndIF
          
      Case Alltrim(FunName()) $ ("MATA140/MATA103/MATA910")

          If cTabPos == ("TABTMP4")
            cFile := TFileDialog("All types (*.*)",'Informe onde será gravado o arquivo.',,,.F.,GETF_MULTISELECT)
            aFile := Separa(Alltrim(cFile),";",.T.)
            If !Empty(aFile)  
              For nY := 1 To Len(aFile) 

                If !lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,aFile[nY])+1)))
                ElseIf lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,STrTran(aFile[nY],"\","/"))+1)))
                EndIf
                
                If File(cDirSer+cNomArq)
                  FWAlertHelp('O arquivo '+cNomArq+', já existe no servidor, por este motivo não será importado.',"Altere o nome do arquivo e importe novamente.")
                Else
                  cSeqACB := u_proxIdACB()

                  If oModelTMP4:Length() > 1 .OR. !Empty(oModelTMP4:GetValue("T4_OBJETO"))
                    oModelTMP4:AddLine()
                  EndIF  
                  oModelTMP4:LoadValue("T4_FILENT" , xFilial("SF1"))
                  oModelTMP4:LoadValue("T4_ENTIDA" , "SF1")
                  oModelTMP4:LoadValue("T4_CODENT" , cCampo1+cCampo2+cCampo3+cCampo4)
                  oModelTMP4:LoadValue("T4_CODOBJ" , cSeqACB)
                  oModelTMP4:LoadValue("T4_OBJETO" , cNomArq)
                  oModelTMP4:LoadValue("T4_DESCRI" , AllTrim(SubSTR(cNomArq,1,FWTamSX3("ACB_DESCRI")[1])))
                  oModelTMP4:LoadValue("T4_RECNO"  , 0)
                  oView:Refresh("VIEW_TABTMP4")
                EndIF
              Next 
              oModelTMP4:GoLine(1)
              oView:Refresh("VIEW_TABTMP4")
            EndIF 
          Else
            ApMsgInfo('Importação de arquivo através da rotina Nota Fiscal de Entrada deve-se ser realizado exclusivamente na aba "Documento de Entrada"!',"ATENÇÃO")
          EndIF
      
      Case Alltrim(FunName()) $ ("FINA050/FINA750")

          If cTabPos == "TABTMP5"
            cFile := TFileDialog("All types (*.*)",'Informe onde será gravado o arquivo.',,,.F.,GETF_MULTISELECT)
            aFile := Separa(Alltrim(cFile),";",.T.)
            If !Empty(aFile)  
              For nY := 1 To Len(aFile)

                If !lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,aFile[nY])+1)))
                ElseIf lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,STrTran(aFile[nY],"\","/"))+1)))
                EndIf
                
                If File(cDirSer+cNomArq)
                  FWAlertHelp('O arquivo '+cNomArq+', já existe no servidor, por este motivo não será importado.',"Altere o nome do arquivo e importe novamente.")
                Else
                  cSeqACB := u_proxIdACB()
                  
                  If oModelTMP5:Length() > 1 .OR. !Empty(oModelTMP5:GetValue("T5_OBJETO"))
                    oModelTMP5:AddLine()
                  EndIF  
                  oModelTMP5:LoadValue("T5_FILENT" , xFilial("SE2"))
                  oModelTMP5:LoadValue("T5_ENTIDA" , "SE2")
                  oModelTMP5:LoadValue("T5_CODENT" , cCampo1+cCampo2+cCampo3+cCampo4+cCampo5+cCampo6)
                  oModelTMP5:LoadValue("T5_CODOBJ" , cSeqACB)
                  oModelTMP5:LoadValue("T5_OBJETO" , cNomArq)
                  oModelTMP5:LoadValue("T5_DESCRI" , AllTrim(SubSTR(cNomArq,1,FWTamSX3("ACB_DESCRI")[1])))
                  oModelTMP5:LoadValue("T5_RECNO"  , 0)
                  oView:Refresh("VIEW_TABTMP5")
                EndIF
              Next
              oModelTMP5:GoLine(1)
              oView:Refresh("VIEW_TABTMP5")
            EndIF 
          Else
            ApMsgInfo('Importação de arquivo através da rotina Contas a Pagar deve-se ser realizado exclusivamente na aba "Contas a Pagar"!',"ATENÇÃO")
          EndIF

      Case Alltrim(FunName()) == "MATA910"

          If cTabPos == "TABTMP6"
            cFile := TFileDialog("All types (*.*)",'Informe onde será gravado o arquivo.',,,.F.,GETF_MULTISELECT)
            aFile := Separa(Alltrim(cFile),";",.T.)
            If !Empty(aFile)  
              For nY := 1 To Len(aFile)
                
                If !lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,aFile[nY])+1)))
                ElseIf lLinux
                  cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,STrTran(aFile[nY],"\","/"))+1)))
                EndIf
                
                If File(cDirSer+cNomArq)
                  FWAlertHelp('O arquivo '+cNomArq+', já existe no servidor, por este motivo não será importado.',"Altere o nome do arquivo e importe novamente.")
                Else
                  cSeqACB := u_proxIdACB()

                  If oModelTMP6:Length() > 1 .OR. !Empty(oModelTMP6:GetValue("T6_OBJETO"))
                    oModelTMP6:AddLine()
                  EndIF  
                  oModelTMP6:LoadValue("T6_FILENT" , xFilial("SF1"))
                  oModelTMP6:LoadValue("T6_ENTIDA" , "SF1")
                  oModelTMP6:LoadValue("T6_CODENT" , cCampo1+cCampo2+cCampo3+cCampo4)
                  oModelTMP6:LoadValue("T6_CODOBJ" , cSeqACB)
                  oModelTMP6:LoadValue("T6_OBJETO" , cNomArq)
                  oModelTMP6:LoadValue("T6_DESCRI" , AllTrim(SubSTR(cNomArq,1,FWTamSX3("ACB_DESCRI")[1])))
                  oModelTMP6:LoadValue("T6_RECNO"  , 0)
                  oView:Refresh("VIEW_TABTMP6")
                EndIF
              Next
              oModelTMP6:GoLine(1)
              oView:Refresh("VIEW_TABTMP6")
            EndIF 
          Else
            ApMsgInfo('Importação de arquivo através da rotina Nota Fiscal Manual de Entrada deve-se ser realizado exclusivamente na aba "Nota Fiscal Manual de Entrada"!',"ATENÇÃO")
          EndIF

    End Case

    If !Empty(aFile)
      For nY := 1 To Len(aFile)
        If !lLinux
          cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,aFile[nY])+1)))
        ElseIf lLinux
          cNomArq := Alltrim(Lower(SubSTR(aFile[nY],RAT(cBarra,STrTran(aFile[nY],"\","/"))+1)))
        EndIf
        If !File(cDirSer+cNomArq)
          If !(__CopyFile(aFile[nY], cDirSer+cNomArq))
            MsgStop("O arquivo" + cNomArq + ", não pode ser copiado para o servidor!", "Atenção")
          EndIF 
        EndIf
      Next
    EndIF
  
  FWRestArea(aArea)
Return

/*------------------------------------------------------------------*
 | Func:  fSave                                                     |
 | Desc:  Grava dados nas tabelas do banco de conhecimento.         |
 | Obs.:  /                                                         |
 *-----------------------------------------------------------------*/
Static Function fSave(oModel)
  Local lRet := .T.
  Local oModelTMP2 := oModel:GetModel("TABTMP2")
  Local oModelTMP3 := oModel:GetModel("TABTMP3")
  Local oModelTMP4 := oModel:GetModel("TABTMP4")
  Local oModelTMP5 := oModel:GetModel("TABTMP5")
  Local oModelTMP6 := oModel:GetModel("TABTMP6")
  Local nY 

  Do Case 
      Case Alltrim(FunName()) == "MATA110"
        
        For nY := 1 To oModelTMP2:Length()
          oModelTMP2:GoLine(nY)
          If !oModelTMP2:IsDeleted() .AND. Empty(oModelTMP2:GetValue("T2_RECNO"));
                                     .AND. !Empty(oModelTMP2:GetValue("T2_FILENT"));
                                     .AND. !Empty(oModelTMP2:GetValue("T2_ENTIDA"));
                                     .AND. !Empty(oModelTMP2:GetValue("T2_CODENT"));
                                     .AND. !Empty(oModelTMP2:GetValue("T2_CODOBJ"));
                                     .AND. !Empty(oModelTMP2:GetValue("T2_OBJETO"));
                                     .AND. !Empty(oModelTMP2:GetValue("T2_DESCRI"))
              RecLock('AC9',.T.)
                AC9->AC9_FILIAL := FWxFilial("AC9")
                AC9->AC9_FILENT := oModelTMP2:GetValue("T2_FILENT")
                AC9->AC9_ENTIDA := oModelTMP2:GetValue("T2_ENTIDA")
                AC9->AC9_CODENT := oModelTMP2:GetValue("T2_CODENT")
                AC9->AC9_CODOBJ := oModelTMP2:GetValue("T2_CODOBJ")
              AC9->(MsUnlock())
              RecLock('ACB',.T.)
                ACB->ACB_FILIAL := FWxFilial("ACB")
                ACB->ACB_CODOBJ := oModelTMP2:GetValue("T2_CODOBJ")
                ACB->ACB_OBJETO := oModelTMP2:GetValue("T2_OBJETO")
                ACB->ACB_DESCRI := oModelTMP2:GetValue("T2_DESCRI")
              ACB->(MsUnlock())
          ElseIf oModelTMP2:IsDeleted() .AND. !Empty(oModelTMP2:GetValue("T2_RECNO"))
              DBSelectArea("AC9")
              If AC9->(MsSeek(FWxFilial("AC9")+oModelTMP2:GetValue("T2_CODOBJ")))
                RecLock('AC9',.F.)
                  DbDelete()
                AC9->(MsUnlock())
              EndIF
              DBSelectArea("ACB")
              If ACB->(MsSeek(FWxFilial("ACB")+oModelTMP2:GetValue("T2_CODOBJ")))
                RecLock('ACB',.F.)
                  DbDelete()
                ACB->(MsUnlock())
              EndIF
          EndIF
        Next

      Case Alltrim(FunName()) == "MATA121"

        For nY := 1 To oModelTMP3:Length()
          oModelTMP3:GoLine(nY)
          If !oModelTMP3:IsDeleted() .AND. Empty(oModelTMP3:GetValue("T3_RECNO"));
                                     .AND. !Empty(oModelTMP3:GetValue("T3_FILENT"));
                                     .AND. !Empty(oModelTMP3:GetValue("T3_ENTIDA"));
                                     .AND. !Empty(oModelTMP3:GetValue("T3_CODENT"));
                                     .AND. !Empty(oModelTMP3:GetValue("T3_CODOBJ"));
                                     .AND. !Empty(oModelTMP3:GetValue("T3_OBJETO"));
                                     .AND. !Empty(oModelTMP3:GetValue("T3_DESCRI"))
              RecLock('AC9',.T.)
                AC9->AC9_FILIAL := FWxFilial("AC9")
                AC9->AC9_FILENT := oModelTMP3:GetValue("T3_FILENT")
                AC9->AC9_ENTIDA := oModelTMP3:GetValue("T3_ENTIDA")
                AC9->AC9_CODENT := oModelTMP3:GetValue("T3_CODENT")
                AC9->AC9_CODOBJ := oModelTMP3:GetValue("T3_CODOBJ")
              AC9->(MsUnlock())
              RecLock('ACB',.T.)
                ACB->ACB_FILIAL := FWxFilial("ACB")
                ACB->ACB_CODOBJ := oModelTMP3:GetValue("T3_CODOBJ")
                ACB->ACB_OBJETO := oModelTMP3:GetValue("T3_OBJETO")
                ACB->ACB_DESCRI := oModelTMP3:GetValue("T3_DESCRI")
              ACB->(MsUnlock())
          ElseIf oModelTMP3:IsDeleted() .AND. !Empty(oModelTMP3:GetValue("T3_RECNO"))
              DBSelectArea("AC9")
              If AC9->(MsSeek(FWxFilial("AC9")+oModelTMP3:GetValue("T3_CODOBJ")))
                RecLock('AC9',.F.)
                  DbDelete()
                AC9->(MsUnlock())
              EndIF
              DBSelectArea("ACB")
              If ACB->(MsSeek(FWxFilial("ACB")+oModelTMP3:GetValue("T3_CODOBJ")))
                RecLock('ACB',.F.)
                  DbDelete()
                ACB->(MsUnlock())
              EndIF
          EndIF
        Next

      Case Alltrim(FunName()) $ ("MATA140/MATA103/MATA910") 

        For nY := 1 To oModelTMP4:Length()
          oModelTMP4:GoLine(nY)
          If !oModelTMP4:IsDeleted() .AND. Empty(oModelTMP4:GetValue("T4_RECNO"));
                                     .AND. !Empty(oModelTMP4:GetValue("T4_FILENT"));
                                     .AND. !Empty(oModelTMP4:GetValue("T4_ENTIDA"));
                                     .AND. !Empty(oModelTMP4:GetValue("T4_CODENT"));
                                     .AND. !Empty(oModelTMP4:GetValue("T4_CODOBJ"));
                                     .AND. !Empty(oModelTMP4:GetValue("T4_OBJETO"));
                                     .AND. !Empty(oModelTMP4:GetValue("T4_DESCRI"))
              RecLock('AC9',.T.)
                AC9->AC9_FILIAL := FWxFilial("AC9")
                AC9->AC9_FILENT := oModelTMP4:GetValue("T4_FILENT")
                AC9->AC9_ENTIDA := oModelTMP4:GetValue("T4_ENTIDA")
                AC9->AC9_CODENT := oModelTMP4:GetValue("T4_CODENT")
                AC9->AC9_CODOBJ := oModelTMP4:GetValue("T4_CODOBJ")
              AC9->(MsUnlock())
              RecLock('ACB',.T.)
                ACB->ACB_FILIAL := FWxFilial("ACB")
                ACB->ACB_CODOBJ := oModelTMP4:GetValue("T4_CODOBJ")
                ACB->ACB_OBJETO := oModelTMP4:GetValue("T4_OBJETO")
                ACB->ACB_DESCRI := oModelTMP4:GetValue("T4_DESCRI")
              ACB->(MsUnlock())
          ElseIf oModelTMP4:IsDeleted() .AND. !Empty(oModelTMP4:GetValue("T4_RECNO"))
              DBSelectArea("AC9")
              If AC9->(MsSeek(FWxFilial("AC9")+oModelTMP4:GetValue("T4_CODOBJ")))
                RecLock('AC9',.F.)
                  DbDelete()
                AC9->(MsUnlock())
              EndIF
              DBSelectArea("ACB")
              If ACB->(MsSeek(FWxFilial("ACB")+oModelTMP4:GetValue("T4_CODOBJ")))
                RecLock('ACB',.F.)
                  DbDelete()
                ACB->(MsUnlock())
              EndIF
          EndIF
        Next

      Case Alltrim(FunName()) $ ("FINA050/FINA750")

        For nY := 1 To oModelTMP5:Length()
          oModelTMP5:GoLine(nY)
          If !oModelTMP5:IsDeleted() .AND. Empty(oModelTMP5:GetValue("T5_RECNO"));
                                     .AND. !Empty(oModelTMP5:GetValue("T5_FILENT"));
                                     .AND. !Empty(oModelTMP5:GetValue("T5_ENTIDA"));
                                     .AND. !Empty(oModelTMP5:GetValue("T5_CODENT"));
                                     .AND. !Empty(oModelTMP5:GetValue("T5_CODOBJ"));
                                     .AND. !Empty(oModelTMP5:GetValue("T5_OBJETO"));
                                     .AND. !Empty(oModelTMP5:GetValue("T5_DESCRI"))
              RecLock('AC9',.T.)
                AC9->AC9_FILIAL := FWxFilial("AC9")
                AC9->AC9_FILENT := oModelTMP5:GetValue("T5_FILENT")
                AC9->AC9_ENTIDA := oModelTMP5:GetValue("T5_ENTIDA")
                AC9->AC9_CODENT := oModelTMP5:GetValue("T5_CODENT")
                AC9->AC9_CODOBJ := oModelTMP5:GetValue("T5_CODOBJ")
              AC9->(MsUnlock())
              RecLock('ACB',.T.)
                ACB->ACB_FILIAL := FWxFilial("ACB")
                ACB->ACB_CODOBJ := oModelTMP5:GetValue("T5_CODOBJ")
                ACB->ACB_OBJETO := oModelTMP5:GetValue("T5_OBJETO")
                ACB->ACB_DESCRI := oModelTMP5:GetValue("T5_DESCRI")
              ACB->(MsUnlock())
          
          ElseIf oModelTMP5:IsDeleted() .AND. !Empty(oModelTMP5:GetValue("T5_RECNO"))
              DBSelectArea("AC9")
              If AC9->(MsSeek(FWxFilial("AC9")+oModelTMP5:GetValue("T5_CODOBJ")))
                RecLock('AC9',.F.)
                  DbDelete()
                AC9->(MsUnlock())
              EndIF
              DBSelectArea("ACB")
              If ACB->(MsSeek(FWxFilial("ACB")+oModelTMP5:GetValue("T5_CODOBJ")))
                RecLock('ACB',.F.)
                  DbDelete()
                ACB->(MsUnlock())
              EndIF
          EndIF
        Next

      Case Alltrim(FunName()) == "MATA910"

        For nY := 1 To oModelTMP6:Length()
          oModelTMP6:GoLine(nY)
          If !oModelTMP6:IsDeleted() .AND. Empty(oModelTMP6:GetValue("T6_RECNO"));
                                     .AND. !Empty(oModelTMP6:GetValue("T6_FILENT"));
                                     .AND. !Empty(oModelTMP6:GetValue("T6_ENTIDA"));
                                     .AND. !Empty(oModelTMP6:GetValue("T6_CODENT"));
                                     .AND. !Empty(oModelTMP6:GetValue("T6_CODOBJ"));
                                     .AND. !Empty(oModelTMP6:GetValue("T6_OBJETO"));
                                     .AND. !Empty(oModelTMP6:GetValue("T6_DESCRI"))
              RecLock('AC9',.T.)
                AC9->AC9_FILIAL := FWxFilial("AC9")
                AC9->AC9_FILENT := oModelTMP6:GetValue("T6_FILENT")
                AC9->AC9_ENTIDA := oModelTMP6:GetValue("T6_ENTIDA")
                AC9->AC9_CODENT := oModelTMP6:GetValue("T6_CODENT")
                AC9->AC9_CODOBJ := oModelTMP6:GetValue("T6_CODOBJ")
              AC9->(MsUnlock())
              RecLock('ACB',.T.)
                ACB->ACB_FILIAL := FWxFilial("ACB")
                ACB->ACB_CODOBJ := oModelTMP6:GetValue("T6_CODOBJ")
                ACB->ACB_OBJETO := oModelTMP6:GetValue("T6_OBJETO")
                ACB->ACB_DESCRI := oModelTMP6:GetValue("T6_DESCRI")
              ACB->(MsUnlock())
          
          ElseIf oModelTMP6:IsDeleted() .AND. !Empty(oModelTMP6:GetValue("T6_RECNO"))
              DBSelectArea("AC9")
              If AC9->(MsSeek(FWxFilial("AC9")+oModelTMP6:GetValue("T6_CODOBJ")))
                RecLock('AC9',.F.)
                  DbDelete()
                AC9->(MsUnlock())
              EndIF
              DBSelectArea("ACB")
              If ACB->(MsSeek(FWxFilial("ACB")+oModelTMP6:GetValue("T6_CODOBJ")))
                RecLock('ACB',.F.)
                  DbDelete()
                ACB->(MsUnlock())
              EndIF
          EndIF
        Next

  End Case
  
  lRet := FwFormCommit(oModel)

Return(lRet)

//--------------------------------------------------------------------------
/*/{Protheus.doc} u_proxIdACB()
Retorna próxima sequencia para a tabela AC9	

@author Elvis Siqueira
@type  Static Function
@version 1.0
@return cProxACB, character, retorna próxima sequencia para a tabela ACB	
/*/
//--------------------------------------------------------------------------
User Function proxIdACB() As Character
Local cProxACB := ""

  DBSelectArea("ACB")
  ACB->(DBSetOrder(1))
  cProxACB := GetSxeNum("ACB","ACB_CODOBJ")
  IF ACB->(MsSeek(xFilial("ACB") + cProxACB))
    While !ACB->(Eof())
      If !ACB->(MsSeek(xFilial("ACB") + cProxACB))
        Exit
      Else
        cProxACB := GetSxeNum("ACB","ACB_CODOBJ")      
      EndIF 
      ACB->(DBSkip())
    End
  EndIF

Return cProxACB

//--------------------------------------------------------------------------
/*/{Protheus.doc} fDelArq
Consulta arquivos do banco de conhecimento para exclusão

@author Elvis Siqueira
@type  User Function
@version 1.0
/*/
//--------------------------------------------------------------------------
User Function fDelArq()
	
  Local oFile   := Nil
  Local nDayDel := SuperGetMV("PC_DELARQ",.F.,0)
  Local cDirSer := SuperGetMV("MV_DIRDOC")+"\co"+cEmpAnt+"\shared\"
  Local aFiles  := {}
  Local nY, nTotal

  If IsSrvUnix()
    cDirSer := STrTran(cDirSer,"\","/")
  EndIf
  
  aFiles := Directory(cDirSer + "*.*")
  nTotal := Len(aFiles)

  If !Empty(nDayDel)
    ProcRegua(Len(aFiles))
             
    For nY := 1 To Len(aFiles)
        IncProc("Analisando arquivo " + cValToChar(nY) + " de " + cValToChar(nTotal) + "...")
      
//      MsProcTxt("Analisando arquivo " + cValToChar(nY) + " de " + cValToChar(nTotal) + "...")
      
      IF aFiles[nY][3] <= DaySub(dDataBase,nDayDel)
        oFile := Nil
        oFile := FwFileReader():New(cDirSer + aFiles[nY][1])
        FErase(cDirSer + aFiles[nY][1])
      EndIF
    Next 

  EndIf
	
Return 
