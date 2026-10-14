"""Provision an isolated D1/Worker copy. Never log data, code or credentials."""
import base64
import datetime
import email.policy
from email.parser import BytesParser
import hashlib
import http.cookiejar
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ACCOUNT = '1728c3b1b852eb6285646842db7256de'
SOURCE_DB = 'a90a8c6d-d6eb-4dc6-8fdb-382e4ad4485a'
SOURCE_WORKER = 'lifeos'
TARGET = 'lifeos-native-test'
MARKER = '_lifeos_native_clone'
API = f'https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}'


class SetupError(Exception):
    pass


def require(ok, message):
    if not ok:
        raise SetupError(message)


def permitted_write(path):
    # Independent allowlist prevents mutations of production, even after a bad refactor.
    return (path == '/d1/database'
            or path == f'/workers/scripts/{TARGET}'
            or path == f'/workers/scripts/{TARGET}/subdomain'
            or re.fullmatch(r'/d1/database/[0-9a-f-]+/query', path)
            and SOURCE_DB not in path)


def api(path, method='GET', value=None, raw=None, content_type=None, allow404=False):
    if method != 'GET':
        # D1 SELECT is POST as well; only query() can send it to the source.
        require(permitted_write(path), 'Operazione remota non consentita.')
    data = json.dumps(value).encode() if value is not None else raw
    headers = {'Authorization': 'Bearer ' + os.environ['CLOUDFLARE_API_TOKEN']}
    if data is not None:
        headers['Content-Type'] = content_type or 'application/json'
    request = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            payload = response.read()
            if 'json' in response.headers.get('Content-Type', ''):
                parsed = json.loads(payload)
                require(parsed.get('success') is True, 'Cloudflare ha rifiutato una richiesta; controllare i permessi del token.')
                return parsed.get('result')
            return payload, response.headers
    except urllib.error.HTTPError as error:
        if allow404 and error.code == 404:
            return None
        # Error bodies can contain secrets or SQL. Only report the HTTP status and path.
        raise SetupError(f'Cloudflare HTTP {error.code}: {path}. Verificare token e permessi.') from None


def query(database, sql, params=None):
    require(database != SOURCE_DB, 'Le query SQL sono consentite solo sulla copia.')
    result = api(f'/d1/database/{database}/query', 'POST', {'sql': sql, 'params': params or []})
    require(isinstance(result, list) and result and all(x.get('success') for x in result), 'Query D1 non riuscita sulla copia.')
    return result[0].get('results', [])


def multipart(parts):
    boundary = 'lifeos-' + secrets.token_hex(16)
    chunks = []
    for name, kind, data in parts:
        require(re.fullmatch(r'[\w.\-/]+', name) is not None, 'Nome modulo Worker non supportato.')
        chunks.extend([f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{name}"\r\nContent-Type: {kind}\r\n\r\n'.encode(), data, b'\r\n'])
    chunks.append(f'--{boundary}--\r\n'.encode())
    return b''.join(chunks), 'multipart/form-data; boundary=' + boundary


def downloaded_modules(payload, headers):
    kind = headers.get('Content-Type', '')
    entry = headers.get('cf-entrypoint') or headers.get('cf-entrypoint-name')
    if kind.startswith('multipart/'):
        message = BytesParser(policy=email.policy.default).parsebytes(('Content-Type: ' + kind + '\r\nMIME-Version: 1.0\r\n\r\n').encode() + payload)
        modules = []
        for part in message.iter_parts():
            name = part.get_filename() or part.get_param('name', header='Content-Disposition')
            if name == 'metadata':
                metadata = json.loads(part.get_payload(decode=True))
                entry = entry or metadata.get('main_module')
                continue
            require(bool(name), 'Modulo Worker senza nome.')
            modules.append((name, part.get_content_type(), part.get_payload(decode=True)))
        if entry is None and len(modules) == 1:
            entry = modules[0][0]
    else:
        entry = entry or 'worker.js'
        modules = [(entry, 'application/javascript+module', payload)]
    require(entry is not None and any(x[0] == entry for x in modules), 'Entrypoint del Worker non identificabile.')
    main = next(x[2] for x in modules if x[0] == entry)
    # Refuse unknown authentication contracts instead of deploying an unprotected clone.
    require(b'export default' in main and all(x in main for x in [b'APP_PASSWORD', b'ACCESS_EMAIL', b'/auth/login', b'validSession', b'getFinanceData']), 'Il Worker pubblicato non usa il contratto atteso; revisione necessaria.')
    return entry, modules


def wrangler(folder, *arguments):
    result = subprocess.run(['npx', '--yes', 'wrangler@4', *arguments], cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=480)
    require(result.returncode == 0, 'Wrangler non ha completato esportazione/importazione. Output SQL mantenuto privato; nessun dato pubblicato.')


def quoted(name):
    return '"' + name.replace('"', '""') + '"'


def copy_database(folder):
    listing = api('/d1/database?per_page=100')
    source = next((x for x in listing if x.get('uuid') == SOURCE_DB), None)
    require(source is not None and source.get('name') == 'liquidita-4-prova', 'Database sorgente non corrispondente a quello approvato.')
    existing = next((x for x in listing if x.get('name') == TARGET), None)
    if existing:
        identifier = existing['uuid']
        require(identifier != SOURCE_DB, 'Database di destinazione uguale al principale.')
        tables = query(identifier, 'SELECT name FROM sqlite_master WHERE type = \'table\' AND name = ?', [MARKER])
        require(bool(tables), 'Esiste già un database con questo nome senza provenienza verificata. Non verrà sovrascritto.')
        provenance = query(identifier, f'SELECT source_id FROM {quoted(MARKER)}')
        require(len(provenance) == 1 and provenance[0].get('source_id') == SOURCE_DB, 'Provenienza della copia non valida.')
        print('Copia esistente riconosciuta: riutilizzo senza reimportare i dati.', flush=True)
        return identifier
    require(len(listing) < 10, 'Limite gratuito di database raggiunto; nessuna risorsa eliminata.')
    config = {'name': TARGET, 'compatibility_date': '2026-10-01', 'account_id': ACCOUNT,
              'd1_databases': [{'binding': 'SOURCE', 'database_name': source['name'], 'database_id': SOURCE_DB}]}
    (folder / 'wrangler.json').write_text(json.dumps(config))
    print('Esporto uno snapshot del database principale (senza eseguire le API dell’app).', flush=True)
    wrangler(folder, 'd1', 'export', 'SOURCE', '--remote', '--output', str(folder / 'copy.sql'))
    sql = (folder / 'copy.sql').read_text()
    require(bool(sql.strip()), 'Export vuoto: copia non creata.')
    with sqlite3.connect(':memory:') as local:
        local.executescript(sql)
        names = [x[0] for x in local.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%'")]
        require(names and MARKER not in names, 'Schema sorgente non compatibile.')
        counts = {name: local.execute(f'SELECT COUNT(*) FROM {quoted(name)}').fetchone()[0] for name in names}
    created = api('/d1/database', 'POST', {'name': TARGET, 'primary_location_hint': 'eeur'})
    identifier = created['uuid']
    require(identifier != SOURCE_DB, 'Destinazione non valida.')
    config['d1_databases'] = [{'binding': 'COPY', 'database_name': TARGET, 'database_id': identifier}]
    (folder / 'wrangler.json').write_text(json.dumps(config))
    print('Importo lo snapshot esclusivamente nel nuovo database.', flush=True)
    wrangler(folder, 'd1', 'execute', 'COPY', '--remote', '--file', str(folder / 'copy.sql'), '--yes')
    for name, expected in counts.items():
        rows = query(identifier, f'SELECT COUNT(*) AS n FROM {quoted(name)}')
        require(rows[0]['n'] == expected, 'Controllo conteggio righe fallito. Copia non pubblicata.')
    query(identifier, f'CREATE TABLE {quoted(MARKER)} (source_id TEXT NOT NULL, copied_at TEXT NOT NULL)')
    query(identifier, f'INSERT INTO {quoted(MARKER)} VALUES (?, ?)', [SOURCE_DB, datetime.datetime.now(datetime.timezone.utc).isoformat()])
    print(f'Copia verificata: {len(names)} tabelle confrontate; nessun contenuto finanziario nei log.', flush=True)
    return identifier


def deploy(database, password):
    source_settings = api(f'/workers/scripts/{SOURCE_WORKER}/settings')
    bindings = source_settings.get('bindings', [])
    db = next((x for x in bindings if x.get('name') == 'DB'), {})
    require(db.get('type') == 'd1' and db.get('id') == SOURCE_DB, 'Il Worker principale non è associato al database atteso.')
    require(all(x.get('name') in ['DB', 'ACCESS_EMAIL', 'APP_PASSWORD'] for x in bindings), 'Il Worker ha altri binding: occorre verificarli prima della copia.')
    download = api(f'/workers/scripts/{SOURCE_WORKER}/content/v2')
    require(isinstance(download, tuple), 'Download del codice non valido.')
    entry, modules = downloaded_modules(*download)
    previous = api(f'/workers/scripts/{TARGET}/settings', allow404=True)
    if previous is not None:
        marker = next((x for x in previous.get('bindings', []) if x.get('name') == 'NATIVE_TEST_SOURCE'), {})
        require(marker.get('text') == SOURCE_DB, 'Worker di destinazione già esistente senza provenienza: nessuna sovrascrittura.')
    require(database != SOURCE_DB and TARGET != SOURCE_WORKER, 'Destinazione non isolata.')
    metadata = {'main_module': entry, 'compatibility_date': source_settings.get('compatibility_date') or '2026-10-01',
                'compatibility_flags': source_settings.get('compatibility_flags', []),
                'bindings': [{'type': 'd1', 'name': 'DB', 'id': database},
                             {'type': 'secret_text', 'name': 'APP_PASSWORD', 'text': password},
                             {'type': 'plain_text', 'name': 'NATIVE_TEST_SOURCE', 'text': SOURCE_DB}],
                'observability': {'enabled': False}}
    body, kind = multipart([('metadata', 'application/json', json.dumps(metadata).encode()), *modules])
    api(f'/workers/scripts/{TARGET}', 'PUT', raw=body, content_type=kind)
    api(f'/workers/scripts/{TARGET}/subdomain', 'POST', {'enabled': True, 'previews_enabled': False})
    # The workers.dev subdomain was supplied by the user, not inferred from an account name.
    return f'https://{TARGET}.a-zeroual-it.workers.dev'


def verify(url, password):
    cookies = http.cookiejar.CookieJar()
    browser = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))
    for attempt in range(12):
        try:
            request = urllib.request.Request(url + '/auth/login', data=json.dumps({'user': 'nas', 'password': password}).encode(), headers={'Origin': url, 'Content-Type': 'application/json'}, method='POST')
            with browser.open(request, timeout=45) as response:
                require(response.status == 200 and 'json' in response.headers.get('Content-Type', ''), 'Accesso copia non riuscito.')
            break
        except urllib.error.URLError:
            if attempt == 11:
                raise SetupError('Worker distribuito; accesso non ancora disponibile (controllare propagazione o protezione Access).') from None
            time.sleep(5)
    require(any(c.name == 'liquidita_session' and c.secure for c in cookies), 'Cookie di accesso sicuro non ricevuto.')
    now = datetime.datetime.now(datetime.timezone.utc)
    month = now.strftime('%Y-%m')
    methods = [('getLifeData', [month], 'tasks'), ('getFinanceData', [now.year, now.month], 'summary'), ('getExtraPlan', [now.year], 'allocations')]
    # Verify the exact three reads used by the installed IPA, on the clone only.
    for method, args, key in methods:
        request = urllib.request.Request(url + '/api/' + method, data=json.dumps(args).encode(), headers={'Origin': url, 'Content-Type': 'application/json'}, method='POST')
        try:
            with browser.open(request, timeout=90) as response:
                require('json' in response.headers.get('Content-Type', ''), 'Risposta API non JSON sulla copia.')
                result = json.loads(response.read())
            require(isinstance(result, dict) and key in result, 'Schema API non compatibile: ' + method)
        except urllib.error.URLError as error:
            raise SetupError(f'Verifica {method} fallita sulla copia (HTTP {getattr(error, "code", "rete")}). Il principale non è stato modificato.') from None
        print(method + ': risposta verificata.', flush=True)
    # An unauthenticated request must never expose financial data.
    request = urllib.request.Request(url + '/api/getFinanceData', data=b'[]', headers={'Origin': url, 'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            raise SetupError('Controllo accesso anonimo fallito: verificare la protezione della copia.')
    except urllib.error.HTTPError as error:
        require(error.code in [401, 403], 'Esito inatteso del controllo accesso anonimo.')


def main():
    require(bool(os.environ.get('CLOUDFLARE_API_TOKEN')), 'Manca il secret CLOUDFLARE_API_TOKEN.')
    password = os.environ.get('LIFEOS_TEST_PASSWORD', '')
    require(24 <= len(password) <= 1000, 'Aggiungere LIFEOS_TEST_PASSWORD: password separata di almeno 24 caratteri.')
    require(os.environ.get('CLOUDFLARE_ACCOUNT_ID') == ACCOUNT, 'Account non corrispondente a quello approvato.')
    with tempfile.TemporaryDirectory(prefix='lifeos-copy-') as directory:
        folder = Path(directory)
        database = copy_database(folder)
        print('Distribuisco il codice corrente in un Worker separato con password dedicata.', flush=True)
        url = deploy(database, password)
        verify(url, password)
        print('COLLEGAMENTO PRONTO: ' + url, flush=True)
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a') as report:
                report.write(f'## Copia di test pronta\n\nServer: {url}\n\nDatabase: `{TARGET}`. Accesso: utente `nas`, password del secret `LIFEOS_TEST_PASSWORD`.\n\nLe tre API usate dall’app e il rifiuto dell’accesso anonimo sono stati verificati. Il database principale non è stato usato per i test.\n')


if __name__ == '__main__':
    try:
        main()
    except SetupError as error:
        print('::error::' + str(error), flush=True)
        raise SystemExit(1)
    except Exception:
        # No traceback: network/CLI exceptions can accidentally include private request data.
        print('::error::Preparazione interrotta. Nessun dump, password o sorgente privato è stato pubblicato.', flush=True)
        raise SystemExit(1)
