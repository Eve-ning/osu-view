if [ $# -eq 0 ]; then
  echo "Specify a directory to save files"
  exit 1
fi

WORKDIR=osu.view/sr-calc/"$1"

echo "Pulling a large amount of .osu files can be slow. Reuse .osu files by another result-set if the query is the same!"
echo "Use an existing result-set's files or create a new result-set:"

# The long find command finds all directories that have the `files` directory. This is necessary to get the files data
# We firstly find all directories in sr-calc which contain the `files` dir
# Then reverse it, so that `cut` can take the element from the back
# Reverse it again after cut.
select opt in "Create Another" $(find ../../osu.view/sr-calc/ -type d -name 'files' | rev | cut -d "/" -f 2 | rev); do
  [ -n "${opt}" ] && break
done

if [ "$opt" == "Create Another" ]; then
  FILES_DIR="$WORKDIR"/files
  echo "Using new files dir $FILES_DIR"
  CUSTOM_FILES=0
else
  FILES_DIR="../../osu.view/sr-calc/${opt}/files"
  CUSTOM_FILES=1
  echo "Using custom files dir $FILES_DIR"
  if [ ! -d "$FILES_DIR" ]; then
    echo "Files Directory does not exist."
    exit 1
  fi
fi

FILELIST_PATH="$WORKDIR"/filelist.txt
NT_RESULTS_PATH="$WORKDIR"/nt.results.json
DT_RESULTS_PATH="$WORKDIR"/dt.results.json
HT_RESULTS_PATH="$WORKDIR"/ht.results.json

echo "Navigating to Project Home"
cd ../../
pwd

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
    -f projects/sr-calc/docker-compose.yml \
    --env-file ./osu-data-docker/.env \
    --env-file ./osu-tools-docker/.env \
    up --wait --build
fi

# Remove Directory if exists
rm -rf "$WORKDIR"

# Make Directory
docker exec osu.files mkdir -p /"$WORKDIR"

# If we're not using custom files, we'll find them via query.
if [ $CUSTOM_FILES -eq 0 ]; then
  # Pull file list according to query
  MYSQL_PASSWORD=p@ssw0rd1
  docker exec osu.mysql mysql -u root --password="$MYSQL_PASSWORD" \
    -D osu -N -e "$(cat projects/sr-calc/query.sql)" \
    >"$FILELIST_PATH"

  echo "Result saved in /osu.view/recalc-sr/$FILELIST_PATH"

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

echo "Copying Over Configurations"
cp osu-data.env "$WORKDIR"/osu-data.env
cp osu-tools.env "$WORKDIR"/osu-tools.env

if [ $SERVICE_ENABLED -eq 0 ]; then
  echo "Stopping Services"
  docker compose \
    --project-directory ./ \
    --profile files \
    -f projects/sr-calc/docker-compose.yml \
    --env-file ./osu-data-docker/.env \
    --env-file ./osu-tools-docker/.env \
    stop
fi

echo "Completed."
