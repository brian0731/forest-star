import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { AppStoreServerAPIClient, SignedDataVerifier, Environment } from '@apple/app-store-server-library';
import { GoogleAuth, OAuth2Client } from 'google-auth-library';
import { ApiError, PRODUCT_ID } from './ledger.mjs';

export function validateApple(transaction, wallet, allowSandbox = false) {
  if (transaction.bundleId !== 'com.foreststar.foreststar' || transaction.productId !== PRODUCT_ID ||
      transaction.type !== 'Consumable' || transaction.appAccountToken?.toLowerCase() !== wallet ||
      !transaction.transactionId || transaction.revocationDate || transaction.quantity !== 1 ||
      (!allowSandbox && transaction.environment !== Environment.PRODUCTION)) {
    throw new ApiError('verification_failed',422);
  }
  return {key:`ios:${transaction.transactionId}`, platform:'ios', transactionId:transaction.transactionId};
}
export function validateGoogle(purchase, wallet, token, alreadyGranted = false) {
  if (purchase.purchaseState !== 0 || (purchase.productId && purchase.productId !== PRODUCT_ID) ||
      purchase.obfuscatedExternalAccountId !== wallet || (purchase.quantity ?? 1) !== 1 ||
      (purchase.consumptionState === 1 && !alreadyGranted)) {
    throw new ApiError('verification_failed',422);
  }
  return {key:`android:${createHash('sha256').update(token).digest('hex')}`, platform:'android', transactionId:purchase.orderId ?? '', verificationData:token};
}
export class StoreVerifier {
  constructor(env = process.env) {
    this.env = env;
    this.ready = [];
    this.apple = [];
    if (env.APPLE_KEY_FILE && env.APPLE_KEY_ID && env.APPLE_ISSUER_ID && env.APPLE_ROOT_CERTS && env.APPLE_APP_ID) {
      const roots = readdirSync(env.APPLE_ROOT_CERTS).filter(file => file.endsWith('.cer')).map(file => readFileSync(`${env.APPLE_ROOT_CERTS}/${file}`));
      if (!roots.length) throw new Error('Apple root certificates missing');
      const environments = [Environment.PRODUCTION];
      if (env.ALLOW_APPLE_SANDBOX === 'true') environments.push(Environment.SANDBOX);
      for (const environment of environments) this.apple.push({
        client:new AppStoreServerAPIClient(readFileSync(env.APPLE_KEY_FILE,'utf8'),env.APPLE_KEY_ID,env.APPLE_ISSUER_ID,'com.foreststar.foreststar',environment),
        verifier:new SignedDataVerifier(roots,true,environment,'com.foreststar.foreststar',Number(env.APPLE_APP_ID)),
      });
      this.ready.push('ios');
    }
    if (env.GOOGLE_APPLICATION_CREDENTIALS) {
      this.google = new GoogleAuth({keyFile:env.GOOGLE_APPLICATION_CREDENTIALS,scopes:['https://www.googleapis.com/auth/androidpublisher']});
      this.pushVerifier = new OAuth2Client();
      if (env.GOOGLE_PUSH_AUDIENCE && env.GOOGLE_PUSH_EMAIL) this.ready.push('android');
    }
  }
  async googleRequest(product, token, suffix = '', method = 'GET') {
    const client = await this.google.getClient();
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.foreststar.forest_star/purchases/products/${encodeURIComponent(product)}/tokens/${encodeURIComponent(token)}${suffix}`;
    return (await client.request({url,method,timeout:15000})).data;
  }
  async verify(data, wallet, ledger) {
    if (data.productId !== PRODUCT_ID || !this.ready.includes(data.platform)) throw new ApiError('store_unavailable',503);
    if (data.platform === 'ios') {
      if (typeof data.purchaseId !== 'string' || !/^\d{1,30}$/.test(data.purchaseId)) throw new ApiError('invalid_purchase');
      for (let index=0; index<this.apple.length; index++) {
        const apple = this.apple[index];
        let response;
        try { response = await apple.client.getTransactionInfo(data.purchaseId); }
        catch (error) {
          if (index+1<this.apple.length && [4040010,4040006,4040005].includes(error.apiError)) continue;
          throw new ApiError('verification_unavailable',503);
        }
        const transaction = await apple.verifier.verifyAndDecodeTransaction(response.signedTransactionInfo);
        return validateApple(transaction,wallet,this.env.ALLOW_APPLE_SANDBOX==='true');
      }
      throw new ApiError('verification_failed',422);
    }
    const token = data.verificationData;
    if (typeof token !== 'string' || token.length<10 || token.length>8192) throw new ApiError('invalid_purchase');
    const purchase = await this.googleRequest(PRODUCT_ID,token);
    const key = `android:${createHash('sha256').update(token).digest('hex')}`;
    return validateGoogle(purchase,wallet,token,Boolean(ledger.purchase(key)));
  }
  async complete(receipt) {
    if (receipt.platform !== 'android') return true;
    const purchase = await this.googleRequest(PRODUCT_ID,receipt.verificationData);
    if (purchase.consumptionState !== 1) await this.googleRequest(PRODUCT_ID,receipt.verificationData,':consume','POST');
    return true;
  }
  async appleNotification(data, ledger) {
    if (typeof data.signedPayload !== 'string') throw new ApiError('invalid_notification');
    for (const apple of this.apple) {
      let event;
      try { event=await apple.verifier.verifyAndDecodeNotification(data.signedPayload); }
      catch { continue; }
      if (['REFUND','REVOKE'].includes(event.notificationType) && event.data?.signedTransactionInfo) {
        const transaction=await apple.verifier.verifyAndDecodeTransaction(event.data.signedTransactionInfo);
        if(transaction.productId===PRODUCT_ID && transaction.bundleId==='com.foreststar.foreststar') ledger.revoke(`ios:${transaction.transactionId}`);
      }
      return;
    }
    throw new ApiError('invalid_notification',401);
  }
  async googleNotification(data, authorization, ledger) {
    if (!this.env.GOOGLE_PUSH_AUDIENCE || !this.env.GOOGLE_PUSH_EMAIL || !this.pushVerifier) throw new ApiError('not_configured',503);
    const idToken=/^Bearer (.+)$/.exec(authorization??'')?.[1];
    if(!idToken)throw new ApiError('unauthorized',401);
    const identity=(await this.pushVerifier.verifyIdToken({idToken,audience:this.env.GOOGLE_PUSH_AUDIENCE})).getPayload();
    if(identity?.email!==this.env.GOOGLE_PUSH_EMAIL || !identity.email_verified)throw new ApiError('unauthorized',401);
    const event=JSON.parse(Buffer.from(data.message?.data??'','base64').toString('utf8'));
    if(event.packageName!=='com.foreststar.forest_star')throw new ApiError('invalid_notification');
    const detail=event.voidedPurchaseNotification??event.oneTimeProductNotification;
    const token=detail?.purchaseToken;
    if(typeof token!=='string')return; // Test notification.
    const key=`android:${createHash('sha256').update(token).digest('hex')}`;
    if(!ledger.purchase(key))return;
    if(event.voidedPurchaseNotification){ledger.revoke(key);return;}
    const purchase=await this.googleRequest(PRODUCT_ID,token);
    if(purchase.purchaseState===1)ledger.revoke(key);
  }
}
