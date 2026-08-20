# Queue Consume for Lyrion Music Server

<!-- Queue consume for LMS 8.x / 9.x. -->
A track leaves the play queue once it has
finished playing or has been skipped with Next. Jumping straight to another
entry in the queue does not consume the track you jumped away from.

Enabled per player, in the web UI.

## Use

(Material Skin)

Settings -> Player -> pick the player -> Extra Settings -> Queue Consume -> tick the box.

Two global options live under Player Settings -> Extra Settings -> Queue Consume:
- consume on Previous (off by default)
- consume the final track of the queue (on by default).

CLI / JSON-RPC:

    <playerid> queueconsume 1
    <playerid> queueconsume 0
    <playerid> queueconsume ?     -> _queueconsume:0|1

Omitting the value toggles.

<!-- ## Troubleshooting

Settings -> Advanced -> Logging, set `plugin.queueconsume` to INFO, then watch
`config/logs/server.log`. Every removal is logged with the queue index and the
reason for the transition. -->

## Known limits

- Consume plus Repeat is contradictory. Repeat-one is detected and never
  consumes; repeat-all will empty the queue one track per lap.
- If the same file appears twice in the queue and positions have shifted, the
  first matching entry is removed.
- Synced groups are handled at the master player; set the preference on the
  master.

## Installation

Scroll to the end of the "Manage Plugins" page in the LMS WebUI. Find the "Additional Repositories" and fill the line with the repository address: https://raw.githubusercontent.com/evb62/lms-plugins/main/public.xml.

Accept the restart prompt, then enable the plugin.

<!-- - Add https://raw.githubusercontent.com/evb62/lms-queue-consume/main/public.xml to "Additional Repositories" to "Manage Plugins" settings page on LMS. Then enable this plugin. -->
