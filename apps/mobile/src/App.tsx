import { productName, productTagline } from '@talktally/domain';
import { StyleSheet, Text, View } from 'react-native';

// Placeholder screen until the iOS shell with sign-in arrives (F-24).
export function App() {
  return (
    <View style={styles.screen}>
      <Text style={styles.title}>{productName}</Text>
      <Text style={styles.subtitle}>{productTagline}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, justifyContent: 'center', padding: 32, backgroundColor: '#FFFFFF' },
  title: { fontSize: 32, fontWeight: '600', color: '#0A0A0A' },
  subtitle: { marginTop: 8, fontSize: 16, color: '#6B6B6B' },
});
