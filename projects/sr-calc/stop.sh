cd ../../
docker compose \
  --project-directory ./ \
  --profile files \
  -f projects/sr-compare/docker-compose.yml \
  --env-file ./osu-data-docker/.env \
  --env-file ./osu-tools-docker/.env \
  stop


