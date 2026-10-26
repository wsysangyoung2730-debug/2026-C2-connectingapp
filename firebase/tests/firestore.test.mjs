import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, limit, onSnapshot, orderBy,
  query, runTransaction, serverTimestamp, setDoc, Timestamp, updateDoc, where, writeBatch,
} from 'firebase/firestore';

let env;
const apple = uid => env.authenticatedContext(uid, {
  firebase: { sign_in_provider: 'apple.com', identities: {} },
  auth_time: Math.floor(Date.now() / 1000),
}).firestore();
const profile = (name = '상영', interests = ['기록', '산책']) => ({
  name, interests, termsVersion: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});
const pending = (senderID = 'alice', recipientID = 'bob') => ({
  members: [senderID, recipientID].sort(), senderID, recipientID,
  status: 'pending', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});
const message = (senderID, body = '안녕하세요') => ({ senderID, body, createdAt: serverTimestamp() });
const roomRef = db => doc(db, 'rooms/alice__bob');
const messageRef = (db, id = 'message-1') => doc(db, `rooms/alice__bob/messages/${id}`);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-naldam-chat',
    firestore: { rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => env.clearFirestore());
after(async () => env?.cleanup());

async function seedProfiles() {
  await setDoc(doc(apple('alice'), 'profiles/alice'), profile('앨리스'));
  await setDoc(doc(apple('bob'), 'profiles/bob'), profile('밥'));
}
async function createRoom() {
  await seedProfiles();
  await setDoc(roomRef(apple('alice')), pending());
}
async function activateRoom() {
  await createRoom();
  await updateDoc(roomRef(apple('bob')), { status: 'active', updatedAt: serverTimestamp() });
}

test('unauthenticated and anonymous accounts cannot read profiles or write data', async () => {
  await seedProfiles();
  const unauth = env.unauthenticatedContext().firestore();
  const anonymous = env.authenticatedContext('guest', {
    firebase: { sign_in_provider: 'anonymous', identities: {} },
  }).firestore();
  for (const db of [unauth, anonymous]) {
    await assertFails(getDocs(collection(db, 'profiles')));
    await assertFails(getDoc(doc(db, 'profiles/alice')));
    await assertFails(setDoc(doc(db, 'profiles/guest'), profile()));
    await assertFails(getDocs(collection(db, 'rooms')));
  }
});

test('profile owner can publish/edit; another account cannot forge/delete or add private fields', async () => {
  const alice = apple('alice'), bob = apple('bob');
  await assertSucceeds(setDoc(doc(alice, 'profiles/alice'), profile()));
  await assertSucceeds(getDocs(query(collection(bob, 'profiles'), limit(100))));
  await assertSucceeds(updateDoc(doc(alice, 'profiles/alice'), { name: '새이름', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(bob, 'profiles/alice'), { name: '위조', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(bob, 'profiles/alice')));
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { diary: '비공개 기록', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { createdAt: Timestamp.fromMillis(1), updatedAt: serverTimestamp() }));
});

test('profile bounds reject blanks, duplicates, invalid tags and client timestamps', async () => {
  const ref = doc(apple('alice'), 'profiles/alice');
  for (const name of ['', '   ', '가'.repeat(1025)]) await assertFails(setDoc(ref, profile(name)));
  for (const tags of [[''], ['  '], ['기록', '기록'], ['a'.repeat(257)], ['#기록'], ['a\nb'], [1], ['1', '2', '3', '4', '5', '6', '7']]) {
    await assertFails(setDoc(ref, profile('상영', tags)));
  }
  await assertFails(setDoc(ref, { ...profile(), createdAt: Timestamp.fromMillis(1) }));
  await assertFails(setDoc(ref, { ...profile(), updatedAt: Timestamp.fromMillis(1) }));
  await assertSucceeds(setDoc(ref, profile('상영', ['러닝', '기록', '산책', '음악', '독서', '한글다섯자'])));
});

test('combined emoji and internal-space tags remain compatible with the 5-grapheme editor', async () => {
  await assertSucceeds(setDoc(doc(apple('alice'), 'profiles/alice'), profile('🏃🏽‍♀️'.repeat(12), ['🏃🏽‍♀️'.repeat(5), '홈 카페', 'e\u0301'])));
  await assertSucceeds(setDoc(doc(apple('bob'), 'profiles/bob'), profile('👨‍👩‍👧‍👦'.repeat(12), ['👨‍👩‍👧‍👦'.repeat(5)])));
});

test('sender can transact against a missing room; self/outsider/missing-profile requests fail', async () => {
  await seedProfiles();
  const alice = apple('alice');
  await assertSucceeds(runTransaction(alice, async tx => {
    const ref = roomRef(alice);
    assert.equal((await tx.get(ref)).exists(), false);
    tx.set(ref, pending());
  }));
  await assertFails(setDoc(doc(apple('eve'), 'rooms/alice__eve'), pending('alice', 'eve')));
  await assertFails(setDoc(doc(alice, 'rooms/alice__alice'), pending('alice', 'alice')));
  await assertFails(setDoc(doc(alice, 'rooms/alice__unknown'), pending('alice', 'unknown')));
  await assertFails(setDoc(doc(alice, 'rooms/another-id'), pending()));
  await assertFails(setDoc(doc(alice, 'rooms/bob__alice'), { ...pending(), members: ['bob', 'alice'] }));
  await assertFails(setDoc(roomRef(alice), { ...pending(), status: 'active' }));
});

test('only recipient can accept; sender, members and accepted state cannot be rewritten', async () => {
  await createRoom();
  await assertFails(updateDoc(roomRef(apple('alice')), { status: 'active', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(roomRef(apple('eve')), { status: 'active', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(roomRef(apple('bob')), { senderID: 'bob', recipientID: 'alice', status: 'active', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(roomRef(apple('bob')), { members: ['bob', 'eve'], status: 'active', updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(roomRef(apple('bob')), { status: 'active', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(roomRef(apple('bob')), { status: 'pending', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(roomRef(apple('alice'))));
});

test('sender can cancel and recipient can decline; declined requests cannot reopen', async () => {
  await createRoom();
  await assertSucceeds(updateDoc(roomRef(apple('alice')), { status: 'declined', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(roomRef(apple('alice')), { status: 'pending', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(roomRef(apple('bob')), { status: 'active', updatedAt: serverTimestamp() }));
  await env.clearFirestore();
  await createRoom();
  await assertSucceeds(updateDoc(roomRef(apple('bob')), { status: 'declined', updatedAt: serverTimestamp() }));
});

test('room list requires membership constraint; outsiders cannot get room metadata', async () => {
  await createRoom();
  await assertSucceeds(getDocs(query(collection(apple('alice'), 'rooms'), where('members', 'array-contains', 'alice'))));
  await assertSucceeds(getDocs(query(collection(apple('bob'), 'rooms'), where('members', 'array-contains', 'bob'))));
  await assertFails(getDocs(collection(apple('alice'), 'rooms')));
  await assertFails(getDoc(roomRef(apple('eve'))));
  await assertFails(getDocs(query(collection(apple('eve'), 'rooms'), where('members', 'array-contains', 'alice'))));
});

test('messages require acceptance, correct sender and server timestamp; outsiders cannot read', async () => {
  await createRoom();
  await assertFails(setDoc(messageRef(apple('alice')), message('alice')));
  await assertFails(getDocs(collection(apple('bob'), 'rooms/alice__bob/messages')));
  await updateDoc(roomRef(apple('bob')), { status: 'active', updatedAt: serverTimestamp() });
  await assertFails(setDoc(messageRef(apple('alice')), message('bob')));
  await assertFails(setDoc(messageRef(apple('eve')), message('eve')));
  await assertFails(setDoc(messageRef(apple('alice')), { ...message('alice'), createdAt: Timestamp.fromMillis(1) }));
  await assertFails(setDoc(messageRef(apple('alice')), { ...message('alice'), isAdmin: true }));
  await assertSucceeds(setDoc(messageRef(apple('alice')), message('alice')));
  await assertSucceeds(getDoc(messageRef(apple('bob'))));
  await assertFails(getDoc(messageRef(apple('eve'))));
  await assertFails(getDocs(collection(apple('eve'), 'rooms/alice__bob/messages')));
  await assertFails(updateDoc(messageRef(apple('alice')), { body: '덮어쓰기' }));
  await assertFails(deleteDoc(messageRef(apple('alice'))));
});

test('message text rejects blank/oversize bodies and accepts 2000 UTF-16 units and multiline text', async () => {
  await activateRoom();
  const alice = apple('alice');
  for (const body of ['', ' \n\t ', '가'.repeat(2001), '😀'.repeat(1001), 'e\u0301'.repeat(1001)]) {
    await assertFails(setDoc(messageRef(alice), message('alice', body)));
  }
  await assertSucceeds(setDoc(messageRef(alice), message('alice', '가'.repeat(2000))));
  await assertSucceeds(setDoc(messageRef(alice, 'emoji'), message('alice', '😀'.repeat(1000))));
  await assertSucceeds(setDoc(messageRef(alice, 'combining'), message('alice', 'e\u0301'.repeat(1000))));
  await assertSucceeds(setDoc(messageRef(alice, 'multiline'), message('alice', '\n첫 줄\n두 번째 줄\n')));
});

test('idempotent outbox retry reads the existing message without replacing it', async () => {
  await activateRoom();
  const alice = apple('alice');
  async function sendOnce() {
    return runTransaction(alice, async tx => {
      const ref = messageRef(alice);
      const snapshot = await tx.get(ref);
      if (snapshot.exists()) {
        assert.equal(snapshot.data().senderID, 'alice');
        assert.equal(snapshot.data().body, '한 번만');
      } else tx.set(ref, message('alice', '한 번만'));
    });
  }
  await assertSucceeds(sendOnce());
  await assertSucceeds(sendOnce());
  assert.equal((await getDocs(collection(alice, 'rooms/alice__bob/messages'))).size, 1);
});

test('two authenticated clients exchange realtime messages and a new session restores history', async () => {
  await activateRoom();
  const alice = apple('alice'), bob = apple('bob');
  const bobReceived = waitForMessage(bob, 'from-alice');
  await setDoc(messageRef(alice, 'from-alice'), message('alice', '안녕하세요, 밥'));
  assert.equal((await bobReceived).body, '안녕하세요, 밥');
  const aliceReceived = waitForMessage(alice, 'from-bob');
  await setDoc(messageRef(bob, 'from-bob'), message('bob', '반가워요, 앨리스'));
  assert.equal((await aliceReceived).senderID, 'bob');
  const restored = await getDocs(query(collection(apple('alice'), 'rooms/alice__bob/messages'), orderBy('createdAt')));
  assert.equal(restored.size, 2);
});

function waitForMessage(db, expectedID) {
  return new Promise((resolve, reject) => {
    let unsubscribe;
    const timer = setTimeout(() => { unsubscribe?.(); reject(new Error(`Missing message ${expectedID}`)); }, 10000);
    unsubscribe = onSnapshot(collection(db, 'rooms/alice__bob/messages'), snapshot => {
      const found = snapshot.docs.find(item => item.id === expectedID && !item.metadata.hasPendingWrites);
      if (found) { clearTimeout(timer); unsubscribe?.(); resolve(found.data()); }
    }, error => { clearTimeout(timer); unsubscribe?.(); reject(error); });
  });
}

test('read/archive state supports separate merge writes and is private to its participant', async () => {
  await activateRoom();
  const alice = apple('alice'), bob = apple('bob');
  const ref = doc(alice, 'rooms/alice__bob/states/alice');
  await assertSucceeds(setDoc(ref, { archived: true }, { merge: true }));
  await assertSucceeds(setDoc(ref, { lastReadAt: serverTimestamp() }, { merge: true }));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(setDoc(doc(bob, 'rooms/alice__bob/states/bob'), { lastReadAt: serverTimestamp() }, { merge: true }));
  await assertFails(getDoc(doc(bob, 'rooms/alice__bob/states/alice')));
  await assertFails(setDoc(doc(bob, 'rooms/alice__bob/states/alice'), { archived: false }));
  await assertFails(setDoc(doc(apple('eve'), 'rooms/alice__bob/states/eve'), { archived: false }));
  await assertFails(updateDoc(ref, { lastReadAt: Timestamp.fromMillis(Date.now() + 86400000) }));
  await assertFails(updateDoc(ref, { unreadCount: 0 }));
});

test('either direction of blocking stops new messages but retains existing readable history', async () => {
  await activateRoom();
  const alice = apple('alice'), bob = apple('bob');
  await setDoc(messageRef(alice), message('alice'));
  await assertSucceeds(setDoc(doc(bob, 'users/bob/blocks/alice'), { createdAt: serverTimestamp() }));
  await assertFails(setDoc(messageRef(alice, 'blocked-a'), message('alice')));
  await assertFails(setDoc(messageRef(bob, 'blocked-b'), message('bob')));
  await assertSucceeds(getDoc(messageRef(alice)));
  await assertSucceeds(getDoc(messageRef(bob)));
  await assertSucceeds(deleteDoc(doc(bob, 'users/bob/blocks/alice')));
  await assertSucceeds(setDoc(messageRef(alice, 'unblocked'), message('alice')));
});

test('blocks are owner-only, cannot block self, and prevent requests and acceptance', async () => {
  await seedProfiles();
  const alice = apple('alice'), bob = apple('bob');
  await assertFails(setDoc(doc(alice, 'users/bob/blocks/alice'), { createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(alice, 'users/alice/blocks/alice'), { createdAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(bob, 'users/bob/blocks/alice'), { createdAt: serverTimestamp() }));
  await assertFails(getDoc(doc(alice, 'users/bob/blocks/alice')));
  await assertSucceeds(getDocs(collection(bob, 'users/bob/blocks')));
  await assertFails(setDoc(roomRef(alice), pending()));
  await deleteDoc(doc(bob, 'users/bob/blocks/alice'));
  await setDoc(roomRef(alice), pending());
  await setDoc(doc(alice, 'users/alice/blocks/bob'), { createdAt: serverTimestamp() });
  await assertFails(updateDoc(roomRef(bob), { status: 'active', updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(roomRef(bob), { status: 'declined', updatedAt: serverTimestamp() }));
});

test('unrecognized collections and nested paths are denied by default', async () => {
  const alice = apple('alice');
  await assertFails(setDoc(doc(alice, 'journals/private'), { answer: '개인 기록' }));
  await assertFails(setDoc(doc(alice, 'users/alice'), { admin: true }));
  await assertFails(setDoc(doc(alice, 'profiles/alice/private/secret'), { value: 'hidden' }));
});

const marker = db => doc(db, 'accountDeletions/alice');
const reportRef = (db, owner = 'alice', id = 'bob__message-1') => doc(db, `contentReports/${owner}/items/${id}`);
const reportFields = () => ({targetUserID: 'bob', roomID: 'alice__bob', messageID: 'message-1', reason: 'harassment', details: '검토 요청', status: 'pending', createdAt: serverTimestamp()});

test('deletion requires recent own authentication and cannot be undone or forged', async () => {
  await seedProfiles();
  const stale = env.authenticatedContext('alice', {firebase: {sign_in_provider:'password'}, auth_time: 1}).firestore();
  await assertFails(setDoc(marker(stale), {createdAt: serverTimestamp()}));
  await assertFails(setDoc(marker(apple('bob')), {createdAt: serverTimestamp()}));
  await assertSucceeds(setDoc(marker(apple('alice')), {createdAt: serverTimestamp()}));
  await assertFails(deleteDoc(marker(apple('alice'))));
  await assertFails(updateDoc(marker(apple('alice')), {createdAt: serverTimestamp()}));
  await assertFails(getDoc(marker(apple('bob'))));
});

test('deletion freezes both-direction contact, profile recreation and state writes', async () => {
  await activateRoom();
  const a=apple('alice'), b=apple('bob');
  await setDoc(marker(a), {createdAt: serverTimestamp()});
  await assertFails(setDoc(messageRef(a), message('alice')));
  await assertFails(setDoc(messageRef(b), message('bob')));
  await assertFails(updateDoc(doc(a,'profiles/alice'), {name:'복원',updatedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(a,'rooms/alice__bob/states/alice'), {archived:true}));
  await deleteDoc(doc(a,'profiles/alice'));
  await assertFails(setDoc(doc(a,'profiles/alice'), profile()));
});

test('deletion cleans only owned rooms, including both message authors and state', async () => {
  await activateRoom();
  const a=apple('alice'), b=apple('bob'), outsider=apple('mallory');
  await setDoc(messageRef(a,'a'),message('alice'));
  await setDoc(messageRef(b,'b'),message('bob'));
  await setDoc(doc(b,'rooms/alice__bob/states/bob'),{archived:false});
  await setDoc(marker(a), {createdAt:serverTimestamp()});
  await assertFails(deleteDoc(messageRef(outsider,'b')));
  const docs=await assertSucceeds(getDocs(query(collection(a,'rooms'),where('members','array-contains','alice'))));
  assert.equal(docs.size,1);
  const messages=await assertSucceeds(getDocs(collection(a,'rooms/alice__bob/messages')));
  const batch=writeBatch(a);
  messages.docs.forEach(d=>batch.delete(d.ref));
  batch.delete(doc(a,'rooms/alice__bob/states/bob'));
  batch.delete(doc(a,'rooms/alice__bob/states/alice'));
  batch.delete(roomRef(a));
  await assertSucceeds(batch.commit());
  assert.equal((await getDocs(query(collection(a,'rooms'),where('members','array-contains','alice')))).size,0);
  await assertFails(setDoc(roomRef(b),pending('bob','alice')));
});

test('interrupted cleanup can resume and ordinary users cannot erase messages', async () => {
  await activateRoom(); const a=apple('alice'), b=apple('bob');
  await setDoc(messageRef(a,'a'),message('alice'));
  await setDoc(messageRef(b,'b'),message('bob'));
  await assertFails(deleteDoc(messageRef(a,'a')));
  await setDoc(marker(a),{createdAt:serverTimestamp()});
  await deleteDoc(messageRef(a,'a'));
  const resumed=apple('alice');
  const left=await getDocs(collection(resumed,'rooms/alice__bob/messages'));
  assert.deepEqual(left.docs.map(d=>d.id),['b']);
  await assertSucceeds(deleteDoc(messageRef(resumed,'b')));
});

test('server filters harmful profile tags and messages even without the app', async () => {
  await activateRoom(); const a=apple('alice');
  await assertFails(setDoc(messageRef(a),message('alice','씨 발')));
  await assertFails(updateDoc(doc(a,'profiles/alice'),{name:'개새끼',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(a,'profiles/alice'),{interests:['강간'],updatedAt:serverTimestamp()}));
  await assertSucceeds(setDoc(messageRef(a),message('alice','따뜻한 산책 이야기')));
});

test('terms consent is required when publishing and sending', async () => {
  const a=apple('alice');
  const data=profile(); delete data.termsVersion;
  await assertFails(setDoc(doc(a,'profiles/alice'),data));
  await activateRoom();
  await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),'profiles/alice'),{termsVersion:0}));
  await assertFails(setDoc(messageRef(a),message('alice')));
});

test('reports are private, immutable, tied to actual sender and cannot be self-approved', async () => {
  await activateRoom(); const a=apple('alice'),b=apple('bob');
  await setDoc(messageRef(b),message('bob'));
  await assertSucceeds(setDoc(reportRef(a),reportFields()));
  await assertSucceeds(getDoc(reportRef(a)));
  await assertFails(getDoc(reportRef(b)));
  await assertFails(getDocs(collection(b,'contentReports/alice/items')));
  await assertFails(updateDoc(reportRef(a),{status:'resolved'}));
  await assertFails(setDoc(reportRef(a,'alice','bad'),{...reportFields(),targetUserID:'alice'}));
  await assertFails(setDoc(reportRef(apple('mallory'),'mallory'),reportFields()));
});

test('profile reports and atomic reporting with blocking work without exposing reports',async()=>{
  await seedProfiles(); const a=apple('alice');
  const batch=writeBatch(a);
  batch.set(reportRef(a,'alice','profile'),{...reportFields(),roomID:'',messageID:''});
  batch.set(doc(a,'users/alice/blocks/bob'),{createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(reportRef(a,'alice','missing'),{...reportFields(),messageID:'missing'}));
  await assertFails(setDoc(reportRef(a,'alice','long'),{...reportFields(),details:'x'.repeat(1001)}));
});

test('restricted account cannot send, accept or republish, but can delete its account',async()=>{
  await activateRoom(); const a=apple('alice');
  await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),'accountRestrictions/alice'),{createdAt:Timestamp.now()}));
  await assertFails(setDoc(messageRef(a),message('alice')));
  await assertFails(updateDoc(doc(a,'profiles/alice'),{name:'다시',updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(a,'accountRestrictions/alice')));
  await assertSucceeds(setDoc(marker(a),{createdAt:serverTimestamp()}));
  await assertSucceeds(deleteDoc(roomRef(a)));
});
