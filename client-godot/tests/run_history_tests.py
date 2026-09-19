"""Offline real HTTP/WS history contract; no public server or account data."""
import argparse, asyncio, json, os
from pathlib import Path
from aiohttp import web
PROJECT = Path(__file__).resolve().parents[1]
async def run(godot, script):
    errors, requests, opened = [], {}, set()
    async def history(request):
        try:
            assert request.headers.get('Authorization') == 'Bearer message-test'
            assert set(request.query) == {'username','count','end_index'}
            assert request.query['count'] == '50'
            user, end = request.query['username'], int(request.query['end_index'])
            seen = requests.setdefault(user, [])
            seen.append(end)
            await asyncio.sleep(.25 if end == -1 else .05)
            if user in ('first_fail','skip') and end == -1 and seen.count(-1) == 1:
                return web.json_response({'detail':'synthetic failure'},status=503)
            if user == 'late_fail' and end == 70 and seen.count(70) == 1:
                return web.json_response({},status=503)
            stop = 120 if end == -1 else end
            start = max(0,stop-50)
            rows = [{'uuid':f'history-{i}','content':f'{user} record {i}','source':'agent' if i%2 else 'user','timestamp':float(i),'type':'text'} for i in range(start,stop)]
            if user == 'invalid': start = -2
            if user == 'duplicate' and end == 70: rows[-1]['uuid'] = 'history-119'
            if end == -1: opened.add(user)
            return web.json_response({'history':rows,'start_index':start})
        except AssertionError:
            errors.append('history protocol mismatch')
            return web.json_response({},status=400)
    async def websocket(request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        user = None
        async for msg in ws:
            value = json.loads(msg.data)
            kind, payload = value['type'], value['payload']
            if kind == 'user_auth':
                user=payload['username']
                if payload['token'] != 'message-test': errors.append('wrong WS token')
                await ws.send_json({'type':'auth_ok','payload':{}})
            elif kind == 'hb_ping':
                await ws.send_json({'type':'hb_pong','payload':{'ping_id':payload['ping_id']}})
            elif kind == 'user_text':
                if user not in opened and user != 'skip': errors.append('business sent before first history boundary')
                await ws.send_json({'type':'server_ack','reply_to':value['client_msg_id'],'payload':{'ok':True}})
                await ws.send_json({'type':'agent_message','payload':{'uuid':'history-119','text':'live reply','is_final_package':True}})
        return ws
    app=web.Application()
    app.router.add_get('/history',history)
    app.router.add_get('/chat_ws',websocket)
    runner=web.AppRunner(app,access_log=None)
    await runner.setup()
    site=web.TCPSite(runner,'127.0.0.1',0)
    await site.start()
    port=site._server.sockets[0].getsockname()[1]
    try:
        proc=await asyncio.create_subprocess_exec(godot,'--headless','--path',str(PROJECT),'--script',script,env={**os.environ,'GODOT_TEST_SERVER':f'http://127.0.0.1:{port}'},stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
        try: out,err=await asyncio.wait_for(proc.communicate(),40)
        except asyncio.TimeoutError:
            proc.kill(); await proc.wait(); raise
        text=(out+err).decode('utf8',errors='replace')
        print(text)
        if proc.returncode or 'ERROR:' in text or errors: raise RuntimeError(str(errors) or 'Godot history test failed')
        if requests.get('normal') != [-1,70,20]: raise AssertionError(f'fixed boundary: {requests}')
        if requests.get('skip') != [-1]: raise AssertionError('skip reimported history')
        print('HTTP + WebSocket history: PASS')
    finally: await runner.cleanup()
if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--godot',required=True); parser.add_argument('--script',default='res://tests/test_history_sync.gd')
    args=parser.parse_args(); asyncio.run(run(args.godot,args.script))
