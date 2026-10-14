#!/usr/bin/env node

import fs from 'node:fs';

const STATUS = new Set([
  'READY','BUSY','DEGRADED','BLOCKED','OFFLINE','FAIL','HOLD','PASS','PENDING_VALIDATION'
]);
const ADAPTER = new Set(['excel','ios','pwa','generic']);
const FAILURE = new Set(['INFRA_FAIL','CODE_FAIL','VALIDATION_FAIL','CONFLICT','BLOCKED','UNKNOWN']);
const RUN_OUTCOME = new Set(['PASS','FAIL','BLOCKED','CANCELLED','IN_PROGRESS','QUEUED']);
const GATE_STATUS = new Set(['PENDING','PASS','FAIL','BLOCKED','SKIPPED']);
const RETRY_POLICY = new Set(['NO_RETRY','INFRA_ONCE','MANUAL','ADAPTER_DEFINED']);
const SHA40 = /^[0-9a-f]{40}$/;
function looksSecretKey(key) {
  const normalized = String(key).toLowerCase().replace(/[^a-z0-9]/g, '');
  return /(token|password|passwd|secret|privatekey|apikey)$/.test(normalized);
}

function fail(message) {
  throw new Error(message);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function expectObject(value, name) {
  if (!isObject(value)) fail(`${name} must be an object`);
}

function expectString(value, name, allowNull = false) {
  if (allowNull && value === null) return;
  if (typeof value !== 'string' || value.length === 0) fail(`${name} must be a non-empty string`);
}

function expectSha(value, name, allowNull = true) {
  if (allowNull && value === null) return;
  if (typeof value !== 'string' || !SHA40.test(value)) fail(`${name} must be a lowercase 40-character SHA`);
}

function walkNoSecrets(value, path = 'extensions') {
  if (Array.isArray(value)) {
    value.forEach((v, i) => walkNoSecrets(v, `${path}[${i}]`));
    return;
  }
  if (!isObject(value)) return;
  for (const [key, child] of Object.entries(value)) {
    if (looksSecretKey(key)) fail(`${path}.${key} looks like a secret-bearing field; authority files must not store secrets`);
    walkNoSecrets(child, `${path}.${key}`);
  }
}

function validate(doc) {
  expectObject(doc, 'root');

  const required = [
    'schemaVersion','project','adapter','phase','status','authority','failure','retry',
    'gates','blockers','next','rollback','handoff','extensions','updatedAt'
  ];
  for (const key of required) {
    if (!(key in doc)) fail(`missing required key: ${key}`);
  }

  if (doc.schemaVersion !== '1.0') fail('schemaVersion must equal 1.0');
  expectString(doc.project, 'project');
  if (!ADAPTER.has(doc.adapter)) fail(`unsupported adapter: ${doc.adapter}`);
  if (!STATUS.has(doc.status)) fail(`unsupported status: ${doc.status}`);

  expectObject(doc.phase, 'phase');
  expectString(doc.phase.id, 'phase.id');
  expectString(doc.phase.name, 'phase.name');

  expectObject(doc.authority, 'authority');
  expectSha(doc.authority.baselineSha, 'authority.baselineSha');
  expectSha(doc.authority.candidateSha, 'authority.candidateSha');
  if (typeof doc.authority.candidateFrozen !== 'boolean') fail('authority.candidateFrozen must be boolean');
  if (doc.authority.sourceRef !== null) expectString(doc.authority.sourceRef, 'authority.sourceRef');

  const lastRun = doc.authority.lastRun;
  if (lastRun !== null) {
    expectObject(lastRun, 'authority.lastRun');
    if (!['github-actions','local','other'].includes(lastRun.provider)) fail('authority.lastRun.provider is invalid');
    if (typeof lastRun.runId !== 'string' && !Number.isInteger(lastRun.runId)) fail('authority.lastRun.runId must be string or integer');
    if (lastRun.jobId !== null && typeof lastRun.jobId !== 'string' && !Number.isInteger(lastRun.jobId)) fail('authority.lastRun.jobId must be string, integer, or null');
    expectSha(lastRun.commitSha, 'authority.lastRun.commitSha');
    if (!RUN_OUTCOME.has(lastRun.outcome)) fail(`authority.lastRun.outcome is invalid: ${lastRun.outcome}`);
  }

  if (doc.failure !== null) {
    expectObject(doc.failure, 'failure');
    if (!FAILURE.has(doc.failure.class)) fail(`failure.class is invalid: ${doc.failure.class}`);
    expectString(doc.failure.signature, 'failure.signature');
    expectString(doc.failure.methodKey, 'failure.methodKey');
  }

  expectObject(doc.retry, 'retry');
  if (!Number.isInteger(doc.retry.attempt) || doc.retry.attempt < 0 || doc.retry.attempt > 2) fail('retry.attempt must be 0..2');
  if (!Number.isInteger(doc.retry.maxAttemptsSameMethod) || doc.retry.maxAttemptsSameMethod < 1 || doc.retry.maxAttemptsSameMethod > 2) fail('retry.maxAttemptsSameMethod must be 1..2');
  if (!RETRY_POLICY.has(doc.retry.policy)) fail(`retry.policy is invalid: ${doc.retry.policy}`);
  if (doc.retry.attempt > doc.retry.maxAttemptsSameMethod) fail('retry.attempt cannot exceed retry.maxAttemptsSameMethod');

  if (!Array.isArray(doc.gates)) fail('gates must be an array');
  const gateIds = new Set();
  for (const gate of doc.gates) {
    expectObject(gate, 'gate');
    expectString(gate.id, 'gate.id');
    if (gateIds.has(gate.id)) fail(`duplicate gate id: ${gate.id}`);
    gateIds.add(gate.id);
    if (!GATE_STATUS.has(gate.status)) fail(`gate ${gate.id} has invalid status ${gate.status}`);
    if (!Array.isArray(gate.evidence)) fail(`gate ${gate.id}.evidence must be an array`);
  }

  if (!Array.isArray(doc.blockers)) fail('blockers must be an array');
  for (const blocker of doc.blockers) {
    expectObject(blocker, 'blocker');
    expectString(blocker.code, 'blocker.code');
    expectString(blocker.summary, 'blocker.summary');
    if (typeof blocker.requiresHuman !== 'boolean') fail('blocker.requiresHuman must be boolean');
  }

  expectObject(doc.next, 'next');
  expectString(doc.next.action, 'next.action');
  if (!Array.isArray(doc.next.requires)) fail('next.requires must be an array');

  expectObject(doc.rollback, 'rollback');
  expectSha(doc.rollback.sha, 'rollback.sha');
  if (doc.rollback.ref !== null) expectString(doc.rollback.ref, 'rollback.ref');
  if (doc.rollback.note !== null && typeof doc.rollback.note !== 'string') fail('rollback.note must be string or null');

  expectObject(doc.handoff, 'handoff');
  if (typeof doc.handoff.recommendedNewChat !== 'boolean') fail('handoff.recommendedNewChat must be boolean');
  if (doc.handoff.prompt !== null && typeof doc.handoff.prompt !== 'string') fail('handoff.prompt must be string or null');
  if (doc.handoff.recommendedNewChat && (!doc.handoff.prompt || doc.handoff.prompt.trim().length === 0)) {
    fail('handoff.prompt is required when recommendedNewChat=true');
  }

  expectObject(doc.extensions, 'extensions');
  walkNoSecrets(doc.extensions);

  if (typeof doc.updatedAt !== 'string' || Number.isNaN(Date.parse(doc.updatedAt))) fail('updatedAt must be an ISO-8601 datetime');

  if (doc.status === 'PENDING_VALIDATION' && !doc.authority.candidateFrozen) {
    fail('PENDING_VALIDATION requires authority.candidateFrozen=true');
  }
  if (doc.status === 'PASS') {
    if (!doc.authority.candidateSha) fail('PASS requires authority.candidateSha');
    if (!lastRun || lastRun.outcome !== 'PASS') fail('PASS requires an authoritative PASS lastRun');
  }
  if (doc.status === 'FAIL' && doc.failure === null) {
    fail('FAIL requires failure classification');
  }
  if (doc.status === 'BLOCKED' && doc.failure === null && doc.blockers.length === 0) {
    fail('BLOCKED requires failure classification or at least one blocker');
  }

  if (doc.retry.attempt === 2 && doc.failure !== null && !/change|switch|replace|redesign|別方式|方式変更/i.test(doc.next.action)) {
    console.warn('CONTROL_PLANE_WARNING retry.attempt=2: next.action should normally change method');
  }
}

const paths = process.argv.slice(2);
if (paths.length === 0) {
  console.error('usage: node control-plane/validate-authority.mjs <authority.json> [...]');
  process.exit(2);
}

let failed = false;
for (const file of paths) {
  try {
    const raw = fs.readFileSync(file, 'utf8');
    const doc = JSON.parse(raw);
    validate(doc);
    console.log(`CONTROL_PLANE_AUTHORITY_PASS ${file}`);
  } catch (error) {
    failed = true;
    console.error(`CONTROL_PLANE_AUTHORITY_FAIL ${file} :: ${error.message}`);
  }
}
process.exit(failed ? 1 : 0);
