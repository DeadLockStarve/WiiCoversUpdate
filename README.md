# WiiCoversUpdate

Very simple bash script which lets you download covers like WiiFlow does, or maybe better

## How it works?

It simply generates gamestdb urls pointing to png cover files according to input parameters, with localization priority according to user's preference.

When trying to fetch a remote cover, it attempts to fetch a front cover, if it succeeds tries to download corresponding 3d and full covers.

## Installation

Just `git clone` this repo and copy the script somewhere in folders present in `$PATH`

## Configuration

A config file can be set with `-c` argument or simply by having it's path in `WII_COVERS_CONFIG` environment variable, cli argument takes preference over the env var. The config file should follow this format:

    # WiiCoversUpdate Config
    root_dir=/wbfs/dir/parent/path/here
    wbfs_dir=wbfs
    covers_root_dir=/your/path/here
    covers_path=covers
    covers_path_3d=3d
    covers_path_full=full
    locales=ES,EN,US,JA

As you may have noticed there are multiple locales written in `locales`, they must be written in order of priority, in this example it tries to download covers in this country order: Spain, UK, USA, Japan. This is optimal for example for a spanish user who also plays with american and japanese games

## TODO

GameCube roms identification and support
