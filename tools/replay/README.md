# Local replay analysis

SHAI can read a Dota Source 2 `.dem` without running the Dota client or uploading the match. This exports gameplay evidence, not internal Lua reasons or mode priorities.

```powershell
.\tools\replay\Export-SHAIReplay.ps1 -ReplayPath .\artifacts\replays\9035705167.dem -OutputDirectory .\.tools\replay\export-9035705167
```

The runtime is already prepared on this PC under ignored `.tools/replay/`. For another checkout, obtain these dependencies from their publishers before running the script:

| Local path | Publisher artifact |
|---|---|
| `jre21/<distribution>/bin/java.exe` | [Eclipse Temurin Java 21 JRE](https://adoptium.net/temurin/releases/?version=21) |
| `ecj.jar` | Maven `org.eclipse.jdt:ecj:3.40.0` |
| `lib/clarity.jar` | Maven `com.skadistats:clarity:5.0.1` |
| `lib/clarity-protobuf.jar` | Maven `com.skadistats:clarity-protobuf:7.0` |
| `lib/fastutil.jar` | Maven `it.unimi.dsi:fastutil-core:8.5.12` |
| `lib/snappy.jar` | Maven `org.xerial.snappy:snappy-java:1.1.10.7` |
| `lib/slf4j-api.jar` | Maven `org.slf4j:slf4j-api:2.0.17` |
| `lib/slf4j-simple.jar` | Maven `org.slf4j:slf4j-simple:2.0.17` |

Parser API and event handling follow the publisher's [Clarity](https://github.com/skadistats/clarity) and [combat log / position examples](https://github.com/skadistats/clarity-examples). Java 21 is required by Clarity 5.0.1. The script compiles the adapter, parses the recording and creates a Node summary. Dependency binaries are local tools, not SHAI Workshop content.

`combat.tsv` contains event timestamps, optional attacker/target/inflictor, health, damage, illusion flags and XP reason. `positions.tsv` samples selected player hero entities (excluding unselected illusions) and Roshan at roughly 1 replay-second intervals. Its clock is **the last combat event timestamp**, not an independently reconstructed live game clock; samples can lag during quiet periods and pauses. Do not use it to measure subsecond movement or exact rune pickup times. Positions use Source 2 cell coordinates (`cell * 128 + vec`); the map origin offset cancels when calculating distances.

For this replay, subtract final `m_flGameStartTime = 117.333336` from combat timestamps to get displayed match time. The screenshot's 25 Silencer kills by 24:37 independently agrees with that alignment. Rune counter increases and glyph cooldown increases are sampled state changes: the summary does not classify every rune contest or identify who pressed glyph. XP reason 4 alone is not proof of a Wisdom pickup. Empty visibility/attack-target columns indicate unavailable queried fields, not invisibility or no target.

`parse-summary.txt` is written only after the parser finishes; an old completion marker is removed before reruns. Check exit status and warnings, not just whether exports exist. Optional fields are left blank. `info.txt` and entity dumps may include account identifiers; leave raw exports in ignored `.tools/`, and publish only a reviewed analysis. A future patch may require a newer Clarity release.
