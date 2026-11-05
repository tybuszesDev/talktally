import { describe, expect, it } from 'vitest';

import { productName, productTagline } from './index';

describe('product', () => {
  it('exposes the product name and tagline through the package entry point', () => {
    expect(productName).toBe('TalkTally');
    expect(productTagline).toBe('You talk, it tallies.');
  });
});
