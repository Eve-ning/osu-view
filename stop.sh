echo "Stopping osu-data-docker"
cd osu-data-docker || exit 1
docker compose --profile files stop

echo "Stopping osu-tools-docker"
cd ../osu-tools-docker || exit 1
docker compose stop

exit 0