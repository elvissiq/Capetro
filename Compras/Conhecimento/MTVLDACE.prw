#INCLUDE "Totvs.ch"

//--------------------------------------------------------------------------
/*/{PROTHEUS.DOC} MTVLDACE
Ponto-de-Entrada: MTVLDACE - Valida acesso à rotina de conhecimento
@OWNER TOTVS Nordeste (Elvis Siqueira)
@VERSION PROTHEUS 12
@SINCE 16/01/2026
/*/
//--------------------------------------------------------------------------
User Function MTVLDACE()
	Local lRet    := .T.

	If IsInCallStack( 'GEREXCNF' )
		Return(lRet)
	Endif

	//MsAguarde({|| U_fDelArq()}, "Aguarde...", "Consultando arquivos para exclusão...") //Function fDelArq no fonte XBCON.prw

	Do Case
	Case Alltrim(FunName()) == "MATA110"
		u_XBCON(SC1->C1_NUM,SC1->C1_ITEM)
		lRet := .F.
	Case Alltrim(FunName()) == "MATA121"
		u_XBCON(SC7->C7_NUM,SC7->C7_ITEM)
		lRet := .F.
	Case Alltrim(FunName()) $ ("MATA140/MATA103/MATA910")
		u_XBCON(SF1->F1_DOC,SF1->F1_SERIE,SF1->F1_FORNECE,SF1->F1_LOJA)
		lRet := .F.
	Case Alltrim(FunName()) $ ("FINA050/FINA750") .And. !FwIsInCallStack("FA050DELET")
		u_XBCON(SE2->E2_PREFIXO,SE2->E2_NUM,SE2->E2_PARCELA,SE2->E2_TIPO,SE2->E2_FORNECE,SE2->E2_LOJA)
		lRet := .F.
	End Case

Return lRet
