import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Ledger, PRODUCT_ID, rewardAt } from '../src/ledger.mjs';
import { validateApple, validateGoogle, StoreVerifier } from '../src/verifier.mjs';
import { makeServer } from '../src/server.mjs';

const walletId='be389284-9197-4a3f-b5c7-117b826ec331';
const auth=`Bearer ${walletId}.${'ab'.repeat(32)}`;
const receipt={key:'ios:10001',platform:'ios',transactionId:'10001'};

test('exact odds cover 1000 tickets, with equal per-pet probability',()=>{
  const counts={};
  for(let n=0;n<1000;n++){
    const reward=rewardAt(n),key=`${reward.kind}:${reward.pet??reward.amount}`;
    counts[key]=(counts[key]??0)+1;
  }
  for(let pet=6;pet<26;pet++)assert.equal(counts[`pet:${pet}`],15);
  assert.deepEqual(Object.fromEntries(Object.entries(counts).filter(([key])=>!key.startsWith('pet'))),
    {'sugar:20':250,'sugar:40':150,'sugar:80':50,'marbles:3':150,'marbles:8':80,'marbles:15':20});
});

test('grants verified transactions once, binds owner, and draws idempotently',()=>{
  const ledger=new Ledger(':memory:',()=>0);
  try{
    assert.equal(ledger.authenticate(auth),walletId);
    assert.throws(()=>ledger.authenticate(`Bearer ${walletId}.${'cd'.repeat(32)}`));
    assert.equal(ledger.grant(walletId,receipt),true);
    assert.equal(ledger.grant(walletId,receipt),false);
    assert.equal(ledger.snapshot(walletId).tickets,10);
    const other=ledger.authenticate(`Bearer ${randomUUID()}.${'cc'.repeat(32)}`);
    assert.throws(()=>ledger.grant(other,receipt),/purchase_owned_elsewhere/);
    const request=randomUUID(),first=ledger.draw(walletId,request);
    assert.equal(first.sequence,1);
    assert.deepEqual(first.reward,{kind:'pet',amount:1,pet:6});
    assert.deepEqual(ledger.draw(walletId,request),first);
    assert.equal(ledger.snapshot(walletId).tickets,9);
    for(let i=0;i<9;i++)ledger.draw(walletId,randomUUID());
    assert.throws(()=>ledger.draw(walletId,randomUUID()),/no_tickets/);
    assert.equal(ledger.snapshot(walletId).rewards.length,10);
    assert.equal(ledger.snapshot(walletId,10).rewards.length,0);
  }finally{ledger.close();}
});

test('refunds are idempotent and consumed tickets become debt',()=>{
  const ledger=new Ledger();
  try{
    ledger.authenticate(auth);ledger.grant(walletId,receipt);
    ledger.draw(walletId,randomUUID());
    ledger.revoke(receipt.key);ledger.revoke(receipt.key);
    assert.equal(ledger.snapshot(walletId).tickets,0);
    assert.equal(ledger.snapshot(walletId).debt,1);
    assert.throws(()=>ledger.grant(walletId,receipt),/purchase_revoked/);
    ledger.grant(walletId,{...receipt,key:'ios:10002',transactionId:'10002'});
    assert.equal(ledger.snapshot(walletId).tickets,9);
  }finally{ledger.close();}
});

test('database survives restart, with no lost or repeated paid draw',()=>{
  const dir=mkdtempSync(join(tmpdir(),'forest-gacha-'));
  const path=join(dir,'ledger.sqlite'),request=randomUUID();
  let ledger=new Ledger(path,()=>980);
  ledger.authenticate(auth);ledger.grant(walletId,receipt);
  const reward=ledger.draw(walletId,request);ledger.close();
  ledger=new Ledger(path);
  try{ledger.authenticate(auth);assert.equal(ledger.snapshot(walletId).tickets,9);assert.deepEqual(ledger.draw(walletId,request),reward);}
  finally{ledger.close();rmSync(dir,{recursive:true});}
});

test('store fields must match paid state, app, product, quantity and wallet',()=>{
  const apple={bundleId:'com.foreststar.foreststar',productId:PRODUCT_ID,type:'Consumable',appAccountToken:walletId,
    transactionId:'10001',quantity:1,environment:'Production'};
  assert.equal(validateApple(apple,walletId).key,'ios:10001');
  for(const change of [{bundleId:'other'},{productId:'other'},{appAccountToken:randomUUID()},
    {quantity:2},{revocationDate:100},{type:'Auto-Renewable Subscription'},{environment:'Sandbox'}])
    assert.throws(()=>validateApple({...apple,...change},walletId));
  assert.doesNotThrow(()=>validateApple({...apple,environment:'Sandbox'},walletId,true));
  const google={purchaseState:0,consumptionState:0,productId:PRODUCT_ID,obfuscatedExternalAccountId:walletId,quantity:1};
  assert.equal(validateGoogle(google,walletId,'someToken').platform,'android');
  for(const change of [{purchaseState:1},{purchaseState:2},{obfuscatedExternalAccountId:randomUUID()},
    {quantity:2},{productId:'other'},{consumptionState:1}])
    assert.throws(()=>validateGoogle({...google,...change},walletId,'someToken'));
  assert.doesNotThrow(()=>validateGoogle({...google,consumptionState:1},walletId,'someToken',true));
  assert.deepEqual(new StoreVerifier({}).ready,[]);
});

test('HTTP rejects unauthenticated/forged purchases and never grants on failure',async()=>{
  const ledger=new Ledger();
  const verifier={ready:[],verify:async()=>{throw new Error('forged');}};
  const server=makeServer(ledger,verifier);
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}`;
  try{
    assert.equal((await fetch(`${url}/wallet`)).status,401);
    let response=await fetch(`${url}/wallet`,{headers:{authorization:auth}});
    assert.equal((await response.json()).tickets,0);
    response=await fetch(`${url}/purchases/verify`,{method:'POST',headers:{authorization:auth,'content-type':'application/json'},body:JSON.stringify({verified:true,tickets:100})});
    assert.equal(response.status,503);
    assert.equal(ledger.snapshot(walletId).tickets,0);
    response=await fetch(`${url}/draw`,{method:'POST',headers:{authorization:auth,'content-type':'application/json'},body:JSON.stringify({requestId:randomUUID()})});
    assert.equal(response.status,409);
  }finally{await new Promise(resolve=>server.close(resolve));ledger.close();}
});
