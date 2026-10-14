import importlib.util
import io
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('provision', Path(__file__).with_name('provision-lifeos-test.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class IsolationTests(unittest.TestCase):
    def test_public_check_uses_own_client_identity_and_cannot_target_production(self):
        url = f'https://{p.TARGET}.a-zeroual-it.workers.dev'
        request = p.public_request(url, '/auth/login', {'user': 'nas', 'password': 'dummy'})
        self.assertEqual(request.get_header('User-agent'), 'LifeOS-Native-Check/1.0')
        self.assertEqual(request.get_header('Origin'), url)
        self.assertNotIn('dummy', request.full_url)
        with self.assertRaises(p.SetupError):
            p.public_request('https://lifeos.a-zeroual-it.workers.dev', '/api/getFinanceData', [])
    def test_production_mutations_and_sql_cannot_reach_network(self):
        paths = [f'/d1/database/{p.SOURCE_DB}/query', f'/workers/scripts/{p.SOURCE_WORKER}',
                 f'/workers/scripts/{p.SOURCE_WORKER}/subdomain', '/workers/subdomain']
        with patch.object(p.urllib.request, 'urlopen') as network:
            for path in paths:
                with self.assertRaises(p.SetupError):
                    p.api(path, 'PUT', {'sql': 'DELETE FROM source_rows'})
            with self.assertRaises(p.SetupError):
                p.query(p.SOURCE_DB, 'SELECT * FROM source_rows')
            network.assert_not_called()

    def test_missing_password_fails_before_export_or_resource_creation(self):
        with patch.dict(os.environ, {'CLOUDFLARE_API_TOKEN': 'dummy', 'LIFEOS_TEST_PASSWORD': ''}), patch.object(p, 'copy_database') as copy:
            with self.assertRaises(p.SetupError):
                p.main()
            copy.assert_not_called()

    def test_existing_unmarked_database_is_not_overwritten(self):
        calls = []
        def api(path, *args, **kwargs):
            calls.append(path)
            return [{'uuid': p.SOURCE_DB, 'name': 'liquidita-4-prova'}, {'uuid': 'abc-def', 'name': p.TARGET}]
        with patch.object(p, 'api', side_effect=api), patch.object(p, 'query', return_value=[]), patch.object(p, 'wrangler') as cli:
            with self.assertRaises(p.SetupError):
                p.copy_database(Path('/unused'))
            cli.assert_not_called()
            self.assertEqual(calls, ['/d1/database?per_page=100'])

    def test_existing_verified_copy_is_reused_without_reimport(self):
        listing = [{'uuid': p.SOURCE_DB, 'name': 'liquidita-4-prova'}, {'uuid': 'abc-def', 'name': p.TARGET}]
        with patch.object(p, 'api', return_value=listing), patch.object(p, 'query', side_effect=[[{'name': p.MARKER}], [{'source_id': p.SOURCE_DB}]]), patch.object(p, 'wrangler') as cli, patch('sys.stdout', new_callable=io.StringIO):
            self.assertEqual(p.copy_database(Path('/unused')), 'abc-def')
            cli.assert_not_called()

    def test_multipart_roundtrip_preserves_code_and_entrypoint(self):
        code = b'export default {}; // APP_PASSWORD ACCESS_EMAIL /auth/login validSession getFinanceData'
        data, kind = p.multipart([('metadata', 'application/json', b'{"main_module":"index.js"}'), ('index.js', 'application/javascript+module', code)])
        entry, modules = p.downloaded_modules(data, {'Content-Type': kind})
        self.assertEqual(entry, 'index.js')
        self.assertEqual(modules, [('index.js', 'application/javascript+module', code)])

    def test_unknown_authentication_contract_is_rejected(self):
        with self.assertRaises(p.SetupError):
            p.downloaded_modules(b'export default {fetch(){return new Response("private")}}', {'Content-Type': 'application/javascript'})


if __name__ == '__main__':
    unittest.main()
