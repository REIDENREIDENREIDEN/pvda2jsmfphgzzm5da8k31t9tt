"""Lanza y junta corridas del workflow bench.yml con el CLI `gh` (tiene que estar logueado: gh auth login).
  dispatch.py jar JAR [--tag jar-0.6.1]            cifra el jar (openssl aes-256-cbc pbkdf2, clave en la variable JAR_KEY)
                                                   y lo sube como asset m.bin de un release (lo crea si no existe)
  dispatch.py run --bench terreno|flujo [--jar jar-0.6.1] [--sha SHA256] [--scenarios all] [--shards 20] [--ref main]
  dispatch.py list                                 ultimas corridas del workflow
  dispatch.py watch RUN_ID                         sigue una corrida hasta que termina
  dispatch.py fetch RUN_ID [--dir runs]            baja los artifacts a runs/RUN_ID y junta las lineas RES
  dispatch.py merge DIR                            junta las lineas RES de una carpeta ya bajada
Repo: --repo OWNER/NOMBRE, o la variable BENCH_REPO, o el default de abajo.
"""
import argparse, os, subprocess, sys, tempfile

DEFAULT_REPO = 'REIDENREIDENREIDEN/pvda2jsmfphgzzm5da8k31t9tt'
HERE = os.path.dirname(os.path.abspath(__file__))


def gh(*args, check=True):
    print('+ gh ' + ' '.join(args), flush=True)
    return subprocess.run(['gh'] + list(args), check=check)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--repo', default=os.environ.get('BENCH_REPO', DEFAULT_REPO))
    sp = p.add_subparsers(dest='cmd', required=True)
    j = sp.add_parser('jar'); j.add_argument('jar'); j.add_argument('--tag', default='jar-0.6.1')
    r = sp.add_parser('run')
    r.add_argument('--bench', choices=['terreno', 'flujo'], required=True)
    r.add_argument('--jar', default='jar-0.6.1')
    r.add_argument('--sha', default='1e133afe27e9290542ef9324721e13f7e7a18ede3a2182eab8c4109e95da7d47')
    r.add_argument('--scenarios', default='all'); r.add_argument('--shards', default='20'); r.add_argument('--ref', default='main')
    sp.add_parser('list')
    w = sp.add_parser('watch'); w.add_argument('run_id')
    f = sp.add_parser('fetch'); f.add_argument('run_id'); f.add_argument('--dir', default='runs')
    m = sp.add_parser('merge'); m.add_argument('dir')
    a = p.parse_args()
    R = a.repo
    if a.cmd == 'jar':
        if subprocess.run(['gh', 'release', 'view', a.tag, '-R', R], capture_output=True).returncode != 0:
            gh('release', 'create', a.tag, '-R', R, '--title', a.tag, '--notes', 'jar bajo prueba')
        key = os.environ.get('JAR_KEY')
        if not key:
            sys.exit('falta la variable JAR_KEY (la misma clave que el secret JAR_KEY del repo)')
        with tempfile.TemporaryDirectory() as t:
            kf, out = os.path.join(t, 'k'), os.path.join(t, 'm.bin')
            with open(kf, 'w') as f:
                f.write(key)
            subprocess.run(['openssl', 'enc', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-salt',
                            '-in', a.jar, '-out', out, '-pass', 'file:' + kf], check=True)
            os.remove(kf)
            gh('release', 'upload', a.tag, out, '-R', R, '--clobber')
    elif a.cmd == 'run':
        gh('workflow', 'run', 'bench.yml', '-R', R, '--ref', a.ref, '-f', 'bench=' + a.bench, '-f', 'jar=' + a.jar,
           '-f', 'jar_sha256=' + a.sha, '-f', 'scenarios=' + a.scenarios, '-f', 'shards=' + str(a.shards))
        print('Ver el RUN_ID con: dispatch.py list')
    elif a.cmd == 'list':
        gh('run', 'list', '-R', R, '-w', 'bench.yml', '-L', '15')
    elif a.cmd == 'watch':
        gh('run', 'watch', a.run_id, '-R', R, '--exit-status', check=False)
    elif a.cmd == 'fetch':
        d = os.path.join(a.dir, a.run_id)
        os.makedirs(d, exist_ok=True)
        gh('run', 'download', a.run_id, '-R', R, '-D', d, check=False)
        subprocess.run([sys.executable, '-I', os.path.join(HERE, 'merge.py'), d], check=False)
    elif a.cmd == 'merge':
        subprocess.run([sys.executable, '-I', os.path.join(HERE, 'merge.py'), a.dir], check=False)


if __name__ == '__main__':
    main()
