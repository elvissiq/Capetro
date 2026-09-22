#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOTVS.CH"
#INCLUDE "TOPCONN.CH"

//---------------------------------------------------------
/*/ Rotina A410EXC
  Funcao A410EXC() - Ponto de Entrada MATA410 (exclusao)

  Descricao:
  Ponto de Entrada padrao do MATA410, disparado antes da
  exclusao fisica do Pedido de Venda, com a SC5 ja posicionada
  no registro a ser excluido. Bloqueia a exclusao quando existe
  titulo (SE1) gerado por XFAT003BOL() (XFAT003.PRW) para o
  pedido posicionado (E1_PREFIXO="FAT"), evitando que um pedido
  com boleto ja emitido seja excluido sem o devido cancelamento
  do titulo.

  @author Raphael Neves (Hubvision)
  @since  21/09/2026
/*/
//----------------------------------------------------------
User Function A410EXC()

    Local lRet   := .T.
    Local cAlias := GetNextAlias()

    BeginSql Alias cAlias
        SELECT COUNT(*) AS QTDTIT
        FROM %table:SE1% SE1
        WHERE SE1.%notDel%
          AND SE1.E1_FILIAL  = %exp:xFilial("SE1")%
          AND SE1.E1_PREFIXO = %exp:PadR("FAT", FWTamSX3("E1_PREFIXO")[1])%
          AND SE1.E1_NUM     = %exp:SC5->C5_NUM%
    EndSql

    If (cAlias)->QTDTIT > 0
        lRet := .F.
        Help(" ", 1, "Atencao", , "Existe titulo de boleto gerado para o pedido " + AllTrim(SC5->C5_NUM) + ". Exclusao bloqueada.", 1, 0)
    EndIf

    (cAlias)->(DbCloseArea())

Return lRet
