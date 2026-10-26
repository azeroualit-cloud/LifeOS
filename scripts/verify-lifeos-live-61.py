"""Verify the authenticated app read contract after the approved task deployment.

No task, event, routine, or finance record is created, completed, or deleted.
Reading life data applies the already-reviewed additive schema migration.
Only a success marker is logged; private responses stay in memory.
"""
import datetime
import http.cookiejar
import json
import os
import time
import urllib.request
from zoneinfo import ZoneInfo


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        raise RuntimeError('Unexpected application redirect.')


def verify(origin, password):
    client = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def call(path, value):
        request = urllib.request.Request(origin + path, data=json.dumps(value).encode(), method='POST', headers={'Origin': origin, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-61-Verified-Contract/1.0'})
        with client.open(request, timeout=45) as response:
            if response.status != 200 or 'application/json' not in response.headers.get('Content-Type', ''):
                raise RuntimeError('Application contract unavailable.')
            return json.load(response)
    call('/auth/login', {'user': 'nas', 'password': password})
    month = datetime.datetime.now(ZoneInfo('Europe/Rome')).strftime('%Y-%m')
    data = call('/api/getLifeData', [month])
    if data.get('capabilities') != {'routineSchedules': True, 'taskNotificationTimes': True}:
        raise RuntimeError('Updated capabilities not confirmed.')
    if not all(isinstance(data.get(key), list) for key in ('tasks', 'routines', 'events', 'upcomingEvents')):
        raise RuntimeError('App read contract invalid.')
    for task in data['tasks']:
        if task.get('section_status') not in ('todo', 'waiting') or 'scheduled_time' not in task:
            raise RuntimeError('Additive task migration not confirmed.')
    for routine in data['routines']:
        if not isinstance(routine.get('schedule'), dict):
            raise RuntimeError('Existing routine schedule contract changed.')


def main():
    password = os.environ.get('LIFEOS_TEST_PASSWORD')
    if not password:
        raise RuntimeError('Application credential unavailable.')
    for origin in ('https://lifeos-native-test.a-zeroual-it.workers.dev', 'https://lifeos.a-zeroual-it.workers.dev'):
        for attempt in range(4):
            try:
                verify(origin, password)
                break
            except Exception:
                if attempt == 3:
                    raise RuntimeError('Authenticated application verification failed; private responses omitted.') from None
                time.sleep(2)
    print('LIVE_61_AUTHENTICATED_CONTRACT_OK; both applications and additive task migration verified; no task/event completion or deletion actions.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('::error::' + (str(error) if isinstance(error, RuntimeError) else 'Application verification stopped (' + type(error).__name__ + '); private details omitted.'))
        raise SystemExit(1)
