// no-circular, together with cycle-a.ts
import { a } from './cycle-a';

export const b = (): string => `b${String(a.length)}`;
