# Durcissement SSH — srv-web (10.10.20.10)

## Objectif

Restreindre l'accès SSH à l'authentification par clé publique uniquement, désactiver l'authentification par mot de passe, et limiter les utilisateurs autorisés.

## Modifications apportées à `/etc/ssh/sshd_config`

```
# Protocole
Protocol 2

# Authentification
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes

# Restriction des utilisateurs
AllowUsers admin1

# Timeouts et limites
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 5

# Désactivation de fonctionnalités inutiles
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitUserEnvironment no
PrintLastLog yes

# Bannière
Banner /etc/ssh/banner.txt
```

## Clé déployée

Type : ED25519 (générée pour ce TP)  
Fichier côté client : `/home/student/.ssh/id_td5`  
Fichier côté serveur : `/home/admin1/.ssh/authorized_keys`

```bash
# Génération (côté client)
ssh-keygen -t ed25519 -C "td5-kara" -f ~/.ssh/id_td5

# Déploiement (côté client)
ssh-copy-id -i ~/.ssh/id_td5.pub admin1@10.10.20.10
```

## Vérifications

```bash
# Test connexion par clé (doit réussir)
ssh -i ~/.ssh/id_td5 -o BatchMode=yes admin1@10.10.20.10 whoami
# → admin1

# Test connexion par mot de passe (doit échouer)
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password \
    -o BatchMode=yes admin1@10.10.20.10 whoami
# → Permission denied (publickey,password).
```

## Fichier banner

```
/etc/ssh/banner.txt :
-------------------------------------------------------------------
Accès restreint — Système de TP TD5
Toute connexion est journalisée.
Utilisateurs non autorisés : déconnectez-vous immédiatement.
-------------------------------------------------------------------
```

## Redémarrage du service

```bash
sudo systemctl restart ssh
sudo systemctl status ssh   # vérifier active (running)
```
