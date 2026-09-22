//Bibliotecas
#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'

/*/{Protheus.doc} MA410COR
Ponto-de-Entrada: MA410COR - Alterar cores do browse do cadastro de status do Pedido de Venda
@author Elvis Siqueira
@since 19/11/2021
@version 1.0
    @return aCores(vetor) Array com as cores para o "browse"
    @example
    u_MA410COR()
    @obs
/*/

User Function MA410COR()
  Local aCores := { { "(U_fn410Vld('C'))", "BR_PINK"},;        // Bloqueado por credito
				            { "(U_fn410Vld('E'))", "BR_MARROM"},;      // Bloqueado por estoque
	                  { "(! Empty(C5_NOTA) .or. C5_LIBEROK == 'E') .and. Empty(C5_BLQ) .and. (U_fn410Vld('L')) ","DISABLE" },;    // Pedido Encerrado
				          { "! Empty(C5_LIBEROK) .and. Empty(C5_NOTA) .and. Empty(C5_BLQ) .and. (U_fn410Vld('L')) " ,"BR_AMARELO"},;  // Pedido Liberado
				            { "C5_BLQ == '1'"    , "BR_AZUL"},;        // Pedido Bloquedo por regra
				            { "C5_BLQ == '2'"    , "BR_LARANJA"},;     // Pedido Bloquedo por verba
				            { "(U_fn410Vld('W'))", "BR_BRANCO"},;      // Bloqueado por WMS
				            { "(U_fn410Fat())"   , "BR_VIOLETA"},;     // Pedido com Fatura de Cobranca gerada
				            { "Empty(C5_LIBEROK) .and. Empty(C5_NOTA) .and. Empty(C5_BLQ)","ENABLE"},;  // Pedido em Aberto
				            { "C5_BLQ == '9'"    , "BR_PRETO"}}        // Pedido bloqueado por regra (desconto/acrescimo)

Return aCores

//--------------------------------------------------------
/*/ Funcao fn410Vld

  Ler as liberacoes do Pedido de Venda para ver bloqueio

  @parametro pTipo - Tipo do bloqueio
  @author Anderson Almeida (TOTVS NE)
  @since 20/01/2021
/*/
//--------------------------------------------------------
User Function fn410Vld(pTipo)
  Local aArea  := GetArea()
  Local lRet   := .T.
  Local cQuery := ""

  cQuery := "Select SC9.C9_BLEST from " + RetSqlName("SC9") + " SC9"
  cQuery += "  where SC9.D_E_L_E_T_ <> '*'"
  cQuery += "    and SC9.C9_FILIAL  = '" + SC5->C5_FILIAL + "'"
  cQuery += "    and SC9.C9_PEDIDO  = '" + SC5->C5_NUM + "'"

  Do Case
     Case pTipo == "E"     // Bloqueio de Estoque
          cQuery += " and SC9.C9_BLEST in ('02','03')"

	   Case pTipo == "C"     // Bloqueio de Credito
	        cQuery += " and SC9.C9_BLCRED in ('01','02','04','09')"

	   Case pTipo == "L"     // Pedido Liberado / Encerrado
          cQuery += " and SC9.C9_BLEST not in ('02','03')"
          cQuery += " and SC9.C9_BLCRED not in ('01','02','04','09')"
          cQuery += " and SC9.C9_BLWMS in ('  ','05','06','07')"

     Case pTipo == "W"     // Pedido Bloqueado WMS
	        cQuery += " and SC9.C9_BLEST not in ('02','03')"
	        cQuery += " and SC9.C9_BLCRED not in ('01','02','04','09')"
	        cQuery += " and SC9.C9_BLWMS in ('01','02','03')"
  EndCase

  cQuery := ChangeQuery(cQuery)
  dbUseArea(.T.,"TOPCONN",TCGenQry(,,cQuery),"QSC9",.F.,.T.)

  lRet := ! QSC9->(Eof())

  QSC9->(dbCloseArea())

  RestArea(aArea)
Return lRet

//--------------------------------------------------------
/*/ Funcao fn410Fat

  Verifica se existe titulo de Fatura de Cobranca (SE1, com
  E1_PREFIXO = "FAT") gerado para o Pedido de Venda posicionado
  atraves da rotina XFAT003BOL() (fonte XFAT003.PRW), para
  sinalizar o pedido com uma cor diferenciada no browse do
  MATA410, indicando que o boleto/titulo ja foi emitido.

  @author Raphael Neves (Hubvision)
  @since 21/09/2026
/*/
//--------------------------------------------------------
User Function fn410Fat()
  Local aArea  := GetArea()
  Local lRet   := .F.
  Local cQuery := ""

  cQuery := "Select SE1.E1_NUM from " + RetSqlName("SE1") + " SE1"
  cQuery += "  where SE1.D_E_L_E_T_ <> '*'"
  cQuery += "    and SE1.E1_FILIAL  = '" + SC5->C5_FILIAL + "'"
  cQuery += "    and SE1.E1_PREFIXO = 'FAT'"
  cQuery += "    and SE1.E1_NUM     = '" + SC5->C5_NUM + "'"

  cQuery := ChangeQuery(cQuery)
  dbUseArea(.T.,"TOPCONN",TCGenQry(,,cQuery),"QSE1FAT",.F.,.T.)

  lRet := ! QSE1FAT->(Eof())

  QSE1FAT->(dbCloseArea())

  RestArea(aArea)
Return lRet

