Import-Module ActiveDirectory

function choix(){
        Write-Host "Choix 1 = Supprimée les O.U actuel"
        Write-Host "Choix 2 = Créer O.U a partir d'un CSV"
        $choix= Read-Host "Rien ne va plus, faites vos jeux ! "
            if($choix -eq 1){
               Write-Host "Suppression des O.U n` Faites votres choix"
               SupprimerOUManuelles 
        }else{
                Write-Host "Création d'OU, utilisateurs et groupe a partir d'un CSV "
                Deploy-ADInfrastructure
        }
}

# =====================================================================
# Fonction : SupprimerOUManuelles
# Objectif : Supprimer les Unités d’Organisation (OU) créées manuellement
# =====================================================================

function SupprimerOUManuelles {

    # Liste des OUs système par défaut à ne jamais supprimer
    $OUsDefaut = @(
        "Builtin",
        "Computers",
        "Domain Controllers",
        "ForeignSecurityPrincipals",
        "Keys",
        "LostAndFound",
        "Managed Service Accounts",
        "NTDS Quotas",
        "Program Data",
        "System",
        "TPM Devices",
        "Users",
        "Contrôle d'accès dynamique",
        "Authentification"
        "etude.lab.dl"
    )

    # Récupère automatiquement le nom complet (DN) du domaine actif
    $DCpath = (Get-ADDomain).DistinguishedName

    do {
        # ----------------------------------------------------------------
        # Étape 1 : Récupérer la liste des OU de premier niveau
        # Filtre : seules les OU dont le parent est le domaine racine
        #          sont conservées (donc pas les sous-OU)
        # ----------------------------------------------------------------
        $ouManuelles = Get-ADOrganizationalUnit -Filter * -Properties 'msDS-ParentDistName' |
            Where-Object {
                $_.'msDS-ParentDistName' -eq $DCpath -and
                ($OUsDefaut -notcontains $_.Name)
            }

        # Extrait uniquement les noms simples des OU trouvées
        $ouNoms = $ouManuelles | Select-Object -ExpandProperty Name

        # ----------------------------------------------------------------
        # Étape 2 : Vérifie s’il reste des OU à supprimer
        # ----------------------------------------------------------------
        if ($ouNoms.Count -eq 0) {
            Write-Host "Il n'y a pas d'OU à supprimer. Arrêt du programme."
            break
        }

        # Affiche la liste des OU supprimables
        Write-Host "`nVoici les OU créées manuellement, potentiellement supprimables :"
        $ouNoms | ForEach-Object { Write-Host "- $_" }

        # ----------------------------------------------------------------
        # Étape 3 : Demande à l’utilisateur quelle OU il souhaite supprimer
        # ----------------------------------------------------------------
        $ouASupprimer = Read-Host "`nQuelle OU voulez-vous supprimer ? (Tapez le nom exact ou laissez vide pour annuler)"

        # Si l’utilisateur n’a rien saisi, on quitte le script
        if ([string]::IsNullOrWhiteSpace($ouASupprimer)) {
            Write-Host "Opération annulée."
            break
        }

        # ----------------------------------------------------------------
        # Étape 4 : Vérifie si le nom saisi existe dans la liste d’OU
        # ----------------------------------------------------------------
        if ($ouNoms -contains $ouASupprimer) {

            # Demande confirmation avant suppression
            $confirmation = Read-Host "Voulez-vous vraiment supprimer l'OU '$ouASupprimer' ? (y/n)"
            
            if ($confirmation -eq "y") {
                # Construit le chemin complet LDAP de l’OU à supprimer
                $ouPath = "OU=$ouASupprimer,$DCpath"

                # Supprime l’OU de façon récursive (avec ses sous-éléments)
                Remove-ADOrganizationalUnit -Identity $ouPath -Recursive -Confirm:$false

                Write-Host "L'OU '$ouASupprimer' a été supprimée de manière récursive."
            } else {
                Write-Host "Suppression annulée pour '$ouASupprimer'."
            }

        } else {
            # Si l’utilisateur s’est trompé dans le nom
            $choix = Read-Host "Nom incorrect. Voulez-vous relancer le programme ? (y/n)"
            if ($choix -ne "y") {
                Write-Host "Fin du programme."
                break
            }
            continue
        }

        # ----------------------------------------------------------------
        # Étape 5 : Propose de continuer s’il reste d’autres OU
        # ----------------------------------------------------------------
        $ouRestantes = (Get-ADOrganizationalUnit -Filter * -SearchBase $DCpath | Where-Object { $OUsDefaut -notcontains $_.Name }).Count
        
        if ($ouRestantes -gt 0) {
            $relancer = Read-Host "Voulez-vous relancer le programme pour supprimer une autre OU ? (y/n)"
            if ($relancer -ne "y") {
                Write-Host "Fin du programme."
                break
            }
        } else {
            Write-Host "Il n'y a plus d'OU à supprimer. Arrêt du programme."
            break
        }

    } while ($true)
}

# ==================================================================
# FONCTION : Deploy-ADInfrastructure
# OBJECTIF : Créer automatiquement les OU racine, sous-OU, groupes et utilisateurs
# à partir d’un CSV, en appliquant les bonnes pratiques d’architecture AD.
# ==================================================================# -----------------------------------------------------------
# Ce script crée une structure Active Directory complète :
#  - Création d'une OU racine,
#  - Création de sous-OU pour chaque service,
#  - Création d'un groupe de sécurité pour chaque service,
#  - Création des utilisateurs à partir d'un fichier CSV,
#  - Ajout des utilisateurs dans le groupe correspondant à leur service.
#
# -----------------------------------------------------------

function Deploy-ADInfrastructure {

    # 1) On récupère le "Distinguished Name" (= l'identité unique dans AD) du domaine courant
    # Ex : "DC=srv2025,DC=local"
    $DomainDN = (Get-ADDomain).DistinguishedName

    # 2) On demande à l'utilisateur le nom de l'OU racine à créer (exemple : UBIJURISTE)
    $RootOU = Read-Host "Nom de l'OU racine (ex: UBIJURISTE)"

    # 3) On prépare le chemin LDAP complet pour cette OU racine (c'est l'adresse pour Active Directory)
    # Ex : "OU=UBIJURISTE,DC=srv2025,DC=local"
    $OUDN = "OU=$RootOU,$DomainDN"

    # 4) On vérifie si le dossier C:\CSV existe. C'est ici qu'on attend le fichier contenant les utilisateurs.
    $CSVDir = "C:\CSV"
    if (-not (Test-Path $CSVDir)) {
        Write-Error "Le dossier $CSVDir est introuvable. Créez-le et déposez le fichier CSV."
        return
    }

    # 5) On cherche le fichier 'fichier.csv' dans le dossier, et on prend le plus récent (important si plusieurs versions)
    $CSVFile = Get-ChildItem -Path $CSVDir -Filter "fichier.csv" |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1

    # 6) Vérifie qu'on a bien trouvé un fichier. Sinon, on arrête le script avec une erreur.
    if (-not $CSVFile) {
        Write-Error "Aucun fichier 'fichier.csv' trouvé dans $CSVDir."
        return
    }

    Write-Host "Fichier CSV sélectionné : $($CSVFile.FullName)"

    # 7) Lecture du fichier CSV. On gère les erreurs si le format est mauvais.
    try {
        # On précise le séparateur ';' (standard français)
        $Users = Import-Csv -Path $CSVFile.FullName -Delimiter ';' -Encoding UTF8
    } catch {
        Write-Error "Erreur de lecture du fichier CSV : $_"
        return
    }

    # 8) Demander à l'utilisateur le mot de passe qui sera attribué à tous les nouveaux comptes AD.
    $DefaultPwdClear = Read-Host "Mot de passe par défaut des utilisateurs"
    # On convertit ce mot de passe en format sécurisé (obligatoire pour AD)
    $DefaultPwd = ConvertTo-SecureString $DefaultPwdClear -AsPlainText -Force

    # 9) On met tous nos paramètres importants dans un hashtable "context", c'est plus pratique si le script devient gros.
    $context = @{
        DomainDN = $DomainDN      # Chemin du domaine, ex : DC=srv2025,DC=local
        RootOU   = $RootOU        # Nom choisi par l'utilisateur, ex : UBIJURISTE
        RootPath = $OUDN          # Chemin LDAP complet de l'OU racine
        Password = $DefaultPwd    # Mot de passe sécurisé par défaut
    }

    # ---------- Création de l'OU racine si elle n'existe pas déjà ----------
    # On cherche si une OU avec ce nom existe déjà à la racine du domaine.
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(OU=$($context.RootOU))" -ErrorAction SilentlyContinue)) {
        # Si non, on la crée !
        New-ADOrganizationalUnit -Name $context.RootOU -Path $context.DomainDN -ProtectedFromAccidentalDeletion:$false
        Write-Host "OU racine créée : $($context.RootOU)"
    } else {
        # Sinon, information à l'utilisateur
        Write-Host "OU racine déjà existante : $($context.RootOU)"

        return  Write-Host "Programme stop"
    }

    # ---------- Création des OU de service et groupe de sécurité ----------
    # On parcourt le fichier CSV pour trouver tous les "service" à créer,
    # On retire les doublons et on les trie pour plus de clarté.
    $services = $Users.service | Where-Object { $_ } | Sort-Object -Unique

    foreach ($srv in $services) {
        # Chemin LDAP complet pour ce service, ex : "OU=Accueil,OU=UBIJURISTE,DC=srv2025,DC=local"
        $srvPath = "OU=$srv,$($context.RootPath)"

        # Cherche si l'OU de service existe déjà
        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(OU=$srv)" -SearchBase $context.RootPath -ErrorAction SilentlyContinue)) {
            # Si non, la crée.
            New-ADOrganizationalUnit -Name $srv -Path $context.RootPath -ProtectedFromAccidentalDeletion:$false
            Write-Host "OU créée : $srv"
        }
        # Crée le groupe de sécurité AGDLP pour ce service (principe : chaque service a son groupe)
        $ggName = "GG_$srv"
        # Cherche si le groupe existe déjà dans cette OU
        if (-not (Get-ADGroup -LDAPFilter "(CN=$ggName)" -SearchBase $srvPath -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $ggName -GroupScope Global -GroupCategory Security -Path $srvPath
            Write-Host "Groupe créé : $ggName"
        }
    }

    # ---------- Création des comptes utilisateurs ----------
    foreach ($user in $Users) {
        # On extrait les infos principales de chaque ligne du CSV
        $Nom      = $user.nom
        $Prenom   = $user.prenom
        $Service  = $user.service
        $Fonction = $user.fonction

        # Si une des infos obligatoires manque, on affiche un avertissement et on passe au suivant
        if (-not ($Nom -and $Prenom -and $Service)) {
            Write-Warning "Données obligatoires manquantes : $($user | ConvertTo-Json -Compress)"
            continue
        }

        # On crée le login en concaténant les 3 lettres du prénom + nom, tout en minuscule
        # ex : Philippe Halle -> phi.halle
        $Login = ("{0}.{1}" -f $Prenom.Substring(0, [Math]::Min(3, $Prenom.Length)), $Nom).ToLower()

        # On génère l'email pour l'utilisateur, basé sur le login
        $Mail  = "$Login@srv2025.local"

        # Chemin LDAP de l'OU du service
        $OUPath = "OU=$Service,$($context.RootPath)"

        # Nom du groupe global
        $GGName = "GG_$Service"

        # Vérifie si ce login existe déjà dans AD, pour éviter les doublons
        if (Get-ADUser -Filter "SamAccountName -eq '$Login'" -ErrorAction SilentlyContinue) {
            Write-Host "Utilisateur $Login déjà existant."
            continue
        }

        # On essaye de créer le compte utilisateur AD
        try {
            New-ADUser -Name "$Prenom $Nom" `
                       -GivenName $Prenom `
                       -Surname $Nom `
                       -SamAccountName $Login `
                       -UserPrincipalName "$Login@srv2025.local" `
                       -EmailAddress $Mail `
                       -Title $Fonction `
                       -Path $OUPath `
                       -AccountPassword $context.Password `
                       -ChangePasswordAtLogon $true `
                       -Enabled $true
            Write-Host "Utilisateur créé : $Login"

            # On ajoute l'utilisateur à son groupe de service
            Add-ADGroupMember -Identity $GGName -Members $Login -ErrorAction SilentlyContinue
        } catch {
            # Si une erreur arrive, on l'affiche (très utile en dépannage)
            Write-Warning "Erreur lors de la création de $Login : $_"
        }
    }

    Write-Host "`nDéploiement complet terminé 🏁"
}

# ---------- Lancement du script principal ----------
choix