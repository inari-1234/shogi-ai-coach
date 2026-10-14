#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const repo = process.env.GITHUB_REPOSITORY;
const token = process.env.GITHUB_TOKEN;
const targetSha = process.env.TARGET_SHA;
const outPath = process.env.AUTHORITY_OUT;
const previousPath = process.env.PREVIOUS_AUTHORITY || '';
const pollSeconds = Number(process.env.POLL_SECONDS || '180');
const intervalSeconds = Number(process.env.POLL_INTERVAL_SECONDS || '15');

if (!repo || !token || !/^[0-9a-f]{40}$/.test(targetSha || '') || !outPath) {
  throw new Error('IOS_CONTROL_PLANE_CONFIG_INVALID');
}

const expected = [
  {name: 'iOS Device Build', gate: 'device-build'},
  {name: 'iOS Simulator E2E', gate: 'simulator-e2e'},
  {name: 'Build18-M Final Regression', gate: 'final-regression'},
];

const api = async (url) => {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'shogi-ai-coach-control-plane-v1'
    }
  });
  if (!response.ok) throw new Error(`GITHUB_API_${response.status} ${url}`);
  return response.json();
};

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function getRuns() {
  const url = `https://api.github.com/repos/${repo}/actions/runs?branch=main&event=push&per_page=100`;
  const body = await api(url);
  const found = new Map();
  for (const spec of expected) {
    const runs = (body.workflow_runs || [])
      .filter(r => r.name === spec.name && r.head_sha === targetSha && r.head_branch === 'main' && r.event === 'push')
      .sort((a,b) => Number(b.id) - Number(a.id));
    found.set(spec.name, runs[0] || null);
  }
  return found;
}

let runs = await getRuns();
const deadline = Date.now() + pollSeconds * 1000;
while (Date.now() < deadline) {
  const allPresent = expected.every(s => runs.get(s.name));
  const allCompleted = allPresent && expected.every(s => runs.get(s.name).status === 'completed');
  if (allCompleted) break;
  await sleep(intervalSeconds * 1000);
  runs = await getRuns();
}

const missing = expected.filter(s => !runs.get(s.name));
const incomplete = expected.filter(s => runs.get(s.name) && runs.get(s.name).status !== 'completed');

if (missing.length === 0 && incomplete.length > 0) {
  console.log(`IOS_CONTROL_PLANE_DEFER incomplete=${incomplete.map(x => x.name).join(',')}`);
  process.exit(0);
}

async function failedSteps(run) {
  if (!run || run.status !== 'completed' || run.conclusion === 'success') return [];
  const body = await api(`https://api.github.com/repos/${repo}/actions/runs/${run.id}/jobs?per_page=100`);
  const failed = [];
  for (const job of body.jobs || []) {
    for (const step of job.steps || []) {
      if (step.conclusion && step.conclusion !== 'success' && step.conclusion !== 'skipped') {
        failed.push(`${job.name}/${step.name}:${step.conclusion}`);
      }
    }
  }
  return failed;
}

function classifyFailure(name, run, steps) {
  if (!run) return {class:'BLOCKED', signature:`${name}:missing`};
  if (run.conclusion === 'cancelled' || run.conclusion === 'timed_out' || run.conclusion === 'startup_failure') {
    return {class:'INFRA_FAIL', signature:`${name}:${run.conclusion}:${steps.join('|') || 'no-step'}`};
  }
  const text = steps.join(' | ').toLowerCase();
  const infra = ['checkout', 'restore engine assets', 'install build tools', 'set up job', 'complete job'];
  const validation = ['upload', 'validate ipa', 'verify artifact', 'evidence'];
  if (infra.some(k => text.includes(k))) return {class:'INFRA_FAIL', signature:`${name}:${run.conclusion}:${steps.join('|') || 'infra'}`};
  if (validation.some(k => text.includes(k))) return {class:'VALIDATION_FAIL', signature:`${name}:${run.conclusion}:${steps.join('|') || 'validation'}`};
  const code = ['core regression tests', 'build ios', 'generate xcode project', 'run simulator engine e2e', 'final regression'];
  if (code.some(k => text.includes(k))) return {class:'CODE_FAIL', signature:`${name}:${run.conclusion}:${steps.join('|') || 'code'}`};
  return {class:'UNKNOWN', signature:`${name}:${run.conclusion}:${steps.join('|') || 'unknown'}`};
}

let previous = null;
if (previousPath && fs.existsSync(previousPath)) {
  try { previous = JSON.parse(fs.readFileSync(previousPath, 'utf8')); } catch {}
}

const observations = {};
const gates = [];
let failure = null;
const blockers = [];

for (const spec of expected) {
  const run = runs.get(spec.name);
  if (!run) {
    gates.push({id:spec.gate, status:'BLOCKED', evidence:[`No ${spec.name} main/push run found for ${targetSha} after ${pollSeconds}s grace.`]});
    observations[spec.name] = null;
    if (!failure) failure = {class:'BLOCKED', signature:`${spec.name}:missing`, methodKey:'ios-main-ci-set'};
    blockers.push({code:'IOS_EXPECTED_WORKFLOW_RUN_MISSING', summary:`${spec.name} did not produce a main/push run for ${targetSha}.`, requiresHuman:false});
    continue;
  }
  observations[spec.name] = {runId:run.id, status:run.status, conclusion:run.conclusion, url:run.html_url};
  if (run.status !== 'completed') {
    gates.push({id:spec.gate, status:'PENDING', evidence:[`run ${run.id} is ${run.status}`]});
    continue;
  }
  if (run.conclusion === 'success') {
    gates.push({id:spec.gate, status:'PASS', evidence:[`run ${run.id} success`, run.html_url]});
  } else {
    const steps = await failedSteps(run);
    const classified = classifyFailure(spec.name, run, steps);
    gates.push({id:spec.gate, status:'FAIL', evidence:[`run ${run.id} conclusion=${run.conclusion}`, ...steps.slice(0,5), run.html_url]});
    if (!failure) failure = {class:classified.class, signature:classified.signature.slice(0,500), methodKey:'ios-main-ci-set'};
  }
}

const allPass = gates.length === expected.length && gates.every(g => g.status === 'PASS');
let attempt = 0;
if (failure) {
  const sameCandidate = previous?.authority?.candidateSha === targetSha;
  const sameFailure = previous?.failure?.methodKey === failure.methodKey && previous?.failure?.signature === failure.signature;
  if (sameCandidate && sameFailure) attempt = Number(previous?.retry?.attempt || 1);
  else if (sameFailure) attempt = Math.min(2, Number(previous?.retry?.attempt || 0) + 1);
  else attempt = 1;
}

let status = allPass ? 'PASS' : (blockers.length ? 'BLOCKED' : 'FAIL');
if (failure && attempt >= 2) status = 'BLOCKED';

const baselineSha = allPass ? targetSha : (previous?.authority?.baselineSha || null);
const outcome = allPass ? 'PASS' : (status === 'BLOCKED' ? 'BLOCKED' : 'FAIL');

let nextAction = allPass
  ? 'Use this CI-set PASS as durable iOS authority and continue only from this main SHA or a new frozen candidate.'
  : 'Investigate the failed iOS CI gate; do not auto-rerun code or validation failures.';
if (status === 'BLOCKED' && attempt >= 2) {
  nextAction = 'Change method before another attempt; the same iOS CI method has failed twice.';
} else if (blockers.length) {
  nextAction = 'Restore the missing expected iOS workflow run or explicitly redesign the required gate set before proceeding.';
}

const recommendNewChat = status === 'BLOCKED' && (attempt >= 2 || blockers.length > 0);
const prompt = recommendNewChat ? [
  'PROJECT: shogi-ai-coach',
  'CURRENT AUTHORITY: control-plane/state/shogi-ai-coach.json',
  `CANDIDATE SHA: ${targetSha}`,
  `STATUS: ${status}`,
  `FAILURE: ${failure?.class || 'none'} / ${failure?.signature || 'none'}`,
  `BLOCKERS: ${blockers.map(b => b.code).join(',') || 'none'}`,
  `NEXT: ${nextAction}`,
  'DO NOT CHANGE: existing iOS Device Build, iOS Simulator E2E, and Build18-M Final Regression workflows until the blocker is understood.',
  'FIRST CHECK: exact GitHub Actions run set for the candidate SHA.'
].join('\n') : null;

const doc = {
  schemaVersion:'1.0',
  project:'shogi-ai-coach',
  adapter:'ios',
  phase:{id:'IOS-CI-GATE', name:'Hosted macOS/Xcode/Simulator CI gate'},
  status,
  authority:{
    baselineSha,
    candidateSha:targetSha,
    candidateFrozen:true,
    sourceRef:'refs/heads/main',
    lastRun:{
      provider:'other',
      runId:`ios-ci-set:${targetSha}`,
      jobId:null,
      commitSha:targetSha,
      outcome,
      url:`https://github.com/${repo}/commit/${targetSha}/checks`
    }
  },
  failure: failure ? {class:failure.class, signature:failure.signature, methodKey:failure.methodKey} : null,
  retry:{attempt, maxAttemptsSameMethod:2, policy:'MANUAL'},
  gates,
  blockers,
  next:{action:nextAction, requires: allPass ? [] : ['resolved required iOS CI gate set']},
  rollback:{
    sha:previous?.authority?.baselineSha || null,
    ref:'refs/heads/main',
    note:'Rollback authority points to the last recorded PASS baseline when available.'
  },
  handoff:{recommendedNewChat:recommendNewChat, prompt},
  extensions:{
    ios:{
      mode:'observe-only',
      platform:'github-hosted-macos',
      recoveryEnabled:false,
      controlPlaneSource:'inari-1234/Excel-Tests@b11e775d51d7cdff179184e2d7313fce18d77444',
      observedWorkflows:observations,
      missingWorkflowGraceSeconds:pollSeconds
    }
  },
  updatedAt:new Date().toISOString()
};

fs.mkdirSync(path.dirname(outPath), {recursive:true});
fs.writeFileSync(outPath, JSON.stringify(doc, null, 2) + '\n', 'utf8');
console.log(`IOS_CONTROL_PLANE_AUTHORITY_WRITTEN status=${status} sha=${targetSha} attempt=${attempt} path=${outPath}`);
