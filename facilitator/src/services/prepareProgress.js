/**
 * Progress of the exam environment preparation.
 *
 * prepare-exam-env (jumphost) writes one line per event to the SSH channel:
 *   CKX-PROGRESS<TAB><percent><TAB><run|ok|fail><TAB><step id><TAB><message>
 *   CKX-OUTPUT<TAB><line>      (the last lines of the output of the step that failed, right after its "fail")
 * Everything else the script prints goes to the container log and is ignored here.
 */

const PROGRESS_PREFIX = 'CKX-PROGRESS';
const OUTPUT_PREFIX = 'CKX-OUTPUT';
const MAX_OUTPUT_LINES = 30;

/**
 * Parse one line written by prepare-exam-env.
 * @param {string} line - a line of the SSH stdout, without the line break
 * @returns {Object|null} {type: 'progress', percent, state, step, message} or {type: 'output', text}; null for any other line
 */
function parseLine(line) {
  const parts = line.replace(/\r$/, '').split('\t');
  if (parts[0] === PROGRESS_PREFIX && parts.length >= 5) {
    const percent = Number(parts[1]);
    if (!Number.isFinite(percent) || !['run', 'ok', 'fail'].includes(parts[2])) return null;
    return { type: 'progress', percent: Math.max(0, Math.min(100, percent)), state: parts[2], step: parts[3], message: parts.slice(4).join('\t') };
  }
  if (parts[0] === OUTPUT_PREFIX) {
    return { type: 'output', text: parts.slice(1).join('\t') };
  }
  return null;
}

/**
 * Accumulates the events of one preparation.
 * @returns {{push: Function, event: Function, fail: Function, snapshot: Function}}
 */
function createTracker() {
  let buffer = '';
  let percent = 0;
  let message = '';
  let failure = null;
  const steps = [];

  function apply(event) {
    if (event.type === 'output') {
      if (failure && failure.output.length < MAX_OUTPUT_LINES) failure.output.push(event.text);
      return;
    }
    percent = Math.max(percent, event.percent);
    message = event.message;
    const known = steps.find(step => step.id === event.step);
    if (known) {
      known.message = event.message;
      known.state = event.state;
    } else {
      steps.push({ id: event.step, message: event.message, state: event.state });
    }
    if (event.state === 'fail') {
      failure = { step: event.step, message: event.message, output: [] };
    }
  }

  return {
    /**
     * Feed a chunk of the SSH stdout (lines may be split across chunks).
     * @param {string|Buffer} chunk
     * @returns {boolean} true when the chunk changed the progress
     */
    push(chunk) {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop();
      let changed = false;
      for (const line of lines) {
        const event = parseLine(line);
        if (event) {
          apply(event);
          changed = true;
        }
      }
      return changed;
    },

    /** Record an event of the facilitator itself (steps it runs before the script). */
    event(eventPercent, state, step, eventMessage) {
      apply({ type: 'progress', percent: eventPercent, state, step, message: eventMessage });
    },

    /**
     * Record a failure that the script did not report (SSH error, crash, non-zero exit without a "fail" event).
     * Keeps the failure the script reported when there is one.
     */
    fail(failureMessage, output = []) {
      if (failure) return;
      message = failureMessage;
      failure = { step: 'preparation', message: failureMessage, output: output.slice(-MAX_OUTPUT_LINES) };
      steps.push({ id: 'preparation', message: failureMessage, state: 'fail' });
    },

    snapshot() {
      return { percent, message, steps: steps.map(step => ({ ...step })), failure: failure && { ...failure, output: [...failure.output] } };
    },
  };
}

module.exports = { parseLine, createTracker };
