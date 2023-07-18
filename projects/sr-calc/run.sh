#!/bin/bash
#
# Executes `difficulty` of the osu-tools project on specified branches.
# The beatmaps used depends on the query that pulls the beatmap_id.
# Arg 1 is the working dir for outputs. osu.view/sr-calc/$1
#
# Additionally, the script will prompt the user if they want to use an existing set of `.osu` files to infer from.
# This is necessary as pulling `.osu` files is costly.
#
# If the docker services are already running, this will just use that.
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

if [ $# -eq 0 ]; then
  echo "Specify a directory to save files"
  exit 1
fi

PROJ_DIR="$(pwd)"
RESULT_DIR=osu.view/sr-calc/"$1"

echo -n "Navigating to Project Home: "
cd ../../
pwd

echo ""
echo "Pulling a large amount of .osu files can be slow."
echo "Reuse .osu files by another result-set if the query is the same!"
echo ""
echo "Use an existing result-set's files or create a new result-set:"

# The long find command finds all directories that have the `files` directory. This is necessary to get the files data
# We firstly find all directories in sr-calc which contain the `files` dir
# Then reverse it, so that `cut` can take the element from the back
# Reverse it again after cut.
select opt in "[NEW]" $(find osu.view/sr-calc/ -type d -name 'files' | rev | cut -d "/" -f 2 | rev); do
  [ -n "${opt}" ] && break
done

if [ "$opt" == "[NEW]" ]; then
  FILES_DIR="$RESULT_DIR"/files
  echo "Using new files dir $FILES_DIR"
  CUSTOM_FILES_DIR=0
else
  FILES_DIR="osu.view/sr-calc/${opt}/files"
  CUSTOM_FILES_DIR=1
  echo "Using custom files dir $FILES_DIR"
  if [ ! -d "$FILES_DIR" ]; then
    echo "Files Directory does not exist."
    exit 1
  fi
fi

FILELIST_PATH="$RESULT_DIR"/filelist.txt
NT_RESULTS_PATH="$RESULT_DIR"/nt.results.json
DT_RESULTS_PATH="$RESULT_DIR"/dt.results.json
HT_RESULTS_PATH="$RESULT_DIR"/ht.results.json

# Check if docker service osu.mysql is up
if docker ps | grep -q osu.mysql && docker ps | grep -q osu.files; then
  SERVICE_ENABLED=1
  echo "Services are already running, will use current services."
else
  SERVICE_ENABLED=0
  echo "Services not available, starting Services"
  docker compose \
    --project-directory ./ \
    --profile files \
    -f "$PROJ_DIR"/docker-compose.yml \
    --env-file ./osu-data-docker/.env \
    --env-file ./osu-tools-docker/.env \
    --env-file "$PROJ_DIR"/.env \
    up --wait --build

  echo "Configurations: "
  echo " - /osu.git: $(grep OSU_GIT= "$PROJ_DIR"/docker-compose.yml | cut -d = -f 2 | head -1)"
  echo "   - branch: $(grep OSU_GIT_BRANCH= "$PROJ_DIR"/docker-compose.yml | cut -d = -f 2 | head -1)"
  echo " - /osu-tools.git: $(grep OSU_TOOLS_GIT= "$PROJ_DIR"/docker-compose.yml | cut -d = -f 2 | head -1)"
  echo "   - branch: $(grep OSU_TOOLS_GIT_BRANCH= "$PROJ_DIR"/docker-compose.yml | cut -d = -f 2 | head -1)"
fi

# Replace Directory if exists
rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"

# If we're not using custom files, we'll find them via query.
if [ $CUSTOM_FILES_DIR -eq 0 ]; then
  # Pull file list according to query
  MYSQL_PASSWORD=p@ssw0rd1
  docker exec osu.mysql mysql -u root --password="$MYSQL_PASSWORD" \
    -D osu -N -e "$(cat "$PROJ_DIR"/query.sql)" \
    >"$FILELIST_PATH"

  echo "File List saved in /osu.view/recalc-sr/$FILELIST_PATH"

  # Get osu.files dir name dynamically
  OSU_FILES_DIRNAME=$(docker exec osu.files ls)

  # Create a temporary directory to copy all files to send to tar.
  echo "Moving Files to /$FILES_DIR/"
  docker exec osu.files sh -c \
    'mkdir -p /'"$FILES_DIR"'/;
    while read beatmap_id;
    do cp /osu.files/'"$OSU_FILES_DIRNAME"'/"$beatmap_id".osu /'"$FILES_DIR"'/"$beatmap_id".osu;
    done < /'"$FILELIST_PATH"';'
fi

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

echo "Copying Over Configurations for Lineage"
cp "$PROJ_DIR"/query.sql "$RESULT_DIR"/query.sql

if [ $SERVICE_ENABLED -eq 0 ]; then
  cp "$PROJ_DIR"/docker-compose.yml "$RESULT_DIR"/docker-compose.yml
  echo "Stopping Services"
  docker compose \
    --project-directory ./ \
    --profile files \
    -f "$PROJ_DIR"/docker-compose.yml \
    --env-file ./osu-data-docker/.env \
    --env-file ./osu-tools-docker/.env \
    stop
else
  echo "As you used a custom service, the docker-compose.yml will not be copied over."
fi

echo "Completed."
