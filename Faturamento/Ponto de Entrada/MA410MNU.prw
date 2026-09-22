#Include "TOTVS.CH"

//---------------------------------------------------------
/*/ Rotina MATA410 
  Ponto de entrada MA410MNU

   Disparado antes da abertura do Browse, caso Browse 
   inicial da rotina esteja habilitado, ou antes da 
   apresentação do Menu de opções, caso Browse inicial
   esteja desabilitado.
    
    Implementado para:
      - Adicionar opção customizada, integração com FUSION.

  @author Raphael Neves (Hubvision)
  @since   21/09/2026
/*/
//----------------------------------------------------------
User Function MA410MNU()
  local aNovoIte := {}
  
  If ! IsBlind()
    aAdd(aRotina,{'Imprimir Pedido','U_zRPedVen',0,2,0,NIL})

    aAdd(aNovoIte,{"Imprimir Fatura" ,"U_XFAT003" ,0,2,0,Nil})
    aAdd(aNovoIte,{"Imprimir Boleto" ,"U_XFATBOL" ,0,2,0,Nil})

    aAdd(aRotina,{"Fatura" ,aNovoIte ,0,2,0,Nil})
  EndIf 
Return 
