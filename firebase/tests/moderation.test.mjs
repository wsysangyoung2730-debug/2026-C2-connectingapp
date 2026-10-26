import test from 'node:test';
import assert from 'node:assert/strict';
import { expired } from '../scripts/moderate.mjs';
test('retention does not purge pending, malformed, future or younger timestamps',()=>{
 const now=Date.parse('2026-10-26T00:00:00Z');
 for(const value of [undefined,'invalid','2026-10-27T00:00:00Z','2026-09-26T00:00:01Z']) assert.equal(expired(value,now),false);
 assert.equal(expired('2026-09-26T00:00:00Z',now),true);
});
