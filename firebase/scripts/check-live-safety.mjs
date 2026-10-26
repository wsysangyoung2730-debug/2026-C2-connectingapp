// Opt-in disposable fixtures. Never uses or deletes the App Review accounts.
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, deleteUser } from 'firebase/auth';
import { getFirestore, doc, collection, query, where, getDocsFromServer, getDocFromServer, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, terminate } from 'firebase/firestore';
import { readFile, writeFile, chmod } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode, plistPath, credentialPath] = process.argv.slice(2);
if(process.env.NALDAM_LIVE_PROJECT !== 'naldam-dev' || !['prepare','verify-cleanup'].includes(mode) || !path.isAbsolute(credentialPath || '') || path.resolve(credentialPath).startsWith(path.resolve(import.meta.dirname,'../..')+path.sep)) throw new Error('Explicit project, mode, plist and private external fixture path required.');
const plist=JSON.parse(execFileSync('/usr/bin/plutil',['-convert','json','-o','-',plistPath],{encoding:'utf8'}));
assert.equal(plist.PROJECT_ID,'naldam-dev');
const config={apiKey:plist.API_KEY,appId:plist.GOOGLE_APP_ID,projectId:plist.PROJECT_ID};
const apps=[0,1].map(i=>initializeApp(config,`safety-${i}-${randomUUID()}`));const auth=apps.map(getAuth), db=apps.map(app=>getFirestore(app));
let fixture; let stage = "start";
try {
 if(mode==='prepare') {
  fixture={projectID:'naldam-dev',disposable:true,accounts:['가','나'].map(n=>({name:`안전검증${n}`,email:`naldam-safety-${randomUUID()}@example.invalid`,password:randomBytes(20).toString('base64url')+'!8aA'}))};
  try { await writeFile(credentialPath,JSON.stringify(fixture),{mode:0o600,flag:'wx'}); } catch(e) { if(e.code !== 'EEXIST') throw e; fixture=JSON.parse(await readFile(credentialPath,'utf8')); assert.equal(fixture.disposable,true); }
  for(let i=0;i<2;i++) {
   stage=`profile-${i}`; const a=fixture.accounts[i]; assert.ok(a.email.startsWith('naldam-safety-')); a.uid=(a.uid ? await signInWithEmailAndPassword(auth[i],a.email,a.password) : await createUserWithEmailAndPassword(auth[i],a.email,a.password)).user.uid;
   await writeFile(credentialPath,JSON.stringify(fixture),{mode:0o600});
   const previous=await getDocFromServer(doc(db[i],'profiles',a.uid)); await setDoc(doc(db[i],'profiles',a.uid),{name:a.name,interests:['산책'],termsVersion:1,createdAt:previous.exists()?previous.data().createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  }
  const [a,b]=fixture.accounts;fixture.roomID=[a.uid,b.uid].sort().join('__');
  stage='room-create'; await setDoc(doc(db[0],'rooms',fixture.roomID),{members:[a.uid,b.uid].sort(),senderID:a.uid,recipientID:b.uid,status:'pending',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  stage='room-accept'; await updateDoc(doc(db[1],'rooms',fixture.roomID),{status:'active',updatedAt:serverTimestamp()});
  stage='messages'; for(let i=0;i<2;i++) await setDoc(doc(db[i],'rooms',fixture.roomID,'messages',`fixture-${i}`),{senderID:fixture.accounts[i].uid,body:i?'반가워요. 안전 기능 검증용 대화예요.':'안녕하세요. 삭제할 테스트 대화예요.',createdAt:serverTimestamp()});
  await assert.rejects(setDoc(doc(db[0],'rooms',fixture.roomID,'messages','filtered'),{senderID:a.uid,body:'씨.발',createdAt:serverTimestamp()}),e=>e.code==='permission-denied');
  await assert.rejects(getDocFromServer(doc(db[1],'contentReports',a.uid,'items',b.uid+'__profile')),e=>e.code==='permission-denied');
  await writeFile(credentialPath,JSON.stringify(fixture),{mode:0o600});
  console.log('PASS disposable accounts, real conversation, server filtering and private report boundary');
 } else {
  fixture=JSON.parse(await readFile(credentialPath,'utf8'));assert.equal(fixture.disposable,true);assert.equal(fixture.projectID,'naldam-dev');
  const [a,b]=fixture.accounts;
  assert.ok(a.email.startsWith('naldam-safety-')&&b.email.startsWith('naldam-safety-'));
  await assert.rejects(signInWithEmailAndPassword(auth[0],a.email,a.password),e=>['auth/invalid-credential','auth/user-not-found'].includes(e.code));
  await signInWithEmailAndPassword(auth[1],b.email,b.password);
  assert.equal((await getDocFromServer(doc(db[1],'profiles',a.uid))).exists(),false);
  assert.equal((await getDocFromServer(doc(db[1],'rooms',fixture.roomID))).exists(),false);
  console.log('PASS native app deleted the first Auth account, public profile and shared room');
  const uid=b.uid;
  await setDoc(doc(db[1],'accountDeletions',uid),{createdAt:serverTimestamp()});
  for(const room of (await getDocsFromServer(query(collection(db[1],'rooms'),where('members','array-contains',uid)))).docs) {
   for(const message of (await getDocsFromServer(collection(room.ref,'messages'))).docs) await deleteDoc(message.ref);
   const batch=writeBatch(db[1]);for(const member of room.data().members) batch.delete(doc(room.ref,'states',member));batch.delete(room.ref);await batch.commit();
  }
  for(const parts of [['users',uid,'blocks'],['contentReports',uid,'items']]) for(const item of (await getDocsFromServer(collection(db[1],...parts))).docs) await deleteDoc(item.ref);
  await deleteDoc(doc(db[1],'profiles',uid));await deleteUser(auth[1].currentUser);
  await writeFile(credentialPath+'.results.json',JSON.stringify({projectID:'naldam-dev',checkedAt:new Date().toISOString(),nativeDeletionVerified:true,disposableAccountsDeleted:true}),{mode:0o600});
  console.log('PASS second disposable account cleaned up; review accounts preserved');
 }
 await chmod(credentialPath,0o600);
} catch(e) {console.error(`FAIL ${stage} ${e.code || e.name}`);process.exitCode=1;}
finally {await Promise.all(db.map(terminate));await Promise.all(apps.map(deleteApp));}
