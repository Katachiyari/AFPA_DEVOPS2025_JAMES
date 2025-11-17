Powershell & AD
L'étude dont vous avez la charge, à racheté une autre étude, et vous devez intégrer l'ensemble des nouveaux utilisateurs contenus dans le fichier CSV  ci-joint.
 
Les ouvertures de session des utilisateurs se feront à l'aide des "3 premières lettres du prénom" "." "Nom", eg : ala.picard@mondomaine.fr
les utilisateurs doivent être importés dans leurs OU respectives, et dans les GG correspondants.
https://www.it-connect.fr/chapitres/creer-des-utilisateurs-dans-lad-a-partir-dun-csv/ 
https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit?view=windowsserver2025-ps#example-2-create-an-ou-that-is-not-protected-from-accidental-deletion
Dans votre AD, à l'aide de powershell créez une nouvelle structure OU
 
UBIJURISTE
   |
   Direction ( GG_ubi_Direction )
   Gestion ( GG_ubi_Gestion )
   Rédaction ( ... )
   Accueil
   Comptabilité
 
Créez les GG_ubi_**** , directement dans ces OU ( pas besoin de faire de sous OU de service, ni utilisateurs et ordinateurs ) .
https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adgroup?view=windowsserver2025-ps#example-1-create-a-group-and-set-its-properties 
De même pour les utilisateurs, ils sont placés dans le groupe de service ( pas de GG pour les fonctions ).
 
Use this topic to help manage Windows and Windows Server technologies with Windows PowerShell.
PowerShell-AD-Utilisateurs (1).pdf
CSV_etude.csv
 