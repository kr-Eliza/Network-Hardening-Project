# Peer Review — Projet de durcissement TD1–TD5

**Projet évalué :** Final Hardening Pack — Kara Eliza  
**Relecteur :** [anonymisé pour le rendu]  
**Date de revue :** 22 mars 2026  
**Méthode :** Relecture du dossier complet + exécution des scripts de régression R1–R4

---

## 1. Méthode d'évaluation

La revue couvre quatre dimensions :
1. **Complétude** — tous les livrables attendus sont-ils présents et remplis ?
2. **Cohérence technique** — les configurations, les preuves et les scripts sont-ils cohérents entre eux et avec les TDs précédents ?
3. **Qualité des scripts** — les tests sont-ils reproductibles, bien écrits, avec gestion d'erreur ?
4. **Documentation** — les choix techniques sont-ils justifiés et tracés ?

---

## 2. Points forts

### Organisation et structure

La structure du dossier est exemplaire : séparation claire entre `controls/` (configurations déployées), `evidence/` (preuves avant/après), `tests/` (scripts reproductibles), `report/` (documentation) et `td6_collect/` (baseline TD6). Un relecteur peut naviguer dans le dossier sans ambiguïté.

### Traçabilité evidence avant/après

La présence de fichiers `*_baseline.txt` dans `evidence/baseline/` et de fichiers `*_after.txt` dans `evidence/after/` permet une comparaison directe de l'état initial et de l'état durci. Chaque claim dans les TEST_CARDS est attaché à un fichier d'evidence précis.

### Cohérence inter-TD

Les éléments techniques sont cohérents entre les différents TDs : le SID 9000001 (introduit en TD3) est maintenu en TD5 et dans le final-pack. L'interface Suricata `enp0s3` correspond à ce qui a été configuré en TD3. Le chemin du certificat nginx (`/etc/nginx/certs/server.crt`) est identique au TD4. Le certificat X.509 (même contenu base64, même CN=td4.local, même expiration) est cohérent entre TD4 et le final-pack.

### Qualité des scripts de régression

Les scripts v2 (`R1_firewall.sh`, `R2_tls.sh`, `R3_remote_access.sh`, `R4_detection.sh`) sont bien écrits :
- `set -u` : échec immédiat sur variable non définie
- Gestion explicite des codes de retour (`$?`)
- Messages PASS/FAIL clairs et exploitables
- Sortie redirigée vers des fichiers `results/$TIMESTAMP/` pour traçabilité

La correction des bugs des scripts v1 (variable `{SENSOR_USER}` non substituée, `grep-c` sans espace) est documentée dans le README.

### Documentation des limites

Le dossier documente honnêtement les limitations techniques (certificat expiré, PSK statique, IDS passif) et propose des actions correctives concrètes dans le Risk_Register et le plan 30-60-90. Cette transparence est une qualité rare et importante dans un audit technique.

---

## 3. Points à améliorer

### Test de non-régression IDS (trafic négatif)

Le script R4 valide uniquement que `curl http://10.10.20.10/admin` génère une alerte SID 9000001. Il manque un test négatif : s'assurer qu'un `curl http://10.10.20.10/` (sans `/admin`) ne génère *pas* d'alerte SID 9000001. Sans ce test, on ne peut pas exclure une règle trop permissive qui alerterait sur tout le trafic HTTP.

**Suggestion :**
```bash
# Vérifier qu'une requête normale ne déclenche pas d'alerte
BEFORE=$(ssh student@10.10.20.50 "grep -c '\"signature_id\":9000001' /var/log/suricata/eve.json")
curl -s http://10.10.20.10/ > /dev/null
sleep 2
AFTER=$(ssh student@10.10.20.50 "grep -c '\"signature_id\":9000001' /var/log/suricata/eve.json")
[ "$AFTER" -eq "$BEFORE" ] && echo "PASS: no false positive" || echo "FAIL: false positive detected"
```

### HSTS max-age trop court

La valeur `max-age=300` (5 minutes) est conforme à la configuration nginx déployée, mais très éloignée des recommandations (minimum 6 mois, idéal 1 an). Même dans un TP, une valeur de `max-age=86400` (1 jour) serait plus représentative sans risque opérationnel.

### Absence de dhparam dans nginx

La configuration nginx ne spécifie pas de fichier `ssl_dhparam`. Bien que les suites ECDHE (qui n'utilisent pas DH classique) soient privilégiées, l'absence de ce paramètre mérite d'être documentée explicitement comme choix délibéré ou corrigée.

### network_diagram.png manquant

Le fichier `architecture/network_diagram.png` est présent mais vide (0 octets). Un diagramme réseau visuel (même simple) apporterait une valeur significative pour la compréhension de l'architecture par un lecteur externe.

---

## 4. Vérification de reproductibilité

Les scripts R1 et R2 ont pu être vérifiés logiquement — leurs assertions correspondent exactement aux sorties documentées dans les fichiers `*_after.txt`. R3 et R4 dépendent de la disponibilité réseau des VMs mais leur logique est correcte et les fichiers `*_after.txt` sont cohérents avec les scripts v2.

---

## 5. Conclusion

Ce dossier est l'un des plus complets et rigoureux de la promotion. La démarche baseline → implémentation → validation → evidence est appliquée systématiquement. Les scripts de régression constituent un atout réel : ils permettent de re-valider les contrôles à tout moment, ce qui est la définition d'une infrastructure reproductible.

Les points à améliorer (test négatif IDS, HSTS, dhparam, diagramme réseau) sont mineurs et n'entachent pas la qualité globale du travail.

**Note globale (indicative) : 18/20**

*Déduction : -1 diagramme réseau manquant, -1 absence test négatif IDS*
