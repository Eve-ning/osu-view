# Recalculate SR w.r.t. Branch

This recalculates SR of beatmaps matching a specific SQL query.

## How to Use

**IMPORTANT**: osu! Data on Docker doesn't check the version of the files. If you're updating the data version, delete
the volume, and it'll rebuild itself.

1) Prep the settings in `docker-compose.yml`
    - Change your `osu` branch: https://github.com/Eve-ning/osu/tree/my-branch
        - `OSU_GIT=https://github.com/Eve-ning/osu`
        - `OSU_GIT_BRANCH=my-branch`
    - Change your `osutools` branch: https://github.com/Eve-ning/osu-tools/tree/my-tools-branch
        - `OSU_TOOLS_GIT=https://github.com/Eve-ning/osu`
        - `OSU_TOOLS_GIT_BRANCH=my-tools-branch`
    - Change your Database File version under `osu.mysql.dl`
        - `FILE_NAME=https://data.ppy.sh/2023_07_01_performance_mania_top_1000.tar.bz2`
    - Change your Files version under `osu.files`
        - `FILE_NAME=https://data.ppy.sh/2023_07_01_osu_files.tar.bz2`
2) Change `query.sql` to pull `beatmap_id` of the files to evaluate.
   Queries that result in less records will be faster.
   I recommend trying with `LIMIT 100` to make sure that everything runs smoothly.
    - Keep in mind that you can only evaluate ranked or loved maps, 
      as they are the only ones included in the data dump.
    - The query must only return a single column.
3) Navigate the shell here and run `./run.sh`
