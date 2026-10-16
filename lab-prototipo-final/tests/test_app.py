import concurrent.futures
import contextlib
import http.client
import importlib.util
import io
import json
from pathlib import Path
import re
import sqlite3
import tempfile
import threading
import time
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('experiment_app', Path(__file__).parents[1] / 'app' / 'main.py')
app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(app)


class ApplicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.now = 1000.0
        self.store = app.Store(Path(self.temp.name) / 'nested' / 'events.sqlite3', clock=lambda: self.now)
        self.logs = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.logs)
        self.redirect.__enter__()
        self.start_server()

    def start_server(self):
        self.server = app.Server(('127.0.0.1', 0), self.store)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def tearDown(self):
        self.stop_server()
        self.redirect.__exit__(None, None, None)
        self.temp.cleanup()

    def request(self, path, headers=None, method='GET'):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=10)
        connection.request(method, path, headers=headers or {})
        response = connection.getresponse()
        result = response.status, dict(response.getheaders()), response.read().decode()
        connection.close()
        return result

    def issue(self, variant, ua='GPTBot/1.0'):
        status, headers, body = self.request('/experiment/' + variant, {'User-Agent': ua})
        self.assertEqual(status, 200)
        self.assertEqual(headers['Cache-Control'], 'no-store')
        if variant == 'control':
            return body, None, None
        token = re.search(r'/probe/([A-Za-z0-9_-]{32})', body)[1]
        challenge = re.search(r'Challenge: <code>([a-f0-9]+)</code>', body)
        return body, token, challenge[1] if challenge else None

    def settled_events(self, count):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            events = self.store.events(1000)
            if len(events) >= count:
                return events
            time.sleep(0.005)
        self.fail('request events did not persist')

    def test_variants_tokens_and_local_non_executable_html(self):
        control, _, _ = self.issue('control')
        self.assertNotIn('/probe/', control)
        self.assertNotIn('<script', control)
        with self.store.connect() as db:
            token = db.execute('SELECT token FROM challenges WHERE variant="control"').fetchone()[0]
        self.assertNotIn(token, control)
        self.assertEqual(self.request('/probe/' + token)[0], 422)
        link, token, _ = self.issue('link')
        self.assertIn('href="/probe/' + token + '"', link)
        self.assertEqual(self.request('/probe/' + token)[0], 200)
        instruction, token2, _ = self.issue('instruction')
        self.assertNotIn('href=', instruction)
        self.assertEqual(self.request('/probe/' + token2)[0], 200)
        transform, token3, challenge = self.issue('transform')
        expected = '/probe/' + token3 + '/reverse/' + challenge[::-1]
        self.assertNotIn(expected, transform)
        self.assertNotIn('href=', transform)
        self.assertEqual(self.request(expected)[0], 200)
        self.assertEqual(len({token, token2, token3}), 3)

    def test_false_answer_expiration_and_replay(self):
        _, token, challenge = self.issue('transform')
        self.assertEqual(self.request('/probe/' + token)[0], 422)
        self.assertEqual(self.request('/probe/' + token + '/reverse/wrong')[0], 422)
        self.now += 2.5
        path = '/probe/' + token + '/reverse/' + challenge[::-1]
        self.assertEqual(json.loads(self.request(path)[2]), {'outcome': 'success'})
        self.assertEqual(json.loads(self.request(path)[2]), {'outcome': 'repeat'})
        self.now += 900
        self.assertEqual(self.request(path)[0], 410)
        events = self.settled_events(6)
        valid = [e for e in events if e.get('first_valid_return')]
        self.assertEqual(len(valid), 1)
        self.assertEqual(valid[0]['delay_seconds'], 2.5)
        self.assertEqual(self.store.summary()['experiments'][0]['returned'], 1)
        _, expired, _ = self.issue('link')
        self.now += 900
        self.assertEqual(self.request('/probe/' + expired)[0], 410)
        returned = {e['variant']: e['returned'] for e in self.store.summary()['experiments']}
        self.assertEqual(returned['link'], 0)

    def test_persistent_restart_and_ordered_paginated_export(self):
        _, token, _ = self.issue('link')
        self.assertEqual(self.request('/probe/' + token)[0], 200)
        events = self.settled_events(2)
        before = self.store.metrics()
        self.stop_server()
        self.store = app.Store(self.store.path, clock=lambda: self.now)
        self.start_server()
        self.assertEqual(self.store.metrics(), before)
        self.assertEqual(json.loads(self.request('/probe/' + token)[2])['outcome'], 'repeat')
        self.settled_events(3)
        payload = json.loads(self.request('/api/events?after=' + str(events[0]['sequence']) + '&limit=1')[2])
        self.assertEqual(payload['events'][0]['sequence'], events[1]['sequence'])
        status, headers, exported = self.request('/api/export?limit=1000')
        self.assertEqual(status, 200)
        self.assertIn('attachment', headers['Content-Disposition'])
        sequence = [e['sequence'] for e in json.loads(exported)['events']]
        self.assertEqual(sequence, sorted(set(sequence)))

    def test_concurrent_first_return_exactly_once(self):
        _, token, _ = self.issue('instruction')
        self.now += 4
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            responses = list(pool.map(lambda _: self.request('/probe/' + token), range(24)))
        self.assertTrue(all(status == 200 for status, _, _ in responses))
        outcomes = [json.loads(body)['outcome'] for _, _, body in responses]
        self.assertEqual(outcomes.count('success'), 1)
        self.assertEqual(outcomes.count('repeat'), 23)
        events = self.settled_events(25)
        self.assertEqual(sum(e.get('first_valid_return', False) for e in events), 1)
        metrics = self.store.metrics()
        self.assertIn('lab_challenges_returned_total{provider="openai",variant="instruction"} 1', metrics)
        self.assertIn('lab_callback_delay_seconds_count{variant="instruction"} 1', metrics)
        self.assertIn('lab_callback_delay_seconds_sum{variant="instruction"} 4', metrics)

    def test_malicious_ua_credentials_queries_and_forwarded_ip(self):
        ua = '<script>alert("owned")</script>' + 'X' * 800
        status, headers, body = self.request('/experiment/link?secret=DO_NOT_LOG',
            {'User-Agent': ua, 'Authorization': 'Bearer DO_NOT_LOG', 'X-Forwarded-For': '203.0.113.99'})
        self.assertEqual(status, 200)
        self.assertIn('&lt;script&gt;', body)
        self.assertNotIn('<script>', body)
        self.assertIn("default-src 'none'", headers['Content-Security-Policy'])
        event = self.settled_events(1)[0]
        self.assertEqual(event['client_ip'], '127.0.0.1')
        self.assertEqual(len(event['user_agent']), 512)
        self.assertEqual(event['identification_state'], 'unknown')
        self.assertNotIn('DO_NOT_LOG', self.logs.getvalue())
        self.assertNotIn('203.0.113.99', self.logs.getvalue())

    def test_bounded_metrics_observer_exclusion_and_invalid_routes(self):
        for path in ('/', '/healthz', '/readyz', '/metrics', '/api/events', '/api/summary', '/api/export'):
            self.assertEqual(self.request(path)[0], 200)
        self.assertEqual(self.store.summary()['events'], 0)
        for path in ('/experiment/nope', '/experiment/../link', '/experiment/%2e%2e/link', '/probe/nope', '/random-secret'):
            self.assertEqual(self.request(path)[0], 404)
        self.assertEqual(self.request('/experiment/link', method='POST')[0], 405)
        self.assertEqual(self.request('/api/events?limit=1001')[0], 400)
        self.assertEqual(self.request('/api/events?after=-1')[0], 400)
        self.assertEqual(self.request('/api/events?limit=NaN')[0], 400)
        self.assertEqual(self.store.summary()['experiments'], [])
        self.settled_events(6)
        metrics = self.store.metrics()
        samples = '\n'.join(line for line in metrics.splitlines() if not line.startswith('#'))
        for raw in ('random-secret', 'nope', '127.0.0.1', 'User-Agent', 'token="'):
            self.assertNotIn(raw, samples)
        self.assertIn('route="other"', metrics)
        self.assertIn('lab_db_events 6', metrics)

    def test_callback_storage_failure_and_legacy_incomplete_event(self):
        _, token, _ = self.issue('link')
        with mock.patch.object(self.store, 'callback', side_effect=sqlite3.OperationalError('injected failure')):
            self.assertEqual(self.request('/probe/' + token)[0], 503)
        event = self.settled_events(2)[-1]
        self.assertEqual(event['direction'], 'callback')
        self.assertEqual(event['token'], token)
        self.assertEqual(event['variant'], 'unknown')
        self.assertEqual(event['outcome'], 'storage_error')
        self.assertFalse(event['first_valid_return'])
        self.assertFalse(event['repeat'])
        self.assertIsNone(event['delay_seconds'])
        # A row persisted by the previous handler has no callback result fields.
        legacy = {key: value for key, value in event.items()
                  if key not in ('sequence', 'variant', 'outcome', 'first_valid_return', 'repeat', 'delay_seconds')}
        self.store.record(legacy)
        status, _, metrics = self.request('/metrics')
        self.assertEqual(status, 200)
        self.assertIn('lab_callback_attempts_total{outcome="storage_error",provider="unknown",variant="unknown"} 2', metrics)
        self.assertIn('lab_callback_delay_seconds_count{variant="link"} 0', metrics)
        self.assertEqual(json.loads(self.request('/probe/' + token)[2])['outcome'], 'success')
        self.settled_events(4)
        status, _, metrics = self.request('/metrics')
        self.assertEqual(status, 200)
        self.assertIn('lab_callback_delay_seconds_count{variant="link"} 1', metrics)

    def test_catalog_is_declaration_only(self):
        for ua, provider in [('ChatGPT-User/1.0', 'openai'), ('ClaudeBot/1', 'anthropic'), ('PerplexityBot/1', 'perplexity')]:
            identity = app.identify(ua)
            self.assertEqual(identity['provider'], provider)
            self.assertEqual(identity['identification_state'], 'declared')
        self.assertEqual(app.identify('FakeGPTBot')['identification_state'], 'unknown')
        self.assertEqual(app.identify('ordinary browser')['provider'], 'unknown')


class PersistentStateTests(unittest.TestCase):
    def test_delay_histograms_start_at_zero_and_persist_first_sample(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events.sqlite3'
            now = [1000.0]
            store = app.Store(path, clock=lambda: now[0])
            initial = store.metrics()
            for variant in app.VARIANTS:
                self.assertIn(f'lab_callback_delay_seconds_count{{variant="{variant}"}} 0', initial)
                self.assertIn(f'lab_callback_delay_seconds_sum{{variant="{variant}"}} 0.0', initial)
                for bound in (*map(str, app.BUCKETS), '+Inf'):
                    self.assertIn(f'lab_callback_delay_seconds_bucket{{variant="{variant}",le="{bound}"}} 0', initial)
            token, _ = store.issue('link', 'unknown')
            self.assertIn('lab_callback_delay_seconds_count{variant="link"} 0', store.metrics())
            now[0] += 3
            self.assertEqual(store.callback(token, None, False)[0], 200)
            returned = store.metrics()
            self.assertIn('lab_callback_delay_seconds_count{variant="link"} 1', returned)
            self.assertIn('lab_callback_delay_seconds_sum{variant="link"} 3.0', returned)
            self.assertIn('lab_callback_delay_seconds_bucket{variant="link",le="+Inf"} 1', returned)
            restarted = app.Store(path, clock=lambda: now[0])
            self.assertEqual(returned, restarted.metrics())

    def test_delay_survives_committed_return_without_request_event(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events.sqlite3'
            now = [1000.0]
            store = app.Store(path, clock=lambda: now[0])
            token, _ = store.issue('link', 'unknown')
            now[0] += 3
            status, result = store.callback(token, None, False)
            self.assertEqual(status, 200)
            self.assertTrue(result['first_valid_return'])
            # Simulate a crash after committing the return, before HTTP logging.
            restarted = app.Store(path, clock=lambda: now[0])
            metrics = restarted.metrics()
            self.assertIn('lab_callback_delay_seconds_count{variant="link"} 1', metrics)
            self.assertIn('lab_callback_delay_seconds_sum{variant="link"} 3', metrics)
            self.assertIn('# TYPE lab_callback_delay_seconds histogram', metrics)
            self.assertIn('lab_challenges_returned_total{provider="unknown",variant="link"} 1', metrics)
            self.assertEqual(restarted.events(), [])
            self.assertEqual(restarted.callback(token, None, False)[1]['outcome'], 'repeat')
            self.assertIn('lab_callback_delay_seconds_count{variant="link"} 1', restarted.metrics())


if __name__ == '__main__':
    unittest.main()
