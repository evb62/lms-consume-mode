# Consume Mode for Lyrion Music Server

MPD-style consume for LMS 8.x / 9.x. A track leaves the play queue once it has
finished playing or has been skipped with Next. Jumping straight to another
entry in the queue leaves the track you jumped away from alone.

Enabled per player, in the web UI.

## Use

Settings -> Player -> pick the player -> Consume Mode -> tick the box.

Two global options live under Settings -> Advanced -> Consume Mode:
consume on Previous (off by default) and consume the final track of the
queue (on by default).

CLI / JSON-RPC:

    <playerid> consumemode 1
    <playerid> consumemode 0
    <playerid> consumemode ?     -> _consumemode:0|1

Omitting the value toggles.

## Troubleshooting

Settings -> Advanced -> Logging, set `plugin.consumemode` to INFO, then watch
`config/logs/server.log`. Every removal is logged with the queue index and the
reason for the transition.

## Known limits

- Consume plus Repeat is contradictory. Repeat-one is detected and never
  consumes; repeat-all will empty the queue one track per lap.
- If the same file appears twice in the queue and positions have shifted, the
  first matching entry is removed.
- Synced groups are handled at the master player; set the preference on the
  master.
