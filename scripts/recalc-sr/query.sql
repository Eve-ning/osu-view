SELECT beatmap_id
FROM osu_beatmaps
WHERE playmode = 3
  AND (
    difficultyrating > 2.5
    )
  AND approved = 1
;
