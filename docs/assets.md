# Chiptorio — Generated Assets, Locale, Release

## Icon generation

`tools/make-icons.ps1` regenerates all item icons, technology icons, the
sixteen connection-aware cable world sprites in `graphics/entity/cable/`,
`thumbnail.png`, and `graphics/answer-ending.png`. Do not hand-edit generated
PNGs.

- A new icon needs a `Save-Icon` call and an entry in the contact-sheet
  `$order`.
- A new cable shape needs an entry in `$cableShapes` and in `CABLE_SHAPES` in
  `scripts/network.lua` and `tools/test-probe/data-updates.lua`.
- A new technology also needs an entry in `$techIcons`.

## Sound generation

`tools/make-sound.ps1` rebuilds `sound/answer-fanfare.ogg` and requires
`ffmpeg` on `PATH`.

## Locale

Add `locale/en/locale.cfg` entries for new items, entities, and technologies;
placeholders are `__1__`, not `%s`.

Locale keys are auto-resolved by Factorio (`item-name.<name>`,
`entity-name.<name>`, `technology-name.<name>`, `recipe-name.<name>`,
`fluid-name.<name>`), so explicit `localised_name` is not required. The data
contract in `tools/test-probe/data-updates.lua` verifies every Chiptorio-created
prototype has a locale entry.

## Release

Bump `info.json` `version` and add a dated `changelog.txt` entry under
Features/Balance/Bugfixes, newest first.
