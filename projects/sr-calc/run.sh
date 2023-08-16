#!/bin/bash

# See -h for more details on the usage of this script.

PROJ_DIR="$(dirname "$(realpath "$0")")"
source "$PROJ_DIR"/utils/input.sh
source "$PROJ_DIR"/utils/validate.sh
cd "$PROJ_DIR"/../../ || exit 1

# This function checks if the directory exists, and if so, asks the user if they want to overwrite it.
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

# This function selects the result directory, and sets the FILES_DIR and CUSTOM_FILES variable
# FILES_DIR is the dir where the .osu files are stored
# CUSTOM_FILES is a boolean that is set to 1 if the user selects a custom run or files dir
select_result_dir() {
  echo ""
  echo "Pulling a large amount of .osu files can be slow."
  echo "Reuse .osu files by another result-set if the query is the same!"
  echo ""
  echo "Use an existing result-set's files or create a new result-set:"

  local RUN_DIR="$1"
  FILES_DIR=""
  CUSTOM_FILES=0

  # We're interested on listing all [RUN_TAG] with a `files` dir.
  #   Impl: 1) Find all dirs in RUN_DIR/.. containing `files` dir
  #         2) Reverse all paths, so `cut` can take the element from the back
  #            E.g. /a/b/[RUN_TAG]/files -> selif/[GAT_NUR]/b/a/
  #                                      -> cut -f 2 -> [GAT_NUR]
  #                                      -> rev -> [RUN_TAG]
  #         3) Feed the list to select
  select opt in "[NEW]" "[External Directory]" \
    $(find "$RUN_DIR"/.. -type d -name 'files' | rev | cut -d "/" -f 2 | rev); do
    [ -n "${opt}" ] && break
  done

  # If New, we'll run the query, then extract matching files
  if [ "$opt" == "[NEW]" ]; then
    FILES_DIR="$RUN_DIR"/files
    echo "Using new files dir $FILES_DIR"
    CUSTOM_FILES=0

    validate_set "SQL_QUERY" "$SQL_QUERY" # To query the db
    validate_url "DB_URL" "$DB_URL"       # To run the query
    validate_url "FILES_URL" "$FILES_URL" # To download the files

  # If External, we'll skip the query and file copying, we'll just run difficulty on this new dir.
  elif [ "$opt" == "[External Directory]" ]; then
    echo If you use a relative directory, you are at "$(pwd)"

    read -r -p "Your *.osu files directory: " EXT_FILES_DIR
    while [ ! -d "$EXT_FILES_DIR" ]; do
      echo "$EXT_FILES_DIR" is not a directory
      read -r -p "Your *.osu files directory: " EXT_FILES_DIR
      ((r++)) && ((r == 10)) && exit 1
    done

    echo "Found $(find "$EXT_FILES_DIR" -name "*.osu" | wc -l) *.osu files in $FILES_DIR"
    FILES_DIR="$RUN_DIR"/files

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

  mkdir -p "$FILES_DIR"
}

# ENV_PATH is the path to the .env file fed to docker compose
start_docker() {
  local ENV_PATH="$1"

  echo "Starting Services"
  if [ $CUSTOM_FILES -eq 1 ]; then
    docker compose \
      --project-directory ./ \
      --profile files \
      -f "$PROJ_DIR"/docker-compose.yml \
      --env-file ./osu-data-docker/.env \
      --env-file ./osu-tools-docker/.env \
      --env-file "$ENV_PATH" \
     build --no-cache osu.tools
    docker compose \
      --project-directory ./ \
      --profile files \
      -f "$PROJ_DIR"/docker-compose.yml \
      --env-file ./osu-data-docker/.env \
      --env-file ./osu-tools-docker/.env \
      --env-file "$ENV_PATH" \
      up --wait osu.tools
  else
    docker compose \
      --project-directory ./ \
      --profile files \
      -f "$PROJ_DIR"/docker-compose.yml \
      --env-file ./osu-data-docker/.env \
      --env-file ./osu-tools-docker/.env \
      --env-file "$ENV_PATH" \
     build --no-cache
    docker compose \
      --project-directory ./ \
      --profile files \
      -f "$PROJ_DIR"/docker-compose.yml \
      --env-file ./osu-data-docker/.env \
      --env-file ./osu-tools-docker/.env \
      --env-file "$ENV_PATH" \
      up --wait
  fi

}

# ENV_PATH is the path to the .env file fed to docker compose
stop_docker() {
  local ENV_PATH="$1"

  echo "Stopping Services"
  docker compose \
    --project-directory ./ \
    --profile files \
    -f "$PROJ_DIR"/docker-compose.yml \
    --env-file ./osu-data-docker/.env \
    --env-file ./osu-tools-docker/.env \
    --env-file "$ENV_PATH" \
    stop
}

# This function runs the query, and extracts the files from the tarball
# This uses the get_maps.sh script from osu-data-docker
# FILES_DIR is the dir where the .osu files are stored
run_query() {
  local FILES_DIR="$1"
  ./osu-data-docker/scripts/get_maps.sh -q "$SQL_QUERY" -o ./"$FILES_DIR"/files.tar.bz2
  tar -xjf ./"$FILES_DIR"/files.tar.bz2 -C ./"$FILES_DIR"/
}

# This function copies the configs to the run dir
# CUSTOM_FILES is a boolean that is set to 1 if the user selects a custom run or files dir
# RUN_DIR is the dir where the configs are stored
# PROJ_DIR is the
# ENV_PATH is the path to the .env file fed to docker compose
copy_configs() {
  local CUSTOM_FILES="$1"
  local RUN_DIR="$2"
  local ENV_PATH="$3"

  if [ "$CUSTOM_FILES" -eq 0 ]; then
    echo "$SQL_QUERY" >"$RUN_DIR"/query.sql
  fi

  cp "$PROJ_DIR"/docker-compose.yml "$RUN_DIR"/
  cp ./osu-data-docker/.env "$RUN_DIR"/osu-data.env
  cp ./osu-tools-docker/.env "$RUN_DIR"/osu-tools.env
  cp "$ENV_PATH" "$RUN_DIR"/.env
}

evaluate_maps() {
  local FILES_DIR="$1"
  local RUN_DIR="$2"
  local NT_RESULTS_PATH="$RUN_DIR"/nt.results.json
  local DT_RESULTS_PATH="$RUN_DIR"/dt.results.json
  local HT_RESULTS_PATH="$RUN_DIR"/ht.results.json

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
  # The following variables are set by the input.sh script
  # VERSION, RUN_TAG, DATASET_DATE, OSU_GIT, OSU_GIT_BRANCH, OSU_TOOLS_GIT, OSU_TOOLS_GIT_BRANCH,
  # DB_URL, FILES_URL, ENV_PATH, SQL_QUERY

  # The DIR variables are relative to the project root locally, and absolute in the docker container
  # E.g. /$RUN_DIR refers to RUN_DIR in the docker container,
  #      ./$RUN_DIR refers to the RUN_DIR locally
  RUN_DIR=osu.view/sr-calc/"$RUN_TAG" # RUN_DIR is where all results are stored
  FILES_DIR=""                        # FILES_DIR is where the .osu files are stored

  validate_git "OSU_GIT" "$OSU_GIT" "$OSU_GIT_BRANCH"
  validate_git "OSU_TOOLS_GIT" "$OSU_TOOLS_GIT" "$OSU_TOOLS_GIT_BRANCH"

  check_overwrite "$RUN_DIR"
  select_result_dir "$RUN_DIR"
  start_docker "$ENV_PATH" "osu.mysql" "osu.files" "osu.tools"

  if [ "$CUSTOM_FILES" -eq 0 ]; then
    run_query "$FILES_DIR"
  fi

  evaluate_maps "$FILES_DIR" "$RUN_DIR"

  echo -e "\e[34mCopying Over Configurations for Lineage\e[0m"
  copy_configs "$CUSTOM_FILES" "$RUN_DIR" "$ENV_PATH"
  stop_docker "$ENV_PATH"

  echo -e "\e[32mCompleted.\e[0m"
}

run
