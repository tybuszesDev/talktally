import { describe, expect, it } from 'vitest';

import { headline } from './headline';

describe('headline', () => {
  it('uses the product name from the shared domain package', () => {
    expect(headline()).toEqual({ title: 'TalkTally', subtitle: 'You talk, it tallies.' });
  });
});
