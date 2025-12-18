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
@since 18/12/2025
//APIOMS01 - Web Service (REST)
Return
@project
@history
/*/

WSRestFul APIOMS01 Description "Painel de Ordens" FORMAT APPLICATION_JSON

WSMethod GET Description "GET Entidades" WSSYNTAX "/api/retail/v1/APIOMS01" PATH "/api/retail/v1/APIOMS01"
End WSRestFul

WSMethod GET WSReceive RECEIVE WSService APIOMS01
Local cMensag := {}

  If Select("SX2") <= 0
    RPCSetEnv("99", "01", "admin", "admin", "SIGAOMS")
  EndIf

  cMensag := Order()

  ::SetContentType("application/json")
  ::SetResponse(cMensag)

  RPCClearEnv()

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
Local nTotWhile := 0
Local nWhile    := 1

  cMsgRet := "[ "

    cQry := "SELECT DAK.DAK_COD, SC5.C5_NUM, SC5.C5_EMISSAO, SA1.A1_NOME, DAK.DAK_MOTORI, DAK.DAK_CAMINH, DAK.DAK_PESO, DAI.DAI_NFISCA FROM " + RetSqlName("SC5") + " SC5 "
    cQry += "LEFT JOIN " + RetSqlName("DAI") + " DAI ON DAI.DAI_FILIAL = SC5.C5_FILIAL AND DAI.DAI_PEDIDO = SC5.C5_NUM AND DAI.DAI_CLIENT = SC5.C5_CLIENTE AND DAI.DAI_LOJA = SC5.C5_LOJACLI AND DAI.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("DAK") + " DAK ON DAK.DAK_FILIAL = DAI.DAI_FILIAL AND DAK.DAK_COD = DAI.DAI_COD AND DAK.D_E_L_E_T_ <> '*' "
    cQry += "LEFT JOIN " + RetSqlName("SA1") + " SA1 ON SA1.A1_FILIAL = '" + xFilial("SA1") + "' AND SA1.A1_COD = SC5.C5_CLIENTE AND SA1.A1_LOJA = SC5.C5_LOJACLI AND SA1.D_E_L_E_T_ <> '*' "
    cQry += "WHERE SC5.D_E_L_E_T_ <> '*' "
    cQry += "  AND SC5.C5_FILIAL  = '" + xFilial("SC5") + "' "
    cQry += "ORDER BY SC5.C5_NUM "
    IF Select(__cAlias) <> 0
      (__cAlias)->(DBCloseArea())
    EndIf
    TCQuery cQry New Alias &__cAlias
    Count To nTotWhile
    (__cAlias)->(DBGoTop())

    While (__cAlias)->(!Eof())
      
      Do Case
        Case !Empty((__cAlias)->DAI_NFISCA)
          cStatus := "LIBERADO"
        Case !Empty((__cAlias)->DAK_COD)
          cStatus := "AGUARDANDO FATURAMENTO"
        Case !Empty((__cAlias)->DAK_PESO)
          cStatus := "VEICULO PESADO"
        Otherwise
          cStatus := "aguardando"
      EndCase
      
      cMsgRet += ' { '
      cMsgRet += ' "oc": "'+ AllTrim((__cAlias)->DAK_COD) +'",'             //Número da Ordem
      cMsgRet += ' "pedido": "'+ AllTrim((__cAlias)->C5_NUM) +'", '         //Número do Pedido
      cMsgRet += ' "data": "'+ DTOC(STOD((__cAlias)->C5_EMISSAO)) +'", '    //Data do Pedido
      cMsgRet += ' "cliente": "'+ AllTrim((__cAlias)->A1_NOME) +'",'        //Nome do Cliente
      cMsgRet += ' "motorista": "'+ AllTrim((__cAlias)->DAK_MOTORI) +'", '  //Nome do Motorista
      cMsgRet += ' "produto": "", '                                         //Produto
      cMsgRet += ' "placa": "'+ AllTrim((__cAlias)->DAK_CAMINH) +'", '      //Placa do Veículo
      cMsgRet += ' "Status": "' + cStatus + '", '                           //Status da Ordem
      cMsgRet += ' "peso": "'+ AllTrim((__cAlias)->DAK_PESO) +'", '         //Peso da Carga
      cMsgRet += ' "lacres": "" '                                           //Número do Lacre
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
