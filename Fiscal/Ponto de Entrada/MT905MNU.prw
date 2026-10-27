#Include "Protheus.ch"

/*/{Protheus.doc} MT905MNU
Ponto de entrada da MenuDef da MATA905 (Manutencao do CIAP).
Inclui a opcao "Importar CIAP (TXT)" em Outras Acoes, chamando U_IMPCIAP.
aRotina e Private na MenuDef, por isso o aAdd direto funciona.
/*/
User Function MT905MNU()
	aAdd(aRotina, {"Importar CIAP (TXT)", "U_IMPCIAP", 0, 3, 0, NIL})
Return
