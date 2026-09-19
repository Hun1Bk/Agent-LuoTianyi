"""Offline authenticated settings API fixture; never contacts public/paid services."""
import argparse, json, os, subprocess, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
def run(godot,script):
    reads, writes, errors = {}, {}, []
    from run_security_interop import server_crypto
    crypto=server_crypto(); crypto.generate_keys()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def reply(self,status,data):
            body=json.dumps(data).encode(); self.send_response(status); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(body))); self.end_headers()
            try: self.wfile.write(body)
            except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError): pass
        def do_GET(self):
            self.reply(200,{'public_key':crypto.get_public_key_pem()}) if self.path=='/auth/public_key' else self.reply(404,{})
        def do_POST(self):
            data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            if self.path=='/auth/login':
                self.reply(200,{'user_id':'ui-uuid','login_token':'login-test','message_token':'message-test'}); return
            user=data.get('username')
            if data.get('token')!='message-test': errors.append('wrong preference token'); self.reply(401,{}); return
            if self.path=='/preference/get':
                reads[user]=reads.get(user,0)+1
                if user=='fail_load': self.reply(503,{}); return
                prefs={'relationship':'知己','speaking_style':'' if reads[user]==1 else '文静恬淡','personality_traits':['真诚','安静'],'#sym:personality_text':'old ignored','custom_context':'original','unknown':'old' if reads[user]==1 else 'new'}
                if user=='legacy': prefs.pop('personality_traits'); prefs['#sym:personality_text']='开朗，认真'
                self.reply(200,{'preferences':prefs}); return
            if self.path=='/preference/overwrite':
                if user=='fail_load': errors.append('overwrote despite failed load')
                if user=='fail_save': self.reply(503,{}); return
                prefs=data['preferences']; writes[user]=prefs
                if user=='merge':
                    if prefs.get('unknown')!='new' or prefs.get('speaking_style')!='文静恬淡' or prefs.get('relationship')!='' or prefs.get('personality_traits')!=['温柔','认真','活泼','诚实']:
                        errors.append('preference merge or trait mismatch')
                    if prefs.get('#sym:personality_text')!='温柔，认真，活泼，诚实': errors.append('legacy personality not synchronized')
                self.reply(200,{'status':'success'}); return
            self.reply(404,{})
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler); thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
    try:
        result=subprocess.run([godot,'--headless','--path',str(PROJECT),'--script',script],env={**os.environ,'GODOT_TEST_SERVER':f'http://127.0.0.1:{server.server_port}'},capture_output=True,text=True,encoding='utf8',errors='replace',timeout=40)
        print(result.stdout); print(result.stderr)
        if result.returncode or 'ERROR:' in result.stdout+result.stderr or errors: raise RuntimeError(str(errors) or 'feature test failed')
        if script.endswith('test_preferences.gd'): assert 'merge' in writes
    finally: server.shutdown(); server.server_close(); thread.join(2)
    print('Offline feature API: PASS')
if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--godot',required=True); parser.add_argument('--script',default='res://tests/test_preferences.gd'); args=parser.parse_args(); run(args.godot,args.script)
