import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';

import { checkPullRequestBody, parseChecklists } from './check-pr-checklist.mjs';

const template = readFileSync(
  new URL('../.github/pull_request_template.md', import.meta.url),
  'utf8',
);

/** The template as an author fills it in: issue linked, every Definition of Done box ticked. */
function completeBody({ manual = [true, false] } = {}) {
  let manualIndex = 0;
  let section = '';
  return template
    .replace('Closes #', 'Closes #4')
    .split('\n')
    .map((line) => {
      if (line.startsWith('## ')) section = line.slice(3);
      if (!line.startsWith('- [ ]')) return line;
      if (section === 'Definition of Done') return line.replace('[ ]', '[x]');
      if (section === 'Manual test')
        return manual[manualIndex++] ? line.replace('[ ]', '[x]') : line;
      return line;
    })
    .join('\n');
}

const check = (body) => checkPullRequestBody(body, template);

describe('checkPullRequestBody', () => {
  it('accepts a completed template', () => {
    assert.deepEqual(check(completeBody()), []);
  });

  it('rejects the untouched template', () => {
    const problems = check(template);
    assert.ok(problems.includes('Link the issue with "Closes #<number>".'));
    assert.ok(problems.some((problem) => problem.startsWith('Definition of Done not ticked')));
    assert.ok(problems.includes('Tick exactly one box in "Manual test" (ticked: 0).'));
  });

  it('names each unticked Definition of Done box', () => {
    const body = completeBody().replace(
      '- [x] Every acceptance criterion',
      '- [ ] Every acceptance criterion',
    );
    assert.deepEqual(check(body), [
      'Definition of Done not ticked: Every acceptance criterion in the issue is met and checked',
    ]);
  });

  it('rejects a Definition of Done list replaced by other items', () => {
    const body = completeBody().replace(
      /## Definition of Done[\s\S]*?## Manual test/,
      '## Definition of Done\n\n- [x] done\n\n## Manual test',
    );
    const problems = check(body);
    assert.equal(problems.length, 6);
    assert.ok(problems.every((problem) => problem.startsWith('Definition of Done item missing')));
  });

  it('accepts notes added after an item', () => {
    const body = completeBody().replace('What was checked:', 'What was checked: the CI run');
    assert.deepEqual(check(body), []);
  });

  it('rejects two ticked manual test boxes', () => {
    assert.deepEqual(check(completeBody({ manual: [true, true] })), [
      'Tick exactly one box in "Manual test" (ticked: 2).',
    ]);
  });

  it('accepts the second manual test box alone', () => {
    assert.deepEqual(check(completeBody({ manual: [false, true] })), []);
  });

  it('reports a deleted manual test option', () => {
    const body = completeBody().replace(/^- \[ \] No user-visible change.*$/m, '');
    assert.deepEqual(check(body), [
      'Manual test option missing: No user-visible change; verified by CI (and smoke tests on `dev` from M1)',
    ]);
  });

  it('does not require the optional area checks', () => {
    const body = completeBody();
    assert.ok(body.includes('- [ ] UI:'));
    assert.deepEqual(check(body), []);
  });

  it('reports missing template sections', () => {
    assert.deepEqual(check('Closes #4\n\nJust a summary.'), [
      'The "Definition of Done" section from the template is missing.',
      'The "Manual test" section from the template is missing.',
    ]);
  });

  it('accepts Fixes and Resolves as issue links', () => {
    for (const keyword of ['Fixes', 'resolves']) {
      const body = completeBody().replace('Closes #4', `${keyword} #4`);
      assert.deepEqual(check(body), []);
    }
  });

  it('ignores an issue link hidden in an HTML comment', () => {
    const body = completeBody().replace('Closes #4', '<!-- Closes #4 -->');
    assert.deepEqual(check(body), ['Link the issue with "Closes #<number>".']);
  });

  it('fails loudly when the template has no checklist', () => {
    assert.throws(() => checkPullRequestBody('Closes #4', '## Summary'), /needs/);
  });
});

describe('parseChecklists', () => {
  it('ignores checkboxes inside HTML comments', () => {
    const sections = parseChecklists('## Manual test\n<!--\n- [x] hidden\n-->\n- [ ] visible\n');
    assert.deepEqual(sections.get('Manual test'), [{ checked: false, text: 'visible' }]);
  });

  it('reads an uppercase X and Windows line endings', () => {
    const sections = parseChecklists('## Definition of Done\r\n- [X] done\r\n* [ ] open\r\n');
    assert.deepEqual(sections.get('Definition of Done'), [
      { checked: true, text: 'done' },
      { checked: false, text: 'open' },
    ]);
  });
});
