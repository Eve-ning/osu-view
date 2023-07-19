import json
from pathlib import Path

import altair as alt
import numpy as np
import pandas as pd
import streamlit as st

st.set_page_config(layout="wide")


@st.cache_resource
def load():
    WORKDIR = Path(__file__).parents[2] / 'osu.view/recalc-sr/master-strain/'

    JSON_FILES = "nt.results.json", "dt.results.json", "ht.results.json"
    MODS = "NT", "DT", "HT"

    with open(WORKDIR / JSON_FILES[0]) as f:
        data = json.load(f)['results']
        df = pd.DataFrame(data)
        df = (
            pd.concat([df.drop('attributes', axis=1),
                       df['attributes'].apply(pd.Series)], axis=1)
            .assign(mods='NT')
        )
    return df


# strain = df.loc[df.beatmap_id == 3469849, 'strains'].to_numpy()[0]

df = load()



# %%
strains = df[['beatmap', 'strains']].set_index('beatmap').to_dict()['strains']

beatmaps = strains.keys()

strain_max = st.slider("Strain Max", value=50, min_value=0, max_value=100)
beatmap_select = st.multiselect('Map', options=beatmaps)

cols = st.columns(len(beatmap_select))
for i, col in zip(beatmap_select, cols):
    with col:
        s = strains[i]
        chart: alt.Chart = (
            alt.Chart(
                pd.DataFrame(data={'Strain Section': np.arange(len(s)),
                                   'Strain': s}))
            .mark_line()
            .encode(
                x=alt.X('Strain Section'),
                y=alt.Y('Strain').scale(domain=(0, strain_max))
            )
        ).properties(
            title=i,
        )
        st.altair_chart(chart, use_container_width=True)
