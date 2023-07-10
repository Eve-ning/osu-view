if [ $# -eq 0 ]; then
  echo "Specify a directory to save files"
  exit 1
fi

WORKDIR=osu.view/sr-calc/"$1"

if [ ! "$2" == "" ]; then
  FILES_DIR="$2"
  CUSTOM_FILES=1
  echo "Using custom file dir $FILES_DIR"
  if [ ! -d "$FILES_DIR" ]; then
    echo "Files Directory does not exist."
    exit 1
  fi
else
  FILES_DIR="$WORKDIR"/files
  CUSTOM_FILES=0
fi

FILELIST_PATH="$WORKDIR"/filelist.txt
NT_RESULTS_PATH="$WORKDIR"/nt.results.json
DT_RESULTS_PATH="$WORKDIR"/dt.results.json
HT_RESULTS_PATH="$WORKDIR"/ht.results.json

echo "Starting Services"
./start.sh

# Check if docker service osu.mysql is up
if ! docker ps | grep osu.mysql >/dev/null; then
  echo "osu.mysql is not running"
  exit 1
fi

# Check if docker service osu.files is up
if ! docker ps | grep osu.files >/dev/null; then
  echo "osu.files is not running"
  exit 1
fi

# Remove Directory if exists
rm -rf ../../"$WORKDIR"

# Make Directory
docker exec osu.files mkdir -p /"$WORKDIR"

# If we're not using custom files, we'll find them via query.
if [ $CUSTOM_FILES -eq 0 ]; then
  # Pull file list according to query
  MYSQL_PASSWORD=p@ssw0rd1
  docker exec osu.mysql mysql -u root --password="$MYSQL_PASSWORD" \
    -D osu -N -e "$(cat query.sql)" \
    >../../"$FILELIST_PATH"

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
  echo -n "Evaluating Beatmaps (Normal Time)";
  dotnet PerformanceCalculator.dll difficulty "/'"$FILES_DIR"'" -j -o "/'"$NT_RESULTS_PATH"'" >> /dev/null;
  echo "Exported to '"$NT_RESULTS_PATH"'";

  echo -n "Evaluating Beatmaps (Double Time)";
  dotnet PerformanceCalculator.dll difficulty "/'"$FILES_DIR"'" -j -m dt -o "/'"$DT_RESULTS_PATH"'" >> /dev/null;
  echo "Exported to '"$DT_RESULTS_PATH"'";

  echo -n "Evaluating Beatmaps (Half Time)";
  dotnet PerformanceCalculator.dll difficulty "/'"$FILES_DIR"'" -j -m ht -o "/'"$HT_RESULTS_PATH"'" >> /dev/null;
  echo "Exported to '"$HT_RESULTS_PATH"'";
  '

echo "Copying Over Configurations"
cp ../../osu-data.env ../../"$WORKDIR"/osu-data.env
cp ../../osu-tools.env ../../"$WORKDIR"/osu-tools.env

echo "Stopping Services"
./stop.sh

echo "Completed."
