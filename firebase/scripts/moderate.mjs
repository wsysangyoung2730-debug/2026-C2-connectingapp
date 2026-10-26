// Operator-only tool. Uses the already-authorized Firebase CLI account, never an app credential.
// Every mutation is dry-run unless --apply is supplied. It never deletes Auth users.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
const require = createRequire(import.meta.url);
const { getGlobalDefaultAccount } = require('firebase-tools/lib/auth');
const { requireAuth } = require('firebase-tools/lib/requireAuth');
const { Client } = require('firebase-tools/lib/apiv2');
const project = 'naldam-dev';
const root = `projects/${project}/databases/(default)/documents`;
const db = new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
const identity = new Client({ urlPrefix: 'https://identitytoolkit.googleapis.com', apiVersion: 'v1' });
const strings = fields => Object.fromEntries(Object.entries(fields || {}).map(([k,v]) => [k, v.stringValue ?? v.timestampValue ?? v.booleanValue]));
const encoded = obj => Object.fromEntries(Object.entries(obj).map(([k,v]) => [k, typeof v === 'boolean' ? {booleanValue:v} : k.endsWith('At') ? {timestampValue:v} : {stringValue:v}]));
const full = path => `${root}/${path}`;
const relative = doc => doc.name.slice(root.length + 1);
const uidPattern = /^[A-Za-z0-9_-]{1,128}$/;
export const expired = (timestamp, now = Date.now()) => Number.isFinite(Date.parse(timestamp)) && now - Date.parse(timestamp) >= 30 * 86400000;

async function all(collectionId, descendants = false) {
  const output = []; let cursor;
  do {
    const structuredQuery = { from: [{collectionId, allDescendants:descendants}], orderBy:[{field:{fieldPath:'__name__'},direction:'ASCENDING'}],limit:300 };
    if (cursor) structuredQuery.startAt = {values:[{referenceValue:cursor}],before:false};
    const {body} = await db.post(`${root}:runQuery`, {structuredQuery});
    const page = body.flatMap(row => row.document ? [row.document] : []);
    output.push(...page); cursor = page.length === 300 ? page.at(-1).name : undefined;
  } while (cursor);
  return output;
}
async function get(path) {
  try { return (await db.get(full(path))).body; }
  catch (e) { if (e.status === 404 || e.context?.response?.statusCode === 404) return null; throw e; }
}
async function existsAuth(uid) {
  const {body} = await identity.post(`projects/${project}/accounts:lookup`, {localId:[uid]});
  return (body.users || []).some(user => user.localId === uid);
}
async function commit(writes, apply) {
  if (!writes.length) return;
  if (!apply) { console.log(`DRY RUN: ${writes.length} change(s). Add --apply after reviewing.`); return; }
  for (let i=0;i<writes.length;i+=200) await db.post(`${root}:commit`, {writes:writes.slice(i,i+200)});
  console.log(`APPLIED: ${writes.length} change(s).`);
}
const remove = doc => ({delete:doc.name,currentDocument:{updateTime:doc.updateTime}});
const update = (doc, fields) => ({update:{name:doc.name,fields:encoded(fields)},updateMask:{fieldPaths:Object.keys(fields)},currentDocument:{updateTime:doc.updateTime}});

export async function run(args) {
  if (process.env.NALDAM_OPERATOR_PROJECT !== project) throw new Error('Set NALDAM_OPERATOR_PROJECT=naldam-dev explicitly.');
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first.');
  await requireAuth({project,...account});
  const [command, reference, action] = args.filter(x=>x !== '--apply'); const apply = args.includes('--apply');
  const now = new Date().toISOString();
  if (command === 'reports') {
    const reports = (await all('items',true)).filter(doc => /^contentReports\/[^/]+\/items\/[^/]+$/.test(relative(doc)));
    for (const report of reports) {
      const data = strings(report.fields);
      if (data.status === 'pending') console.log(JSON.stringify({path:relative(report),...data}));
    }
    console.log(`Checked ${reports.length} report(s). Pending reports are printed above.`);
  } else if (command === 'review') {
    if (!/^contentReports\/[A-Za-z0-9_-]+\/items\/[A-Za-z0-9_-]+$/.test(reference || '')) throw new Error('Expected a report path from reports.');
    const report = await get(reference); if (!report) throw new Error('Report not found.');
    const data = strings(report.fields);
    if (!uidPattern.test(data.targetUserID)) throw new Error('Invalid report target.');
    if (!action || action === 'inspect') {
      const profile = await get(`profiles/${data.targetUserID}`);
      let message;
      if (data.messageID && /^[A-Za-z0-9_-]+$/.test(data.messageID) && /^[A-Za-z0-9_-]+$/.test(data.roomID)) {
        message = await get(`rooms/${data.roomID}/messages/${data.messageID}`);
      }
      console.log(JSON.stringify({report:data,profile:profile?.fields,message:message?.fields})); return;
    }
    const writes=[];
    if (action === 'remove-message') {
      if (!/^[A-Za-z0-9_-]+$/.test(data.messageID) || !/^[A-Za-z0-9_-]+$/.test(data.roomID)) throw new Error('Report has no valid message.');
      const message=await get(`rooms/${data.roomID}/messages/${data.messageID}`);
      if (message && strings(message.fields).senderID !== data.targetUserID) throw new Error('Message target mismatch.');
      if (message) writes.push(remove(message));
    } else if (action === 'restrict') {
      writes.push({update:{name:full(`accountRestrictions/${data.targetUserID}`),fields:encoded({reason:'community-rules',updatedAt:now})}});
      const profile=await get(`profiles/${data.targetUserID}`);if(profile) writes.push(remove(profile));
    } else if (action !== 'resolve') throw new Error('Use inspect, remove-message, restrict or resolve.');
    writes.push(update(report,{status:'resolved',resolution:action,resolvedAt:now}));
    console.log(`Report action: ${action}`); await commit(writes,apply);
  } else if (command === 'unrestrict') {
    if (!uidPattern.test(reference || '')) throw new Error('Expected a UID.');
    const restriction=await get(`accountRestrictions/${reference}`);
    await commit(restriction ? [remove(restriction)] : [],apply);
  } else if (command === 'cleanup') {
    const writes=[];
    const reports=(await all('items',true)).filter(doc=>/^contentReports\/[^/]+\/items\/[^/]+$/.test(relative(doc)));
    for (const report of reports) {
      const data=strings(report.fields);
      if(data.status==='resolved' && expired(data.resolvedAt)) writes.push(remove(report));
    }
    const markers=await all('accountDeletions');
    const rooms=await all('rooms');
    const blocks=markers.length ? await all('blocks',true) : [];
    for (const marker of markers) {
      const uid=relative(marker).split('/')[1];if(!uidPattern.test(uid)) continue;
      if(await existsAuth(uid)) continue;
      if(await get(`profiles/${uid}`)) continue;
      if(rooms.some(room=>(room.fields.members?.arrayValue?.values||[]).some(v=>v.stringValue===uid))) continue;
      const data=strings(marker.fields);
      if(!data.confirmedDeletedAt) {
        writes.push(update(marker,{confirmedDeletedAt:now}));continue;
      }
      if(!expired(data.confirmedDeletedAt)) continue;
      for(const block of blocks) if(relative(block).match(/^users\/[^/]+\/blocks\/[^/]+$/) && relative(block).split('/')[3]===uid) writes.push(remove(block));
      const restriction=await get(`accountRestrictions/${uid}`);if(restriction) writes.push(remove(restriction));
      writes.push(remove(marker));
    }
    console.log('Only resolved reports older than 30 days and verified deleted-account metadata are eligible.');
    await commit(writes,apply);
  } else throw new Error('Commands: reports; review <report-path> [inspect|remove-message|restrict|resolve]; unrestrict <uid>; cleanup.');
}
if(process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run(process.argv.slice(2)).catch(error=>{console.error(`Operation failed: ${error.status || error.name}. No credentials are printed.`);process.exitCode=1;});
}
