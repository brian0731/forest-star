import { DatabaseSync } from 'node:sqlite';
import { createHash, randomInt } from 'node:crypto';

export const PRODUCT_ID = 'forest_star_draws_10';
export const PACK_DRAWS = 10;
export class ApiError extends Error {
  constructor(code, status = 400) { super(code); this.status = status; }
}
export function rewardAt(ticket) {
  if (!Number.isInteger(ticket) || ticket < 0 || ticket >= 1000) throw new ApiError('invalid_ticket');
  if (ticket < 300) return {kind:'pet', amount:1, pet:6 + Math.floor(ticket / 15)};
  if (ticket < 550) return {kind:'sugar', amount:20};
  if (ticket < 700) return {kind:'sugar', amount:40};
  if (ticket < 750) return {kind:'sugar', amount:80};
  if (ticket < 900) return {kind:'marbles', amount:3};
  if (ticket < 980) return {kind:'marbles', amount:8};
  return {kind:'marbles', amount:15};
}
export const isUuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
export class Ledger {
  constructor(path = ':memory:', roll = () => randomInt(1000)) {
    this.db = new DatabaseSync(path);
    this.roll = roll;
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS wallets(id TEXT PRIMARY KEY, secret_hash TEXT NOT NULL, tickets INTEGER NOT NULL DEFAULT 0, next_sequence INTEGER NOT NULL DEFAULT 1);
      CREATE TABLE IF NOT EXISTS purchases(receipt_key TEXT PRIMARY KEY, wallet TEXT NOT NULL REFERENCES wallets(id), platform TEXT NOT NULL, transaction_id TEXT NOT NULL, verification_data TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS draws(wallet TEXT NOT NULL REFERENCES wallets(id), request_id TEXT NOT NULL, sequence INTEGER NOT NULL, reward TEXT NOT NULL, created INTEGER NOT NULL, PRIMARY KEY(wallet,request_id), UNIQUE(wallet,sequence));`);
  }
  authenticate(authorization) {
    const match = /^Bearer ([0-9a-f-]{36})\.([0-9a-f]{64})$/.exec(authorization ?? '');
    if (!match || !isUuid(match[1])) throw new ApiError('unauthorized', 401);
    const [,id,secret] = match;
    const digest = createHash('sha256').update(secret).digest('hex');
    const wallet = this.db.prepare('SELECT * FROM wallets WHERE id=?').get(id);
    if (wallet && wallet.secret_hash !== digest) throw new ApiError('unauthorized', 401);
    if (!wallet) this.db.prepare('INSERT INTO wallets(id,secret_hash) VALUES(?,?)').run(id,digest);
    return id;
  }
  transaction(fn) {
    this.db.exec('BEGIN IMMEDIATE');
    try { const result = fn(); this.db.exec('COMMIT'); return result; }
    catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  snapshot(wallet, after = 0) {
    if (!Number.isSafeInteger(after) || after < 0) throw new ApiError('invalid_sequence');
    const balance = this.db.prepare('SELECT tickets,next_sequence FROM wallets WHERE id=?').get(wallet);
    if (after >= balance.next_sequence) throw new ApiError('invalid_sequence');
    const entries = this.db.prepare('SELECT sequence,reward FROM draws WHERE wallet=? AND sequence>? ORDER BY sequence LIMIT 100').all(wallet,after);
    return {tickets:Math.max(0,balance.tickets), debt:Math.max(0,-balance.tickets),
      latestSequence:balance.next_sequence-1,
      rewards:entries.map(entry => ({sequence:entry.sequence,reward:JSON.parse(entry.reward)}))};
  }
  purchase(receiptKey) { return this.db.prepare('SELECT * FROM purchases WHERE receipt_key=?').get(receiptKey); }
  grant(wallet, receipt) {
    return this.transaction(() => {
      const previous = this.purchase(receipt.key);
      if (previous) {
        if (previous.wallet !== wallet) throw new ApiError('purchase_owned_elsewhere',409);
        if (previous.revoked) throw new ApiError('purchase_revoked',409);
        return false;
      }
      this.db.prepare('INSERT INTO purchases VALUES(?,?,?,?,?,0,?)').run(receipt.key,wallet,receipt.platform,receipt.transactionId,receipt.verificationData ?? '',Date.now());
      this.db.prepare('UPDATE wallets SET tickets=tickets+? WHERE id=?').run(PACK_DRAWS,wallet);
      return true;
    });
  }
  revoke(receiptKey) {
    return this.transaction(() => {
      const previous = this.purchase(receiptKey);
      if (!previous || previous.revoked) return;
      this.db.prepare('UPDATE purchases SET revoked=1 WHERE receipt_key=?').run(receiptKey);
      this.db.prepare('UPDATE wallets SET tickets=tickets-? WHERE id=?').run(PACK_DRAWS,previous.wallet);
    });
  }
  draw(wallet, requestId) {
    if (!isUuid(requestId)) throw new ApiError('invalid_request_id');
    return this.transaction(() => {
      const previous = this.db.prepare('SELECT sequence,reward FROM draws WHERE wallet=? AND request_id=?').get(wallet,requestId);
      if (previous) return {sequence:previous.sequence,reward:JSON.parse(previous.reward)};
      const account = this.db.prepare('SELECT tickets,next_sequence FROM wallets WHERE id=?').get(wallet);
      if (account.tickets <= 0) throw new ApiError('no_tickets',409);
      const reward = rewardAt(this.roll()), sequence = account.next_sequence;
      this.db.prepare('INSERT INTO draws VALUES(?,?,?,?,?)').run(wallet,requestId,sequence,JSON.stringify(reward),Date.now());
      this.db.prepare('UPDATE wallets SET tickets=tickets-1,next_sequence=next_sequence+1 WHERE id=?').run(wallet);
      return {sequence,reward};
    });
  }
  close() { this.db.close(); }
}
