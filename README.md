# Wasteless Lab - AWS Test Environment

Infrastructure Terraform pour tester wasteless à moindre coût.

## 📊 Ressources créées

- 4x EC2 instances (1x active, 3x idle)
- 3x EBS volumes (2 orphaned)
- 1x VPC + networking
- (Optional) 1x RDS MySQL

## 💰 Coût

**Sans RDS** : ~€23-25/month  
**Avec RDS** : ~€38-40/month

**Économie** : Arrêter instances quand pas utilisées → ~€3/month (EBS seulement)

## 🚀 Déploiement

### Prérequis
```bash
# AWS CLI configuré
aws configure

# Terraform installé
terraform --version
```

### Étapes
```bash
# 1. Créer SSH key
aws ec2 create-key-pair \
  --key-name wasteless-lab \
  --query 'KeyMaterial' \
  --output text > wasteless-lab.pem

chmod 400 wasteless-lab.pem

# 2. Obtenir ton IP
curl ifconfig.me
# Ex: 82.123.45.67

# 3. Éditer terraform.tfvars
nano terraform.tfvars
# Mettre ton IP: your_ip = "82.123.45.67/32"

# 4. Initialiser Terraform
terraform init

# 5. Planifier
terraform plan

# 6. Déployer
terraform apply
```

## 🧪 Tests Wasteless

### Test 1 : Détection EC2 Idle
```bash
# Attendre 24h pour métriques CloudWatch

# Collecter métriques
python src/collectors/aws_cloudwatch.py

# Détecter waste
python src/detectors/ec2_idle.py

# Attendu : 3 instances idle détectées
# - dev-old-app
# - staging-forgotten  
# - test-ancient
```

### Test 2 : Whitelist Protection
```bash
# production-api a tag Critical=true
# Doit être IGNORÉ par détecteur

# Vérifier dans logs :
# "Instance i-xxx is WHITELISTED (tag Critical=true)"
```

### Test 3 : Auto-Remediation
```bash
# Activer dans config/remediation.yaml
auto_remediation:
  enabled: true

# Dry-run
python src/remediators/ec2_remediator.py

# Réel (arrête instances)
python -c "from src.remediators.ec2_remediator import EC2Remediator; \
EC2Remediator(dry_run=False).process_pending_recommendations()"
```

### Test 4 : EBS Orphaned
```bash
# Détacher volume temp_volume manuellement
aws ec2 detach-volume --volume-id vol-xxxxx

# Attendre 5 min

# Détecter (Phase 2)
# Attendu : 3 volumes orphaned
```

## 📋 Outputs

Après `terraform apply` :
```bash
# Voir toutes les instances
terraform output instances

# Voir commandes SSH
terraform output ssh_commands

# Voir estimation coûts
terraform output cost_estimate
```

## 🧹 Nettoyage
```bash
# Détruire TOUTES les ressources
terraform destroy

# Vérifier que tout est supprimé
aws ec2 describe-instances --filters "Name=tag:Project,Values=wasteless-lab"
```

## 💡 Tips

### Réduire coûts pendant tests
```bash
# Arrêter toutes instances (garde EBS)
aws ec2 stop-instances --instance-ids $(terraform output -json instances | jq -r '.production_api.id, .dev_old_app.id, .staging_forgotten.id, .test_ancient.id')

# Redémarrer pour tester
aws ec2 start-instances --instance-ids i-xxxxx
```

### Simuler instance TRÈS idle
```bash
# SSH dans instance
ssh -i wasteless-lab.pem ubuntu@

# Tuer tous processus sauf sshd
sudo pkill -9 stress-ng

# Vérifier CPU proche de 0%
top
```

## ⚠️ Sécurité

- SSH uniquement depuis ton IP
- Pas de ports publics ouverts
- RDS non accessible publiquement
- Credentials RDS à changer en prod

## 📊 Scénarios de test

| Scénario | Instance | Attendu |
|----------|----------|---------|
| Whitelist | production-api | IGNORÉ (Critical=true) |
| Idle high conf | test-ancient | DÉTECTÉ (CPU ~0%, ancien) |
| Idle medium | dev-old-app | DÉTECTÉ (CPU ~0%) |
| Idle medium | staging-forgotten | DÉTECTÉ (CPU ~0%) |
| Active | production-api | NON détecté (CPU 20%) |