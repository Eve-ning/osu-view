SELECT beatmap_id
FROM osu_beatmaps
WHERE playmode = 3
  AND approved = 1
LIMIT 10
;
