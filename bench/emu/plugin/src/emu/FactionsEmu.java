package emu;

import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.Chunk;
import org.bukkit.GameMode;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryDragEvent;
import org.bukkit.event.world.WorldInitEvent;
import org.bukkit.generator.BlockPopulator;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.plugin.java.JavaPlugin;
import org.bukkit.scheduler.BukkitTask;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

/**
 * Emulador minimo de un servidor de factions para probar la preparacion automatica del mod:
 * /wild (GUI de cofre con ender pearl), factions (/f create, /f claim N, /f map con el formato real, /f setwarp,
 * /f warp, /f show), /fly, /ci, /printer, chunk busters (borran el chunk hasta la bedrock de a capas, cooldown).
 * Siembra claims de otras factions cerca de algunos destinos de /wild. Todo el texto sale de config.yml.
 * Cada evento importante queda en server.log con el prefijo EMU para que el banco lo cuente.
 */
public final class FactionsEmu extends JavaPlugin implements Listener {
    private static final class Fac {
        final String name;
        final boolean npc;
        final Map<String, Location> warps = new LinkedHashMap<String, Location>();

        Fac(String name, boolean npc) {
            this.name = name;
            this.npc = npc;
        }
    }

    private final Map<String, Fac> factions = new LinkedHashMap<String, Fac>();
    private final Map<UUID, String> members = new HashMap<UUID, String>();
    private final Map<Long, String> claims = new HashMap<Long, String>();
    private final Map<UUID, Double> money = new HashMap<UUID, Double>();
    private final Map<UUID, Long> wildCooldown = new HashMap<UUID, Long>();
    private final Map<UUID, Long> busterCooldown = new HashMap<UUID, Long>();
    private final Set<UUID> printer = new HashSet<UUID>();
    private final Set<Long> clearing = new HashSet<Long>();
    // Chunks donde se puso un buster. El buster real borra todo (liquidos y bloques con fisica incluidos) sin
    // actualizar a los vecinos: ni el agua/lava ni la arena/grava del anillo entran despues al chunk limpiado.
    private final Set<Long> busted = new HashSet<Long>();
    private final Random random = new Random();
    private int enemySeq;
    private int bustersPlaced, chunksCleared, wildTps, enemySeeds;

    @Override
    public void onLoad() {
        saveDefaultConfig();
    }

    @Override
    public void onEnable() {
        saveDefaultConfig();
        reloadConfig();
        getServer().getPluginManager().registerEvents(this, this);
        load();
        for (World w : getServer().getWorlds()) addPopulators(w);
        startMonitor();
        log("habilitado: " + factions.size() + " factions, " + claims.size() + " claims");
    }

    @Override
    public void onDisable() {
        save();
    }

    // ------------------------------------------------------------------ util

    private String c(String s) {
        return ChatColor.translateAlternateColorCodes('&', s == null ? "" : s);
    }

    private String msg(String path, String... kv) {
        String s = getConfig().getString(path, path);
        for (int i = 0; i + 1 < kv.length; i += 2) s = s.replace(kv[i], kv[i + 1]);
        return c(s);
    }

    private void log(String s) {
        getLogger().info("EMU " + s);
    }

    private static long key(int cx, int cz) {
        return ((long) cx << 32) ^ (cz & 0xffffffffL);
    }

    private Fac factionOf(Player p) {
        String f = members.get(p.getUniqueId());
        return f == null ? null : factions.get(f);
    }

    private String ownerAt(int cx, int cz) {
        return claims.get(key(cx, cz));
    }

    // ------------------------------------------------------------------ mundo

    private final Set<String> populated = new HashSet<String>();

    @EventHandler
    public void onWorldInit(WorldInitEvent e) {
        addPopulators(e.getWorld());
    }

    private void addPopulators(World w) {
        if (!populated.add(w.getName())) return;
        if (w.getEnvironment() != World.Environment.NORMAL) return;
        w.getPopulators().add(new BlockPopulator() {
            @Override
            public void populate(World world, Random r, Chunk chunk) {
                if (getConfig().getBoolean("world.flat-bedrock", true)) {
                    for (int x = 0; x < 16; x++) {
                        for (int z = 0; z < 16; z++) {
                            chunk.getBlock(x, 0, z).setType(Material.BEDROCK, false);
                            for (int y = 1; y <= 4; y++) {
                                Block b = chunk.getBlock(x, y, z);
                                if (b.getType() == Material.BEDROCK) b.setType(Material.STONE, false);
                            }
                        }
                    }
                }
                // TERRENO: chunks parcialmente borrados (otro buster a medias, pozo, techo flotante, chunk ya vacio).
                if (r.nextDouble() < getConfig().getDouble("world.partial-chance", 0)) partial(world, r, chunk);
                // TERRENO: pilares altos (torres de otra gente / montanas extremas) hasta cerca de la capa 250.
                if (r.nextDouble() < getConfig().getDouble("world.pillar-chance", 0)) {
                    int x = r.nextInt(16), z = r.nextInt(16), w = 1 + r.nextInt(3);
                    int top = getConfig().getInt("world.pillar-top", 250) - r.nextInt(30);
                    for (int dx = 0; dx < w && x + dx < 16; dx++) for (int dz = 0; dz < w && z + dz < 16; dz++)
                        for (int y = 1; y <= top; y++) if (chunk.getBlock(x + dx, y, z + dz).getType() == Material.AIR) chunk.getBlock(x + dx, y, z + dz).setType(Material.COBBLESTONE, false);
                }
                int flN = 1 + (r.nextDouble() < getConfig().getDouble("world.floating-extra-chance", 0) ? 2 + r.nextInt(3) : 0);
                for (int fl = 0; fl < flN; fl++)
                if (r.nextDouble() < getConfig().getDouble("world.floating-chance", 0.18)) {
                    int x = r.nextInt(12) + 2, z = r.nextInt(12) + 2;
                    int top = world.getHighestBlockYAt(chunk.getX() * 16 + x, chunk.getZ() * 16 + z);
                    int y = Math.min(getConfig().getInt("world.floating-max-y", 240), top + 4 + r.nextInt(getConfig().getInt("world.floating-spread", 10)));
                    int size = 1 + r.nextInt(getConfig().getInt("world.floating-size", 4));
                    Material[] mats = {Material.STONE, Material.DIRT, Material.LEAVES, Material.COBBLESTONE, Material.SAND};
                    Material m = mats[r.nextInt(mats.length)];
                    for (int dx = 0; dx < size; dx++) {
                        for (int dz = 0; dz < size; dz++) {
                            for (int dy = 0; dy < Math.max(1, size - 1); dy++) {
                                if (x + dx > 15 || z + dz > 15) continue;
                                if (r.nextInt(5) == 0) continue;
                                // arena flotante: se queda (sin fisica) como los bloques flotantes reales
                                chunk.getBlock(x + dx, y + dy, z + dz).setType(m, false);
                            }
                        }
                    }
                }
            }
        });
        log("poblador (bedrock plana + bloques flotantes) en " + w.getName());
    }

    /** TERRENO: deja el chunk como si otro lo hubiera borrado a medias. */
    private void partial(World world, Random r, Chunk chunk) {
        int kind = r.nextInt(4);
        int x0 = r.nextInt(8), z0 = r.nextInt(8), x1 = x0 + 4 + r.nextInt(12 - x0 + 4), z1 = z0 + 4 + r.nextInt(12 - z0 + 4);
        x1 = Math.min(15, x1);
        z1 = Math.min(15, z1);
        int top = 1;
        for (int x = 0; x < 16; x++) for (int z = 0; z < 16; z++) top = Math.max(top, world.getHighestBlockYAt(chunk.getX() * 16 + x, chunk.getZ() * 16 + z));
        int ya, yb;
        if (kind == 0) { ya = 1; yb = 255; x0 = 0; z0 = 0; x1 = 15; z1 = 15; }           // ya vacio hasta la bedrock
        else if (kind == 1) { ya = 1 + r.nextInt(Math.max(1, top / 2)); yb = 255; }       // pozo/escalon: arriba borrado
        else if (kind == 2) { ya = 3 + r.nextInt(20); yb = Math.max(ya + 4, top - 3 - r.nextInt(6)); x0 = 0; z0 = 0; x1 = 15; z1 = 15; } // techo flotante
        else { ya = 1; yb = 255; }                                                             // columna hasta la bedrock
        for (int x = x0; x <= x1; x++) for (int z = z0; z <= z1; z++) for (int y = ya; y <= yb && y < 256; y++) {
            Block b = chunk.getBlock(x, y, z);
            if (b.getType() != Material.AIR && b.getType() != Material.BEDROCK) b.setType(Material.AIR, false);
        }
        log("PARCIAL chunk " + chunk.getX() + "," + chunk.getZ() + " tipo " + kind + " x" + x0 + "-" + x1 + " z" + z0 + "-" + z1 + " y" + ya + "-" + yb);
    }

    // ------------------------------------------------------------------ TERRENO: medicion

    private final Map<UUID, Boolean> wasFlying = new HashMap<UUID, Boolean>();
    private final Map<UUID, Double> fallTop = new HashMap<UUID, Double>();
    private int printPlaced;
    private int monTick;
    private final List<String> printFirst = new ArrayList<String>();

    private void startMonitor() {
        Bukkit.getScheduler().runTaskTimer(this, new Runnable() {
            @Override
            public void run() {
                for (Player p : Bukkit.getOnlinePlayers()) {
                    UUID id = p.getUniqueId();
                    Location l = p.getLocation();
                    boolean fl = p.isFlying();
                    Boolean was = wasFlying.put(id, fl);
                    if (was != null && was && !fl) log(String.format(Locale.ROOT, "VUELO off %s en %.2f,%.2f,%.2f", p.getName(), l.getX(), l.getY(), l.getZ()));
                    // Caida: sin vuelo y bajando. Se registra al tocar el piso si bajo > 2.5 bloques.
                    if (!fl && !p.isOnGround()) {
                        Double t = fallTop.get(id);
                        if (t == null || l.getY() > t) fallTop.put(id, l.getY());
                    } else {
                        Double t = fallTop.remove(id);
                        if (t != null && t - l.getY() > 2.5) log(String.format(Locale.ROOT, "CAIDA %s de y=%.2f a y=%.2f (%.1f bloques) en %.1f,%.1f", p.getName(), t, l.getY(), t - l.getY(), l.getX(), l.getZ()));
                    }
                    // Dentro de un bloque solido (cabeza o pies).
                    Block feet = l.getBlock(), head = l.clone().add(0, 1.62, 0).getBlock();
                    if ((feet.getType().isSolid() && feet.getType().isOccluding()) || (head.getType().isSolid() && head.getType().isOccluding()))
                        if (++monTick % 10 == 0) log(String.format(Locale.ROOT, "ADENTRO %s %s/%s en %.2f,%.2f,%.2f", p.getName(), feet.getType(), head.getType(), l.getX(), l.getY(), l.getZ()));
                }
            }
        }, 20, 1);
    }

    @EventHandler
    public void onDamage(org.bukkit.event.entity.EntityDamageEvent e) {
        if (!(e.getEntity() instanceof Player)) return;
        Location l = e.getEntity().getLocation();
        log(String.format(Locale.ROOT, "DANO %s %s %.1f en %.2f,%.2f,%.2f", ((Player) e.getEntity()).getName(), e.getCause(), e.getDamage(), l.getX(), l.getY(), l.getZ()));
    }

    @EventHandler
    public void onDeath(org.bukkit.event.entity.PlayerDeathEvent e) {
        log("MUERTE " + e.getEntity().getName() + " " + e.getDeathMessage());
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onPrintPlace(BlockPlaceEvent e) {
        if (isBuster(e.getItemInHand()) || !printer.contains(e.getPlayer().getUniqueId())) return;
        printPlaced++;
        Block b = e.getBlockPlaced();
        String s = b.getX() + "," + b.getY() + "," + b.getZ() + " " + b.getType();
        if (printFirst.size() < 40) {
            printFirst.add(s);
            log("PRINT " + printPlaced + " " + s);
        }
    }

    // ------------------------------------------------------------------ persistencia

    private File dataFile() {
        return new File(getDataFolder(), "data.yml");
    }

    private void load() {
        File f = dataFile();
        if (!f.isFile()) return;
        YamlConfiguration y = YamlConfiguration.loadConfiguration(f);
        enemySeq = y.getInt("enemySeq", 0);
        ConfigurationSection fs = y.getConfigurationSection("factions");
        if (fs != null) {
            for (String k : fs.getKeys(false)) {
                ConfigurationSection s = fs.getConfigurationSection(k);
                Fac fac = new Fac(s.getString("name", k), s.getBoolean("npc"));
                ConfigurationSection ws = s.getConfigurationSection("warps");
                if (ws != null) {
                    for (String wn : ws.getKeys(false)) {
                        World w = Bukkit.getWorld(ws.getString(wn + ".world", "world"));
                        if (w != null) fac.warps.put(wn, new Location(w, ws.getDouble(wn + ".x"), ws.getDouble(wn + ".y"), ws.getDouble(wn + ".z")));
                    }
                }
                factions.put(k, fac);
                for (String cl : s.getStringList("claims")) {
                    String[] p = cl.split(",");
                    claims.put(key(Integer.parseInt(p[0]), Integer.parseInt(p[1])), k);
                }
            }
        }
        ConfigurationSection ms = y.getConfigurationSection("members");
        if (ms != null) for (String u : ms.getKeys(false)) members.put(UUID.fromString(u), ms.getString(u));
        ConfigurationSection mo = y.getConfigurationSection("money");
        if (mo != null) for (String u : mo.getKeys(false)) money.put(UUID.fromString(u), mo.getDouble(u));
    }

    private void save() {
        YamlConfiguration y = new YamlConfiguration();
        y.set("enemySeq", enemySeq);
        Map<String, List<String>> byFac = new HashMap<String, List<String>>();
        for (Map.Entry<Long, String> e : claims.entrySet()) {
            int cx = (int) (e.getKey() >> 32), cz = (int) (long) e.getKey();
            List<String> l = byFac.get(e.getValue());
            if (l == null) byFac.put(e.getValue(), l = new ArrayList<String>());
            l.add(cx + "," + cz);
        }
        for (Map.Entry<String, Fac> e : factions.entrySet()) {
            String p = "factions." + e.getKey();
            y.set(p + ".name", e.getValue().name);
            y.set(p + ".npc", e.getValue().npc);
            List<String> l = byFac.get(e.getKey());
            y.set(p + ".claims", l == null ? new ArrayList<String>() : l);
            for (Map.Entry<String, Location> w : e.getValue().warps.entrySet()) {
                y.set(p + ".warps." + w.getKey() + ".world", w.getValue().getWorld().getName());
                y.set(p + ".warps." + w.getKey() + ".x", w.getValue().getX());
                y.set(p + ".warps." + w.getKey() + ".y", w.getValue().getY());
                y.set(p + ".warps." + w.getKey() + ".z", w.getValue().getZ());
            }
        }
        for (Map.Entry<UUID, String> e : members.entrySet()) y.set("members." + e.getKey(), e.getValue());
        for (Map.Entry<UUID, Double> e : money.entrySet()) y.set("money." + e.getKey(), e.getValue());
        try {
            getDataFolder().mkdirs();
            y.save(dataFile());
        } catch (Exception ex) {
            log("no se pudo guardar data.yml: " + ex);
        }
    }

    private double balance(Player p) {
        Double d = money.get(p.getUniqueId());
        return d == null ? getConfig().getDouble("money.start", 1000000) : d;
    }

    // ------------------------------------------------------------------ comandos

    @Override
    public boolean onCommand(CommandSender sender, Command cmd, String label, String[] args) {
        String name = cmd.getName().toLowerCase(Locale.ROOT);
        if (name.equals("cbgive")) return cbgive(sender, args);
        if (name.equals("emu")) return emu(sender, args);
        if (!(sender instanceof Player)) {
            sender.sendMessage("Solo jugadores.");
            return true;
        }
        Player p = (Player) sender;
        log("CMD " + p.getName() + " /" + label + " " + String.join(" ", args));
        switch (name) {
            case "wild": wild(p); return true;
            case "f": faction(p, args); return true;
            case "fly": fly(p); return true;
            case "ci":
                p.getInventory().clear();
                p.getInventory().setArmorContents(null);
                p.sendMessage(msg("ci.msg"));
                return true;
            case "printer": printer(p); return true;
            case "bal":
                p.sendMessage(c("&aBalance: &e$" + String.format(Locale.ROOT, "%,.2f", balance(p))));
                return true;
            default: return false;
        }
    }

    private boolean cbgive(CommandSender sender, String[] args) {
        if (sender instanceof Player && !sender.isOp()) return true;
        Player t = args.length >= 1 ? Bukkit.getPlayerExact(args[0]) : (sender instanceof Player ? (Player) sender : null);
        int n = args.length >= 2 ? Integer.parseInt(args[1]) : 64;
        if (t == null) {
            sender.sendMessage("Jugador no conectado.");
            return true;
        }
        int left = n;
        while (left > 0) {
            ItemStack it = busterItem(Math.min(64, left));
            t.getInventory().addItem(it);
            left -= it.getAmount();
        }
        sender.sendMessage("Dados " + n + " chunk busters a " + t.getName());
        log("CBGIVE " + t.getName() + " " + n);
        return true;
    }

    private boolean emu(CommandSender sender, String[] args) {
        if (sender instanceof Player && !sender.isOp()) return true;
        String sub = args.length > 0 ? args[0].toLowerCase(Locale.ROOT) : "info";
        if (sub.equals("reset")) {
            factions.clear();
            members.clear();
            claims.clear();
            money.clear();
            wildCooldown.clear();
            busterCooldown.clear();
            printer.clear();
            save();
            sender.sendMessage("EMU reseteado");
            log("RESET");
        } else if (sub.equals("enemy") && args.length >= 4) {
            Player t = Bukkit.getPlayerExact(args[1]);
            if (t != null) {
                Chunk ch = t.getLocation().getChunk();
                seedEnemy(ch.getX() + Integer.parseInt(args[2]), ch.getZ() + Integer.parseInt(args[3]), 1 + random.nextInt(4));
            }
        } else if (sub.equals("join") && args.length >= 3) {
            // Para probar la regla "ya esta en una faction": mete al jugador en una faction existente o nueva.
            Player t = Bukkit.getPlayerExact(args[1]);
            if (t != null) {
                String k = args[2].toLowerCase(Locale.ROOT);
                if (!factions.containsKey(k)) factions.put(k, new Fac(args[2], false));
                members.put(t.getUniqueId(), k);
                save();
                log("JOIN " + t.getName() + " " + args[2]);
            }
        } else if (sub.equals("check") && args.length >= 2) {
            check(sender, args[1], args.length >= 3 ? Integer.parseInt(args[2]) : 3);
        } else {
            sender.sendMessage("EMU factions=" + factions.size() + " claims=" + claims.size() + " busters=" + bustersPlaced
                + " limpios=" + chunksCleared + " wild=" + wildTps + " enemigos=" + enemySeeds);
        }
        return true;
    }

    /** Verificacion del banco: faction del jugador, warp, claim y hueco vacio hasta la bedrock. */
    private void check(CommandSender sender, String player, int radius) {
        Player t = Bukkit.getPlayerExact(player);
        UUID id = t != null ? t.getUniqueId() : null;
        String k = id == null ? null : members.get(id);
        Fac f = k == null ? null : factions.get(k);
        if (f == null) {
            log("CHECK sin faction");
            return;
        }
        Location w = f.warps.isEmpty() ? null : f.warps.values().iterator().next();
        if (w == null) {
            log("CHECK " + f.name + " sin warp");
            return;
        }
        int ccx = w.getBlockX() >> 4, ccz = w.getBlockZ() >> 4;
        int own = 0, ownTotal = 0;
        for (String o : claims.values()) if (o.equals(k)) ownTotal++;
        int ring = radius + 1;
        for (int dx = -ring; dx <= ring; dx++) for (int dz = -ring; dz <= ring; dz++) if (k.equals(ownerAt(ccx + dx, ccz + dz))) own++;
        int solid = 0, liquid = 0, bad = 0;
        StringBuilder badChunks = new StringBuilder();
        Map<Material, Integer> types = new HashMap<Material, Integer>();
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                int n = 0;
                for (int x = 0; x < 16; x++) for (int z = 0; z < 16; z++) for (int y = 1; y < 256; y++) {
                    Block b = w.getWorld().getBlockAt((ccx + dx) * 16 + x, y, (ccz + dz) * 16 + z);
                    Material m = b.getType();
                    if (m == Material.AIR || m == Material.BEDROCK) continue;
                    if (b.isLiquid()) liquid++;
                    else { solid++; n++; Integer q = types.get(m); types.put(m, q == null ? 1 : q + 1); }
                }
                if (n > 0) { bad++; badChunks.append(' ').append(ccx + dx).append(',').append(ccz + dz).append('=').append(n); }
            }
        }
        int side = 2 * radius + 1, sideRing = 2 * ring + 1;
        String r = String.format(Locale.ROOT, "CHECK print=%d faction=%s warp=%.2f,%.2f,%.2f chunk=%d,%d warpCentrado=%s claim%dx%d=%d/%d claimsTotal=%d hueco%dx%d solidos=%d liquidos=%d chunksConBloques=%d%s jugador=%s",
            printPlaced, f.name, w.getX(), w.getY(), w.getZ(), ccx, ccz, (Math.abs(w.getX() - (ccx * 16 + 8)) <= 8 && Math.abs(w.getZ() - (ccz * 16 + 8)) <= 8),
            sideRing, sideRing, own, sideRing * sideRing, ownTotal, side, side, solid, liquid, bad, badChunks + " tipos=" + types,
            t == null ? "-" : String.format(Locale.ROOT, "%.2f,%.2f,%.2f (relativo a la esquina min del hueco: %.2f,%.2f)", t.getLocation().getX(), t.getLocation().getY(), t.getLocation().getZ(),
                t.getLocation().getX() - (ccx - radius) * 16, t.getLocation().getZ() - (ccz - radius) * 16));
        log(r);
        sender.sendMessage(r);
    }

    // ------------------------------------------------------------------ /wild

    private void wild(Player p) {
        Long until = wildCooldown.get(p.getUniqueId());
        if (until != null && until > System.currentTimeMillis()) {
            long s = (until - System.currentTimeMillis() + 999) / 1000;
            p.sendMessage(msg("wild.msg-cooldown").replace("%s", Long.toString(s)));
            return;
        }
        int size = getConfig().getInt("wild.gui-size", 27);
        Inventory inv = Bukkit.createInventory(null, size, c(getConfig().getString("wild.gui-title")));
        if (getConfig().getBoolean("wild.filler", true)) {
            for (int i = 0; i < size; i++) inv.setItem(i, named(new ItemStack(Material.STAINED_GLASS_PANE, 1, (short) 7), " ", null));
            inv.setItem(11, named(new ItemStack(Material.GRASS), "&aOverworld", list("&7You are here.")));
            inv.setItem(15, named(new ItemStack(Material.BARRIER), "&cClose", null));
        }
        inv.setItem(getConfig().getInt("wild.pearl-slot", 13), named(new ItemStack(Material.ENDER_PEARL),
            getConfig().getString("wild.pearl-name"), getConfig().getStringList("wild.pearl-lore")));
        p.openInventory(inv);
        log("WILD gui " + p.getName());
    }

    private static List<String> list(String... s) {
        List<String> l = new ArrayList<String>();
        for (String x : s) l.add(x);
        return l;
    }

    private ItemStack named(ItemStack it, String name, List<String> lore) {
        ItemMeta m = it.getItemMeta();
        m.setDisplayName(c(name));
        if (lore != null) {
            List<String> l = new ArrayList<String>();
            for (String s : lore) l.add(c(s));
            m.setLore(l);
        }
        it.setItemMeta(m);
        return it;
    }

    @EventHandler
    public void onClick(InventoryClickEvent e) {
        if (!(e.getWhoClicked() instanceof Player)) return;
        String title = e.getInventory().getTitle();
        if (title == null || !title.equals(c(getConfig().getString("wild.gui-title")))) return;
        e.setCancelled(true);
        final Player p = (Player) e.getWhoClicked();
        ItemStack it = e.getCurrentItem();
        if (e.getRawSlot() >= e.getInventory().getSize() || it == null) return;
        if (it.getType() == Material.BARRIER) {
            p.closeInventory();
            return;
        }
        if (it.getType() != Material.ENDER_PEARL) return;
        p.closeInventory();
        p.sendMessage(msg("wild.msg-teleporting"));
        log("WILD click " + p.getName());
        Bukkit.getScheduler().runTaskLater(this, new Runnable() {
            @Override
            public void run() {
                if (p.isOnline()) teleportWild(p);
            }
        }, getConfig().getInt("wild.delay-ticks", 30));
    }

    @EventHandler
    public void onDrag(InventoryDragEvent e) {
        String title = e.getInventory().getTitle();
        if (title != null && title.equals(c(getConfig().getString("wild.gui-title")))) e.setCancelled(true);
    }

    private void teleportWild(Player p) {
        World w = p.getWorld();
        int min = getConfig().getInt("wild.min-radius", 1200), max = getConfig().getInt("wild.max-radius", 4000);
        Location dest = null;
        for (int tries = 0; tries < 40 && dest == null; tries++) {
            int x = (min + random.nextInt(Math.max(1, max - min))) * (random.nextBoolean() ? 1 : -1);
            int z = (min + random.nextInt(Math.max(1, max - min))) * (random.nextBoolean() ? 1 : -1);
            if (ownerAt(x >> 4, z >> 4) != null) continue;
            // r2-terreno: poblar antes de medir (arboles/bloques flotantes de los vecinos caian encima del jugador).
            if (getConfig().getBoolean("wild.safe", true))
                for (int dx = -2; dx <= 2; dx++) for (int dz = -2; dz <= 2; dz++) w.loadChunk((x >> 4) + dx, (z >> 4) + dz, true);
            int y = w.getHighestBlockYAt(x, z);
            Block ground = w.getBlockAt(x, y - 1, z);
            if (getConfig().getBoolean("wild.avoid-liquids", true) && ground.isLiquid() && tries < 39) continue;
            if (getConfig().getBoolean("wild.safe", true) && !safeSpot(w, x, y, z) && tries < 39) { log("WILD inseguro " + x + "," + y + "," + z); continue; }
            dest = new Location(w, x + 0.5, y + 0.1, z + 0.5, p.getLocation().getYaw(), p.getLocation().getPitch());
        }
        if (dest == null) return;
        if (random.nextDouble() < getConfig().getDouble("wild.enemy-chance", 0.45)) {
            int mn = getConfig().getInt("wild.enemy-min-chunks", 2), mx = getConfig().getInt("wild.enemy-max-chunks", 8);
            int dx = (mn + random.nextInt(Math.max(1, mx - mn + 1))) * (random.nextBoolean() ? 1 : -1);
            int dz = random.nextInt(2 * Math.min(mx, 7) + 1) - Math.min(mx, 7);
            if (random.nextBoolean()) { int t = dx; dx = Math.max(-7, Math.min(7, dz)); dz = Math.max(-7, Math.min(7, t)); if (Math.abs(dx) < mn && Math.abs(dz) < mn) dz = mn; }
            seedEnemy((dest.getBlockX() >> 4) + dx, (dest.getBlockZ() >> 4) + dz, 1 + random.nextInt(5));
        }
        p.teleport(dest);
        wildTps++;
        wildCooldown.put(p.getUniqueId(), System.currentTimeMillis() + getConfig().getInt("wild.cooldown-seconds", 8) * 1000L);
        p.sendMessage(msg("wild.msg-teleported", "%x%", Integer.toString(dest.getBlockX()), "%y%", Integer.toString(dest.getBlockY()),
            "%z%", Integer.toString(dest.getBlockZ())));
        log("WILD tp " + p.getName() + " -> " + dest.getBlockX() + "," + dest.getBlockY() + "," + dest.getBlockZ()
            + " chunk " + (dest.getBlockX() >> 4) + "," + (dest.getBlockZ() >> 4) + " bioma " + w.getBiome(dest.getBlockX(), dest.getBlockZ()));
    }

    private void seedEnemy(int cx, int cz, int n) {
        String name = "Rivals" + (++enemySeq);
        String k = name.toLowerCase(Locale.ROOT);
        factions.put(k, new Fac(name, true));
        int x = cx, z = cz;
        for (int i = 0; i < n; i++) {
            if (ownerAt(x, z) == null) claims.put(key(x, z), k);
            if (random.nextBoolean()) x += random.nextBoolean() ? 1 : -1;
            else z += random.nextBoolean() ? 1 : -1;
        }
        enemySeeds++;
        save();
        log("ENEMY " + name + " cerca del chunk " + cx + "," + cz + " (" + n + " chunks)");
    }

    // ------------------------------------------------------------------ /f

    private void faction(Player p, String[] args) {
        String sub = args.length > 0 ? args[0].toLowerCase(Locale.ROOT) : "help";
        switch (sub) {
            case "create": create(p, args); return;
            case "claim": claim(p, args); return;
            case "map": map(p); return;
            case "setwarp": setwarp(p, args); return;
            case "warp": warp(p, args); return;
            case "show": case "f": case "who": show(p); return;
            case "disband": case "leave": case "kick": case "unclaim": case "unclaimall": case "deinvite":
                log("PROHIBIDO /f " + sub + " de " + p.getName());
                p.sendMessage(msg("faction.msg-disabled"));
                return;
            default:
                p.sendMessage(c("&6/f create <name>, /f claim <radius>, /f map, /f setwarp <name>, /f warp <name>, /f show"));
        }
    }

    private void create(Player p, String[] args) {
        if (factionOf(p) != null) {
            p.sendMessage(msg("faction.msg-must-leave"));
            return;
        }
        if (args.length < 2 || !args[1].matches(getConfig().getString("faction.name-regex", "[A-Za-z0-9]{3,16}"))) {
            p.sendMessage(msg("faction.msg-bad-name"));
            return;
        }
        String k = args[1].toLowerCase(Locale.ROOT);
        if (factions.containsKey(k)) {
            p.sendMessage(msg("faction.msg-tag-taken"));
            return;
        }
        factions.put(k, new Fac(args[1], false));
        members.put(p.getUniqueId(), k);
        save();
        p.sendMessage(msg("faction.msg-created", "%name%", args[1]));
        log("CREATE " + p.getName() + " " + args[1]);
    }

    private void show(Player p) {
        Fac f = factionOf(p);
        if (f == null && !getConfig().getBoolean("faction.show-wilderness-for-factionless", true)) {
            p.sendMessage(msg("faction.msg-not-in-faction"));
            return;
        }
        String name = f == null ? "Wilderness" : f.name;
        int land = 0;
        if (f != null) for (String o : claims.values()) if (o.equals(f.name.toLowerCase(Locale.ROOT))) land++;
        for (String l : getConfig().getStringList("faction.show-lines")) {
            p.sendMessage(c(l.replace("%name%", name).replace("%land%", Integer.toString(land))));
        }
    }

    private void claim(Player p, String[] args) {
        Fac f = factionOf(p);
        if (f == null) {
            p.sendMessage(msg("faction.msg-not-in-faction"));
            return;
        }
        int r = 1;
        if (args.length >= 2) {
            try {
                r = Integer.parseInt(args[1]);
            } catch (NumberFormatException e) {
                p.sendMessage(msg("claim.msg-usage"));
                return;
            }
        }
        if (r < 1 || r > getConfig().getInt("claim.max-radius", 15)) {
            p.sendMessage(msg("claim.msg-usage"));
            return;
        }
        Chunk ch = p.getLocation().getChunk();
        int half = r - 1; // FactionsUUID: radio N = cuadrado de lado 2N-1
        String k = f.name.toLowerCase(Locale.ROOT);
        List<long[]> todo = new ArrayList<long[]>();
        for (int dx = -half; dx <= half; dx++) {
            for (int dz = -half; dz <= half; dz++) {
                int cx = ch.getX() + dx, cz = ch.getZ() + dz;
                String o = ownerAt(cx, cz);
                if (o != null && !o.equals(k)) {
                    p.sendMessage(msg("claim.msg-conflict", "%x%", Integer.toString(cx), "%z%", Integer.toString(cz), "%owner%", factions.get(o).name));
                    continue;
                }
                if (o == null) todo.add(new long[] {cx, cz});
            }
        }
        double cost = todo.size() * getConfig().getDouble("claim.cost-per-chunk", 0);
        if (cost > balance(p)) {
            p.sendMessage(msg("claim.msg-money", "%cost%", String.format(Locale.ROOT, "%.2f", cost)));
            return;
        }
        money.put(p.getUniqueId(), balance(p) - cost);
        for (long[] t : todo) claims.put(key((int) t[0], (int) t[1]), k);
        save();
        p.sendMessage(msg("claim.msg-ok", "%name%", f.name, "%count%", Integer.toString(todo.size()), "%radius%", Integer.toString(r)));
        log("CLAIM " + p.getName() + " " + f.name + " centro " + ch.getX() + "," + ch.getZ() + " radio " + r + " nuevos " + todo.size());
    }

    private void map(Player p) {
        Location l = p.getLocation();
        int pcx = l.getBlockX() >> 4, pcz = l.getBlockZ() >> 4;
        Fac mine = factionOf(p);
        String mineKey = mine == null ? null : mine.name.toLowerCase(Locale.ROOT);
        String here = ownerAt(pcx, pcz);
        String territory = here == null ? getConfig().getString("map.territory-wilderness", "&2Wilderness")
            : (here.equals(mineKey) ? getConfig().getString("map.own-color", "&a") : getConfig().getString("map.enemy-color", "&c")) + factions.get(here).name;
        p.sendMessage(msg("map.header", "%x%", Integer.toString(pcx), "%z%", Integer.toString(pcz), "%territory%", territory));
        int h = getConfig().getInt("map.height", 17), w = getConfig().getInt("map.width", 49);
        int hh = h / 2, hw = w / 2;
        String[] compass = compass(l.getYaw());
        String wild = c(getConfig().getString("map.wild-color", "&7")) + getConfig().getString("map.wild-char", "-");
        for (int r = 0; r < h; r++) {
            StringBuilder row = new StringBuilder();
            for (int col = 0; col < w; col++) {
                if (r < 3 && col < 3) {
                    row.append(compass[r * 3 + col]);
                    continue;
                }
                int cx = pcx - hw + col, cz = pcz - hh + r;
                if (cx == pcx && cz == pcz) {
                    row.append(c(getConfig().getString("map.player-color", "&b"))).append(getConfig().getString("map.player-char", "+"));
                    continue;
                }
                String o = ownerAt(cx, cz);
                if (o == null) row.append(wild);
                else if (o.equals(mineKey)) row.append(c(getConfig().getString("map.own-color", "&a"))).append(getConfig().getString("map.own-char", "/"));
                else row.append(c(getConfig().getString("map.enemy-color", "&c"))).append(getConfig().getString("map.enemy-char", "\\"));
            }
            p.sendMessage(row.toString());
        }
        String legend = getConfig().getString("map.legend", "");
        if (!legend.isEmpty()) p.sendMessage(c(legend));
    }

    /** Brujula de FactionsUUID: 3x3 celdas, la direccion a la que mira el jugador en rojo. */
    private String[] compass(float yaw) {
        double deg = ((yaw - 180) % 360 + 360) % 360; // 0 = norte (-Z)
        String act = c(getConfig().getString("map.compass-active-color", "&c")), def = c(getConfig().getString("map.compass-color", "&6"));
        String[] chars = {"\\", "N", "/", "W", "+", "E", "/", "S", "\\"};
        int active; // indice de la celda activa
        if (deg < 22.5 || deg >= 337.5) active = 1;
        else if (deg < 67.5) active = 2;
        else if (deg < 112.5) active = 5;
        else if (deg < 157.5) active = 8;
        else if (deg < 202.5) active = 7;
        else if (deg < 247.5) active = 6;
        else if (deg < 292.5) active = 3;
        else active = 0;
        String[] out = new String[9];
        for (int i = 0; i < 9; i++) out[i] = (i == active ? act : def) + chars[i];
        return out;
    }

    private void setwarp(Player p, String[] args) {
        Fac f = factionOf(p);
        if (f == null) {
            p.sendMessage(msg("faction.msg-not-in-faction"));
            return;
        }
        Chunk ch = p.getLocation().getChunk();
        if (!f.name.toLowerCase(Locale.ROOT).equals(ownerAt(ch.getX(), ch.getZ()))) {
            p.sendMessage(msg("warp.msg-not-own"));
            return;
        }
        String n = args.length >= 2 ? args[1] : "home";
        f.warps.put(n, p.getLocation().clone());
        save();
        p.sendMessage(msg("warp.msg-set", "%name%", n));
        Location l = p.getLocation();
        log(String.format(Locale.ROOT, "SETWARP %s %s %s en %.2f,%.2f,%.2f chunk %d,%d", p.getName(), f.name, n, l.getX(), l.getY(), l.getZ(), ch.getX(), ch.getZ()));
    }

    private void warp(Player p, String[] args) {
        Fac f = factionOf(p);
        Location l = f == null || args.length < 2 ? null : f.warps.get(args[1]);
        if (l == null) {
            p.sendMessage(msg("warp.msg-unknown"));
            return;
        }
        p.teleport(l);
        p.sendMessage(msg("warp.msg-warped", "%name%", args[1]));
    }

    // ------------------------------------------------------------------ /fly /printer

    private void fly(Player p) {
        boolean on = !p.getAllowFlight();
        p.setAllowFlight(on);
        if (!on) p.setFlying(false);
        p.sendMessage(msg(on ? "fly.msg-on" : "fly.msg-off"));
        Location fl = p.getLocation();
        log(String.format(Locale.ROOT, "FLY %s %s en %.2f,%.2f,%.2f pies=%s abajo=%s bioma=%s", p.getName(), on, fl.getX(), fl.getY(), fl.getZ(),
            fl.getBlock().getType(), fl.clone().add(0, -1, 0).getBlock().getType(), fl.getBlock().getBiome()));
    }

    private void printer(Player p) {
        boolean on = printer.add(p.getUniqueId());
        if (!on) printer.remove(p.getUniqueId());
        if (getConfig().getBoolean("printer.creative", true)) {
            boolean flying = p.isFlying();
            p.setGameMode(on ? GameMode.CREATIVE : GameMode.SURVIVAL);
            p.setAllowFlight(true);
            p.setFlying(flying);
        }
        p.sendMessage(msg(on ? "printer.msg-on" : "printer.msg-off"));
        log("PRINTER " + p.getName() + " " + on);
        // TERRENO: foto del hueco justo al prender el printer (antes de que el cane coloque nada).
        if (on) check(Bukkit.getConsoleSender(), p.getName(), 3);
    }

    // ------------------------------------------------------------------ chunk buster

    private ItemStack busterItem(int n) {
        Material m = Material.matchMaterial(getConfig().getString("buster.material", "ENDER_PORTAL_FRAME"));
        return named(new ItemStack(m == null ? Material.ENDER_PORTAL_FRAME : m, n), getConfig().getString("buster.name"),
            getConfig().getStringList("buster.lore"));
    }

    private boolean isBuster(ItemStack it) {
        if (it == null || !it.hasItemMeta() || !it.getItemMeta().hasDisplayName()) return false;
        return it.getItemMeta().getDisplayName().equals(c(getConfig().getString("buster.name")));
    }

    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        if (!isBuster(e.getItemInHand())) return;
        Player p = e.getPlayer();
        Block b = e.getBlockPlaced();
        int cx = b.getX() >> 4, cz = b.getZ() >> 4;
        Long until = busterCooldown.get(p.getUniqueId());
        if (until != null && until > System.currentTimeMillis()) {
            e.setCancelled(true);
            long s = (until - System.currentTimeMillis() + 999) / 1000;
            p.sendMessage(msg("buster.msg-cooldown").replace("%s", Long.toString(s)));
            log("BUSTER cooldown " + p.getName() + " chunk " + cx + "," + cz + " faltan " + s + " s");
            return;
        }
        String mode = getConfig().getString("buster.territory", "own-or-wilderness");
        String o = ownerAt(cx, cz);
        Fac f = factionOf(p);
        boolean own = f != null && f.name.toLowerCase(Locale.ROOT).equals(o);
        if ((mode.equals("own") && !own) || (mode.equals("own-or-wilderness") && o != null && !own)) {
            e.setCancelled(true);
            p.sendMessage(msg("buster.msg-territory"));
            log("BUSTER territorio " + p.getName() + " chunk " + cx + "," + cz);
            return;
        }
        if (!clearing.add(key(cx, cz))) {
            // Ya se esta borrando: igual gasta el item (como un plugin real) y no hace nada nuevo.
            p.sendMessage(msg("buster.msg-placed", "%x%", Integer.toString(cx), "%z%", Integer.toString(cz)));
            busterCooldown.put(p.getUniqueId(), System.currentTimeMillis() + getConfig().getInt("buster.cooldown-seconds", 5) * 1000L);
            bustersPlaced++;
            log("BUSTER repetido " + p.getName() + " chunk " + cx + "," + cz + " en " + b.getX() + "," + b.getY() + "," + b.getZ());
            return;
        }
        busterCooldown.put(p.getUniqueId(), System.currentTimeMillis() + getConfig().getInt("buster.cooldown-seconds", 5) * 1000L);
        bustersPlaced++;
        p.sendMessage(msg("buster.msg-placed", "%x%", Integer.toString(cx), "%z%", Integer.toString(cz)));
        log("BUSTER puesto " + p.getName() + " chunk " + cx + "," + cz + " en " + b.getX() + "," + b.getY() + "," + b.getZ() + " n=" + bustersPlaced);
        startClear(p, b.getWorld(), cx, cz);
    }

    @EventHandler(ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        if (clearing.contains(key(e.getBlock().getX() >> 4, e.getBlock().getZ() >> 4)) && e.getBlock().getType() == Material.ENDER_PORTAL_FRAME) {
            e.setCancelled(true);
        }
    }

    /** r2-terreno: y del bloque no-aire mas alto del chunk (sin heightmap). */
    private static int topNonAir(World w, int cx, int cz) {
        int t = 1;
        for (int x = 0; x < 16; x++) for (int z = 0; z < 16; z++)
            for (int y = 255; y > t; y--) if (w.getBlockAt(cx * 16 + x, y, cz * 16 + z).getType() != Material.AIR) { t = y; break; }
        return Math.min(255, t + 1);
    }

    /** r2-terreno: destino seguro como un RTP real (piso solido sin liquido/cactus, pies y cabeza libres, sin lava al lado). */
    private static boolean safeSpot(World w, int x, int y, int z) {
        Block g = w.getBlockAt(x, y - 1, z), f = w.getBlockAt(x, y, z), h = w.getBlockAt(x, y + 1, z);
        if (!g.getType().isSolid() || g.isLiquid() || g.getType() == Material.CACTUS) return false;
        if (f.getType().isSolid() || h.getType().isSolid() || f.isLiquid() || h.isLiquid()) return false;
        for (int dx = -1; dx <= 1; dx++) for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) {
            Material m = w.getBlockAt(x + dx, y + dy, z + dz).getType();
            if (m == Material.LAVA || m == Material.STATIONARY_LAVA || m == Material.FIRE || m == Material.CACTUS) return false;
        }
        return true;
    }

    @EventHandler(ignoreCancelled = true)
    public void onBustedFlow(org.bukkit.event.block.BlockFromToEvent e) {
        Block t = e.getToBlock();
        if (busted.contains(key(t.getX() >> 4, t.getZ() >> 4))) e.setCancelled(true);
    }

    @EventHandler(ignoreCancelled = true)
    public void onBustedFall(org.bukkit.event.entity.EntityChangeBlockEvent e) {
        if (!(e.getEntity() instanceof org.bukkit.entity.FallingBlock)) return;
        Block b = e.getBlock();
        if (busted.contains(key(b.getX() >> 4, b.getZ() >> 4))) { e.setCancelled(true); e.getEntity().remove(); }
    }

    private void startClear(final Player p, final World w, final int cx, final int cz) {
        busted.add(key(cx, cz));
        // TERRENO: orden (top-down | bottom-up), velocidad (layers-per-tick, ticks-per-layer), fisica (gravedad y
        // liquidos que entran del borde) y bloques que el buster deja (leave-chance: un grupo de piedra suelto).
        final int layers = Math.max(1, getConfig().getInt("buster.layers-per-tick", 2));
        final int every = Math.max(1, getConfig().getInt("buster.ticks-per-layer", 1));
        final boolean bottomUp = "bottom-up".equalsIgnoreCase(getConfig().getString("buster.order", "top-down"));
        final boolean physics = getConfig().getBoolean("buster.physics", false);
        final boolean leave = random.nextDouble() < getConfig().getDouble("buster.leave-chance", 0);
        final int lx = random.nextInt(14), lz = random.nextInt(14), ly = 2 + random.nextInt(40);
        final int[] y = {-1};
        final int[] top = {0};
        final int[] n = {0};
        final BukkitTask[] task = new BukkitTask[1];
        final long t0 = System.currentTimeMillis();
        task[0] = Bukkit.getScheduler().runTaskTimer(this, new Runnable() {
            @Override
            public void run() {
                if (y[0] < 0) {
                    // r2-terreno: el tope real del chunk (el heightmap no cuenta cactus/vidrio/etc. -> quedaban flotando).
                    top[0] = topNonAir(w, cx, cz);
                    y[0] = bottomUp ? 1 : top[0];
                }
                if (++n[0] % every != 0) return;
                for (int k = 0; k < layers && (bottomUp ? y[0] <= top[0] : y[0] >= 1); k++) {
                    for (int x = 0; x < 16; x++) {
                        for (int z = 0; z < 16; z++) {
                            if (leave && x >= lx && x < lx + 2 && z >= lz && z < lz + 2 && y[0] >= ly && y[0] < ly + 2) continue;
                            Block b = w.getBlockAt(cx * 16 + x, y[0], cz * 16 + z);
                            Material m = b.getType();
                            if (m != Material.AIR && m != Material.BEDROCK) b.setType(Material.AIR, false); // el buster real no actualiza vecinos (buster.physics ya no aplica)
                        }
                    }
                    y[0] += bottomUp ? 1 : -1;
                }
                if (bottomUp ? y[0] > top[0] : y[0] < 1) {
                    task[0].cancel();
                    clearing.remove(key(cx, cz));
                    chunksCleared++;
                    if (leave) {
                        for (int dx = 0; dx < 2; dx++) for (int dz = 0; dz < 2; dz++) for (int dy = 0; dy < 2; dy++)
                            w.getBlockAt(cx * 16 + lx + dx, ly + dy, cz * 16 + lz + dz).setType(Material.STONE, false);
                        log("BUSTER dejo bloques en chunk " + cx + "," + cz + " en " + (cx * 16 + lx) + "," + ly + "," + (cz * 16 + lz));
                    }
                    if (p.isOnline()) p.sendMessage(msg("buster.msg-done", "%x%", Integer.toString(cx), "%z%", Integer.toString(cz)));
                    log("BUSTER limpio chunk " + cx + "," + cz + " en " + (System.currentTimeMillis() - t0) + " ms (total " + chunksCleared + ")");
                }
            }
        }, getConfig().getInt("buster.start-delay-ticks", 20), 1);
    }
}
