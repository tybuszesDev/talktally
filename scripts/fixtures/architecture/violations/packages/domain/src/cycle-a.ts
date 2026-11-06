// no-circular, together with cycle-b.ts
import { b } from './cycle-b';

export const a = (): string => `a${b()}`;
