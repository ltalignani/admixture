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
