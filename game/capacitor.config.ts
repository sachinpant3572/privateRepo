import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.fateengine.game',
  appName: 'Fate Engine',
  webDir: 'dist',
  backgroundColor: '#02030a',
  android: { backgroundColor: '#02030a' },
  ios: { backgroundColor: '#02030a', contentInset: 'never' },
};

export default config;
