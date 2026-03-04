#include "Totvs.ch"
#include "Protheus.ch"
#Include "RESTFUL.CH"
#Include "FWMVCDEF.CH"
#Include "TBICONN.CH"
#Include "TopConn.ch"
#Define ENTER Chr(10)

/*/
Função APIOMS01
@param Recebe parâmetro Nil
@author Totvs Nordeste (Elvis Siqueira)
@since 04/03/2026
//APIOMS01 - Web Service (REST)
Return
@project
@history
/*/

WSRestFul APIOMS01 Description "Painel de Ordens" FORMAT APPLICATION_JSON

WSDATA Branch AS CHARACTER OPTIONAL

WSMethod GET Description "GET Entidades" WSSYNTAX "/api/retail/v1/APIOMS01" PATH "/api/retail/v1/APIOMS01"
End WSRestFul

WSMethod GET WSReceive Branch WSService APIOMS01
Local cMensag := {}

DEFAULT ::Branch := "010101"

  If IsBlind()
    RpcClearEnv()
    RpcSetType(2) 
    RpcSetEnv("01",::Branch)
  EndIF 

  cMensag := Order()

  ::SetContentType("application/json")
  ::SetResponse(cMensag)

  If IsBlind()
    RPCClearEnv()
  EndIF

Return 

/*------------------------------------------------------------------------*
 | Func:  Order                                                           |
 | Autor: TOTVS Nordeste (Elvis Siqueira)                                 |
 | Desc:  Função que retorna os dados necessários para o painel de ordens |
 *------------------------------------------------------------------------*/
Static Function Order()
Local cQry      := ""
Local __cAlias  := GetNextAlias()
Local cMsgRet   := ""
Local cStatus   := ""
Local lOMS      := SuperGetMV("MV_XMONOMS", .F.,.F.)
Local nDias     := SuperGetMV("MV_XDIAMON", .F.,10)
Local cQtdMon   := SuperGetMV("MV_XQTDMON", .F.,"50")
Local cPictPeso := PesqPict( "SC5", "C5_PBRUTO")
Local nTotWhile := 0
Local nWhile    := 1

  If lOMS
    cQry := "SELECT DAK.DAK_COD AS OC, SC5.C5_NUM AS PEDIDO, SC5.C5_EMISSAO AS EMISSAO, SC5.C5_LIBEROK AS LIBERADO, SA1.A1_NOME AS CLIENTE, DA4.DA4_NREDUZ AS MOTORISTA, DAK.DAK_CAMINH AS CAMINHAO, DAK.DAK_PESO AS PESO, DAI.DAI_NFISCA AS NOTA_FISCAL FROM " + RetSqlName("SC5") + " SC5 "
    cQry += "LEFT JOIN " + RetSqlName("DAI") + " DAI ON DAI.DAI_FILIAL = SC5.C5_FILIAL AND DAI.DAI_PEDIDO = SC5.C5_NUM AND DAI.DAI_CLIENT = SC5.C5_CLIENTE AND DAI.DAI_LOJA = SC5.C5_LOJACLI AND DAI.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("DAK") + " DAK ON DAK.DAK_FILIAL = DAI.DAI_FILIAL AND DAK.DAK_COD = DAI.DAI_COD AND DAK.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("DA4") + " DA4 ON DA4.DA4_FILIAL = '" + xFilial("DA4") + "' AND DA4.DA4_COD = DAK.DAK_MOTORI AND DA4.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("SA1") + " SA1 ON SA1.A1_FILIAL = '" + xFilial("SA1") + "' AND SA1.A1_COD = SC5.C5_CLIENTE AND SA1.A1_LOJA = SC5.C5_LOJACLI AND SA1.D_E_L_E_T_ <> '*' "
    cQry += "WHERE SC5.D_E_L_E_T_ <> '*' "
    cQry += "  AND SC5.C5_FILIAL  = '" + xFilial("SC5") + "' "
    cQry += "  AND SC5.C5_EMISSAO >= '" + DToS(DaySub(dDataBase,nDias)) + "' "
    cQry += "ORDER BY SC5.C5_NUM "
    cQry += "OFFSET 0 ROWS FETCH FIRST " + cQtdMon + " ROWS ONLY "
  Else
    cQry := "SELECT SC5.C5_NUM AS OC, SC5.C5_NUM AS PEDIDO, SC5.C5_EMISSAO AS EMISSAO, SC5.C5_LIBEROK AS LIBERADO, SA1.A1_NOME AS CLIENTE, DA4.DA4_NREDUZ AS MOTORISTA, DA3.DA3_PLACA AS CAMINHAO, SC5.C5_PBRUTO AS PESO, SC5.C5_NOTA AS NOTA_FISCAL FROM " + RetSqlName("SC5") + " SC5 "
    cQry += "LEFT JOIN " + RetSqlName("SF2") + " SF2 ON SF2.F2_FILIAL  = '" + xFilial("SF2") + "' AND SF2.F2_CLIENTE = SC5.C5_CLIENTE AND SF2.F2_LOJA = SC5.C5_LOJACLI  AND SF2.F2_DOC = SC5.C5_NOTA AND SF2.F2_SERIE = SC5.C5_SERIE AND SF2.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("DA3") + " DA3 ON DA3.DA3_FILIAL = '" + xFilial("DA3") + "' AND DA3.DA3_COD = SF2.F2_VEICUL1 AND DA3.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("DA4") + " DA4 ON DA4.DA4_FILIAL = '" + xFilial("DA4") + "' AND DA4.DA4_COD = DA3.DA3_MOTORI AND DA4.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("SA1") + " SA1 ON SA1.A1_FILIAL  = '" + xFilial("SA1") + "' AND SA1.A1_COD = SC5.C5_CLIENTE AND SA1.A1_LOJA = SC5.C5_LOJACLI AND SA1.D_E_L_E_T_ <> '*' "
    cQry += "WHERE SC5.D_E_L_E_T_ <> '*' "
    cQry += "  AND SC5.C5_FILIAL  = '" + xFilial("SC5") + "' "
    cQry += "  AND SC5.C5_EMISSAO >= '" + DToS(DaySub(dDataBase,nDias)) + "' "
    cQry += "ORDER BY SC5.C5_NUM "
    cQry += "OFFSET 0 ROWS FETCH FIRST " + cQtdMon + " ROWS ONLY "
  EndIF 
  IF Select(__cAlias) <> 0
    (__cAlias)->(DBCloseArea())
  EndIf
  TCQuery cQry New Alias &__cAlias
  Count To nTotWhile
  (__cAlias)->(DBGoTop())

  cMsgRet := "[ "

  IF (__cAlias)->(Eof())
    cMsgRet += "{}"
  EndIF 

  While (__cAlias)->(!Eof())
      
    Do Case
      Case !Empty((__cAlias)->NOTA_FISCAL)
        cStatus := "LIBERADO"
      Case (__cAlias)->LIBERADO == "S" .AND. Empty((__cAlias)->NOTA_FISCAL)
        cStatus := "AGUARDANDO FATURAMENTO"
      Case !Empty((__cAlias)->PESO)
        cStatus := "VEICULO PESADO"
      Otherwise
        cStatus := "AGUARDANDO"
    EndCase
      
    cMsgRet += ' { '
    cMsgRet += ' "oc": "'+ AllTrim((__cAlias)->OC) +'",'                            //Número da Ordem
    cMsgRet += ' "pedido": "'+ AllTrim((__cAlias)->PEDIDO) +'", '                   //Número do Pedido
    cMsgRet += ' "data": "'+ DTOC(STOD((__cAlias)->EMISSAO)) +'", '                 //Data do Pedido
    cMsgRet += ' "cliente": "'+ AllTrim((__cAlias)->CLIENTE) +'",'                  //Nome do Cliente
    cMsgRet += ' "motorista": "'+ AllTrim((__cAlias)->MOTORISTA) +'", '             //Nome do Motorista
    cMsgRet += ' "produto": "", '                                                   //Produto
    cMsgRet += ' "placa": "'+ AllTrim((__cAlias)->CAMINHAO) +'", '                  //Placa do Veículo
    cMsgRet += ' "Status": "' + cStatus + '", '                                     //Status da Ordem
    cMsgRet += ' "peso": "'+ AllTrim(AllToChar((__cAlias)->PESO,cPictPeso)) +'", '  //Peso da Carga
    cMsgRet += ' "lacres": "" '                                                     //Número do Lacre
    IF nWhile < nTotWhile
    cMsgRet += ' }, '
    Else
    cMsgRet += ' } '
    EndIF
    nWhile++

  (__cAlias)->(DBSkip())
  End
  (__cAlias)->(DBCloseArea()) 

  cMsgRet += "]"

Return cMsgRet
