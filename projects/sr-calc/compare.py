import json
from pathlib import Path

import pandas as pd

WDIR = Path(__file__).parents[2] / 'osu.view/sr-calc'

JSON_FILES = "nt.results.json", "dt.results.json", "ht.results.json"
MODS = "NT", "DT", "HT"

master = "master"
compare = "natelytle"


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
        pd.concat(dfs)[['star_rating', 'beatmap', 'mods', 'strains']]
        .set_index(['beatmap', 'mods'])
        .rename({'star_rating': 'sr'}, axis=1)
    )


df_master = read_json(WDIR / master)[['sr']]
df_compare = read_json(WDIR / compare)[['sr']]

# %%
df = df_master.merge(df_compare, how='inner', right_index=True, left_index=True,
                     suffixes=['_master', f'_{compare}']).sort_values('sr_master', ascending=False)
# %%
df['delta'] = df[f'sr_{compare}'] - df['sr_master']
df.reset_index().sort_values('delta', ascending=False)[:250].to_markdown(f"{compare}_delta_desc.md", index=False)
df.reset_index().sort_values('delta', ascending=True)[:250].to_markdown(f"{compare}_delta_asc.md", index=False)
