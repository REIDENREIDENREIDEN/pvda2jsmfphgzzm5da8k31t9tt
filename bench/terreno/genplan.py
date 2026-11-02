# Banco TERRENO ronda 2 (jar 0.6.1 sha 1e133afe...): terrenos NUEVOS (semillas r2t-*) contra emu-terreno corregido.
# Uso: python genplan.py NVM  -> plan-tK.sh (3 corridas por VM, mezcla rapidas/lentas)
import json, sys
S = {
 'PHYS': 's/^  physics: false/  physics: true/',
 'SLOW': 's/^  ticks-per-layer: 1/  ticks-per-layer: 4/;s/^  layers-per-tick: 2/  layers-per-tick: 1/;s/^  start-delay-ticks: 20/  start-delay-ticks: 60/',
 'FAST': 's/^  layers-per-tick: 2/  layers-per-tick: 32/;s/^  start-delay-ticks: 20/  start-delay-ticks: 2/',
 'BUP': 's/^  order: top-down/  order: bottom-up/',
 'LEAVE': 's/^  leave-chance: 0.0/  leave-chance: 0.06/',
 'PART': 's/^  partial-chance: 0.0/  partial-chance: 0.35/',
 'PILL': 's/^  pillar-chance: 0.0/  pillar-chance: 0.12/',
 'FLOAT': 's/^  floating-chance: 0.18/  floating-chance: 1.0/;s/^  floating-extra-chance: 0.0/  floating-extra-chance: 0.5/;s/^  floating-max-y: 240/  floating-max-y: 250/;s/^  floating-spread: 10/  floating-spread: 120/;s/^  floating-size: 4/  floating-size: 7/',
}
def B(i): return json.dumps({"fixedBiome": i}, separators=(',', ':'))
def J(d): return json.dumps(d, separators=(',', ':'))
# fixedBiome real = id - 2 para ids >= 10 (visto en r1)
R = [
 ('d01','DEFAULT','',[],''), ('d02','DEFAULT','',['SLOW'],''), ('d03','DEFAULT','',['FAST'],''), ('d04','DEFAULT','',['BUP'],''),
 ('d05','DEFAULT','',['PART'],''), ('d06','DEFAULT','',['FLOAT','PILL'],''), ('d07','DEFAULT','',['PART'],'RESUME_AT=170'),
 ('d08','DEFAULT','',['SLOW','BUP'],''), ('d09','LARGEBIOMES','',[],''), ('d10','LARGEBIOMES','',['FAST'],''),
 ('a01','AMPLIFIED','',[],''), ('a02','AMPLIFIED','',['SLOW'],''), ('a03','AMPLIFIED','',['FAST'],''), ('a04','AMPLIFIED','',['PART'],''),
 ('a05','AMPLIFIED','',['FLOAT'],''), ('a06','AMPLIFIED','',[],'RESUME_AT=150'), ('a07','AMPLIFIED','',['PILL','FLOAT'],''), ('a08','AMPLIFIED','',['BUP','SLOW'],''),
 ('b-desierto1','CUSTOMIZED',B(2),[],''), ('b-desierto2','CUSTOMIZED',B(2),['SLOW'],''), ('b-mesa','CUSTOMIZED',B(35),[],''),
 ('b-hielo','CUSTOMIZED',B(10),[],''), ('b-montanahielo','CUSTOMIZED',B(11),['FAST'],''), ('b-taigafria','CUSTOMIZED',B(28),[],''),
 ('b-jungla','CUSTOMIZED',B(19),[],''), ('b-megataiga','CUSTOMIZED',B(30),[],''), ('b-roble','CUSTOMIZED',B(27),['BUP'],''),
 ('b-sabana','CUSTOMIZED',B(33),[],''), ('b-colinas','CUSTOMIZED',B(3),[],'RESUME_AT=200'), ('b-bosque','CUSTOMIZED',B(4),['LEAVE'],''),
 ('w-agua','CUSTOMIZED',J({"seaLevel":92}),[],''), ('w-lagos','CUSTOMIZED',J({"useWaterLakes":True,"waterLakeChance":1,"useLavaLakes":True,"lavaLakeChance":10}),[],''),
 ('w-lava','CUSTOMIZED',J({"useLavaOceans":True}),[],''), ('w-oceano','CUSTOMIZED',J({"seaLevel":80}),['LEAVE'],''), ('w-pantano','CUSTOMIZED',B(6),[],''),
 ('v-voladizo1','CUSTOMIZED',J({"heightScale":3000,"stretchY":1.0,"baseSize":8.5}),[],''),
 ('v-voladizo2','CUSTOMIZED',J({"heightScale":2000,"stretchY":2.0,"upperLimitScale":200,"lowerLimitScale":200}),['SLOW'],''),
 ('v-cuevas','AMPLIFIED','',['PART'],''), ('v-cuevas2','CUSTOMIZED',J({"useCaves":True,"useRavines":True,"useMineShafts":True,"dungeonChance":100,"baseSize":6.0}),['BUP'],''),
 # ESTRES (aparte): buster con fisica -> los liquidos del anillo entran al hueco.
 ('p-d01','DEFAULT','',['PHYS'],''), ('p-pantano','CUSTOMIZED',B(6),['PHYS'],''), ('p-lagos','CUSTOMIZED',J({"useWaterLakes":True,"waterLakeChance":1,"useLavaLakes":True,"lavaLakeChance":10}),['PHYS'],''),
 ('p-a01','AMPLIFIED','',['PHYS'],''), ('p-desierto','CUSTOMIZED',B(2),['PHYS'],''), ('p-taiga','CUSTOMIZED',B(28),['PHYS'],''),
 # RONDA X (mas dificil): semillas nuevas, cuevas/ravinas expuestas, lava a la vista, picos, agua alta y fallas combinadas.
 ('x-amp1','AMPLIFIED','',[],''), ('x-amp2','AMPLIFIED','',['LEAVE','SLOW'],''), ('x-amp3','AMPLIFIED','',['PART','LEAVE'],''),
 ('x-amp4','AMPLIFIED','',['FAST','BUP'],''), ('x-mezcla','AMPLIFIED','',['PART','LEAVE','PILL','SLOW'],''),
 ('x-cuevasexp','CUSTOMIZED',J({"useCaves":True,"useRavines":True,"useMineShafts":True,"dungeonChance":100,"seaLevel":10,"baseSize":4.0,"stretchY":20.0}),[],''),
 ('x-ravinas','CUSTOMIZED',J({"useRavines":True,"useCaves":True,"seaLevel":1,"baseSize":10.0,"heightScale":1500}),['LEAVE'],''),
 ('x-lavaexp','CUSTOMIZED',J({"useLavaLakes":True,"lavaLakeChance":4,"useLavaOceans":True,"seaLevel":56}),[],''),
 ('x-lavacuevas','CUSTOMIZED',J({"useLavaLakes":True,"lavaLakeChance":4,"useCaves":True,"useRavines":True,"seaLevel":8,"baseSize":5.0}),['PHYS'],''),
 ('x-picos','CUSTOMIZED',J({"fixedBiome":3,"biomeDepthOffset":3.0,"biomeScaleOffset":6.0,"heightScale":2000}),[],''),
 ('x-picos2','CUSTOMIZED',J({"biomeDepthOffset":5.0,"biomeScaleOffset":10.0}),['SLOW','LEAVE'],''),
 ('x-meseta','CUSTOMIZED',B(36),['PART'],''), ('x-hongos','CUSTOMIZED',B(12),[],''), ('x-megataiga','CUSTOMIZED',B(31),['LEAVE'],''),
 ('x-aguaalta','CUSTOMIZED',J({"seaLevel":150}),['LEAVE'],''),
 ('x-voladizos','CUSTOMIZED',J({"heightScale":4000,"stretchY":1.5,"baseSize":7.0,"upperLimitScale":100}),['FLOAT','PILL'],''),
]
if __name__ == '__main__':
    nvm = int(sys.argv[1])
    plans = [[] for _ in range(nvm)]
    for i, (tag, lt, gen, mods, extra) in enumerate(R):
        sed = ';'.join(S[m] for m in mods)
        plans[i % nvm].append("SEED=r2t-%s LEVEL_TYPE=%s GEN='%s' EMU_SED='%s' POST=90 MIN=16 %s bash /home/user/emu/run.sh /home/user/cane.jar %s" % (tag, lt, gen, sed, extra, tag))
    for k, p in enumerate(plans):
        open('plan-t%d.sh' % k, 'w', newline='\n').write('#!/bin/bash\n' + '\n'.join(p) + '\necho PLAN_FIN >> /home/user/emu/out/results.txt\n')
    print(len(R), 'corridas en', nvm, 'VMs')
