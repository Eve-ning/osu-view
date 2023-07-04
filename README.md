# osu! View

A project suite on osu! related tools for building data science solutions.

**osu!View** is:
- [osu! Data on Docker](https://github.com/Eve-ning/osu-data-docker)
- [osu! Tools on Docker](https://github.com/Eve-ning/osu-tools-docker)

## Get Started

You need Linux (for now)

1) Edit the `.env` for each submodule. See each project for details on what the `.env` does.
2) Run `run.sh`

This will spin up 2 Docker Stacks.
1) One for osu! Data
2) One for osu! Tools

They have a shared directory, `osu.view/`, which is `/osu.view` on both stacks' containers:
- `osu.files`
- `osu.mysql`
- `osu.tools`

Pressing any key on `run.sh` will automatically stop containers.
