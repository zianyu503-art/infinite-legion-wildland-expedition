# UI icon assets

These monochrome SVGs form the shared semantic icon vocabulary for the game's
drawn UI. `map.svg` is an original folded-map glyph created for this project.
The other SVGs listed in the Adwaita mapping below are selected from the
**Adwaita Icon Theme** by the GNOME Project.

The following attribution and license apply **only to the Adwaita-derived
files explicitly listed in that mapping**; they do not apply to `map.svg`.

- Upstream: <https://gitlab.gnome.org/GNOME/adwaita-icon-theme>
- Attribution: GNOME Project (<https://www.gnome.org>)
- License used here: GNU Lesser General Public License 3.0
- License text: `LICENSE-LGPL-3.txt`
- Incorporated GNU GPL 3 terms: `LICENSE-GPL-3.txt`

## Vendored source

- Build system: Debian GNU/Linux 13 (trixie)
- Installed package: `adwaita-icon-theme` version `48.1-1`
- Source root: `/usr/share/icons/Adwaita/symbolic/`
- Copied on: 2026-08-10

The only visual modification to the Adwaita-derived files is normalization of
solid fills to `#ffffff` so Godot can tint each icon with
`draw_texture_rect(..., modulate)`. The project-original map uses the same
white silhouette convention. Godot imports every 16 px SVG at 5x scale (80 px
textures), keeping the game's 19--78 px UI rendering crisp under browser and
high-density display scaling.

The Adwaita-derived semantic filenames map to these upstream icons:

| Local file | Source below `/usr/share/icons/Adwaita/symbolic/` |
| --- | --- |
| `close.svg` | `ui/window-close-symbolic.svg` |
| `previous.svg` | `actions/go-previous-symbolic.svg` |
| `next.svg` | `actions/go-next-symbolic.svg` |
| `plus.svg` | `actions/list-add-symbolic.svg` |
| `minus.svg` | `actions/list-remove-symbolic.svg` |
| `fullscreen.svg` | `actions/view-fullscreen-symbolic.svg` |
| `pause.svg` | `actions/media-playback-pause-symbolic.svg` |
| `notifications.svg` | `legacy/preferences-system-notifications-symbolic.svg` |
| `notifications_off.svg` | `status/notifications-disabled-symbolic.svg` |
| `help.svg` | `status/dialog-question-symbolic.svg` |
| `info.svg` | `actions/help-about-symbolic.svg` |
| `cheat.svg` | `legacy/utilities-terminal-symbolic.svg` |
| `upgrades.svg` | `categories/applications-engineering-symbolic.svg` |
| `recruit.svg` | `actions/contact-new-symbolic.svg` |
| `flag.svg` | `categories/emoji-flags-symbolic.svg` |
| `skills.svg` | `status/starred-symbolic.svg` |
| `command.svg` | `legacy/system-users-symbolic.svg` |
| `save.svg` | `actions/document-save-symbolic.svg` |
| `load.svg` | `actions/document-open-symbolic.svg` |
| `restart.svg` | `actions/view-refresh-symbolic.svg` |
| `warning.svg` | `status/dialog-warning-symbolic.svg` |
| `check.svg` | `ui/checkbox-checked-symbolic.svg` |
| `play.svg` | `actions/media-playback-start-symbolic.svg` |
| `exit.svg` | `actions/system-log-out-symbolic.svg` |
| `volume_up.svg` | `status/audio-volume-high-symbolic.svg` |
| `volume_off.svg` | `status/audio-volume-muted-symbolic.svg` |
| `battle.svg` | `status/security-high-symbolic.svg` |
| `settings.svg` | `categories/preferences-system-symbolic.svg` |
| `language.svg` | `actions/font-select-symbolic.svg` |

## Project-original icon

| Local file | Source |
| --- | --- |
| `map.svg` | Original 16 px folded-map glyph created for this project; no external asset or path data used. |

The shield (battle), star (skills), and letter with bidirectional selectors
(language) communicate their in-game actions more directly than the former
gamepad, sort-order, and web-browser glyphs. The language glyph also avoids
being confused with the game's separate national-flag action.
