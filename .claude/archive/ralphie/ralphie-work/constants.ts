
import { VariantType, DesignVariant, WatchSize } from './types';

export const VARIANTS: DesignVariant[] = [
  {
    id: VariantType.TERMINAL,
    name: "Terminal Classic",
    concept: "The core identity—a minimalist square block representing a prompt.",
    accentColor: "#D97757",
    canvasColor: "#1A1A1A"
  },
  {
    id: VariantType.MASCOT,
    name: "Watch Mascot",
    concept: "Terminal character as a wearable device with Digital Crown ears.",
    accentColor: "#D97757",
    canvasColor: "#1A1A1A"
  },
  {
    id: VariantType.ABSTRACT,
    name: "Abstract Node",
    concept: "Stylized geometric interpretation of connection and data flow.",
    accentColor: "#D97757",
    canvasColor: "#1A1A1A"
  }
];

export const WATCH_SIZES: WatchSize[] = [
  { size: 1024, label: "1024px", usage: "App Store", shape: 'squircle' },
  { size: 216, label: "216px", usage: "Short Look (Ultra)", shape: 'squircle' },
  { size: 100, label: "100px", usage: "Home Screen (Ultra)", shape: 'circle' },
  { size: 55, label: "55px", usage: "Notification (42mm)", shape: 'circle' }
];

export const TOKENS = {
  COLORS: {
    BRAND: { ORANGE: "#FF9500", LIGHT: "#FFB340", DARK: "#CC7700" },
    SEMANTIC: { SUCCESS: "#34C759", DANGER: "#FF3B30", WARNING: "#FF9500", INFO: "#007AFF" },
    SURFACE: { BG: "#000000", S1: "#1C1C1E", S2: "#2C2C2E", S3: "#3A3A3C" }
  },
  SPACING: { XS: 4, SM: 8, MD: 12, LG: 16, XL: 24 },
  RADIUS: { SM: 8, MD: 12, LG: 16, XL: 20, FULL: 999 }
};

export const APP_VERSION = "v2026.1.0";
