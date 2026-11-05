#!/usr/bin/env node
// Checks a pull request description against the template in .github/pull_request_template.md
// (Definition of Done in docs/WORKING-AGREEMENT.md). CI runs it with the description in PR_BODY.
// The template is the source of truth: its Definition of Done items and manual-test options
// must all be present in the description, so they cannot be replaced or deleted.

import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const DONE_SECTION = 'Definition of Done';
const MANUAL_TEST_SECTION = 'Manual test';
const CHECKBOX = /^\s*[-*]\s+\[([ xX])\]\s+(.*)$/;
const ISSUE_LINK = /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#\d+/i;

/**
 * Markdown that renders as checklists and closing keywords: without HTML comments (hidden) and
 * fenced code blocks (shown as code), with LF line endings.
 * @param {string} markdown
 */
export function visibleText(markdown) {
  const lines = markdown
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/\r\n/g, '\n')
    .split('\n');
  const visible = [];
  let fence;
  for (const line of lines) {
    const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line)?.[1];
    if (fence) {
      // A fence closes with the same character, at least as long as the opening one.
      if (marker?.[0] === fence[0] && marker.length >= fence.length) fence = undefined;
    } else if (marker) {
      fence = marker;
    } else {
      visible.push(line);
    }
  }
  return visible.join('\n');
}

/**
 * Collects the checkboxes under each level-2 heading of the visible text.
 * @param {string} markdown
 * @returns {Map<string, { checked: boolean, text: string }[]>}
 */
export function parseChecklists(markdown) {
  const sections = new Map();
  let current;
  for (const line of visibleText(markdown).split('\n')) {
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
 * Finds the description's checkbox for a template item. Authors may add text after an item,
 * for example what was checked after "Manually tested ...".
 * @param {{ text: string }[]} boxes
 * @param {{ text: string }} item
 */
function findBox(boxes, item) {
  return boxes.find((box) => box.text.startsWith(item.text));
}

/**
 * Returns the problems that block the merge; an empty list means the description is complete.
 * @param {string} body the pull request description
 * @param {string} template the pull request template
 * @returns {string[]}
 */
export function checkPullRequestBody(body, template) {
  const required = parseChecklists(template);
  const requiredDone = required.get(DONE_SECTION) ?? [];
  const manualOptions = required.get(MANUAL_TEST_SECTION) ?? [];
  if (requiredDone.length === 0 || manualOptions.length === 0) {
    throw new Error(
      `The template needs "${DONE_SECTION}" and "${MANUAL_TEST_SECTION}" checkboxes.`,
    );
  }

  const problems = [];
  const sections = parseChecklists(body);

  if (!ISSUE_LINK.test(visibleText(body))) {
    problems.push('Link the issue with "Closes #<number>".');
  }

  const done = sections.get(DONE_SECTION);
  if (!done) {
    problems.push(`The "${DONE_SECTION}" section from the template is missing.`);
  } else {
    for (const item of requiredDone) {
      const box = findBox(done, item);
      if (!box) problems.push(`Definition of Done item missing: ${item.text}`);
      else if (!box.checked) problems.push(`Definition of Done not ticked: ${item.text}`);
    }
  }

  const manual = sections.get(MANUAL_TEST_SECTION);
  if (!manual) {
    problems.push(`The "${MANUAL_TEST_SECTION}" section from the template is missing.`);
  } else {
    const boxes = manualOptions.map((option) => findBox(manual, option));
    manualOptions.forEach((option, index) => {
      if (!boxes[index]) problems.push(`Manual test option missing: ${option.text}`);
    });
    const ticked = boxes.filter((box) => box?.checked).length;
    if (ticked !== 1) {
      problems.push(
        `Tick exactly one box in "${MANUAL_TEST_SECTION}" (ticked: ${String(ticked)}).`,
      );
    }
  }

  return problems;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const template = readFileSync(
    new URL('../.github/pull_request_template.md', import.meta.url),
    'utf8',
  );
  const problems = checkPullRequestBody(process.env.PR_BODY ?? '', template);
  for (const problem of problems) console.log(`::error title=PR checklist::${problem}`);
  if (problems.length > 0) {
    process.exitCode = 1;
  } else {
    console.log('The pull request description meets the checklist.');
  }
}
