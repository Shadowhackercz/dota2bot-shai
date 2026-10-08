import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import skadistats.clarity.Clarity;
import skadistats.clarity.event.Insert;
import skadistats.clarity.model.CombatLogEntry;
import skadistats.clarity.model.Entity;
import skadistats.clarity.processor.entities.Entities;
import skadistats.clarity.processor.entities.UsesEntities;
import skadistats.clarity.processor.gameevents.OnCombatLogEntry;
import skadistats.clarity.processor.reader.OnTickEnd;
import skadistats.clarity.processor.runner.Context;
import skadistats.clarity.processor.runner.SimpleRunner;
import skadistats.clarity.source.MappedFileSource;

/** Local replay export. Does not recover Lua intents or issue game actions. */
@UsesEntities
public class ReadReplay implements AutoCloseable {
    @Insert private Entities entities;
    private final PrintWriter combat, positions, fields, teamState;
    private final Set<String> dumped = new HashSet<>();
    private final Map<String, Long> counts = new TreeMap<>();
    private int lastSample = Integer.MIN_VALUE;
    private long events, samples;
    private float lastTime;

    ReadReplay(Path dir) throws IOException {
        Files.createDirectories(dir);
        combat = writer(dir.resolve("combat.tsv"));
        positions = writer(dir.resolve("positions.tsv"));
        fields = writer(dir.resolve("fields.txt"));
        teamState = writer(dir.resolve("team-state.tsv"));
        combat.println("time\ttype\tattacker\ttarget\tinflictor\tvalue\thealth\tattackerHero\ttargetHero\tattackerIllusion\ttargetIllusion\tx\ty\tvisibleRadiant\tvisibleDire\trune\txpReason");
        positions.println("tick\tlastCombatTime\tstartTime\tclass\tentity\tteam\thp\tmaxHp\tmana\tmaxMana\tlevel\tx\ty\tlifeState\tvisibility\tattackTarget");
        teamState.println("tick\tlastCombatTime\tstartTime\tkey\tvalue");
    }
    static PrintWriter writer(Path p) throws IOException {
        return new PrintWriter(Files.newBufferedWriter(p, StandardCharsets.UTF_8));
    }
    static String clean(Object v) {
        return v == null ? "" : v.toString().replace('\t', ' ').replace('\n', ' ').replace('\r', ' ');
    }
    @OnCombatLogEntry public void combat(CombatLogEntry e) {
        String type = String.valueOf(e.getType());
        counts.merge(type, 1L, Long::sum);
        events++;
        if (e.hasTimestamp()) lastTime = e.getTimestamp();
        combat.println(String.join("\t", clean(e.hasTimestamp() ? e.getTimestamp() : null), type,
            clean(e.hasAttackerName() ? e.getAttackerName() : null),
            clean(e.hasTargetName() ? e.getTargetName() : null),
            clean(e.hasInflictorName() ? e.getInflictorName() : null),
            clean(e.hasValue() ? e.getValue() : null), clean(e.hasHealth() ? e.getHealth() : null),
            clean(e.hasAttackerHero() ? e.isAttackerHero() : null), clean(e.hasTargetHero() ? e.isTargetHero() : null),
            clean(e.hasAttackerIllusion() ? e.isAttackerIllusion() : null), clean(e.hasTargetIllusion() ? e.isTargetIllusion() : null),
            clean(e.hasLocationX() ? e.getLocationX() : null), clean(e.hasLocationY() ? e.getLocationY() : null),
            clean(e.hasVisibleRadiant() ? e.isVisibleRadiant() : null), clean(e.hasVisibleDire() ? e.isVisibleDire() : null),
            clean(e.hasRuneType() ? e.getRuneType() : null), clean(e.hasXpReason() ? e.getXpReason() : null)));
    }
    static Object property(Entity e, String key) {
        if (e == null || e.getFieldPathForName(key) == null) return null;
        return e.getProperty(key);
    }
    static Object coord(Entity e, String axis) {
        Object cell = property(e, "CBodyComponent.m_cell" + axis);
        Object vec = property(e, "CBodyComponent.m_vec" + axis);
        return cell instanceof Number c && vec instanceof Number v ? c.doubleValue() * 128 + v.doubleValue() : null;
    }
    @OnTickEnd public void tick(Context ctx, boolean synthetic) {
        // Sample at replay tick rate; game clock is exported separately to preserve pauses/pregame.
        int bucket = (int)Math.floor(ctx.getTick() * ctx.getMillisPerTick() / 1000);
        if (bucket == lastSample || synthetic) return;
        lastSample = bucket;
        List<Entity> active = entities.stream().filter(Entity::isActive).toList();
        Entity rules = active.stream().filter(e -> e.getDtClass().getDtName().equals("CDOTAGamerulesProxy")).findFirst().orElse(null);
        Object time = lastTime;
        Object start = property(rules, "m_pGameRules.m_flGameStartTime");
        Entity players = active.stream().filter(e -> e.getDtClass().getDtName().equals("CDOTA_PlayerResource")).findFirst().orElse(null);
        Set<Integer> heroIndices = new HashSet<>();
        for (int p = 0; p < 10; p++) {
            String prefix = String.format("m_vecPlayerTeamData.%04d.", p);
            Object handle = property(players, prefix + "m_hSelectedHero");
            Entity hero = handle instanceof Number n ? entities.getByHandle(n.intValue()) : null;
            if (hero != null) heroIndices.add(hero.getIndex());
            for (String key : List.of("m_iBountyRunes", "m_iPowerRunes", "m_iWaterRunes"))
                teamState.println(String.join("\t", clean(ctx.getTick()), clean(time), clean(start), "player" + p + "." + key, clean(property(players, prefix + key))));
        }
        for (String key : List.of("m_fGoodGlyphCooldown", "m_fBadGlyphCooldown", "m_flScanCooldowns.0002", "m_flScanCooldowns.0003"))
            teamState.println(String.join("\t", clean(ctx.getTick()), clean(time), clean(start), key, clean(property(rules,"m_pGameRules." + key))));
        for (Entity e : active) {
            String cls = e.getDtClass().getDtName();
            if (cls.startsWith("CDOTA_Unit_Hero_") || cls.startsWith("CDOTA_Data") || cls.equals("CDOTAGamerulesProxy") || cls.equals("CDOTA_PlayerResource") || cls.equals("CDOTA_Unit_Roshan") || cls.contains("Rune") || cls.contains("Tormentor")) {
                if (dumped.add(cls)) fields.println(e);
            }
            if (!heroIndices.contains(e.getIndex()) && !cls.equals("CDOTA_Unit_Roshan") && !cls.contains("Tormentor")) continue;
            positions.println(String.join("\t", clean(ctx.getTick()), clean(time), clean(start), cls, clean(e.getIndex()),
                clean(property(e,"m_iTeamNum")), clean(property(e,"m_iHealth")), clean(property(e,"m_iMaxHealth")),
                clean(property(e,"m_flMana")), clean(property(e,"m_flMaxMana")), clean(property(e,"m_iCurrentLevel")),
                clean(coord(e,"X")), clean(coord(e,"Y")), clean(property(e,"m_lifeState")),
                clean(property(e,"m_iTaggedAsVisibleByTeam")), clean(property(e,"m_hAttackTarget"))));
            samples++;
        }
    }
    public void close() { combat.close(); positions.close(); fields.close(); teamState.close(); }
    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("ReadReplay replay.dem output-directory");
        long begin = System.nanoTime();
        Path dir = Path.of(args[1]);
        Files.deleteIfExists(dir.resolve("parse-summary.txt"));
        try (ReadReplay exporter = new ReadReplay(dir); MappedFileSource source = new MappedFileSource(args[0])) {
            Files.writeString(dir.resolve("info.txt"), Clarity.infoForFile(args[0]).toString());
            SimpleRunner runner = new SimpleRunner(source);
            runner.runWith(exporter);
            try (PrintWriter out = writer(dir.resolve("parse-summary.txt"))) {
                out.println("completed=true");
                out.println("events=" + exporter.events);
                out.println("positionRows=" + exporter.samples);
                out.println("lastCombatTimestamp=" + exporter.lastTime);
                exporter.counts.forEach((k,v) -> out.println(k + "=" + v));
            }
            System.out.println("Completed: " + exporter.events + " combat events, " + exporter.samples + " position rows, " + (System.nanoTime()-begin)/1e9 + " seconds.");
        }
    }
}
