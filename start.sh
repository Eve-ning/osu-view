echo "Starting osu-data-docker"
cd osu-data-docker || exit 1
docker compose \
  --profile files \
  -f docker-compose.yml \
  -f ../osu-data.override.yml \
  --env-file .env \
  --env-file ../osu-data.env \
  up -d --build

echo "Starting osu-tools-docker"
cd ../osu-tools-docker || exit 1
docker compose \
  -f docker-compose.yml \
  -f ../osu-tools.override.yml \
  --env-file .env \
  --env-file ../osu-tools.env \
  up -d --build

exit 0