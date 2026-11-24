"""Local stand-in for the ChatGPT Responses backend, used by the ChatGPT gate tests.

Args: port cert key log. Environment: GATE_REAL, GATE_ACCOUNT, GATE_MARKER.
Logs only the class of each credential (real, stub, none, other), never a value.
A request with the real token and account header gets a short streamed reply
that contains GATE_MARKER; anything else gets 401.
"""
import http.server
import json
import os
import ssl
import sys

port, cert, key, log = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
real, account, marker = os.environ['GATE_REAL'], os.environ['GATE_ACCOUNT'], os.environ['GATE_MARKER']
STUB_TEXT = 'nono-injects-chatgpt-credentials'


def events(model):
    base = {'id': 'resp_gate', 'object': 'response', 'created_at': 1, 'model': model}
    item = {'id': 'msg_gate', 'type': 'message', 'role': 'assistant'}
    part = {'type': 'output_text', 'text': marker, 'annotations': []}
    ref = {'item_id': 'msg_gate', 'output_index': 0, 'content_index': 0}
    done_item = {**item, 'status': 'completed', 'content': [part]}
    usage = {'input_tokens': 1, 'input_tokens_details': {'cached_tokens': 0}, 'output_tokens': 1,
             'output_tokens_details': {'reasoning_tokens': 0}, 'total_tokens': 2}
    return [
        {'type': 'response.created', 'response': {**base, 'status': 'in_progress', 'output': []}},
        {'type': 'response.output_item.added', 'output_index': 0, 'item': {**item, 'status': 'in_progress', 'content': []}},
        {'type': 'response.content_part.added', **ref, 'part': {**part, 'text': ''}},
        {'type': 'response.output_text.delta', **ref, 'delta': marker, 'logprobs': []},
        {'type': 'response.output_text.done', **ref, 'text': marker, 'logprobs': []},
        {'type': 'response.content_part.done', **ref, 'part': part},
        {'type': 'response.output_item.done', 'output_index': 0, 'item': done_item},
        {'type': 'response.completed', 'response': {**base, 'status': 'completed', 'output': [done_item], 'usage': usage}},
    ]


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):
        pass

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get('content-length') or 0))
        try:
            body = json.loads(raw or b'{}')
        except ValueError:
            body = {}
        auth = self.headers.get('authorization') or ''
        kind = 'real' if auth == 'Bearer ' + real else 'stub' if STUB_TEXT in auth else 'none' if not auth else 'other'
        has_account = self.headers.get('chatgpt-account-id') == account
        with open(log, 'a', encoding='utf-8') as fh:
            fh.write(json.dumps({'path': self.path, 'auth': kind, 'account': has_account,
                                 'auth_headers': len(self.headers.get_all('authorization') or [])}) + '\n')
        self.close_connection = True
        if not (kind == 'real' and has_account and self.path == '/backend-api/codex/responses'):
            out = b'{"error":{"message":"gate upstream rejected credential"}}'
            self.send_response(401)
            self.send_header('content-type', 'application/json')
            self.send_header('content-length', str(len(out)))
            self.send_header('connection', 'close')
            self.end_headers()
            self.wfile.write(out)
            return
        self.send_response(200)
        self.send_header('content-type', 'text/event-stream')
        self.send_header('cache-control', 'no-cache')
        self.send_header('connection', 'close')
        self.end_headers()
        for n, event in enumerate(events(body.get('model') or 'gate')):
            event['sequence_number'] = n
            self.wfile.write(f"event: {event['type']}\ndata: {json.dumps(event)}\n\n".encode())
            self.wfile.flush()


server = http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(cert, key)
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
