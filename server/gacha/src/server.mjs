import { createServer } from 'node:http';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { ApiError, Ledger, PRODUCT_ID, PACK_DRAWS } from './ledger.mjs';
import { StoreVerifier } from './verifier.mjs';

async function body(request) {
  if (!request.headers['content-type']?.startsWith('application/json')) throw new ApiError('json_required',415);
  let size=0, chunks=[];
  for await (const chunk of request) {
    size+=chunk.length;
    if (size>262144) throw new ApiError('too_large',413);
    chunks.push(chunk);
  }
  try { const data=JSON.parse(Buffer.concat(chunks).toString('utf8')); if (!data || typeof data!=='object' || Array.isArray(data)) throw 0; return data; }
  catch { throw new ApiError('invalid_json'); }
}
export function makeServer(ledger, verifier) {
  const activePurchases = new Set(), requests = new Map();
  const cleanup = setInterval(() => requests.clear(),60000).unref();
  const server = createServer(async (request,response) => {
    response.setHeader('Content-Type','application/json; charset=utf-8');
    response.setHeader('Cache-Control','no-store');
    response.setHeader('X-Content-Type-Options','nosniff');
    try {
      const path = new URL(request.url,'http://localhost');
      if (request.method==='GET' && path.pathname==='/health') {
        response.end(JSON.stringify({ok:true,platforms:verifier.ready})); return;
      }
      if(request.method==='POST' && path.pathname==='/notifications/apple'){
        await verifier.appleNotification(await body(request),ledger);
        response.end('{"ok":true}');return;
      }
      if(request.method==='POST' && path.pathname==='/notifications/google'){
        await verifier.googleNotification(await body(request),request.headers.authorization,ledger);
        response.end('{"ok":true}');return;
      }
      const authorization = request.headers.authorization ?? '';
      if (requests.size>10000) throw new ApiError('busy',429);
      const count = (requests.get(authorization)??0)+1;
      if (count>60) throw new ApiError('rate_limited',429);
      requests.set(authorization,count);
      const wallet = ledger.authenticate(authorization);
      let result;
      if (request.method==='GET' && path.pathname==='/wallet') {
        result={...ledger.snapshot(wallet,Number(path.searchParams.get('after')??0)),platforms:verifier.ready,productId:PRODUCT_ID,packDraws:PACK_DRAWS};
      } else if (request.method==='POST' && path.pathname==='/draw') {
        const data = await body(request);
        result=ledger.draw(wallet,data.requestId);
      } else if (request.method==='POST' && path.pathname==='/purchases/verify') {
        const data = await body(request);
        if (activePurchases.has(wallet)) throw new ApiError('verification_pending',409);
        activePurchases.add(wallet);
        try {
          const receipt=await verifier.verify(data,wallet,ledger);
          ledger.grant(wallet,receipt);
          let storeComplete=false;
          try { storeComplete=await verifier.complete(receipt); } catch { /* Retry on next verification. */ }
          result={verified:true,storeComplete,tickets:ledger.snapshot(wallet).tickets};
        } finally { activePurchases.delete(wallet); }
      } else { throw new ApiError('not_found',404); }
      response.end(JSON.stringify(result));
    } catch (error) {
      response.statusCode=error instanceof ApiError ? error.status : 503;
      response.end(JSON.stringify({error:error instanceof ApiError ? error.message : 'service_unavailable'}));
    }
  });
  server.requestTimeout=20000;
  server.headersTimeout=10000;
  server.on('close',()=>clearInterval(cleanup));
  return server;
}
if (process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  const path=process.env.DB_PATH??'/data/gacha.sqlite';
  mkdirSync(dirname(path),{recursive:true,mode:0o700});
  process.umask(0o077);
  const ledger=new Ledger(path), verifier=new StoreVerifier();
  const server=makeServer(ledger,verifier);
  server.listen(Number(process.env.PORT??8081),'0.0.0.0',()=>console.log('Forest Star purchase service listening'));
  for (const signal of ['SIGTERM','SIGINT']) process.on(signal,()=>server.close(()=>{ledger.close();process.exit(0);}));
}
