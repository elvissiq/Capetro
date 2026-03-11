#Include "Protheus.ch"
#Include "TBICONN.CH"
#Include "TopConn.ch"

/*-----------------------------------------------------------------------------------------------------*
| P.E.:  FISENVNFE                                                                                     |
| Desc:  Ponto de entrada executado logo após a transmissão da NF-e.                                   |
| Links: https://tdn.totvs.com/display/public/TSS/FISENVNFE+-+Envio+de+NF-e                            |
*-----------------------------------------------------------------------------------------------------*/

User function FISENVNFE()
Local aArea    := FWGetArea()
Local aIdNfe   := PARAMIXB[1]
Local aBankBol := StrTokArr(SuperGetMV("MV_XBANKBO",.F.,""),"/")
Local cSerieNF := ""
Local cIdsNfe  := ""
Local nY 

  IF !Empty(aIdNfe) .AND. !Empty(aBankBol)
    For nY := 1 To Len(aIdNfe)
        If Empty(cIdsNfe)
            cSerieNF := SubSTR(aIdNfe[nY],1,3)
            cIdsNfe  += SubSTR(aIdNfe[nY],4)
        Else
            cIdsNfe += "/"+SubSTR(aIdNfe[nY],4)
        EndIF
    Next nY
    u_fnGerBol(cSerieNF,cIdsNfe) //Função que irá gerar os boletos
  EndIF

  FWRestArea(aArea)

Return
