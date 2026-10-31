package hielo;

import org.bukkit.Material;
import org.bukkit.block.Block;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.craftbukkit.v1_8_R3.entity.CraftPlayer;
import net.minecraft.server.v1_8_R3.PacketPlayInBlockPlace;
import io.netty.channel.ChannelDuplexHandler;
import io.netty.channel.ChannelHandlerContext;
import org.bukkit.plugin.java.JavaPlugin;

/**
 * Emula el printer del servidor real: un golpe (rotura en creativo) a un hielo lo deja como
 * agua fuente en vez de aire. Se usa WATER (id 8, agua que se actualiza, meta 0 = fuente),
 * igual que BlockIce de vanilla al romperse en supervivencia: si abajo o al costado hay
 * aire, el agua fluye (asi se ven las fugas). Cada 5 s escribe en el log los contadores.
 * Ademas saca el limitador de Spigot (5 C08 cada 30 ms por jugador): el servidor real no lo tiene
 * (el bot de cactus coloca ~950/s ahi). Se reescribe el timestamp de cada C08 en Netty.
 */
public final class HieloAgua extends JavaPlugin implements Listener {
    private volatile long c08;
    private long interact, rcb, placeCancel;
    private long golpes, agua, colocados, hieloColocado, ultimoGolpes, ultimoColocados;

    @Override
    public void onEnable() {
        getServer().getPluginManager().registerEvents(this, this);
        getServer().getScheduler().runTaskTimer(this, new Runnable() {
            @Override
            public void run() {
                for (org.bukkit.entity.Player pl : getServer().getOnlinePlayers()) {
                    try {
                        Object pc = ((CraftPlayer) pl).getHandle().playerConnection;
                        java.lang.reflect.Field f = pc.getClass().getDeclaredField("checkMovement"); f.setAccessible(true);
                        java.lang.reflect.Field fo = pc.getClass().getDeclaredField("o"); fo.setAccessible(true);
                        java.lang.reflect.Field fp = pc.getClass().getDeclaredField("p"); fp.setAccessible(true);
                        java.lang.reflect.Field fq = pc.getClass().getDeclaredField("q"); fq.setAccessible(true);
                        getLogger().info("DBG checkMovement=" + f.get(pc) + " tp=" + fo.get(pc) + "," + fp.get(pc) + "," + fq.get(pc) + " loc=" + pl.getLocation());
                    } catch (Exception ex) { getLogger().info("DBG " + ex); }
                }
                if (golpes == ultimoGolpes && colocados == ultimoColocados && c08 == 0) return;
                getLogger().info("HIELO golpes=" + golpes + " agua=" + agua + " colocados=" + colocados
                    + " hieloColocado=" + hieloColocado + " c08=" + c08 + " interact=" + interact + " rcb=" + rcb + " placeCancel=" + placeCancel + " t=" + System.currentTimeMillis());
                ultimoGolpes = golpes;
                ultimoColocados = colocados;
            }
        }, 100L, 100L);
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onInteract(org.bukkit.event.player.PlayerInteractEvent e) {
        interact++;
        if (e.getAction() == org.bukkit.event.block.Action.RIGHT_CLICK_BLOCK && ++rcb % 200 == 1) getLogger().info("RCB #" + rcb + " " + e.getClickedBlock() + " face=" + e.getBlockFace() + " cancel=" + e.isCancelled() + " item=" + e.getItem());
        if (interact % 1000 == 1) getLogger().info("interact #" + interact + " " + e.getAction() + " " + e.getClickedBlock() + " cancel=" + e.isCancelled()
            + " item=" + e.getItem());
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        final org.bukkit.entity.Player jugador = e.getPlayer();
        ((CraftPlayer) e.getPlayer()).getHandle().playerConnection.networkManager.channel.pipeline()
            .addBefore("packet_handler", "hielo_sin_limite", new ChannelDuplexHandler() {
                private long falso;

                @Override
                public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
                    if (msg instanceof PacketPlayInBlockPlace) {
                        falso = Math.max(falso + 31, System.currentTimeMillis());
                        ((PacketPlayInBlockPlace) msg).timestamp = falso;
                        c08++;
                        if (c08 <= 12 || c08 % 2000 == 1) {
                            PacketPlayInBlockPlace pk = (PacketPlayInBlockPlace) msg;
                            org.bukkit.Location l = jugador.getLocation();
                            getLogger().info("C08 #" + c08 + " pos=" + pk.a() + " face=" + pk.getFace() + " item=" + pk.getItemStack()
                                + " jugador=" + String.format("%.2f %.2f %.2f", l.getX(), l.getY(), l.getZ()));
                        }
                    }
                    super.channelRead(ctx, msg);
                }
            });
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        golpes++;
        Block b = e.getBlock();
        if (b.getType() != Material.ICE) return;
        e.setCancelled(true);
        b.setType(Material.WATER);
        agua++;
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onPlaceAll(BlockPlaceEvent e) {
        if (e.isCancelled() && ++placeCancel % 200 == 1) getLogger().info("PLACE cancelado #" + placeCancel + " " + e.getBlockPlaced() + " canBuild=" + e.canBuild());
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        colocados++;
        if (e.getBlockPlaced().getType() == Material.ICE) hieloColocado++;
    }
}
