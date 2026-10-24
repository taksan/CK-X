// Run with: node --test tests/prepareProgress.test.js
const test = require('node:test');
const assert = require('node:assert');
const { parseLine, createTracker } = require('../src/services/prepareProgress');

const line = (percent, state, step, message) => ['CKX-PROGRESS', percent, state, step, message].join('\t') + '\n';

test('parses progress and output lines, ignores everything else', () => {
  assert.deepStrictEqual(parseLine(line(40, 'run', 'cluster', 'Creating the cluster').trimEnd()),
    { type: 'progress', percent: 40, state: 'run', step: 'cluster', message: 'Creating the cluster' });
  assert.deepStrictEqual(parseLine('CKX-OUTPUT\terror: boom'), { type: 'output', text: 'error: boom' });
  assert.strictEqual(parseLine('[2026-10-24 10:00:00] some log line'), null);
  assert.strictEqual(parseLine('CKX-PROGRESS\tabc\trun\tx\tbad percent'), null);
  assert.strictEqual(parseLine('CKX-PROGRESS\t10\tweird\tx\tbad state'), null);
});

test('the percentage never goes back and the steps are updated in place', () => {
  const tracker = createTracker();
  tracker.push(line(10, 'run', 'cluster', 'Creating the cluster'));
  tracker.push(line(40, 'ok', 'cluster', 'Cluster created'));
  tracker.push(line(5, 'run', 'q1', 'Preparing question 1 of 2'));
  const snapshot = tracker.snapshot();
  assert.strictEqual(snapshot.percent, 40);
  assert.deepStrictEqual(snapshot.steps.map(s => [s.id, s.state]), [['cluster', 'ok'], ['q1', 'run']]);
  assert.strictEqual(snapshot.message, 'Preparing question 1 of 2');
  assert.strictEqual(snapshot.failure, null);
});

test('lines split across chunks are put back together', () => {
  const tracker = createTracker();
  const text = line(55, 'run', 'q1', 'Preparing question 1 of 3');
  assert.strictEqual(tracker.push(text.slice(0, 12)), false);
  assert.strictEqual(tracker.push(text.slice(12)), true);
  assert.strictEqual(tracker.snapshot().percent, 55);
});

test('a failed step keeps its message and the output lines that follow', () => {
  const tracker = createTracker();
  tracker.push(line(60, 'run', 'q3', 'Preparing question 3 of 5'));
  tracker.push(line(60, 'fail', 'q3', 'Question 3 setup failed (exit code 1)') + 'CKX-OUTPUT\tError from server\nCKX-OUTPUT\tNotFound\n');
  const { failure, steps } = tracker.snapshot();
  assert.deepStrictEqual(failure, { step: 'q3', message: 'Question 3 setup failed (exit code 1)', output: ['Error from server', 'NotFound'] });
  assert.strictEqual(steps[0].state, 'fail');
});

test('fail() records a failure the script did not report, and keeps the one it reported', () => {
  const unreported = createTracker();
  unreported.event(1, 'run', 'desktop', 'Restarting the remote desktop');
  unreported.fail('Could not reach the jumphost', ['connect ECONNREFUSED']);
  assert.strictEqual(unreported.snapshot().failure.message, 'Could not reach the jumphost');
  assert.strictEqual(unreported.snapshot().message, 'Could not reach the jumphost');

  const reported = createTracker();
  reported.push(line(40, 'fail', 'cluster', 'Cluster creation failed'));
  reported.fail('exit code 1');
  assert.strictEqual(reported.snapshot().failure.message, 'Cluster creation failed');
});
