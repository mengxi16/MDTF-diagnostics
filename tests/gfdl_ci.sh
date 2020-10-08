#!/usr/bin/env bash
#SBATCH --job-name=MDTF-CI
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --output=$HOME/mdtf_ci/%x.%j.out
#SBATCH --constraint=bigmem

# Manual script for "CI" testing of MDTF-diagnostics within GFDL firewall.
# Intended to be submitted as a slurm job from analysis.
# Takes one optional argument, the name of the POD to test; otherwise runs all
# PODs in develop branch.

set -Eeo pipefail
set -xv

REPO_NAME="MDTF-diagnostics"
# use conda envs, data from MDTeam installation
MDTEAM_MDTF="/home/mdteam/DET/analysis/mdtf/${REPO_NAME}"

DEFAULT_POD="all"
DEFAULT_BRANCH="feature/gfdl-data"

# parse aruments manually
while (( "$#" )); do
    case "$1" in
        -p|--pod)
            if [ -n "$2" ]; then
                POD="$2"
            fi
            shift 2
            ;;
        -b|--branch)
            if [ -n "$2" ]; then
                BRANCH="$2"
            fi
            shift 2
            ;;
        -?*)
            echo "$0: Unknown option (ignored): $1\n" >&2
            shift 1
            ;;
        *) # Default case: No more options, so break out of the loop.
            break
    esac
done
if [ -z "$POD" ]; then
    POD="$DEFAULT_POD"
fi
if [ -z "$BRANCH" ]; then
    BRANCH="$DEFAULT_BRANCH"
fi

# module load git

# checkout requested branch into $TMPDIR
cd $TMPDIR
git clone --depth 1 --recursive "https://gitlab.gfdl.noaa.gov/thomas.jackson/${REPO_NAME}.git"
cd "$REPO_NAME"
# check if requested branch exists.
git show-ref --verify --quiet "refs/heads/$BRANCH" || error_code=$?
if [ "${error_code}" -eq 0 ]; then
    git checkout "$BRANCH"
else
    echo "ERROR: can't find branch `$BRANCH`, using `$DEFAULT_BRANCH`" >&2
    git checkout "$DEFAULT_BRANCH"
fi
# check if requested POD exists
if [[ "$POD" != "$DEFAULT_POD" && ! -d "diagnostics/${POD}" ]]; then
    echo "ERROR: can't find POD `$POD`, instead using default `$DEFAULT_POD`" >&2
    POD="$DEFAULT_POD"
fi

if [ ! -d "$MDTEAM_MDTF" ]; then
    echo "ERROR: can't find MDTeam install at ${MDTEAM_MDTF}" 1>&2
    exit 1
fi
source "${MDTEAM_MDTF}/src/conda/conda_init.sh" "/home/mdteam/anaconda"
conda activate "${MDTEAM_MDTF}/envs/_MDTF_base"

# run script
/usr/bin/env python -m src.mdtf_gfdl -f "${MDTEAM_MDTF}/tests/gfdl_ci_config.jsonc" --pods "$POD" -- 
