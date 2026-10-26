"""Check the public login endpoints without credentials or private API reads."""
import urllib.error
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        return None


def main():
    client = urllib.request.build_opener(NoRedirect())
    for origin in ('https://lifeos-native-test.a-zeroual-it.workers.dev', 'https://lifeos.a-zeroual-it.workers.dev'):
        request = urllib.request.Request(origin + '/login', method='GET', headers={'User-Agent': 'LifeOS-Public-Health/1.0'})
        try:
            with client.open(request, timeout=30) as response:
                status = response.status
                # Do not read or export page contents.
        except urllib.error.HTTPError as error:
            status = error.code
            error.close()
        if status not in (200, 302, 303, 401, 403):
            raise RuntimeError('Public endpoint unavailable; HTTP=' + str(status))
    print('LIVE_61_PUBLIC_ENDPOINTS_RESPOND; no credentials or private API reads; authenticated contract remains unverified.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('::error::' + (str(error) if isinstance(error, RuntimeError) else 'Public endpoint check failed (' + type(error).__name__ + ').'))
        raise SystemExit(1)
