"""PLAN-KINDS-97: one-off conversion of the active «Spesa ricorrente fissa» plans into Fondi without end, same quota
per month, months up to the current one unchanged (server method convertFixedPlansToFunds). Logs only the count."""
import os, json, time, urllib.request, urllib.error, http.cookiejar

ORIGIN = 'https://lifeos-native-test.a-zeroual-it.workers.dev'
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))


def post(path, payload):
    r = urllib.request.Request(ORIGIN + path, data=json.dumps(payload).encode(), method='POST',
        headers={'Origin': ORIGIN, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-Plan-Kinds/1.0'})
    with client.open(r, timeout=120) as resp: return json.loads(resp.read())


def main():
    post('/auth/login', {'user': 'nas', 'password': os.environ['LIFEOS_TEST_PASSWORD']})
    for attempt in range(4):
        try:
            result = post('/api/convertFixedPlansToFunds', [])
            break
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == 3: raise
            time.sleep(4 + attempt * 4)
    print('PLAN_KINDS_CONVERTED fixed_to_fund=%s' % (result.get('converted') if isinstance(result, dict) else '?'))


if __name__ == '__main__':
    main()
