"""Public novel assets from Écrire. --publish pushes only these assets; --check is read-only."""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

SITE = Path(__file__).resolve().parents[1]
WRITING = SITE.parent / 'Ecrire'
sys.path.insert(0, str(WRITING))
from ecritoire.server import publication_metadata, read_text, cover_path

PUBLICATION_ID = 'les-esclaves-tome-1'
DATA = 'data/les-esclaves-astre-noir.js'
COVER = 'img/les-esclaves-astre-noir.png'
PDF = 'pdf/les-esclaves-t1-astre-noir.pdf'
PAGE = 'ecrits.html'
ARTIFACTS = [DATA, COVER, PDF, PAGE]
STATE = SITE / '.publication-state.json'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def atomic_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temporary, path)

def resolve_work(root=WRITING / 'ouvrages'):
    matches = [p.parent for p in root.glob('*/*/.ecritoire-name.json')
               if json.loads(read_text(p)).get('publicationId') == PUBLICATION_ID]
    if len(matches) != 1:
        raise ValueError(f'Publication {PUBLICATION_ID} : un ouvrage unique est requis, trouvé {len(matches)}.')
    return matches[0]

def read_genre(path):
    match = re.search(r'^genres\s*:\s*\n\s*-\s*(.+)$', read_text(path), re.MULTILINE)
    if not match:
        raise ValueError(f'Genre manquant : {path}')
    return match.group(1).strip().strip('"\'')

def source_data(work):
    meta = publication_metadata(work)
    source = work / 'text/input/input_roman.txt'
    blurb = work / 'text/input/4eme_de_couverture.txt'
    cover = cover_path(work)
    if not cover or not source.is_file() or not source.stat().st_size or not read_text(blurb).strip():
        raise ValueError('Manuscrit, quatrième de couverture et couverture sont requis pour publier.')
    genre = read_genre(work.parent / 'metadata.yml')
    files = [source, blurb, cover, work / '.ecritoire-name.json', work.parent / 'metadata.yml',
             WRITING / 'code/bin/build_book_export.py', WRITING / 'code/bin/root_roman_source.py', Path(__file__)]
    files += sorted(p for p in (WRITING / 'code/exporter').rglob('*') if p.is_file())
    signature = hashlib.sha256(json.dumps({'metadata': meta, 'genre': genre,
        'inputs': [(str(p.relative_to(WRITING)) if p.is_relative_to(WRITING) else p.name, sha(p)) for p in files]
    }, sort_keys=True).encode()).hexdigest()
    title = ' - '.join(v for v in [meta['saga_title'], meta['volume_title']] if v) + ' : ' + meta['book_title']
    return dict(meta=meta, source=source, blurb=blurb, cover=cover, title=title, genre=genre, signature=signature)

def load_data():
    match = re.fullmatch(r'window\.portfolioWritingData = Object\.freeze\((.*)\);\s*', read_text(SITE / DATA), re.DOTALL)
    if not match:
        raise ValueError('Format des données publiques non reconnu.')
    return json.loads(match.group(1))

def verify_generated(data):
    if load_data().get('sourceVersion') != data['signature']:
        raise ValueError('Le site ne correspond pas aux sources actuelles : synchronisation nécessaire.')
    state = json.loads(read_text(STATE)) if STATE.exists() else {}
    for name in ARTIFACTS:
        if not (SITE / name).is_file() or state.get('generatedFiles', {}).get(name) != sha(SITE / name):
            raise ValueError(f'Fichier public non vérifié : {name}')
    return state

def generate(data, work):
    previous = load_data()
    reports = work / 'reports'
    reports.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='portfolio-export-', dir=reports) as folder:
        temporary = Path(folder)
        snapshot = temporary / 'input.txt'
        snapshot.write_bytes(data['source'].read_bytes())
        output = temporary / 'roman.pdf'
        command = [sys.executable, str(WRITING / 'code/bin/build_book_export.py'), '--work', str(work),
                   '--input-file', str(snapshot), '--output-dir', str(temporary / 'html'),
                   '--pdf-file', str(output), '--title', data['meta']['book_title'], '--include-cover']
        result = subprocess.run(command, cwd=WRITING, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=240)
        if result.returncode or not output.exists():
            raise RuntimeError('Export PDF impossible : ' + (result.stderr or result.stdout)[-2500:])
        if not output.read_bytes().startswith(b'%PDF-'):
            raise ValueError('Export PDF invalide.')
        if source_data(work)['signature'] != data['signature']:
            raise ValueError('Le roman a changé pendant son export ; publication reportée au prochain passage.')
        previous.update(title=data['title'], backCover=read_text(data['blurb']).strip(),
                        assetVersion=data['signature'][:24], sourceVersion=data['signature'])
        previous['genres']['lesEsclaves'] = data['genre']
        page, count = re.subn(r'data/les-esclaves-astre-noir\.js(?:\?v=[a-f0-9]+)?',
            'data/les-esclaves-astre-noir.js?v=' + previous['assetVersion'], read_text(SITE / PAGE))
        if count != 1:
            raise ValueError('La page doit référencer exactement une fois les données du roman.')
        for name in ARTIFACTS:
            (SITE / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(output, SITE / PDF)
        shutil.copy2(data['cover'], SITE / COVER)
        (SITE / DATA).write_text('window.portfolioWritingData = Object.freeze(' + json.dumps(previous, ensure_ascii=False, separators=(',', ':')) + ');\n', encoding='utf-8', newline='\n')
        (SITE / PAGE).write_text(page, encoding='utf-8', newline='\n')
    return {name: sha(SITE / name) for name in ARTIFACTS}

def git(*args):
    result = subprocess.run(['git', *args], cwd=SITE, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    if result.returncode:
        raise RuntimeError('Git ' + args[0] + ' : ' + result.stderr.strip())
    return result.stdout.strip()

def check_git_state(state):
    if git('branch', '--show-current') != 'main':
        raise ValueError('Publication automatique suspendue : la branche du portfolio doit être main.')
    if git('diff', '--cached', '--name-only'):
        raise ValueError('Publication automatique suspendue : des fichiers sont déjà indexés par vous.')
    changed = set(filter(None, (git('diff', '--name-only') + '\n' + git('ls-files', '--others', '--exclude-standard')).splitlines()))
    for name in changed:
        if name not in ARTIFACTS or state.get('generatedFiles', {}).get(name) != sha(SITE / name):
            raise ValueError(f'Publication automatique suspendue : modification locale à préserver ({name}).')

def publish():
    # Never git add -A; never commit the private writing repository.
    git('add', '--', *ARTIFACTS)
    if git('diff', '--cached', '--name-only'):
        git('commit', '-m', 'Écrire : actualise le roman publié', '--', *ARTIFACTS)
    git('fetch', 'origin', 'main')
    if git('rev-list', '--count', 'HEAD..origin/main') != '0':
        raise ValueError('Le portfolio distant a changé : synchronisez votre branche avant de republier.')
    if any(name not in ARTIFACTS for name in git('diff', '--name-only', 'origin/main..HEAD').splitlines()):
        raise ValueError('Des commits non liés au roman attendent : publication automatique suspendue.')
    git('push', 'origin', 'HEAD:main')
    return git('rev-parse', 'HEAD')

@contextmanager
def publication_lock():
    with (SITE / '.publication.lock').open('a+b') as stream:
        if stream.tell() == 0:
            stream.write(b'0'); stream.flush()
        stream.seek(0)
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            stream.seek(0)
            if os.name == 'nt':
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream, fcntl.LOCK_UN)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--publish', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--settle-seconds', type=int, default=0)
    args = parser.parse_args()
    if args.check:
        verify_generated(source_data(resolve_work()))
        return
    with publication_lock():
        state = json.loads(read_text(STATE)) if STATE.exists() else {}
        try:
            work = resolve_work()
            data = source_data(work)
            if args.publish and state.get('publishedVersion') == data['signature']:
                return
            if time.time() - max(data['source'].stat().st_mtime, data['blurb'].stat().st_mtime) < args.settle_seconds:
                return
            if args.publish:
                check_git_state(state)
            if load_data().get('sourceVersion') != data['signature']:
                state['generatedFiles'] = generate(data, work)
                state['generatedVersion'] = data['signature']
                atomic_json(STATE, state)
            verify_generated(data)
            if args.publish:
                state.update(publishedVersion=data['signature'], publishedCommit=publish(), publishedAt=time.time())
            state.update(status='published' if args.publish else 'generated', error=None)
            atomic_json(STATE, state)
            print(json.dumps({'status':state['status'], 'title':data['title'], 'version':data['signature'][:12]}, ensure_ascii=False))
        except Exception as error:
            changed = state.get('error') != str(error)
            state.update(status='error', error=str(error))
            atomic_json(STATE, state)
            if changed:
                print('Publication du roman : ' + str(error), file=sys.stderr)
            raise SystemExit(1)

if __name__ == '__main__':
    main()
