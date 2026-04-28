# Renamer

A small WoW Classic addon that replaces guildie character names with their Discord nicknames in raid frames, so you can tell who's who at a glance regardless of which alt they logged in on.

## How it works

You maintain a mapping of `DiscordName → [characters...]` and import it once. The addon stores the flat `character → discord` lookup in SavedVariables and applies it in two places:

- **Default Blizzard CompactRaidFrames** — hooks `CompactUnitFrame_UpdateName` and overwrites the displayed name.
- **ElvUI / oUF** — registers custom tags `[name:discord]`, `[name:discord:short]`, `[name:discord:medium]`, `[name:discord:long]`. Drop one into your raid frame's Name Format (e.g. `[namecolor] [name:discord] [status:text]`).

Characters not in the mapping show their real name unchanged.

## Installation

Clone or copy the folder into your AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/Renamer/
```

## Usage

In-game:

- `/renamer` or `/renamer import` — open the import window. Paste CSV, click **Import**.
- `/renamer count` — show how many entries are loaded.
- `/renamer clear` — wipe the mapping.
- `/renamer test [unit]` — diagnostic lookup (defaults to `player`).
- `/renamer dump` — print the first 10 entries.

## CSV format

One person per line, Discord name first, then their characters:

```
Cafebabe,Cafe,Caffe,Mormongodx
Znips,Znipsorc,Znipscow,Renetiic
# lines starting with # are comments
```

The mapping persists across sessions and is shared account-wide.
