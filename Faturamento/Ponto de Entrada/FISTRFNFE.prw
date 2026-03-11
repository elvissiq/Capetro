#Include "Protheus.ch"
#Include "TBICONN.CH"
#Include "TopConn.ch"

/*------------------------------------------------------------------------------------------------------*
 | P.E.:  FISTRFNFE                                                                                     |
 | Desc:  Este ponto de entrada tem por finalidade incluir novos botões na rotina SPEDNFE()             |
 | Links: https://tdn.totvs.com.br/pages/releaseview.action?pageId=694110055                            |
 *------------------------------------------------------------------------------------------------------*/

User Function FISTRFNFE()
	
	aadd(aRotina,{'Boleto','U_PFAT007' , 0 , 2,0,NIL})

Return
