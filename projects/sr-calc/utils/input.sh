#!/bin/bash
usage="\
Usage:
  If you don't have a custom database or files URL:
  $(basename "$0") [-v MODE_VERSION] [-d DATA_DATE] [-r RUN_TAG] [-q SQL_QUERY] \\
       [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH] [-e ENV_PATH]

  If you have a custom database or files URL:
  $(basename "$0") [-y DATABASE_URL] [-z FILES_URL] [-r RUN_TAG] [-q SQL_QUERY] \\
       [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH] [-e ENV_PATH]

  Depending on the use case, some options are required.
  E.g. if you're using 'sr-calc' using a MySQL query, then SQL_QUERY is expected.

Description:
  This script executes the osu-tools .NET  difficulty  module on queried beatmaps.

  There are 4 important layers in this script, followed by the options:
  1) DATA     : the MySQL database and osu files.
              : MODE_VERSION, DATA_DATE | DATABASE_URL, FILES_URL
  2) QUERY    : the SQL_QUERY used to extract osu files from the database
              : SQL_QUERY
  3) INFERENCE: the osu-tools .NET  difficulty  module.
              : OSU_GIT, OSU_GIT_BRANCH, OSU_TOOLS_GIT, OSU_TOOLS_GIT_BRANCH
  4) OUTPUT   : the output directory for the run.
              : RUN_TAG

  These 4 layers are decoupled, you can use completely different
  - DB and Files URLs
  - SQL Queries
  - osu-tools .NET  difficulty  module on different osu repos
  - Output directories

  See the 'Examples' section for more details.

Outputs:
  This script creates a directory for each run tagged with RUN_TAG (osu.view/sr-calc/[RUN_TAG])
  The directory contains the following files:
  - osu.view/sr-calc/[RUN_TAG]
    - files/            : the osu files queried from the database
      - __.osu          * Note: this dir is omitted if this run depends on an existing osu files directory
      - ...
    - dt.results.json   : DT difficulty results
    - ht.results.json   : HT difficulty results
    - nt.results.json   : NT difficulty results
    - docker-compose.yml: Configuration for osu.mysql and osu.files
    - .env              : Environment Variables supplied from the CLI
    - osu-data.env      : osu-data-docker Environment Variables
    - osu-tools.env     : osu-tools-docker Environment Variables
    - query.sql         : the SQL_QUERY used to extract osu files from the osu.mysql DB

  * Note that .env overwrites all osu-data.env and osu-tools.env variables.

Options:
  -h     Display this help.
  -v     MODE_VERSION: E.g. 'osu_top_1000'.
         - MODE               is either 'osu', 'mania', 'catch' or 'taiko'.
         - VERSION            is either 'top_1000', 'top_10000' or 'random_10000'
  -r     RUN_TAG              identifier of this run       Default: run_$(date '+%Y_%m_%d_%H_%M_%S') (Current Date Time)
  -d     DATA_DATE            in the format YYYY_MM_DD.    Default: $(date '+%Y_%m_01') (1st of this Month)
  -o (0) OSU_GIT              osu! game git link.          Default: https://github.com/ppy/osu
  -o (1) OSU_GIT_BRANCH       osu! game git branch name.   Default: master
  -t (0) OSU_TOOLS_GIT        osu! tools git link.         Default: https://github.com/ppy/osu-tools
  -t (1) OSU_TOOLS_GIT_BRANCH osu! tools git branch name.  Default: master
  -q     SQL_QUERY            MySQL Query to retrieve      Default: SELECT beatmap_id FROM osu_beatmaps WHERE playmode=3 AND approved=1 LIMIT 10;

  Use these options if you need more control
  -y     https://data.ppy.sh DATABASE_URL. Example: https://data.ppy.sh/$(date '+%Y_%m_01')_performance_<VERSION>.tar.bz2
         Overrides -v and -d
  -z     https://data.ppy.sh FILES_URL.    Example: https://data.ppy.sh/$(date '+%Y_%m_01')_osu_files.tar.bz2
         Overrides -d

Examples:
  Use the most recent data ($(date '+%Y_%m_01')) for catch top 1000. Name it 'my_run'.

    $(basename "$0") -r my_run \\
      -v catch_top_1000
      -q 'SELECT beatmap_id FROM osu_beatmaps WHERE playmode=2 LIMIT 10;'

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

while getopts "hv:r:d:o:t:y:z:e:q:" opt; do
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
  q) SQL_QUERY=$OPTARG ;;
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
SQL_QUERY=${SQL_QUERY:="SELECT beatmap_id FROM osu_beatmaps WHERE playmode=3 AND approved=1 LIMIT 10;"}

# Input Validation
echo -n "RUN_TAG=$RUN_TAG: "
if [ ! "$RUN_TAG" ]; then
  echo -e "\e[31mRUN_TAG IS MISSING!\e[0m"
  exit 1
else echo -e "\e[32mOK\e[0m"; fi

echo -n "ENV_PATH=$ENV_PATH: "
if [ ! "$ENV_PATH" ]; then
  echo -e "\e[31mDOES NOT EXIST!\e[0m"
  exit 1
else echo -e "\e[32mOK\e[0m"; fi

mkdir -p "$(dirname "$ENV_PATH")"

echo "RUN_TAG=$RUN_TAG
DB_URL=$DB_URL
FILES_URL=$FILES_URL
OSU_GIT=$OSU_GIT
OSU_GIT_BRANCH=$OSU_GIT_BRANCH
OSU_TOOLS_GIT=$OSU_TOOLS_GIT
OSU_TOOLS_GIT_BRANCH=$OSU_TOOLS_GIT_BRANCH" >"$ENV_PATH"

export VERSION
export RUN_TAG
export DATASET_DATE
export OSU_GIT
export OSU_GIT_BRANCH
export OSU_TOOLS_GIT
export OSU_TOOLS_GIT_BRANCH
export DB_URL
export FILES_URL
export ENV_PATH
export SQL_QUERY
