// Ihsan landing page — the sky follows the clock.
// No dependencies, no network. Palette values mirror SkyPalette.swift.

(() => {
  'use strict';
  const root = document.documentElement;
  root.classList.add('js');

  // ── The six palette states ────────────────────────────────────────────
  const STATES = {
    night:      { zenith: '#0A0E28', top: '#0E1330', bottom: '#141A3A', wash: '#232B5C', plane: '#0A0E26', ink: '#ECEEF5', ink2: '#A9AFC4', metal: '#C9A96A', gold: '#D2AC5C', glow: '#F0D18B', panel: '#191F46', lapis: '#39447F' },
    dawn:       { zenith: '#131A45', top: '#1B2456', bottom: '#2F3670', wash: '#6A5590', plane: '#12173C', ink: '#EDEFF6', ink2: '#B6BCD2', metal: '#C9A96A', gold: '#D2AC5C', glow: '#F3C77F', panel: '#232C63', lapis: '#3B4685' },
    firstLight: { zenith: '#6AC2FD', top: '#E9F6FF', bottom: '#DFF1FF', wash: '#F7DDAD', plane: '#EBDDB8', ink: '#1B2350', ink2: '#3E476B', metal: '#A07F45', gold: '#C9A048', glow: '#F0A93C', panel: '#FBFCFE', lapis: '#2A3780' },
    morning:    { zenith: '#84C2FD', top: '#EAF5FF', bottom: '#E2F1FF', wash: '#D6E8FB', plane: '#E8E0CB', ink: '#1B2350', ink2: '#3E476B', metal: '#A8895A', gold: '#C29B4C', glow: '#E7A93E', panel: '#FBFCFE', lapis: '#2A3780' },
    afternoon:  { zenith: '#9AC0FD', top: '#EDF4FF', bottom: '#E6F0FF', wash: '#F4EAD3', plane: '#E9DFC2', ink: '#231F3D', ink2: '#494365', metal: '#B8923F', gold: '#C79E45', glow: '#ECBB55', panel: '#FEFCF7', lapis: '#2C3579' },
    sunset:     { zenith: '#2C1128', top: '#3A1526', bottom: '#7A2233', wash: '#9A4430', plane: '#38101F', ink: '#F2E9E4', ink2: '#DCC0C7', metal: '#D4A94E', gold: '#DCAF54', glow: '#F6B96E', panel: '#4C1F30', lapis: '#333C74' },
  };
  const GROUND = ['zenith', 'top', 'bottom', 'wash', 'plane', 'glow'];
  const FIGURE = ['ink', 'ink2', 'metal', 'gold', 'panel', 'lapis'];
  const CSS_NAME = { zenith: '--zenith', top: '--sky-top', bottom: '--sky-bottom', wash: '--wash', plane: '--plane', ink: '--ink', ink2: '--ink-2', metal: '--metal', gold: '--gold', glow: '--glow', panel: '--panel', lapis: '--lapis' };

  // The sample day: 30 July in Chicago, the day the screenshots were taken.
  const T = { fajr: 250, sunrise: 342, dhuhr: 778, asr: 1013, maghrib: 1211, isha: 1303 };

  // Minutes after midnight → palette state. The two polarity crossings
  // (dawn → first light, afternoon → sunset) are kept short, as in the app.
  const SKY = [
    [0, 'night'], [205, 'night'], [T.fajr, 'dawn'], [318, 'dawn'], [352, 'firstLight'],
    [540, 'morning'], [840, 'afternoon'], [1168, 'afternoon'], [T.maghrib, 'sunset'],
    [1245, 'sunset'], [1345, 'night'], [1440, 'night'],
  ];

  // ── Colour: mix in OKLab so mid-tones stay clean ──────────────────────
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

  function palette(minute) {
    let i = 0;
    while (i < SKY.length - 2 && minute >= SKY[i + 1][0]) i++;
    const [m0, n0] = SKY[i];
    const [m1, n1] = SKY[i + 1];
    const t = Math.min(1, Math.max(0, (minute - m0) / (m1 - m0)));
    const a = LAB[n0], b = LAB[n1];
    const out = {};
    for (const k of GROUND) out[k] = mix(a[k], b[k], t);
    // Across a light/dark crossing the figure colours change together, once:
    // whichever pole reads against the sky as it is right now.
    const crossing = isLight(a.top) !== isLight(b.top);
    const pole = isLight(out.top) === isLight(a.top) ? a : b;
    for (const k of FIGURE) out[k] = crossing ? pole[k] : mix(a[k], b[k], t);
    out.stars = Math.min(1, Math.max(0, (0.55 - out.top[0]) * 4));
    return out;
  }

  // ── Geometry: where the sun and moon sit at a given minute ────────────
  const ARC = { cx: 330, cy: 372, r: 280, from: 170, to: 6 };
  const ANGLES = [[T.fajr, 170], [T.dhuhr, 90], [T.asr, 52], [T.maghrib, 22], [T.isha, 6]];
  const lerpKeys = (keys, x) => {
    if (x <= keys[0][0]) return keys[0][1];
    for (let i = 0; i < keys.length - 1; i++) {
      const [x0, y0] = keys[i], [x1, y1] = keys[i + 1];
      if (x <= x1) return y0 + ((x - x0) / (x1 - x0)) * (y1 - y0);
    }
    return keys[keys.length - 1][1];
  };
  const polar = (deg, r) => {
    const rad = (deg * Math.PI) / 180;
    return [ARC.cx + r * Math.cos(rad), ARC.cy - r * Math.sin(rad)];
  };

  // ── The readout ───────────────────────────────────────────────────────
  const NAMES = {
    fajr: ['Fajr', 'الفجر'], dhuhr: ['Dhuhr', 'الظهر'], asr: ['Asr', 'العصر'],
    maghrib: ['Maghrib', 'المغرب'], isha: ['Isha', 'العشاء'],
  };
  const clock = m => {
    const h = Math.floor(m / 60) % 24, mm = String(m % 60).padStart(2, '0');
    return `${h % 12 || 12}:${mm} ${h < 12 ? 'AM' : 'PM'}`;
  };
  function moment(minute) {
    if (minute >= T.isha || minute < T.fajr) return { now: 'isha', line: `Now. Fajr is at ${clock(T.fajr)}.` };
    if (minute < T.sunrise) return { now: 'fajr', line: `Now, until sunrise at ${clock(T.sunrise)}.` };
    if (minute < T.dhuhr) return { now: null, next: 'dhuhr', line: `Next, at ${clock(T.dhuhr)}.` };
    if (minute < T.asr) return { now: 'dhuhr', line: `Now, until ${clock(T.asr)}.` };
    if (minute < T.maghrib) return { now: 'asr', line: `Now, until ${clock(T.maghrib)}.` };
    return { now: 'maghrib', line: `Now, until ${clock(T.isha)}.` };
  }

  // ── Wiring ────────────────────────────────────────────────────────────
  const $ = id => document.getElementById(id);
  const slider = $('clock'), orb = $('orb'), travelled = $('travelled');
  const rName = $('r-name'), rAr = $('r-ar'), rLine = $('r-line');
  const prayers = [...document.querySelectorAll('.prayer')];
  const themeMeta = document.querySelector('meta[name="theme-color"]');

  function render(minute) {
    const p = palette(minute);
    for (const k of [...GROUND, ...FIGURE]) root.style.setProperty(CSS_NAME[k], labToHex(p[k]));
    root.style.setProperty('--stars', p.stars.toFixed(2));
    if (themeMeta) themeMeta.content = labToHex(p.zenith);

    // Sun rides the day's arc from sunrise to Maghrib; the moon crosses back underneath.
    const day = minute >= T.sunrise && minute < T.maghrib;
    let x, y;
    if (day) {
      [x, y] = polar(lerpKeys(ANGLES, minute), ARC.r - 66);
    } else {
      const night = 1440 - T.maghrib + T.sunrise;
      const since = minute >= T.maghrib ? minute - T.maghrib : minute + 1440 - T.maghrib;
      [x, y] = polar(20 + (since / night) * 140, 150);
    }
    orb.setAttribute('transform', `translate(${x.toFixed(1)} ${y.toFixed(1)})`);
    orb.dataset.body = day ? 'sun' : 'moon';

    // The gold line is the part of the day already walked.
    const walked = minute < T.fajr ? 0 : ARC.from - lerpKeys(ANGLES, minute);
    travelled.style.strokeDasharray = `${walked.toFixed(2)} 400`;
    travelled.style.visibility = walked > 0.5 ? 'visible' : 'hidden';

    const m = moment(minute);
    const shown = m.now || m.next;
    for (const g of prayers) g.classList.toggle('is-now', g.dataset.prayer === m.now);
    rName.textContent = NAMES[shown][0];
    rAr.textContent = NAMES[shown][1];
    rLine.textContent = `${clock(minute)}. ${m.line}`;
    slider.setAttribute('aria-valuetext', `${clock(minute)}. ${NAMES[shown][0]}. ${m.line}`);
  }

  // ── Stars: one element, many shadows, the same sky on every visit ─────
  function stars() {
    const el = document.querySelector('.stars');
    if (!el) return;
    let seed = 1448;
    const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
    const w = Math.max(window.innerWidth, 320), h = Math.max(window.innerHeight, 480);
    const n = Math.round((w * h) / 14000);
    const dots = [];
    for (let i = 0; i < n; i++) {
      const big = rnd() > 0.86;
      dots.push(`${Math.round(rnd() * w)}px ${Math.round(rnd() ** 1.5 * h)}px 0 ${big ? 0.6 : 0}px rgba(236,238,245,${(0.18 + rnd() * 0.5).toFixed(2)})`);
    }
    el.style.boxShadow = dots.join(',');
  }

  const now = new Date();
  slider.value = String(Math.round((now.getHours() * 60 + now.getMinutes()) / 5) * 5);
  slider.addEventListener('input', () => render(Number(slider.value)));
  render(Number(slider.value));
  stars();
  let resizeTimer;
  window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(stars, 150); });
})();
