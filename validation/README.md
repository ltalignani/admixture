# Validation OpenADMIXTURE (Apple Silicon) contre ADMIXTURE 1.3 (x86)

Ce dossier contient les jeux de test utilisés pendant le portage, les résultats
d'OpenADMIXTURE sur ce Mac, et les scripts pour produire les mêmes résultats
avec le binaire ADMIXTURE 1.3 sur une machine Linux x86, puis les comparer.

## Jeux de données (`data/`)

| Fichier | Individus × SNP | Contenu | Usage |
|---|---|---|---|
| `eur.{bed,bim,fam}` | 379 × 54 051 | Données réelles 1000 Genomes, 5 populations européennes, chromosomes 17–22 (jeu `EUR_subset` du paquet Julia SnpArrays) | **comparaison principale** |
| `eur_2000snp.{bed,bim,fam}` | 379 × 2 000 | Sous-échantillon aléatoire de `eur` (`plink2 --thin-count 2000 --seed 1`) | cas qui faisait planter `--cv` dans Moira |
| `mini.{bed,bim,fam}` + `mini.trueQ` | 300 × 5 000 | Simulé, K = 3, vraies proportions dans `mini.trueQ` | test rapide avec vérité connue |
| `sim.{bed,bim,fam}` + `sim.trueQ` | 2 000 × 200 000 | Simulé, K = 4 (Balding-Nichols, F_ST = 0,1 ; Q ~ Dirichlet(0,5)) | benchmark de vitesse (100 Mo) |
| `sim.py` | | Script de simulation (`python sim.py N M K préfixe`, graine 1) | |
| `eur.ind2pop` | | Population de chaque individu de `eur.fam`, même ordre | pong |
| `eur.pop_order` | | Ordre et noms des populations pour pong | pong |
| `1000G_panel.txt`, `1000G_g1k.ped` | | Fichiers d'échantillons 1000 Genomes (phase 3 et pedigree complet) | origine des étiquettes |

Populations de `eur` : CEU 85, FIN 93, GBR 89, IBS 14, TSI 98. 15 individus
(dont NA20537, HG00104…) ne figurent que dans le pedigree complet, pas dans le
panel de la phase 3 (retirés en phase 3) ; leur population vient de
`1000G_g1k.ped`.

Les codes de chromosome de `eur.bim` sont des entiers (17–22), donc ADMIXTURE
les accepte tels quels.

Sommes MD5 (pour vérifier la copie vers la machine x86) :

```
eur.bed          f5551ba6bee452dd9e7840972f59fd9c
eur.bim          4d4be7cee39fa7e889d6cdd7d641d45e
eur.fam          778942e2d1f40bdfb70f8e4086011e24
eur_2000snp.bed  c58f2f485f28790429cca70774112936
mini.bed         d0d2aad215010175b5be60bc234aa001
sim.bed          0450e346e334ad3a4474942930ef8e18
```

## Lancer ADMIXTURE x86

Copier tout le dossier `validation/` sur la machine Linux x86 (`sim.*` est
facultatif), puis :

```bash
cd validation
md5sum data/eur.bed                     # doit donner f5551ba6…
./run_admixture.sh /chemin/vers/admixture data/eur.bed runs/admixture_x86_eur 8 4 6
```

Arguments : binaire, jeu de données, dossier de sortie, K maximum (8), threads par
run (4), runs en parallèle (6). Le script lance K = 1 à 8 avec les graines 1 à 5,
toujours avec `--cv` (5 plis), soit 40 runs. Chaque run a son dossier
`K{K}/s{graine}/` avec `run.log` et les fichiers `.Q` et `.P`.
`summary.tsv` réunit log-vraisemblance, erreur de CV et durée. Un run
interrompu est relancé à l'appel suivant ; les runs terminés sont conservés.

Les mêmes commandes ont produit `runs/openadmixture_eur/` sur ce Mac (binaire
`openadmixture`).

## Lancer ADMIXTURE x86 sous Slurm (cluster iTrop)

Envoi depuis le Mac. La clé `~/.ssh/id_rsa_itrop` et les alias `itrop`
(bioinfo-master1, soumission) et `itrop-san` (bioinfo-san, transferts) sont
dans `~/.ssh/config`. iTrop demande de passer par bioinfo-san pour les
transferts.

```bash
cd /Users/loic/admixture/validation
rsync -av --exclude runs/ --exclude 'sim.bed' --exclude 'sim.bim' --exclude 'sim.fam' --exclude 'sim.trueQ' \
  ./ itrop-san:/scratch-ib/admixture-tests/
```

(Les exclusions laissent de côté le jeu de benchmark de 100 Mo.)

Sur le cluster (`ssh itrop`) :

```bash
cd /scratch-ib/admixture-tests
md5sum data/eur.bed                     # f5551ba6…
MODULES="bioinfo-itrop admixture/1.3.0" slurm/submit.sh admixture data/eur.bed runs/admixture_x86_eur
squeue -u $USER
```

Particularités d'iTrop :
- les modules d'i-Trop ne sont visibles qu'après `module load bioinfo-itrop` ;
- `/scratch-ib` n'est monté que sur les nœuds des partitions `normal` et
  `supermem` (vérifié le 15/11/2026). Sur `short`, `long` et `highmem`, le
  dossier existe mais il est vide. Il faut donc garder la partition `normal`,
  qui est celle par défaut ;
- le quota de `/home` est plein : tout doit rester dans `/scratch-ib`.

`slurm/submit.sh <binaire> <data.bed> <sortie> [KMAX=8] [THREADS=4] [PARTITION=normal]`
soumet un job array de 40 tâches, une par couple (K, graine), chacune avec
`--cv` sur `THREADS` cœurs. Un second job, qui part quand toutes les tâches sont
finies (`afterany`), écrit `summary.tsv`. Les journaux Slurm sont dans
`<sortie>/slurm_logs/`. Les mêmes dossiers `K{K}/s{graine}/` que
`run_admixture.sh` sont utilisés, donc `make_pong.sh` fonctionne tel quel.

Variables facultatives :
- `MODULES` : modules chargés dans chaque tâche ;
- `MAXPAR` : nombre de tâches simultanées (20 par défaut) ;
- `SBATCH_EXTRA` : options sbatch en plus, par exemple `--account=…` ou
  `--time=12:00:00`.

Chaque tâche demande 4 Go et 4 h par défaut (en-tête de
`slurm/admixture_array.sbatch`). Une nouvelle soumission saute les runs qui ont
déjà un fichier `done`. `summarize_runs.sh <sortie>` reconstruit le tableau à la
main.

Pour la figure, rapatrier les résultats sur le Mac, où pong et Chrome sont
installés :

```bash
rsync -av itrop-san:/scratch-ib/admixture-tests/runs/admixture_x86_eur runs/
./make_pong.sh runs/admixture_x86_eur data/eur.bed data/eur.ind2pop data/eur.pop_order
```

## Figure pong

```bash
./make_pong.sh runs/openadmixture_eur data/eur.bed data/eur.ind2pop data/eur.pop_order
./make_pong.sh runs/admixture_x86_eur  data/eur.bed data/eur.ind2pop data/eur.pop_order
```

Sorties dans `<runs>/pong/` :
- `pong.png` et `pong.pdf` : la figure ;
- `pong_output/` : résultats de pong (alignement des clusters, modes par K) ;
- `pong.log`.

Il faut l'environnement conda `pong` (`conda create -n pong python=3.10 && conda run -n pong pip install pong`)
et Google Chrome, qui sert à exporter la page web de pong. Pour explorer la
figure de façon interactive :
`conda run -n pong pong -m <runs>/pong/filemap.txt -i data/eur.ind2pop -n data/eur.pop_order`
puis ouvrir http://localhost:4000.

## Ce qu'il faut comparer

1. **`.Q`** : mêmes proportions à une permutation des colonnes près. pong aligne
   les deux jeux de runs si l'on met les deux dans un même `filemap.txt`.
2. **Log-vraisemblance** (`summary.tsv`) : les deux programmes maximisent la même
   vraisemblance, donc les meilleures valeurs par K doivent être très proches.
3. **Erreur de CV** : même formule, mais masquage des plis différent. Il faut
   comparer la forme de la courbe et le K choisi, pas les valeurs exactes.
4. **`.P`** : vérifier l'orientation des allèles. OpenADMIXTURE donne la
   fréquence de l'allèle A2 (colonne 6 du `.bim`). Si ADMIXTURE donne celle de
   A1, on aura P_x86 ≈ 1 − P_OpenADMIXTURE après alignement des colonnes.

## Résultats de la comparaison (24/11/2026)

ADMIXTURE 1.3.0 x86 (iTrop, 4 cœurs) contre OpenADMIXTURE 0.2.0 (Mac M3 Ultra),
K = 1 à 8 (1 à 6 pour `sim`), 5 graines, `--cv`. Tableaux détaillés :
`runs/openadmixture_<jeu>/compare_vs_admixture_x86_<jeu>.tsv`, produits par
`compare_runs.py` (pour les jeux sans vrai Q, passer `""` comme 4ᵉ argument).

**Log-vraisemblance et `.Q`** : à K = 1, identiques. Aux K bien identifiés
(K ≤ 4 sur `eur` et `sim`, K ≤ 3 sur `mini`, K ≤ 2 sur `eur_2000snp`), même
optimum : écart de log-vraisemblance < 0,02, RMSE des Q alignés ≤ 3·10⁻⁵. Au-delà,
chaque programme tombe sur des optimums locaux selon la graine, sans que l'un
soit systématiquement meilleur. Sur les simulations, l'erreur par rapport au
vrai Q est la même (`mini` K = 3 : 0,02509 ; `sim` K = 4 : 0,00574).

**Erreur de CV** : les deux choisissent le même K partout (`mini` 3, `sim` 4,
`eur` 2, `eur_2000snp` 1). Aux K bien identifiés, les CV moyennes diffèrent de
moins de 2·10⁻⁴. Aux K élevés, celle d'OpenADMIXTURE est un peu plus haute
(jusqu'à +0,01 sur `eur_2000snp` K = 8), ce qui ne change pas le K retenu.

**`.P`** : même orientation des allèles que ADMIXTURE (pas de 1 − P) ; RMSE
des P alignés < 10⁻⁵ aux K bien identifiés.

**`.Q_se` (bootstrap `-B200`)** : `slurm/bootstrap.sbatch` côté ADMIXTURE,
`compare_qse.py` pour la comparaison. ADMIXTURE fait un bootstrap par blocs de
10 Mb convertis en nombre de SNP (`eur` : 54 051 SNP sur 354,8 Mb → blocs de
1 524 SNP, affiché dans le log). OpenADMIXTURE prend par défaut la racine cubique
du nombre de SNP (38 pour `eur`), d'où des SE environ 2 fois plus petites sur
données réelles :

| `eur`, SE moyenne | ADMIXTURE | OA défaut (38 SNP) | OA SNP par SNP | OA `--bootstrap-block=1524` |
|---|---|---|---|---|
| K = 2 | 0,0951 | 0,0485 | 0,0195 | 0,0917 |
| K = 3 | 0,1141 | 0,0844 | 0,0316 | 0,1168 |

Avec la même longueur de bloc, les SE concordent (rapport médian 0,96 et 1,02,
corrélation 0,99). Sur `mini` (simulé, SNP indépendants), la longueur de bloc ne
change rien. ADMIXTURE plante sur `mini` : ses SNP couvrent 5 kb, moins qu'un
bloc de 10 Mb, et le bootstrap échoue au premier réplicat. ADMIXTURE écrit aussi
un fichier `.Q_bias`, qu'OpenADMIXTURE ne produit pas.
