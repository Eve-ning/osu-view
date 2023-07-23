#!/bin/bash

# This script executes the .NET `difficulty` module in osu-tools on beatmaps.
# Beatmaps evaluated can come from 3 sources
#   1) From files in the `osu.files` service via a MySQL Query: `query.sql`
#   2) From an external directory of *.osu files
#   3) From an internal directory of *.osu files (from previous runs of this script).
# The version of `osu-tools` and `osu` used depends on the `.env` file
#
# Usage: $ ./run.sh [RUN_TAG]
# The tag is used to identify the run, all results will be stored in $PROJECT/osu.view/sr-calc/[RUN_TAG]/
#
# If the docker services are already running, this will just use those services.
# However, note that it can cause replication issues, as we're not in control of the environment spun up.
#
# E.g.
# ./run.sh my_dir
# Will create
# osu.view/sr-calc/my_dir/files/           The directory for all `.osu` files
#                        /filelist.txt     The list of files in /files/ in txt
#                        /dt.results.json  Double Time Results of `difficulty`
#                        /nt.results.json  Normal Time "
#                        /ht.results.json  Half Time   "
#                        /osu-data.env     osu-data  Environment config, will not exist if custom services are used.
#                        /osu-tools.env    osu-tools "

check_overwrite() {
  local OVERWRITE=""
  local RUN_DIR="$1"
  if [ -d "$RUN_DIR" ]; then
    read -r -p "$RUN_DIR exists, overwrite it? [y/N]: " OVERWRITE
    if [ "$OVERWRITE" == "Y" ] || [ "$OVERWRITE" == "y" ]; then
      # Replace Directory if exists
      echo "Accepted Overwrite for $RUN_DIR"
      rm -rf "$RUN_DIR"
    else
      echo "Denied Overwrite, exit early"
      exit 1
    fi
  fi
  mkdir -p "$RUN_DIR"
}

select_result_dir() {
  echo ""
  echo "Pulling a large amount of .osu files can be slow."
  echo "Reuse .osu files by another result-set if the query is the same!"
  echo ""
  echo "Use an existing result-set's files or create a new result-set:"

  local RUN_DIR="$1"
  FILES_DIR=""
  CUSTOM_FILES=0

  # The long find command finds all directories that have the `files` directory. This is necessary to get the files data
  # We firstly find all directories in sr-calc which contain the `files` dir
  # Then reverse it, so that `cut` can take the element from the back
  # Reverse it again after cut.
  select opt in "[NEW]" "[External Directory]" \
    $(find "$RUN_DIR"/.. -type d -name 'files' | rev | cut -d "/" -f 2 | rev); do
    [ -n "${opt}" ] && break
  done

  # If New, we'll run the query, then extract matching files
  if [ "$opt" == "[NEW]" ]; then
    FILES_DIR="$RUN_DIR"/files
    echo "Using new files dir $FILES_DIR"
    CUSTOM_FILES=0

  # If External, we'll skip the query and file copying, we'll just run difficulty on this new dir.
  elif [ "$opt" == "[External Directory]" ]; then
    echo If you use a relative directory, you are at "$(pwd)"
    read -r -p "Your *.osu files directory: " EXT_FILES_DIR
    while [ ! -d "$EXT_FILES_DIR" ]; do
      echo "$EXT_FILES_DIR" is not a directory
      read -r -p "Your *.osu files directory: " EXT_FILES_DIR
    done
    echo "Found $(find "$EXT_FILES_DIR" -name "*.osu" | wc -l) *.osu files in $FILES_DIR"
    FILES_DIR="$RUN_DIR"/files
    mkdir "$FILES_DIR"
    echo "Copying over files from $EXT_FILES_DIR to $FILES_DIR/"
    cp "$EXT_FILES_DIR"/*.osu "$FILES_DIR"/
    CUSTOM_FILES=1
  # Else, we'll just use files from an existing result
  else
    FILES_DIR="$RUN_DIR/../${opt}/files"
    CUSTOM_FILES=1
    echo -e "\e[34mUsing custom files dir $FILES_DIR\e[0m"
    if [ ! -d "$FILES_DIR" ]; then
      echo "Files Directory does not exist."
      exit 1
    fi
  fi

}

start_docker() {
  local ENV_PATH="$1"
  local CUSTOM_FILES="$2"

  if [ "$CUSTOM_FILES" -eq 0 ]; then
    docker compose \
      --project-directory ./ \
      --profile files \
      -f "$PROJ_DIR"/docker-compose.yml \
      --env-file ./osu-data-docker/.env \
      --env-file ./osu-tools-docker/.env \
      --env-file "$ENV_PATH" \
      up --wait --build
  else
    docker compose \
      --project-directory ./ \
      --profile files \
      -f "$PROJ_DIR"/docker-compose.yml \
      --env-file ./osu-data-docker/.env \
      --env-file ./osu-tools-docker/.env \
      --env-file "$ENV_PATH" \
      up --wait --build osu.tools
  fi
}

stop_docker() {
  local ENV_PATH=$1
  docker compose \
    --project-directory ./ \
    --profile files \
    -f "$PROJ_DIR"/docker-compose.yml \
    --env-file ./osu-data-docker/.env \
    --env-file ./osu-tools-docker/.env \
    --env-file "$ENV_PATH" \
    stop
}

run_query() {
  # Pull file list according to query
  local FILELIST_PATH="$1"
  local FILES_DIR="$2"
  local MYSQL_PASSWORD="$3"
  docker exec osu.mysql mysql -u root --password="$MYSQL_PASSWORD" \
    -D osu -N -e "$(cat "$PROJ_DIR"/query.sql)" \
    >"$FILELIST_PATH"

  # Get osu.files dir name dynamically
  local OSU_FILES_DIRNAME=""
  OSU_FILES_DIRNAME="$(docker exec osu.files ls)"

  # Create a temporary directory to copy all files to send to tar.
  echo "Moving Files to /$FILES_DIR/"
  docker exec osu.files sh -c \
    'mkdir -p /'"$FILES_DIR"'/;
    while read beatmap_id;
    do cp /osu.files/'"$OSU_FILES_DIRNAME"'/"$beatmap_id".osu /'"$FILES_DIR"'/"$beatmap_id".osu;
    done < /'"$FILELIST_PATH"';'
}

copy_configs() {
  local CUSTOM_FILES="$1"
  local CUSTOM_SERVICES="$2"
  local RUN_DIR="$3"
  local PROJ_DIR="$4"
  local ENV_PATH="$5"

  if [ "$CUSTOM_FILES" -eq 1 ]; then
    echo -e "\e[33mAs you used a custom fileset, query.sql will not be copied over.\e[0m"
  else
    cp "$PROJ_DIR"/query.sql "$RUN_DIR"/query.sql
  fi

  if [ "$CUSTOM_SERVICES" -eq 1 ]; then
    echo -e "\e[33mAs you used a custom service, docker-compose.yml and .env files will not be copied over.\e[0m"
  else
    cp "$PROJ_DIR"/docker-compose.yml "$RUN_DIR"/
    cp ./osu-data-docker/.env "$RUN_DIR"/osu-data.env
    cp ./osu-tools-docker/.env "$RUN_DIR"/osu-tools.env
    cp "$ENV_PATH" "$RUN_DIR"/sr-calc.env
    echo "Stopping Services"
    stop_docker $ENV_PATH
  fi
}

evaluate_maps() {
  local FILES_DIR="$1"
  local NT_RESULTS_PATH="$2"
  local DT_RESULTS_PATH="$3"
  local HT_RESULTS_PATH="$4"

  # Evaluate beatmaps via osu.tools
  docker exec osu.tools sh -c \
    '
  echo -n "Evaluating Beatmaps (Normal Time): ";
  dotnet PerformanceCalculator.dll difficulty "/'"$FILES_DIR"'" -j -o "/'"$NT_RESULTS_PATH"'" >> /dev/null;
  echo "Exported to '"$NT_RESULTS_PATH"'";

  echo -n "Evaluating Beatmaps (Double Time): ";
  dotnet PerformanceCalculator.dll difficulty "/'"$FILES_DIR"'" -j -m dt -o "/'"$DT_RESULTS_PATH"'" >> /dev/null;
  echo "Exported to '"$DT_RESULTS_PATH"'";

  echo -n "Evaluating Beatmaps (Half Time): ";
  dotnet PerformanceCalculator.dll difficulty "/'"$FILES_DIR"'" -j -m ht -o "/'"$HT_RESULTS_PATH"'" >> /dev/null;
  echo "Exported to '"$HT_RESULTS_PATH"'";
  '
}

run() {
  RUN_DIR=osu.view/sr-calc/"$RUN_TAG"
  PROJ_DIR="$(pwd)"
  MYSQL_PASSWORD="p@ssw0rd1"
  FILELIST_PATH="$RUN_DIR"/filelist.txt
  NT_RESULTS_PATH="$RUN_DIR"/nt.results.json
  DT_RESULTS_PATH="$RUN_DIR"/dt.results.json
  HT_RESULTS_PATH="$RUN_DIR"/ht.results.json

  echo -n -e "\e[34mNavigating to Project Home: \e[0m"
  cd ../../
  pwd

  check_overwrite "$RUN_DIR"
  select_result_dir "$RUN_DIR"

  if docker ps | grep -q osu.mysql && docker ps | grep -q osu.files; then
    CUSTOM_SERVICES=1
    echo -e "\e[33mServices are already running, will use current services.\e[0m"
  else
    CUSTOM_SERVICES=0
    start_docker "$ENV_PATH" "$CUSTOM_FILES"
  fi

  if [ "$CUSTOM_FILES" -eq 0 ]; then
    run_query "$FILELIST_PATH" "$FILES_DIR" "$MYSQL_PASSWORD"
  fi

  evaluate_maps "$FILES_DIR" "$NT_RESULTS_PATH" "$DT_RESULTS_PATH" "$HT_RESULTS_PATH"

  echo -e "\e[34mCopying Over Configurations for Lineage\e[0m"
  copy_configs "$CUSTOM_FILES" "$CUSTOM_SERVICES" "$RUN_DIR" "$PROJ_DIR" "$ENV_PATH"

  echo -e "\e[32mCompleted.\e[0m"
}

source ./input.sh

run