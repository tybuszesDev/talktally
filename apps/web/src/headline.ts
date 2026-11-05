import { productName, productTagline } from '@talktally/domain';

export function headline(): { title: string; subtitle: string } {
  return { title: productName, subtitle: productTagline };
}
