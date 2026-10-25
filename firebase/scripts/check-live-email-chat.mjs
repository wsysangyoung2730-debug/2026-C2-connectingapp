// Explicit opt-in only: creates two review fixtures on the named live project.
// Never invoked by npm test. Credentials are saved outside the repository with mode 0600.
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { getFirestore, doc, setDoc, updateDoc, getDocFromServer, serverTimestamp, onSnapshot, terminate } from 'firebase/firestore';
import { execFileSync } from 'node:child_process';
import { randomBytes, randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile, chmod } from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';

const [plistPath, credentialPath] = process.argv.slice(2);
if (process.env.NALDAM_LIVE_PROJECT !== 'naldam-dev' || !plistPath || !credentialPath || !path.isAbsolute(credentialPath)) {
  throw new Error('Set NALDAM_LIVE_PROJECT=naldam-dev and provide the app plist and an absolute private credential path outside the repository.');
}
const repoRoot = path.resolve(import.meta.dirname, '../..');
if (path.resolve(credentialPath).startsWith(repoRoot + path.sep)) throw new Error('Credentials must be outside the repository.');
const plist = JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', plistPath], { encoding: 'utf8' }));
assert.equal(plist.PROJECT_ID, process.env.NALDAM_LIVE_PROJECT);
const config = { apiKey: plist.API_KEY, projectId: plist.PROJECT_ID, appId: plist.GOOGLE_APP_ID };
const apps = ['a', 'b', 'unauthenticated'].map(id => initializeApp(config, `live-check-${id}-${randomUUID()}`));
const auth = apps.map(app => getAuth(app));
const db = apps.map(app => getFirestore(app));
const passed = [];
const mark = text => { passed.push(text); console.log(`PASS ${text}`); };
let accounts;
try {
  accounts = JSON.parse(await readFile(credentialPath, 'utf8'));
  assert.equal(accounts.projectID, config.projectId);
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  accounts = {
    projectID: config.projectId,
    createdAt: new Date().toISOString(),
    accounts: ['가', '나'].map(name => ({ email: `naldam-review-${randomUUID()}@example.invalid`, password: randomBytes(24).toString('base64url') + '!7aA', name: `검토계정${name}` }))
  };
  await mkdir(path.dirname(credentialPath), { recursive: true, mode: 0o700 });
  await writeFile(credentialPath, JSON.stringify(accounts, null, 2), { mode: 0o600, flag: 'wx' });
}
await chmod(credentialPath, 0o600);
const denied = async action => {
  try { await action(); assert.fail('Expected permission denial'); }
  catch (error) { assert.equal(error.code, 'permission-denied'); }
};
const waitForDocument = (reference, expected) => new Promise((resolve, reject) => {
  let unsubscribe = () => {};
  const timer = setTimeout(() => { unsubscribe(); reject(new Error('Live snapshot timed out')); }, 20000);
  unsubscribe = onSnapshot(reference, { includeMetadataChanges: true }, snapshot => {
    if (snapshot.exists() && !snapshot.metadata.fromCache && expected(snapshot.data())) {
      clearTimeout(timer); unsubscribe(); resolve();
    }
  }, error => { clearTimeout(timer); unsubscribe(); reject(error); });
});

try {
  for (let index = 0; index < 2; index++) {
    const account = accounts.accounts[index];
    try { await signInWithEmailAndPassword(auth[index], account.email, account.password); }
    catch (error) {
      if (!['auth/invalid-credential', 'auth/user-not-found'].includes(error.code)) throw error;
      await createUserWithEmailAndPassword(auth[index], account.email, account.password);
    }
    account.uid = auth[index].currentUser.uid;
    await writeFile(credentialPath, JSON.stringify(accounts, null, 2), { mode: 0o600 });
    const reference = doc(db[index], 'profiles', account.uid);
    const previous = await getDocFromServer(reference);
    await setDoc(reference, { name: account.name, interests: ['기록', '산책', '독서'], createdAt: previous.exists() ? previous.data().createdAt : serverTimestamp(), updatedAt: serverTimestamp() });
  }
  const [a, b] = accounts.accounts;
  assert.notEqual(a.uid, b.uid);
  mark('Two email accounts authenticate and publish profiles');
  await denied(() => getDocFromServer(doc(db[2], 'profiles', a.uid)));
  mark('Unauthenticated profile access is denied');
  const roomID = [a.uid, b.uid].sort().join('__');
  accounts.roomID = roomID;
  await writeFile(credentialPath, JSON.stringify(accounts, null, 2), { mode: 0o600 });
  const roomA = doc(db[0], 'rooms', roomID);
  const roomB = doc(db[1], 'rooms', roomID);
  const existing = await getDocFromServer(roomA);
  if (!existing.exists()) {
    await setDoc(roomA, { members: [a.uid, b.uid].sort(), senderID: a.uid, recipientID: b.uid, status: 'pending', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    await denied(() => setDoc(doc(db[0], 'rooms', roomID, 'messages', randomUUID()), { senderID: a.uid, body: '수락 전 전송은 차단되어야 합니다.', createdAt: serverTimestamp() }));
    await denied(() => updateDoc(roomA, { status: 'active', updatedAt: serverTimestamp() }));
    mark('Pending messages and sender self-acceptance are denied');
    await updateDoc(roomB, { status: 'active', updatedAt: serverTimestamp() });
  }
  assert.equal((await getDocFromServer(roomA)).data().status, 'active');
  mark('Recipient accepts the conversation');
  for (const [sender, receiver] of [[0, 1], [1, 0]]) {
    const messageID = randomUUID();
    const body = sender === 0 ? '안녕하세요. 실제 대화 연결을 확인하고 있어요.' : '반가워요. 답장이 잘 도착했어요.';
    const incoming = waitForDocument(doc(db[receiver], 'rooms', roomID, 'messages', messageID), data => data.body === body && data.senderID === accounts.accounts[sender].uid);
    await setDoc(doc(db[sender], 'rooms', roomID, 'messages', messageID), { senderID: accounts.accounts[sender].uid, body, createdAt: serverTimestamp() });
    await incoming;
  }
  mark('Both accounts receive real-time server-confirmed messages');
  await setDoc(doc(db[1], 'rooms', roomID, 'states', b.uid), { lastReadAt: serverTimestamp(), archived: false });
  await denied(() => getDocFromServer(doc(db[0], 'rooms', roomID, 'states', b.uid)));
  mark('Read state is account-scoped');
  await signOut(auth[0]);
  await denied(() => getDocFromServer(roomA));
  await signInWithEmailAndPassword(auth[0], a.email, a.password);
  assert.equal(auth[0].currentUser.uid, a.uid);
  assert.equal((await getDocFromServer(roomA)).data().status, 'active');
  mark('Sign-out denies access and sign-in restores the same conversation');
  await writeFile(credentialPath + '.results.json', JSON.stringify({ projectID: config.projectId, checkedAt: new Date().toISOString(), passed }, null, 2), { mode: 0o600 });
} catch (error) {
  // Never print a Firebase response, credential, token, or account identifier.
  console.error(`FAIL ${error.code || error.name || 'unknown'}`);
  process.exitCode = 1;
} finally {
  await Promise.all(db.map(database => terminate(database)));
  await Promise.all(apps.map(app => deleteApp(app)));
}
