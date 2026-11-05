#!/usr/bin/env node
// Checks a pull request description against the template in .github/pull_request_template.md
// (Definition of Done in docs/WORKING-AGREEMENT.md). CI runs it with the description in PR_BODY.

import { pathToFileURL } from 'node:url';

const DONE_SECTION = 'Definition of Done';
const MANUAL_TEST_SECTION = 'Manual test';
const CHECKBOX = /^\s*[-*]\s+\[([ xX])\]\s+(.*)$/;
const ISSUE_LINK = /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#\d+/i;

/**
 * Collects the checkboxes under each level-2 heading. HTML comments are ignored.
 * @param {string} body
 * @returns {Map<string, { checked: boolean, text: string }[]>}
 */
export function parseChecklists(body) {
  const sections = new Map();
  let current;
  const visible = body.replace(/<!--[\s\S]*?-->/g, '').replace(/\r\n/g, '\n');
  for (const line of visible.split('\n')) {
    const heading = /^##\s+(.+?)\s*$/.exec(line);
    if (heading) {
      current = heading[1];
      sections.set(current, []);
      continue;
    }
    const box = CHECKBOX.exec(line);
    if (box && current !== undefined) {
      sections.get(current).push({ checked: box[1] !== ' ', text: box[2].trim() });
    }
  }
  return sections;
}

/**
 * Returns the problems that block the merge; an empty list means the description is complete.
 * @param {string} body
 * @returns {string[]}
 */
export function checkPullRequestBody(body) {
  const problems = [];
  const sections = parseChecklists(body);

  if (!ISSUE_LINK.test(body)) {
    problems.push('Link the issue with "Closes #<number>".');
  }

  const done = sections.get(DONE_SECTION);
  if (!done?.length) {
    problems.push(`The "${DONE_SECTION}" section from the template is missing.`);
  } else {
    for (const item of done.filter((box) => !box.checked)) {
      problems.push(`Definition of Done not ticked: ${item.text}`);
    }
  }

  const manual = sections.get(MANUAL_TEST_SECTION);
  if (!manual?.length) {
    problems.push(`The "${MANUAL_TEST_SECTION}" section from the template is missing.`);
  } else {
    const ticked = manual.filter((box) => box.checked).length;
    if (ticked !== 1) {
      problems.push(
        `Tick exactly one box in "${MANUAL_TEST_SECTION}" (ticked: ${String(ticked)}).`,
      );
    }
  }

  return problems;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const problems = checkPullRequestBody(process.env.PR_BODY ?? '');
  for (const problem of problems) console.log(`::error title=PR checklist::${problem}`);
  if (problems.length > 0) {
    process.exitCode = 1;
  } else {
    console.log('The pull request description meets the checklist.');
  }
}
