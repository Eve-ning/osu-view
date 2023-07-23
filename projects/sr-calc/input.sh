#!/bin/bash

usage="Usage: $(basename "$0") [-v MODE_VERSION] [-d DATA_DATE] [-r RUN_TAG] [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH] [-e ENV_PATH ]
       $(basename "$0") [-y DATABASE_URL] [-z FILES_URL] [-r RUN_TAG] [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH] [-e ENV_PATH ]


Options:
  -h     Display this help.
  -v     MODE_VERSION: E.g. 'osu_top_1000'.
         - MODE               is either 'osu', 'mania', 'catch' or 'taiko'.
         - VERSION            is either 'top_1000', 'top_10000' or 'random_10000'
  -r     RUN_TAG              identifier of this run       Default: $(date '+%Y_%m_%d_%H_%M_%S') (Current Date Time)
  -d     DATA_DATE            in the format YYYY_MM_DD.    Default: $(date '+%Y_%m_01') (1st of this Month)
  -o (0) OSU_GIT              osu! game git link.          Default: https://github.com/ppy/osu
  -o (1) OSU_GIT_BRANCH       osu! game git branch name.   Default: master
  -t (0) OSU_TOOLS_GIT        osu! tools git link.         Default: https://github.com/ppy/osu-tools
  -t (1) OSU_TOOLS_GIT_BRANCH osu! tools git branch name.  Default: master
  -e     ENV_PATH             path to .env file            Default: /tmp/sr-calc/.env

  Use these options if you need more control
  -y     https://data.ppy.sh Database URL. Example: https://data.ppy.sh/$(date '+%Y_%m_01')_performance_<VERSION>.tar.bz2
         Overrides -v and -d
  -z     https://data.ppy.sh Files URL.    Example: https://data.ppy.sh/$(date '+%Y_%m_01')_osu_files.tar.bz2
         Overrides -d

Examples:
  Use the most recent data ($(date '+%Y_%m_01')) for catch top 1000. Name it 'my_run'.

    $(basename "$0") -r my_run \\
      -v catch_top_1000

  Use a custom date. (It must exist in https://data.ppy.sh!)

    $(basename "$0") -r my_run \\
      -v catch_top_1000 \\
      -d 2023_05_01

  Use a custom /osu and /osu-tools git

    $(basename "$0") -r my_run \\
      -v catch_top_1000 \\
      -o https://github.com/Eve-ning/osu \\
      -o my_branch \\
      -t https://github.com/Eve-ning/osu-tools \\
      -t my_branch

  Use a custom database and files URL. This will override any -v and -d options.

    $(basename "$0") -r my_run \\
      -y https://github.com/Eve-ning/osu-data-docker/raw/master/rsc/YYYY_MM_DD_performance_mania_top_1000.tar.bz2 \\
      -z https://github.com/Eve-ning/osu-data-docker/raw/master/rsc/YYYY_MM_DD_osu_files.tar.bz2
"

while getopts "hv:r:d:o:t:y:z:e:" opt; do
  case $opt in
  h)
    echo "$usage"
    exit
    ;;
  v) VERSION=$OPTARG ;;
  r) RUN_TAG=$OPTARG ;;
  d) DATASET_DATE=$OPTARG ;;
  o) OSU_GIT_OPTS+=("$OPTARG") ;;
  t) OSU_TOOLS_GIT_OPTS+=("$OPTARG") ;;
  y) DB_URL=$OPTARG ;;
  z) FILES_URL=$OPTARG ;;
  e) ENV_PATH=$OPTARG ;;
  *)
    echo "Invalid Argument"
    exit 1
    ;;
  esac
done

# Normalize all values
RUN_TAG=${RUN_TAG:="run_$(date '+%Y_%m_%d.%H_%M_%S')"}
OSU_GIT=${OSU_GIT_OPTS[0]:='https://github.com/ppy/osu'}
OSU_GIT_BRANCH=${OSU_GIT_OPTS[1]:='master'}
OSU_TOOLS_GIT=${OSU_TOOLS_GIT_OPTS[0]:='https://github.com/ppy/osu-tools'}
OSU_TOOLS_GIT_BRANCH=${OSU_TOOLS_GIT_OPTS[1]:='master'}
DATASET_DATE=${DATASET_DATE:="$(date '+%Y_%m_01')"}
DB_URL=${DB_URL:="https://data.ppy.sh/${DATASET_DATE}_performance_${VERSION}.tar.bz2"}
FILES_URL=${FILES_URL:="https://data.ppy.sh/${DATASET_DATE}_osu_files.tar.bz2"}
ENV_PATH=${ENV_PATH:="/tmp/sr-calc/.env"}
# Input Validation
BAD_INPUT=0
echo "Input Validation: "
echo -n "  RUN_TAG=$RUN_TAG: "
if [ ! "$RUN_TAG" ]; then
  echo -e "\e[31mRUN_TAG IS MISSING!\e[0m"
  BAD_INPUT=1
else echo -e "\e[32mOK\e[0m"; fi

echo -n "  DB_URL=$DB_URL: "
if ! curl --output /dev/null --silent --head --fail "$DB_URL"; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else echo -e "\e[32mOK\e[0m"; fi

echo -n "  FILES_URL=$FILES_URL: "
if ! curl --output /dev/null --silent --head --fail "$FILES_URL"; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else echo -e "\e[32mOK\e[0m"; fi

echo -n "  OSU_GIT @ OSU_GIT_BRANCH=$OSU_GIT @ $OSU_GIT_BRANCH: "
git ls-remote --heads "${OSU_GIT}" "${OSU_GIT_BRANCH}" | grep "${OSU_GIT_BRANCH}" >/dev/null
if [ "$?" == "1" ]; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else echo -e "\e[32mOK\e[0m"; fi

echo -n "  OSU_TOOLS_GIT @ OSU_TOOLS_GIT_BRANCH=$OSU_TOOLS_GIT @ $OSU_TOOLS_GIT_BRANCH: "
git ls-remote --heads "${OSU_TOOLS_GIT}" "${OSU_TOOLS_GIT_BRANCH}" | grep "${OSU_TOOLS_GIT_BRANCH}" >/dev/null
if [ "$?" == "1" ]; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else echo -e "\e[32mOK\e[0m"; fi

echo -n "  ENV_PATH=$ENV_PATH: "
if [ ! "$ENV_PATH" ]; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else echo -e "\e[32mOK\e[0m"; fi

if [ "$BAD_INPUT" == "1" ]; then
  echo -e "\e[31mInvalid Input. See above errors\e[0m. See usage with -h"
  exit 1
fi

mkdir -p "$(dirname "$ENV_PATH")"

echo "RUN_TAG=$RUN_TAG
DB_URL=$DB_URL
FILES_URL=$FILES_URL
OSU_GIT=$OSU_GIT
OSU_GIT_BRANCH=$OSU_GIT_BRANCH
OSU_TOOLS_GIT=$OSU_TOOLS_GIT
OSU_TOOLS_GIT_BRANCH=$OSU_TOOLS_GIT_BRANCH" > "$ENV_PATH"

source ./run.sh

run