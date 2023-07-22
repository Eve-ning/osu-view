#!/bin/bash

usage="$(basename "$0") [RUN_TAG] [-d DB_URL] [-f FILES_URL] [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH]

Argument:
  RUN_TAG   Run tag is a name to identify the current run in future runs.
            This will be used as the name of a directory.
            E.g. my_experiment will create osu.view/sr-calc/my_experiment to store all results.

Options:
  -h     Display this help.
  -v     Game Mode and Version: {MODE}_{VERSION}
         MODE    is either 'osu', 'mania', 'catch' or 'taiko'.
         VERSION is either 'top_1000', 'top_10000' or 'random_10000'
         E.g. 'osu_top_1000'.
  -d     Date in the format YYYY_MM_DD.    Default: $(date '+%Y_%m_01') (1st of this Month)
  -o (0) osu! game git link.               Default: https://github.com/ppy/osu
  -o (1) osu! game git branch name.        Default: master
  -t (0) osu! tools git link.              Default: https://github.com/ppy/osu-tools
  -t (1) osu! tools git branch name.       Default: master

  Use these options if you need more control
  -y     https://data.ppy.sh Database URL. Example: https://data.ppy.sh/$(date '+%Y_%m_01')_performance_<VERSION>.tar.bz2
         Overrides -v and -d
  -z     https://data.ppy.sh Files URL.    Example: https://data.ppy.sh/$(date '+%Y_%m_01')_osu_files.tar.bz2
         Overrides -d

Examples:
  Use the most recent data ($(date '+%Y_%m_01')) for catch top 1000

    $(basename "$0") my_experiment \\
      -v catch_top_1000

  Use a custom date. (It must exist in https://data.ppy.sh!)

    $(basename "$0") my_experiment \\
      -v catch_top_1000 \\
      -d 2023_05_01

  Use a custom /osu and /osu-tools git

    $(basename "$0") my_experiment \\
      -v catch_top_1000 \\
      -o https://github.com/Eve-ning/osu \\
      -o my_branch \\
      -t https://github.com/Eve-ning/osu-tools \\
      -t my_branch

  Use a custom database and files URL. This will override any -v and -d options.

    $(basename "$0") my_experiment \\
      -y https://github.com/Eve-ning/osu-data-docker/raw/master/rsc/YYYY_MM_DD_performance_mania_top_1000.tar.bz2 \\
      -z https://github.com/Eve-ning/osu-data-docker/raw/master/rsc/YYYY_MM_DD_osu_files.tar.bz2
"

while getopts "hv:d:o:t:y:z:" opt; do
  case $opt in
  h)
    echo "$usage"
    exit
    ;;
  v) VERSION=$OPTARG ;;
  d) DATASET_DATE=$OPTARG ;;
  o) OSU_GIT_OPTS+=("$OPTARG") ;;
  t) OSU_TOOLS_GIT_OPTS+=("$OPTARG") ;;
  y) DB_URL=$OPTARG ;;
  z) FILES_URL=$OPTARG ;;
  *)
    echo "Invalid Argument"
    exit 1
    ;;
  esac
done

# Normalize all values
OSU_GIT=${OSU_GIT_OPTS[0]:='https://github.com/ppy/osu'}
OSU_GIT_BRANCH=${OSU_GIT_OPTS[1]:='master'}
OSU_TOOLS_GIT=${OSU_TOOLS_GIT_OPTS[0]:='https://github.com/ppy/osu-tools'}
OSU_TOOLS_GIT_BRANCH=${OSU_TOOLS_GIT_OPTS[1]:='master'}
DATASET_DATE=${DATASET_DATE:="$(date '+%Y_%m_01')"}
DB_URL=${DB_URL:="https://data.ppy.sh/${DATASET_DATE}_performance_${VERSION}.tar.bz2"}
FILES_URL=${FILES_URL:="https://data.ppy.sh/${DATASET_DATE}_osu_files.tar.bz2"}

# Check if all the inputs are correctly specified
BAD_INPUT=0

echo -n "Check validity of $DB_URL: "
if ! curl --output /dev/null --silent --head --fail "$DB_URL"; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else
  echo ""
fi

echo -n "Check validity of $FILES_URL: "
if ! curl --output /dev/null --silent --head --fail "$FILES_URL"; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else
  echo ""
fi

echo -n "Check validity of $OSU_GIT @ $OSU_GIT_BRANCH: "
git ls-remote --heads "${OSU_GIT}" "${OSU_GIT_BRANCH}" | grep "${OSU_GIT_BRANCH}" >/dev/null
if [ "$?" == "1" ]; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else
  echo ""
fi

echo -n "Check validity of $OSU_TOOLS_GIT @ $OSU_TOOLS_GIT_BRANCH: "
git ls-remote --heads "${OSU_TOOLS_GIT}" "${OSU_TOOLS_GIT_BRANCH}" | grep "${OSU_TOOLS_GIT_BRANCH}" >/dev/null
if [ "$?" == "1" ]; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  BAD_INPUT=1
else
  echo ""
fi

if [ "$BAD_INPUT" == "1" ]; then
  echo -e "\e[31mInvalid Input. See above errors\e[0m"
  echo "$usage"
  exit 1
fi

# Print out the configuration
echo "Configuration:
  RUN_TAG=$RUN_TAG
  DB_URL=$DB_URL
  FILES_URL=$FILES_URL
  OSU_GIT=$OSU_GIT
  OSU_GIT_BRANCH=$OSU_GIT_BRANCH
  OSU_TOOLS_GIT=$OSU_TOOLS_GIT
  OSU_TOOLS_GIT_BRANCH=$OSU_TOOLS_GIT_BRANCH
"


