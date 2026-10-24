// Run with: node --test tests/setupProgress.test.js
// The preparation of the environment stores its progress and a clear failure.
const test = require('node:test');
const assert = require('node:assert');

function stub(modulePath, exports) {
  const resolved = require.resolve(modulePath);
  require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports };
}

const store = { status: null, progress: null, statuses: [] };
let sshImpl;

stub('../src/utils/logger', { info() {}, warn() {}, error() {}, debug() {} });
stub('../src/services/remoteDesktopService', { restartVncSession: async () => {} });
stub('../src/services/metricService', { sendMetrics() {} });
stub('../src/services/sshService', { executeCommand: (command, onStdout) => sshImpl(command, onStdout) });
stub('../src/utils/redisClient', {
  persistExamStatus: async (id, status) => { store.status = status; store.statuses.push(status); },
  persistExamProgress: async (id, progress) => { store.progress = progress; },
});

const { setupExamEnvironment } = require('../src/services/jumphostService');
const line = (percent, state, step, message) => ['CKX-PROGRESS', percent, state, step, message].join('\t') + '\n';

test.beforeEach(() => { store.status = null; store.progress = null; store.statuses = []; });

test('a successful preparation stores the steps it reported and ends READY at 100%', async () => {
  sshImpl = async (command, onStdout) => {
    assert.strictEqual(command, 'prepare-exam-env 1 exam-1');
    onStdout(Buffer.from(line(8, 'run', 'cluster', 'Creating the Kubernetes cluster')));
    onStdout(Buffer.from(line(55, 'run', 'q1', 'Preparing question 1 (1 of 1)')));
    return { exitCode: 0, stdout: '', stderr: '' };
  };
  const result = await setupExamEnvironment('exam-1', 1);
  assert.strictEqual(result.success, true);
  assert.deepStrictEqual(store.statuses, ['PREPARING', 'READY']);
  assert.strictEqual(store.progress.percent, 100);
  assert.deepStrictEqual(store.progress.steps.map(s => s.id), ['desktop', 'cluster', 'q1', 'ready']);
  assert.strictEqual(store.progress.failure, null);
});

test('a step that failed is reported with its message and output, and the exam is PREPARATION_FAILED', async () => {
  sshImpl = async (command, onStdout) => {
    onStdout(Buffer.from(line(77, 'fail', 'q3', 'The setup of question 3 failed (exit code 7)') + 'CKX-OUTPUT\tError from server\n'));
    return { exitCode: 1, stdout: '', stderr: '' };
  };
  const result = await setupExamEnvironment('exam-1', 1);
  assert.strictEqual(result.success, false);
  assert.strictEqual(store.status, 'PREPARATION_FAILED');
  assert.deepStrictEqual(store.progress.failure, { step: 'q3', message: 'The setup of question 3 failed (exit code 7)', output: ['Error from server'] });
});

test('a failure the script did not report still says what happened', async () => {
  sshImpl = async () => ({ exitCode: 255, stdout: '', stderr: 'ssh: connection lost\n' });
  await setupExamEnvironment('exam-1', 1);
  assert.strictEqual(store.status, 'PREPARATION_FAILED');
  assert.match(store.progress.failure.message, /exit code 255/);
  assert.deepStrictEqual(store.progress.failure.output, ['ssh: connection lost']);

  sshImpl = async () => { throw new Error('connect ECONNREFUSED'); };
  await setupExamEnvironment('exam-1', 1);
  assert.match(store.progress.failure.message, /ECONNREFUSED/);
});
