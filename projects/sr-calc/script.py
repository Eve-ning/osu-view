import json
from pathlib import Path

import numpy as np
import pandas as pd

COMPARE_WORKDIR = Path(__file__).parents[2] / 'osu.view/recalc-sr/col5-fix-sort/'
MASTER_WORKDIR = Path(__file__).parents[2] / 'osu.view/recalc-sr/master/'

JSON_FILES = "nt.results.json", "dt.results.json", "ht.results.json"
MODS = "NT", "DT", "HT"


def read_json(workdir):
    dfs = []
    for file, mod in zip(JSON_FILES, MODS):
        with open(workdir / file) as f:
            data = json.load(f)['results']
        df = pd.DataFrame(data)
        df = (
            pd.concat([df.drop('attributes', axis=1),
                       df['attributes'].apply(pd.Series)], axis=1)
            .assign(mods=mod)
        )
        dfs.append(df)
    return (
        pd.concat(dfs)[['star_rating', 'beatmap', 'mods']]
        .set_index(['beatmap', 'mods'])
        .rename({'star_rating': 'sr'}, axis=1)
    )


df_master = read_json(MASTER_WORKDIR)
df_compare = read_json(COMPARE_WORKDIR)
df = (
    df_master
    .join(df_compare, lsuffix='_master', rsuffix='_compare')
    .assign(delta=lambda x: x['sr_compare'] - x['sr_master'])
)
df_filter: pd.DataFrame = (df.loc[np.abs(df['delta']) > 0.01].sort_values('delta')[::-1])
df_filter.reset_index()[['sr_master', 'sr_compare', 'mods', 'delta', 'beatmap']].round(2).to_markdown("results.md")