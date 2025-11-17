# ---- MODULE POUR SSH ----
Import-Module Posh-SSH -ErrorAction Stop

# ---- CONFIGURATION DES IDENTIFIANTS SSH ----
$ip = "10.200.200.50"      # Adresse IP du serv Linux
$port = 22                 # Port SSH
$user = "vlan99"           # Nom utilisateur
$plainPassword = "0000"    # Mot de passe SSH
$pass = ConvertTo-SecureString $plainPassword -AsPlainText -Force #secu du MDP
$credential = New-Object System.Management.Automation.PSCredential($user, $pass) #objet contenant user+MDP reutiliser dans la connexion

# ---- ETABLIR LA SESSION SSH ----
$session = $null
try {
    $session = New-SSHSession -ComputerName $ip -Port $port -Credential $credential -AcceptKey
    if ($session -and $session.SessionId) {  #SessionId = token coté session powershell pour connexion SSH
        Write-Host "Session SSH etablie."
    } else {
        Write-Host "Erreur : session SSH non etablie."
        exit
    }
} catch {
    Write-Host "Erreur SSH : impossible d'etablir la connexion."
    exit
}

try {
    # === ETAPE 2 : VERIFIER SI APACHE2 EST INSTALLE SUR LA MACHINE ===
    # Invoke-SSHCommand envoyer une commande a la machine distante (Linux).
    # SessionId, le serveur sait que c'est la meme session/connexion qui fait la demande (en gros il dit : "c'est encore moi qui passe !").
    # On verifie si le service apache2 :
    $outputStatusRaw = Invoke-SSHCommand -SessionId $session.SessionId -Command "systemctl status apache2 2>&1"
    $statusText = $outputStatusRaw.Output.Trim() # .Output reference ce que le serveur retourne, .Trim() enleve les espaces et retours a la ligne pour ne garder que le texte utile.

    # On verifie l'existence du service en cherchant "could not be found" dans la sortie
    if ($statusText -like "*could not be found*") {
        Write-Host "Le service apache2 n'est pas installe, installation requise..."

        # Test droits sudo en essayant une commande sudo sans effet
        $sudoTest = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo -n true 2>&1"
        Write-Host $sudoTest.Output

        if ($sudoTest.Output -match "not in the sudoers" -or $sudoTest.ExitStatus -ne 0) {
            Write-Host "L'utilisateur $user N'A PAS les droits sudo. Impossible d'installer."
            throw "Pas de droits sudo"
        } else {
            Write-Host "L'utilisateur $user a bien les droits sudo."
        }

        # --- TEST PRESENCE DU PAQUET ---
        $outputPackageRaw = Invoke-SSHCommand -SessionId $session.SessionId -Command "dpkg -l apache2 2>/dev/null | grep ^ii"
        Write-Host $outputPackageRaw.Output

        if (-not $outputPackageRaw.Output.Trim()) {
            Write-Host "Installation du paquet apache2 lancee avec sudo apt update et sudo apt install -y apache2"
            $aptUpdate = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo apt update"
            Write-Host $aptUpdate.Output
            $aptInstall = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo apt install -y apache2"
            Write-Host $aptInstall.Output
            Write-Host "Installation terminee, verification du service..."
        }
        # --- APRES INSTALLATION, VERIFIER LE STATUT DU SERVICE ---
        $postInstallStatus = Invoke-SSHCommand -SessionId $session.SessionId -Command "systemctl status apache2 2>&1"
        Write-Host $postInstallStatus.Output

        if ($postInstallStatus.Output.Trim() -like "*could not be found*") {
            Write-Host "Le service apache2 n'est toujours pas disponible apres installation."
        } else {
            Write-Host "Service apache2 installe, demarrage..."
            $startRes = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl start apache2"
            Write-Host $startRes.Output
            $outputStatus2 = Invoke-SSHCommand -SessionId $session.SessionId -Command "systemctl is-active apache2"
            if ($outputStatus2.Output.Trim() -eq "active") {
                Write-Host "apache2 installe et actif."
            } else {
                Write-Host "apache2 installe mais pas actif."
            }
        }
    }
    else {
        Write-Host "Le service apache2 existe sur la machine."

        # --- VERIFIER SI ACTIF OU PAS ---
        $outputActive = Invoke-SSHCommand -SessionId $session.SessionId -Command "systemctl is-active apache2"
        Write-Host $outputActive.Output
        $activeText = $outputActive.Output.Trim()
        if ($activeText -eq "active") {
            Write-Host "apache2 deja actif, tout est OK."
        } else {
            Write-Host "apache2 installe mais pas running, redemarrage..."
            $restartRes = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl restart apache2"
            Write-Host $restartRes.Output
            $outputActive2 = Invoke-SSHCommand -SessionId $session.SessionId -Command "systemctl is-active apache2"
            if ($outputActive2.Output.Trim() -eq "active") {
                Write-Host "apache2 demarre et running."
            } else {
                Write-Host "impossible de demarrer apache2."
            }
        }
    }
}
catch {
    Write-Host "Erreur lors de la verification ou de l'installation d'apache2 : $($_.Exception.Message)"
}
finally {
    # ---- FERMETURE DE LA SESSION SSH ----
    if ($session) {
        Remove-SSHSession -SessionId $session.SessionId
        Write-Host "Session SSH fermee."
    }
}

# ---- FIN DU SCRIPT ----
