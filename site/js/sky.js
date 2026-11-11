// The sky's colour at any instant.
// The six states mirror SkyPalette.swift in IhsanDesignSystem; this file
// only decides which two to blend, and how far, from the day's solar events.

const STATES = {
  night:      { zenith: '#0A0E28', top: '#0E1330', bottom: '#141A3A', wash: '#232B5C', plane: '#0A0E26', ink: '#ECEEF5', ink2: '#A9AFC4', metal: '#C9A96A', gold: '#D2AC5C', glow: '#F0D18B', panel: '#191F46', lapis: '#39447F' },
  dawn:       { zenith: '#131A45', top: '#1B2456', bottom: '#2F3670', wash: '#6A5590', plane: '#12173C', ink: '#EDEFF6', ink2: '#B6BCD2', metal: '#C9A96A', gold: '#D2AC5C', glow: '#F3C77F', panel: '#232C63', lapis: '#3B4685' },
  firstLight: { zenith: '#6AC2FD', top: '#E9F6FF', bottom: '#DFF1FF', wash: '#F7DDAD', plane: '#EBDDB8', ink: '#1B2350', ink2: '#3E476B', metal: '#A07F45', gold: '#C9A048', glow: '#F0A93C', panel: '#FBFCFE', lapis: '#2A3780' },
  morning:    { zenith: '#84C2FD', top: '#EAF5FF', bottom: '#E2F1FF', wash: '#D6E8FB', plane: '#E8E0CB', ink: '#1B2350', ink2: '#3E476B', metal: '#A8895A', gold: '#C29B4C', glow: '#E7A93E', panel: '#FBFCFE', lapis: '#2A3780' },
  afternoon:  { zenith: '#9AC0FD', top: '#EDF4FF', bottom: '#E6F0FF', wash: '#F4EAD3', plane: '#E9DFC2', ink: '#231F3D', ink2: '#494365', metal: '#B8923F', gold: '#C79E45', glow: '#ECBB55', panel: '#FEFCF7', lapis: '#2C3579' },
  sunset:     { zenith: '#2C1128', top: '#3A1526', bottom: '#7A2233', wash: '#9A4430', plane: '#38101F', ink: '#F2E9E4', ink2: '#DCC0C7', metal: '#D4A94E', gold: '#DCAF54', glow: '#F6B96E', panel: '#4C1F30', lapis: '#333C74' },
};

// Ground colours travel smoothly. Figure colours (ink, metal, panels) are
// only legible against one polarity, so across a light/dark crossing they
// change together, once.
const GROUND = ['zenith', 'top', 'bottom', 'wash', 'plane', 'glow'];
const FIGURE = ['ink', 'ink2', 'metal', 'gold', 'panel', 'lapis'];
const CSS_NAME = {
  zenith: '--zenith', top: '--sky-top', bottom: '--sky-bottom', wash: '--wash', plane: '--plane',
  ink: '--ink', ink2: '--ink-2', metal: '--metal', gold: '--gold', glow: '--glow', panel: '--panel', lapis: '--lapis',
};

// ── OKLab, so the blends between states stay clean ──────────────────────
const toLin = c => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const toSrgb = c => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);
const hexToRgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255);
const rgbToLab = rgb => {
  const [r, g, b] = rgb.map(toLin);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
};
const labToHex = ([L, a, b]) => {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  const rgb = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
  return '#' + rgb.map(c => Math.round(Math.min(1, Math.max(0, toSrgb(c))) * 255).toString(16).padStart(2, '0')).join('');
};

const LAB = {};
for (const [name, state] of Object.entries(STATES)) {
  LAB[name] = Object.fromEntries(Object.entries(state).map(([k, v]) => [k, rgbToLab(hexToRgb(v))]));
}
const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
const isLight = lab => lab[0] > 0.62;

const MIN = 60000;

/** Keyframes for three consecutive days of solar events: [[ms, state], …]. */
export function skyKeys(days) {
  const keys = [];
  for (const d of days) {
    keys.push(
      [d.fajr - 45 * MIN, 'night'],
      [d.fajr, 'dawn'],
      [d.sunrise - 24 * MIN, 'dawn'],
      [d.sunrise + 10 * MIN, 'firstLight'],
      [d.sunrise + 0.45 * (d.dhuhr - d.sunrise), 'morning'],
      [d.dhuhr + 0.26 * (d.asr - d.dhuhr), 'afternoon'],
      [d.maghrib - 43 * MIN, 'afternoon'],
      [d.maghrib, 'sunset'],
      [d.maghrib + 0.37 * (d.isha - d.maghrib), 'sunset'],
      [Math.max(d.isha + 42 * MIN, d.maghrib + 70 * MIN), 'night'],
    );
  }
  // Extreme latitudes can fold events over one another; keep time moving forward.
  for (let i = 1; i < keys.length; i++) {
    if (keys[i][0] <= keys[i - 1][0]) keys[i][0] = keys[i - 1][0] + MIN;
  }
  return keys;
}

/** The blended palette at instant `ms`. Values are OKLab triples plus `stars` and `light`. */
export function paletteAt(keys, ms) {
  let i = 0;
  while (i < keys.length - 2 && ms >= keys[i + 1][0]) i++;
  const [m0, n0] = keys[i];
  const [m1, n1] = keys[i + 1];
  const t = Math.min(1, Math.max(0, (ms - m0) / (m1 - m0)));
  const a = LAB[n0], b = LAB[n1];
  const out = {};
  for (const k of GROUND) out[k] = mix(a[k], b[k], t);
  const crossing = isLight(a.top) !== isLight(b.top);
  const pole = isLight(out.top) === isLight(a.top) ? a : b;
  for (const k of FIGURE) out[k] = crossing ? pole[k] : mix(a[k], b[k], t);
  out.stars = Math.min(1, Math.max(0, (0.55 - out.top[0]) * 4));
  out.light = isLight(out.top);
  return out;
}

/** True when the sky changes polarity between two instants (used to keep the opening sweep calm). */
export function crossesPolarity(keys, from, to) {
  const a = paletteAt(keys, from).light;
  for (let ms = from; ms <= to; ms += 5 * MIN) if (paletteAt(keys, ms).light !== a) return true;
  return paletteAt(keys, to).light !== a;
}

/** A CSS gradient of the sky's colour across one civil day, for the scrubber's track. */
export function skyStrip(keys, start, span, stops = 48) {
  const parts = [];
  for (let i = 0; i <= stops; i++) {
    const p = paletteAt(keys, start + (span * i) / stops);
    parts.push(`${labToHex(mix(p.top, p.zenith, p.light ? 0.55 : 0))} ${((i / stops) * 100).toFixed(1)}%`);
  }
  return `linear-gradient(90deg, ${parts.join(', ')})`;
}

let lastTheme = '';
export function applyPalette(p, root = document.documentElement) {
  for (const k of [...GROUND, ...FIGURE]) root.style.setProperty(CSS_NAME[k], labToHex(p[k]));
  root.style.setProperty('--stars', p.stars.toFixed(3));
  root.dataset.sky = p.light ? 'light' : 'dark';
  const theme = labToHex(p.zenith);
  if (theme !== lastTheme) {
    lastTheme = theme;
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.content = theme;
  }
}
