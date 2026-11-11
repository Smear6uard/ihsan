// A city's day: its civil date, its five prayers, and what is "now" at any instant.
// Prayer times come from adhan-js, the JavaScript sibling of the Adhan-Swift
// library the app itself uses. Everything is computed in this tab.

import { Coordinates, CalculationMethod, PrayerTimes, SunnahTimes, HighLatitudeRule, Qibla } from '../vendor/adhan.esm.min.js';
import { methodFor } from './cities.js';

export const PRAYERS = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
export const NAMES = {
  fajr: ['Fajr', 'الفجر'], dhuhr: ['Dhuhr', 'الظهر'], asr: ['Asr', 'العصر'],
  maghrib: ['Maghrib', 'المغرب'], isha: ['Isha', 'العشاء'],
};
export const MIN = 60000;
export const DAY = 86400000;

// ── Time zones, with nothing but Intl ───────────────────────────────────
const partsCache = new Map();
function zoneParts(tz, ms) {
  let fmt = partsCache.get(tz);
  if (!fmt) {
    fmt = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, hourCycle: 'h23',
      year: 'numeric', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric',
    });
    partsCache.set(tz, fmt);
  }
  const out = {};
  for (const p of fmt.formatToParts(ms)) if (p.type !== 'literal') out[p.type] = Number(p.value);
  return out;
}
function offsetMs(tz, ms) {
  const p = zoneParts(tz, ms);
  return Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second) - Math.floor(ms / 1000) * 1000;
}
function dayStartMs(tz, y, m, d) {
  const guess = Date.UTC(y, m - 1, d);
  const first = guess - offsetMs(tz, guess);
  return guess - offsetMs(tz, first);
}

// 12- or 24-hour, whichever the visitor's own locale prefers.
let hour12 = true;
try { hour12 = !/^h2[34]$/.test(new Intl.DateTimeFormat(undefined, { hour: 'numeric' }).resolvedOptions().hourCycle || 'h12'); } catch { /* 12-hour */ }

const clockCache = new Map();
export function clock(tz, ms) {
  let fmt = clockCache.get(tz);
  if (!fmt) {
    fmt = new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', minute: '2-digit', hour12 });
    clockCache.set(tz, fmt);
  }
  return fmt.format(ms).replace(/ /g, ' ');
}

export function longDate(tz, ms) {
  return new Intl.DateTimeFormat('en-GB', { timeZone: tz, weekday: 'long', day: 'numeric', month: 'long' }).format(ms);
}
export function shortDate(tz, ms) {
  return new Intl.DateTimeFormat('en-US', { timeZone: tz, month: 'short', day: 'numeric' }).format(ms);
}
export function weekdayDate(tz, ms) {
  return new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long', month: 'short', day: 'numeric' }).format(ms);
}
export function hijriDate(tz, ms) {
  try {
    const parts = new Intl.DateTimeFormat('en-u-ca-islamic-umalqura', { timeZone: tz, day: 'numeric', month: 'long', year: 'numeric' }).formatToParts(ms);
    const get = t => (parts.find(p => p.type === t) || {}).value;
    if (!get('day') || !get('month') || !get('year')) return '';
    return `${get('day')} ${get('month')} ${get('year')} AH`;
  } catch { return ''; }
}

// ── The day itself ──────────────────────────────────────────────────────
function paramsFor(city) {
  const key = methodFor(city.cc);
  const params = CalculationMethod[key]();
  const coords = new Coordinates(city.lat, city.lon);
  params.highLatitudeRule = HighLatitudeRule.recommended(coords);
  return { key, params, coords };
}

function cycle(coords, params, y, m, d) {
  // adhan reads only the calendar fields of the date it is handed.
  const pt = new PrayerTimes(coords, new Date(y, m - 1, d, 12), params);
  const sunnah = new SunnahTimes(pt);
  const out = {
    fajr: +pt.fajr, sunrise: +pt.sunrise, dhuhr: +pt.dhuhr, asr: +pt.asr, maghrib: +pt.maghrib, isha: +pt.isha,
    middle: +sunnah.middleOfTheNight, lastThird: +sunnah.lastThirdOfTheNight,
  };
  for (const v of Object.values(out)) if (!Number.isFinite(v)) return null;
  return out;
}

/**
 * Everything the page needs for the civil day that contains `ms` in `city`.
 * `cycles` holds yesterday, today and tomorrow, so the night on either side
 * of the day is known too.
 */
export function computeDay(city, ms) {
  const { key, params, coords } = paramsFor(city);
  const p = zoneParts(city.tz, ms);
  const start = dayStartMs(city.tz, p.year, p.month, p.day);
  const cycles = [-1, 0, 1].map(k => {
    const date = new Date(Date.UTC(p.year, p.month - 1, p.day + k));
    const c = cycle(coords, params, date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
    if (c) c.key = date.toISOString().slice(0, 10);
    return c;
  });
  if (cycles.some(c => !c)) return null;
  return {
    city, method: key, start, end: start + DAY,
    cycles, today: cycles[1],
    qibla: Qibla(coords),
    distanceKm: distanceToKaaba(city.lat, city.lon),
  };
}

/** The cycle of five prayers the plate shows at `ms`: before Fajr it is still last night's. */
export function shownCycle(day, ms) {
  return ms < day.cycles[1].fajr ? day.cycles[0] : day.cycles[1];
}

/**
 * What the Today card says at `ms`.
 * `now` is the prayer whose window is open; `next` is the one coming when no window is.
 */
export function momentAt(day, ms) {
  const [prev, today, next] = day.cycles;
  const tz = day.city.tz;
  if (ms < today.fajr) {
    if (ms < prev.middle) return { cycle: prev, now: 'isha', until: prev.middle, began: prev.isha };
    return { cycle: prev, next: 'fajr', at: today.fajr, nextCycle: today };
  }
  if (ms < today.sunrise) return { cycle: today, now: 'fajr', until: today.sunrise, untilLabel: 'sunrise', began: today.fajr };
  if (ms < today.dhuhr) return { cycle: today, next: 'dhuhr', at: today.dhuhr, nextCycle: today };
  if (ms < today.asr) return { cycle: today, now: 'dhuhr', until: today.asr, began: today.dhuhr };
  if (ms < today.maghrib) return { cycle: today, now: 'asr', until: today.maghrib, began: today.asr };
  if (ms < today.isha) return { cycle: today, now: 'maghrib', until: today.isha, began: today.maghrib };
  if (ms < today.middle) return { cycle: today, now: 'isha', until: today.middle, began: today.isha };
  return { cycle: today, next: 'fajr', at: next.fajr, nextCycle: next, tz };
}

/** The next prayer to begin after `ms`, across midnight if need be. */
export function nextPrayer(day, ms) {
  for (const c of day.cycles) {
    for (const p of PRAYERS) if (c[p] > ms) return { prayer: p, at: c[p] };
  }
  return { prayer: 'fajr', at: day.cycles[2].fajr };
}

// ── Where the sun is on its wheel ───────────────────────────────────────
/**
 * The sun's angle on the day's wheel, in radians: 0 at sunrise, π at sunset,
 * 2π at the next sunrise. Above the horizon while sin(angle) > 0.
 */
export function sunAngle(day, ms) {
  const [prev, today, next] = day.cycles;
  if (ms < today.sunrise) return Math.PI + Math.PI * clamp01((ms - prev.maghrib) / (today.sunrise - prev.maghrib));
  if (ms < today.maghrib) return Math.PI * clamp01((ms - today.sunrise) / (today.maghrib - today.sunrise));
  return Math.PI + Math.PI * clamp01((ms - today.maghrib) / (next.sunrise - today.maghrib));
}

/** The inverse of sunAngle, kept inside the civil day so the scrubber can follow a dragged sun. */
export function instantForSunAngle(day, angle) {
  const [prev, today, next] = day.cycles;
  const a = ((angle % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
  if (a < Math.PI) return today.sunrise + (a / Math.PI) * (today.maghrib - today.sunrise);
  const f = (a - Math.PI) / Math.PI;
  const evening = today.maghrib + f * (next.sunrise - today.maghrib);
  if (evening < day.end) return evening;
  const small = prev.maghrib + f * (today.sunrise - prev.maghrib);
  return Math.max(day.start, small);
}

/**
 * The moon's elongation from the sun in radians (0 new, π full), from the
 * mean synodic month. Good to a few hours, which is all a drawn moon needs.
 */
export function moonElongation(ms) {
  const SYNODIC = 29.530588853 * DAY;
  const NEW_MOON = Date.UTC(2000, 0, 6, 18, 14);
  const age = (((ms - NEW_MOON) % SYNODIC) + SYNODIC) % SYNODIC;
  return (age / SYNODIC) * 2 * Math.PI;
}

/** Stars turn once per sidereal day. */
export function siderealAngle(ms) {
  const SIDEREAL = 86164090.5;
  return ((ms % SIDEREAL) / SIDEREAL) * 2 * Math.PI;
}

// ── Qibla ───────────────────────────────────────────────────────────────
function distanceToKaaba(lat, lon) {
  const R = 6371.0088, rad = Math.PI / 180;
  const kLat = 21.4225 * rad, kLon = 39.8262 * rad;
  const a = Math.sin((kLat - lat * rad) / 2) ** 2 + Math.cos(lat * rad) * Math.cos(kLat) * Math.sin((kLon - lon * rad) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function compassWords(bearing) {
  const b = ((bearing % 360) + 360) % 360;
  return ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][Math.round(b / 45) % 8];
}

export const clamp01 = x => Math.min(1, Math.max(0, x));
