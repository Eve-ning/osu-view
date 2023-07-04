echo "Starting osu-data-docker"
cd osu-data-docker || exit 1
docker compose \
       --profile files \
       -f docker-compose.yml \
       -f ../osu-data.override.yml \
       --env-file .env \
       --env-file ../osu-data.env \
       up -d

echo "Starting osu-tools-docker"
cd ../osu-tools-docker || exit 1
docker compose \
       -f docker-compose.yml \
       -f ../osu-tools.override.yml \
       --env-file .env \
       --env-file ../osu-tools.env \
       up -d --build

cd ..

wait_flag=""

while [ "$wait_flag" = "" ]
do
  read -r -n 1 -p "Press any key to stop the containers: " wait_flag
  wait_flag=$?
  printf "\n"
done

echo "Stopping osu-data-docker"
cd osu-data-docker || exit 1
docker compose --profile files stop

echo "Stopping osu-tools-docker"
cd ../osu-tools-docker || exit 1
docker compose stop

exit 0