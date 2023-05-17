# Replay format
The replay is stored as an array inside a JSON file, parsed item by item.
Each item contains at the very least a `time` variable and a `kind` variable, which contains the actual type of event.

The replay is only considered as "started" after the `EVENT_REPLAY_START` command.
This allows the replay to simply use the regular spawn events and such to indicate
already connected players and already spawned vehicles.
