// Ihsan landing page. The sky is today's, where the visitor is.
// No framework, no build step, no request to anyone but this site.

import { CITIES, guessCity, methodName } from './cities.js';
import { PRAYERS, NAMES, MIN, DAY, computeDay, momentAt, nextPrayer, clock, longDate, hijriDate } from './day.js';
import { skyKeys, paletteAt, applyPalette, crossesPolarity, skyStrip } from './sky.js';
import { Plate } from './plate.js';
import { ornamentSvg } from './glyphs.js';
import { PathSpecimen, RepairSpecimen, QiblaSpecimen, watchRequests, paintTimes } from './specimens.js';

const $ = id => document.getElementById(id);
const root = document.documentElement;
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
root.classList.remove('no-js');

const state = {
  city: null, how: 'guessed',   // guessed | chosen | located | fallback
  day: null, keys: null,
  ms: 0, live: true, arriving: false,
  logs: new Map(),              // "2026-11-10:asr" → { status, at, jamaah }
};

const plate = new Plate($('sky'), $('stars'), ms => setTime(ms, false));
const path = new PathSpecimen($('path-specimen'));
const qibla = new QiblaSpecimen($('qibla-specimen'));
new RepairSpecimen($('repair-specimen'));
watchRequests($('ledger-live'));

// ── City ────────────────────────────────────────────────────────────────
function setCity(city, how) {
  const now = Date.now();
  let day = computeDay(city, now);
  if (!day) { city = CITIES[0]; how = 'fallback'; day = computeDay(city, now); }
  Object.assign(state, { city, how, day, keys: skyKeys(day.cycles), live: true });
  seedLogs(now);
  qibla.update(day);
  paintPlace();
  setTime(now, true);
  paintPath();
  paintClosing();
}

// A sample of the day so far, so the plate does not open empty: every prayer
// whose window has closed is shown as recorded. The open one is left to tap.
function seedLogs(now) {
  state.logs.clear();
  const open = momentAt(state.day, now);
  for (const c of state.day.cycles.slice(0, 2)) {
    PRAYERS.forEach((p, i) => {
      if (c[p] >= now) return;
      if (open.cycle === c && open.now === p) return;
      state.logs.set(`${c.key}:${p}`, { status: 'onTime', at: c[p] + (9 + i * 4) * MIN, jamaah: false });
    });
  }
}

function paintPlace() {
  const { city, day, how } = state;
  const tz = city.tz;
  $('date-line').innerHTML = [longDate(tz, day.start + DAY / 2), hijriDate(tz, day.start + DAY / 2)].filter(Boolean).map(t => `<span>${t}</span>`).join(' ');
  $('scrub-label').textContent = `Today ${city.custom ? 'where you are' : `in ${city.name}`}. Drag the sun, or this line, to move through the day.`;
  $('place-note').textContent = {
    guessed: `${city.name} is a guess from your clock’s time zone. These times were worked out in this tab, and nothing was sent anywhere to get them.`,
    chosen: 'Worked out in this tab. Nothing was sent anywhere to get these times.',
    located: 'Your position stayed in this tab. It was used for the arithmetic and not stored or sent.',
    fallback: 'Your time zone was not one this page knows, so it is showing Makkah. Choose a city to see your own day.',
    denied: 'Your browser did not share a position, so the city above still stands.',
  }[how];
  $('method-note').textContent = `Method: ${methodName(day.method)}, where the app starts for this region. In the app the method is yours to choose.`;
  $('track').style.backgroundImage = skyStrip(state.keys, day.start, DAY);

  const marks = [];
  for (const k of ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
    const at = day.today[k];
    if (at >= day.start && at < day.end) marks.push(`<i style="left:${(((at - day.start) / DAY) * 100).toFixed(2)}%"></i>`);
  }
  $('track-marks').innerHTML = marks.join('');

  const select = $('city');
  if (!select.options.length) {
    const sorted = [...CITIES].sort((a, b) => a.name.localeCompare(b.name));
    select.innerHTML = '<option value="here" hidden>Where you are</option>' + sorted.map(c => `<option value="${CITIES.indexOf(c)}">${c.name}</option>`).join('');
  }
  select.value = city.custom ? 'here' : String(CITIES.indexOf(city));
}

// ── Time ────────────────────────────────────────────────────────────────
let queued = false;
function setTime(ms, live) {
  const { day } = state;
  state.ms = Math.min(day.end - MIN, Math.max(day.start, ms));
  state.live = live;
  if (queued) return;
  queued = true;
  // One paint per frame; the timer is for a tab opened in the background,
  // where frames do not come and the page would otherwise stay undrawn.
  requestAnimationFrame(flush);
  setTimeout(flush, 160);
}
function flush() {
  if (!queued) return;
  queued = false;
  render();
}

function render() {
  const { day, keys, ms } = state;
  const palette = paletteAt(keys, ms);
  applyPalette(palette);
  plate.update(day, ms, state.logs, palette.stars);
  paintCard();

  const slider = $('clock');
  const minute = Math.round((ms - day.start) / MIN);
  if (Number(slider.value) !== minute) slider.value = String(minute);
  $('clock-read').textContent = clock(day.city.tz, ms);
  $('to-now').hidden = state.live || state.arriving;
}

// ── The Today card ──────────────────────────────────────────────────────
let cardSignature = '';
function paintCard() {
  const { day, ms, logs } = state;
  const tz = day.city.tz;
  const m = momentAt(day, ms);
  const prayer = m.now || m.next;
  const cycle = m.now ? m.cycle : m.nextCycle;
  const key = `${cycle.key}:${prayer}`;
  // A record made later in the day is not yet on the page when the clock is wound back before it.
  const kept = m.now ? logs.get(key) : null;
  const log = kept && kept.at <= ms ? kept : null;
  const signature = [key, m.now ? 'now' : 'next', log ? `${log.status}:${log.jamaah}:${log.at}` : '-'].join('|');

  const [name, arabic] = NAMES[prayer];
  let status;
  if (!m.now) status = `Next · ${clock(tz, m.at)}`;
  else if (log) status = `${log.status === 'delayed' ? 'Delayed' : 'On time'} · ${clock(tz, log.at)}`;
  else status = `Now · until ${m.untilLabel ? `${m.untilLabel} at ` : ''}${clock(tz, m.until)}`;
  $('clock').setAttribute('aria-valuetext', `${clock(tz, ms)}. ${name}. ${status}`);

  if (signature === cardSignature) return;
  cardSignature = signature;
  const card = $('now-card');
  const hadFocus = card.contains(document.activeElement);

  let actions;
  if (!m.now) {
    actions = `<p class="now-quiet">Nothing to record until then.</p>`;
  } else if (log) {
    actions = `<button type="button" class="btn btn-line btn-toggle" data-act="jamaah" aria-pressed="${log.jamaah}"><i class="check" aria-hidden="true"></i>In jamāʿah</button>
               <button type="button" class="btn-text" data-act="undo">Undo</button>`;
  } else {
    actions = `<button type="button" class="btn btn-gold" data-act="onTime">${ornamentSvg(prayer, 16, 'outline')}On time</button>
               <button type="button" class="btn btn-line" data-act="delayed">${ornamentSvg(prayer, 16, 'outline')}Delayed</button>`;
  }
  card.dataset.key = key;
  card.innerHTML = `
    <div class="now-head">
      ${ornamentSvg(prayer, 46, m.now ? 'filled' : 'outline')}
      <p class="now-title"><span class="now-name">${name}</span> <span class="now-ar" lang="ar" dir="rtl">${arabic}</span></p>
      <p class="now-status ui-label" aria-live="polite">${status}</p>
    </div>
    <div class="now-actions">${actions}</div>`;
  if (hadFocus) (card.querySelector('[data-act="undo"], [data-act="onTime"]') || card).focus?.();
}

$('now-card').addEventListener('click', e => {
  const b = e.target.closest('[data-act]');
  if (!b) return;
  const key = $('now-card').dataset.key;
  const log = state.logs.get(key);
  switch (b.dataset.act) {
    case 'onTime': case 'delayed': state.logs.set(key, { status: b.dataset.act, at: state.ms, jamaah: false }); break;
    case 'jamaah': if (log) log.jamaah = !log.jamaah; break;
    case 'undo': state.logs.delete(key); break;
  }
  render();
  paintPath();
});

function paintPath() {
  const { day, logs } = state;
  const now = Date.now();
  const today = PRAYERS.map(p => {
    const log = logs.get(`${day.today.key}:${p}`);
    if (log) return log.status === 'delayed' ? 'delayed' : log.jamaah ? 'jamaah' : 'ontime';
    return day.today[p] <= now ? 'pending' : 'later';
  });
  path.update(day, today);
}

function paintClosing() {
  const { day } = state;
  const now = Date.now();
  const up = nextPrayer(day, now);
  // After Isha the five shown are tomorrow's, since that is where "next" now lives.
  const cycle = day.cycles.find(c => c[up.prayer] === up.at) || day.today;
  paintTimes($('times'), day, cycle, up);
  const where = day.city.custom ? 'where you are' : `in ${day.city.name}`;
  $('times-next').textContent = `Next ${where}: ${NAMES[up.prayer][0]} at ${clock(day.city.tz, up.at)}.`;
}

// ── Controls ────────────────────────────────────────────────────────────
$('clock').addEventListener('input', e => setTime(state.day.start + Number(e.target.value) * MIN, false));
$('to-now').addEventListener('click', () => { setTime(Date.now(), true); $('clock').focus(); });
$('city').addEventListener('change', e => {
  const city = CITIES[Number(e.target.value)];
  if (city) setCity(city, 'chosen');
});
if (!('geolocation' in navigator)) $('locate').hidden = true;
$('locate').addEventListener('click', () => {
  const button = $('locate');
  button.disabled = true;
  navigator.geolocation.getCurrentPosition(
    pos => {
      button.disabled = false;
      let tz = state.city.tz;
      try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || tz; } catch { /* keep the city's zone */ }
      setCity({ name: 'your position', custom: true, cc: guessCity().city.cc, lat: pos.coords.latitude, lon: pos.coords.longitude, tz }, 'located');
    },
    () => { button.disabled = false; state.how = 'denied'; paintPlace(); },
    { maximumAge: 600000, timeout: 15000 },
  );
});

// Keep time. Past midnight the day itself is worked out again.
function tick() {
  if (document.hidden || state.arriving) return;
  if (Date.now() >= state.day.end) { setCity(state.city, state.how); return; }
  if (state.live) setTime(Date.now(), true);
  paintPath();
  paintClosing();
}
setInterval(tick, 15000);
document.addEventListener('visibilitychange', tick);

// ── Arrival: the one orchestrated moment ────────────────────────────────
// The arch is drawn, the ornaments take their places, and the last stretch
// of the day runs forward to now. It never crosses dawn or dusk, so the
// page does not flash from dark to light as it opens.
function arrive() {
  const guess = guessCity();
  setCity(guess.city, guess.guessed ? 'guessed' : 'fallback');
  root.classList.add('is-ready');
  if (reduceMotion) return;

  const now = Date.now();
  const { day, keys } = state;
  let from = Math.max(day.start, now - 140 * MIN);
  while (from < now && crossesPolarity(keys, from, now)) from += 10 * MIN;
  if (now - from < 20 * MIN) return;

  state.arriving = true;
  root.classList.add('is-arriving');
  const t0 = performance.now(), duration = 2600;
  const finish = () => {
    if (!state.arriving) return;
    state.arriving = false;
    root.classList.remove('is-arriving');
    setTime(Date.now(), true);
  };
  const frame = t => {
    if (!state.arriving) return;
    const k = Math.min(1, (t - t0) / duration);
    const eased = 1 - (1 - k) ** 3;
    setTime(from + (now - from) * eased, false);
    if (k < 1) requestAnimationFrame(frame); else finish();
  };
  setTime(from, false);
  requestAnimationFrame(frame);
  setTimeout(finish, duration + 900); // a throttled tab still lands on now
}

arrive();
