# Recalculate SR w.r.t. Branch

This recalculates SR of beatmaps matching a specific SQL query.

## How to Use

**IMPORTANT**: osu! Data on Docker doesn't check the version of the files. If you're updating the data version, delete
the volume, and it'll rebuild itself.

Run the `./run.sh -h` command to see the help menu. 

```
Usage:
  If you don't have a custom database or files URL:
  run.sh [-v MODE_VERSION] [-d DATA_DATE] [-r RUN_TAG] [-q SQL_QUERY] \
       [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH] [-e ENV_PATH]

  If you have a custom database or files URL:
  run.sh [-y DATABASE_URL] [-z FILES_URL] [-r RUN_TAG] [-q SQL_QUERY] \
       [-o OSU_GIT] [-o OSU_GIT_BRANCH] [-t OSU_TOOLS_GIT] [-t OSU_TOOLS_GIT_BRANCH] [-e ENV_PATH]

Description:
  Depending on the use case, some options are required.
  For example, if you're using 'sr-calc' using a MySQL, then SQL_QUERY is expected.

Options:
  -h     Display this help.
  -v     MODE_VERSION: E.g. 'osu_top_1000'.
         - MODE               is either 'osu', 'mania', 'catch' or 'taiko'.
         - VERSION            is either 'top_1000', 'top_10000' or 'random_10000'
  -r     RUN_TAG              identifier of this run       Default: run_2023_07_23_15_39_18 (Current Date Time)
  -d     DATA_DATE            in the format YYYY_MM_DD.    Default: 2023_07_01 (1st of this Month)
  -o (0) OSU_GIT              osu! game git link.          Default: https://github.com/ppy/osu
  -o (1) OSU_GIT_BRANCH       osu! game git branch name.   Default: master
  -t (0) OSU_TOOLS_GIT        osu! tools git link.         Default: https://github.com/ppy/osu-tools
  -t (1) OSU_TOOLS_GIT_BRANCH osu! tools git branch name.  Default: master
  -q     SQL_QUERY            MySQL Query to retrieve      Default: SELECT beatmap_id FROM osu_beatmaps WHERE playmode=3 AND approved=1 LIMIT 10;

  Use these options if you need more control
  -y     https://data.ppy.sh Database URL. Example: https://data.ppy.sh/2023_07_01_performance_<VERSION>.tar.bz2
         Overrides -v and -d
  -z     https://data.ppy.sh Files URL.    Example: https://data.ppy.sh/2023_07_01_osu_files.tar.bz2
         Overrides -d
```

## Examples

Basic usage

Navigate to `projects/sr-calc/`

```bash
./run.sh -v mania_top_1000
```

This will 
1) Download files from https://data.ppy.sh matching latest `mania_top_1000` & `files.tar.bz2`
   - `https://data.ppy.sh/YYYY_MM_01_performance_mania_top_1000.tar.bz2`
   - `https://data.ppy.sh/YYYY_MM_01_osu_files.tar.bz2`
2) Then, using an SQL query (default is `SELECT beatmap_id FROM osu_beatmaps WHERE playmode=3 AND approved=1 LIMIT 10;`)
   It will pull files from `osu_files`
3) Then, it will use `osu-tools` to evaluate the files pulled
4) Finally, it outputs all results to `osu.view/sr-calc/run_...`. 

### Change mode or version

It's mandatory to specify `-v`, which is `MODE_VERSION`. `MODE` being the game mode and `VERSION` being
the dataset type.

Some examples:
- `mania_top_1000`
- `taiko_random_10000`

See https://data.ppy.sh for all valid names.

### Change date

Change dataset date via `-d`, `./run.sh -v ... -d 2023_12`

### Run Tagging

Default `RUN_TAG` is `run_` + current date time. Tag a meaningful name with `./run.sh -v ... -r my_run_tag`. 

### Using another SQL Query

Default query runs a conservative debug query. Override with 
`./run.sh -v ... -q SELECT beatmap_id FROM osu_beatmaps ...`.

It must only select a single column, `beatmap_id`.

### Use another `osu` or `osu-tools` repo/branch

Use `-o` and `-t` to change repo/branches.
`./run.sh -v ... -o https://.../osu -o my_branch -t https://.../osu-tools -t my_branch`

## Using your own beatmaps

If you have local maps to evaluate, prepare a directory of those *.osu files.
Then choose `[External Directory]` when running and point to that directory.

## Using past query files

If you have multiple runs that use the same set of *.osu files, you can point the run to use the previous run's files.
Instead of `[NEW]`, choose the exact run that you wanted to use.