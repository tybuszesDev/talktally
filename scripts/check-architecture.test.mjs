// Proves that every rule in dependency-cruiser.config.js catches a violation (ADR-0017), using
// small repository-shaped trees in scripts/fixtures/architecture/.

import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';

import { cruise } from 'dependency-cruiser';

import config from '../dependency-cruiser.config.js';

/**
 * Runs the repository rules on one fixture tree.
 * @param {string} fixture folder name in scripts/fixtures/architecture/
 * @returns {Promise<{ modules: number, found: { rule: string, from: string, to: string }[] }>}
 */
async function cruiseFixture(fixture) {
  const baseDir = fileURLToPath(new URL(`fixtures/architecture/${fixture}/`, import.meta.url));
  const result = await cruise(
    ['.'],
    // validate: without it the API collects dependencies but checks no rules.
    { ...config.options, baseDir, validate: true, ruleSet: { forbidden: config.forbidden } },
    config.options?.enhancedResolveOptions,
  );
  if (typeof result.output === 'string') throw new Error('Expected the JSON result');
  return {
    modules: result.output.modules.length,
    found: result.output.summary.violations.map((violation) => ({
      rule: violation.rule.name,
      from: violation.from,
      to: violation.to,
    })),
  };
}

const ruleNames = config.forbidden?.map((rule) => rule.name).sort() ?? [];

describe('architecture rules', () => {
  it('accept code that follows them', async () => {
    const { modules, found } = await cruiseFixture('clean');

    assert.ok(modules > 0, 'the fixture was not cruised');
    assert.deepEqual(found, []);
  });

  it('each catch their violation in the fixture', async () => {
    const { found } = await cruiseFixture('violations');

    const broken = [...new Set(found.map((violation) => violation.rule))].sort();
    assert.deepEqual(broken, ruleNames);
  });

  it('report a platform module imported by the domain package', async () => {
    const { found } = await cruiseFixture('violations');

    assert.ok(
      found.some(
        (violation) =>
          violation.rule === 'platform-neutral-packages' &&
          violation.from === 'packages/domain/src/platform.ts' &&
          violation.to === 'react-native',
      ),
      JSON.stringify(found, null, 2),
    );
  });
});
