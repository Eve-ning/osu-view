# Recalculate SR w.r.t. Branch

This recalculates SR of beatmaps matching a specific SQL query.

## How to Use

**IMPORTANT**: osu! Data on Docker doesn't check the version of the files. If you're updating the data version, delete
the volume, and it'll rebuild itself.

1) Prep the settings in `.env`
    - Change your `osu` branch: E.g. https://github.com/Eve-ning/osu/tree/my-branch
        - `OSU_GIT=https://github.com/Eve-ning/osu`
        - `OSU_GIT_BRANCH=my-branch`
    - Change your `osu-tools` branch: E.g. https://github.com/Eve-ning/osu-tools/tree/my-tools-branch
        - `OSU_TOOLS_GIT=https://github.com/Eve-ning/osu`
        - `OSU_TOOLS_GIT_BRANCH=my-tools-branch`
    - Change your Database File version: E.g. July 2023's Mania Top 1000 Dataset
        - VERSION=2023_07_01
        - DATASET=mania_top_1000
2) Change `query.sql` to pull `beatmap_id` of the files to evaluate.
   Queries that result in less records will be faster.
   I recommend trying with `LIMIT 100` to make sure that everything runs smoothly.
    - Keep in mind that you can only evaluate ranked or loved maps,
      as they are the only ones included in the data dump.
    - The query must only return a single column.
3) Navigate the shell here and run `./run.sh [RUN_TAG]`
    - `[RUN_TAG]` is a tag of the run that you can use to identify this run later on.
    - The directory `$PROJECT/osu.view/sr-calc/[RUN_TAG]/` will be created for all the results.

## Using your own beatmaps

If you have your own maps to evaluate, you need to have a directory of those *.osu files.
Then choose `[External Directory]` and point to that directory.

## Using past query files

If you have multiple runs that use the same set of *.osu files, you can point the run to use the previous run's files.
Instead of `[NEW]`, choose the exact run that you wanted to use.