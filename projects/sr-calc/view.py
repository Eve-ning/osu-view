import json
from pathlib import Path

import altair as alt
import pandas as pd
import streamlit as st

WDIR = Path(__file__).parents[2] / 'osu.view/sr-calc'

JSON_FILES = "nt.results.json", "dt.results.json", "ht.results.json"
MODS = "NT", "DT", "HT"

st.set_page_config(layout="wide")
st.title("osu! View")


@st.cache_resource
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


# Title
st.header("Local Projects Available")

# Select 2 projects to compare
proj_names_all: list[str] = [d.parts[-1] for d in WDIR.iterdir()]
proj_names: list[str] = st.multiselect("Projects to Compare:", options=proj_names_all, max_selections=2)

# Extract Strains from projects
# Each Project Strain is a dictionary {<BEATMAP NAME>: [<STRAIN 0>, <STRAIN 1>, ... ]}
proj_strains: list[dict] = [read_json(WDIR / project).to_dict()['strains'] for project in proj_names]
map_names = proj_strains[0].keys()

strain_min, strain_max = st.slider("Strain Max", value=(0, 50), min_value=0, max_value=100)
map_name = st.selectbox('Map', options=map_names)

# Construct DF compatible with Altair
df = (
    pd.DataFrame({
        proj_names[0]: proj_strains[0][map_name],
        proj_names[1]: proj_strains[1][map_name]
    })
    .reset_index()
    .melt(id_vars='index', value_vars=proj_names)
    .assign(time=lambda x: x['index'] * 400)
)
# Draw Altair chart
chart = (
    alt.Chart(df)
    .mark_line()
    .encode(x='time',
            y=alt.Y('value'),
            color='variable')
)
st.altair_chart(chart, use_container_width=True)
