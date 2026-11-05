import { headline } from './headline';

// Placeholder screen until the web shell with sign-in arrives (F-23).
export function App() {
  const { title, subtitle } = headline();
  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: 32, color: '#0A0A0A' }}>
      <h1 style={{ fontWeight: 600, margin: 0 }}>{title}</h1>
      <p style={{ color: '#6B6B6B' }}>{subtitle}</p>
    </main>
  );
}
