import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sync_writing as sync

class PublicationTests(unittest.TestCase):
    def test_identity_survives_work_and_saga_rename(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            work=root/'Saga'/'Ancien titre'; work.mkdir(parents=True)
            (work/'.ecritoire-name.json').write_text(json.dumps({'publicationId':sync.PUBLICATION_ID}),encoding='utf-8')
            self.assertEqual(sync.resolve_work(root),work)
            destination=work.with_name('Nouveau titre'); work.rename(destination)
            self.assertEqual(sync.resolve_work(root),destination)
            (root/'Saga').rename(root/'Saga renommée')
            self.assertEqual(sync.resolve_work(root),root/'Saga renommée'/'Nouveau titre')
    def test_missing_or_ambiguous_publication_is_an_error(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            with self.assertRaises(ValueError): sync.resolve_work(root)
            for title in ['Un','Deux']:
                work=root/'Saga'/title; work.mkdir(parents=True)
                (work/'.ecritoire-name.json').write_text(json.dumps({'publicationId':sync.PUBLICATION_ID}),encoding='utf-8')
            with self.assertRaises(ValueError): sync.resolve_work(root)
    def test_unrelated_or_staged_changes_block_automatic_publication(self):
        with patch.object(sync,'git',side_effect=lambda *args: 'main' if args[0]=='branch' else 'index.html' if args[:2]==('diff','--name-only') else ''):
            with self.assertRaisesRegex(ValueError,'préserver'): sync.check_git_state({})
        with patch.object(sync,'git',side_effect=lambda *args: 'main' if args[0]=='branch' else 'user-file.txt'):
            with self.assertRaisesRegex(ValueError,'indexés'): sync.check_git_state({})
    def test_future_publication_never_indexes_private_work(self):
        self.assertEqual(set(sync.ARTIFACTS),{'ecrits.html', 'data/les-esclaves-astre-noir.js', 'img/les-esclaves-astre-noir.png', 'pdf/les-esclaves-t1-astre-noir.pdf'})
        self.assertFalse(any('ouvrages' in path for path in sync.ARTIFACTS))

if __name__=='__main__': unittest.main()
