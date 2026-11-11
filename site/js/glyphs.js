// The five prayer ornaments, constructed the way the app constructs them
// (PrayerOrnamentLibrary.swift): Fajr a six-petal rosette, Dhuhr a
// twelve-pointed Khargird star, Asr a khatam of two squares, Maghrib a
// pointed almond, Isha a ten-pointed star within a ring.

const f = n => (Math.round(n * 100) / 100).toString();
const at = (r, deg) => {
  const a = (deg * Math.PI) / 180;
  return [r * Math.cos(a), r * Math.sin(a)];
};

function star(count, outer, inner, start) {
  const step = 360 / count;
  let d = '';
  for (let i = 0; i < count; i++) {
    const [ox, oy] = at(outer, start + i * step);
    const [ix, iy] = at(inner, start + (i + 0.5) * step);
    d += `${i ? 'L' : 'M'}${f(ox)} ${f(oy)}L${f(ix)} ${f(iy)}`;
  }
  return d + 'Z';
}

function polygon(sides, r, start) {
  let d = '';
  for (let i = 0; i < sides; i++) {
    const [x, y] = at(r, start + (i * 360) / sides);
    d += `${i ? 'L' : 'M'}${f(x)} ${f(y)}`;
  }
  return d + 'Z';
}

function circle(r) {
  return `M${f(-r)} 0A${f(r)} ${f(r)} 0 1 0 ${f(r)} 0A${f(r)} ${f(r)} 0 1 0 ${f(-r)} 0Z`;
}

function almond(hh, hw) {
  const c = hw * 1.35, k = hh * 0.38;
  return `M0 ${f(-hh)}C${f(c)} ${f(-k)} ${f(c)} ${f(k)} 0 ${f(hh)}C${f(-c)} ${f(k)} ${f(-c)} ${f(-k)} 0 ${f(-hh)}Z`;
}

function rosette(side) {
  const r = (side * 0.46) / Math.sqrt(3);
  let d = '';
  for (let k = 0; k < 6; k++) {
    const [tx, ty] = at(r * Math.sqrt(3), -90 + k * 60);
    d += `M0 0A${f(r)} ${f(r)} 0 0 0 ${f(tx)} ${f(ty)}A${f(r)} ${f(r)} 0 0 0 0 0Z`;
  }
  return d;
}

/**
 * Both drawings of a prayer's ornament, centred on the origin, `side` units
 * across. CSS shows the filled one once a prayer is recorded or current.
 */
export function ornament(prayer, side) {
  const s = side;
  let filled = '', outline = '';
  switch (prayer) {
    case 'fajr': {
      const d = rosette(s);
      filled = `<path class="orn-gold" d="${d}"/><circle class="orn-field" r="${f(s * 0.045)}"/>`;
      outline = `<path class="orn-line" d="${d}"/>`;
      break;
    }
    case 'dhuhr': {
      const tile = star(12, s * 0.475, s * 0.335, -90);
      const field = star(12, s * 0.255, s * 0.185, -75);
      filled = `<path class="orn-gold" d="${tile}"/><path class="orn-field" d="${field}"/><circle class="orn-pip" r="${f(s * 0.06)}"/>`;
      outline = `<path class="orn-line" d="${tile}${field}"/>`;
      break;
    }
    case 'asr': {
      const r = s * 0.46;
      filled = `<path class="orn-gold" d="${star(8, r, r * 0.7654, -90)}"/>`;
      outline = `<path class="orn-line" d="${polygon(4, r, -90)}${polygon(4, r, -45)}"/>`;
      break;
    }
    case 'maghrib': {
      const hh = s * 0.48, hw = s * 0.21;
      filled = `<path class="orn-gold" fill-rule="evenodd" d="${almond(hh, hw)}${almond(hh * 0.6, hw * 0.13)}"/>`;
      outline = `<path class="orn-line" d="${almond(hh, hw)}M0 ${f(-hh * 0.62)}L0 ${f(hh * 0.62)}"/>`;
      break;
    }
    case 'isha': {
      const st = star(10, s * 0.375, s * 0.375 * 0.5257, -90);
      filled = `<circle class="orn-field" r="${f(s * 0.46)}"/><path class="orn-gold" fill-rule="evenodd" d="${circle(s * 0.49)}${circle(s * 0.435)}"/><path class="orn-gold" d="${st}"/>`;
      outline = `<path class="orn-line" d="${circle(s * 0.49)}${st}"/>`;
      break;
    }
  }
  return `<g class="orn-filled">${filled}</g><g class="orn-outline">${outline}</g>`;
}

/** A standalone inline SVG of one ornament, for cards and lists. */
export function ornamentSvg(prayer, px, mode = 'filled') {
  return `<svg class="orn orn-is-${mode}" viewBox="${-px / 2 - 1} ${-px / 2 - 1} ${px + 2} ${px + 2}" width="${px}" height="${px}" aria-hidden="true">${ornament(prayer, px)}</svg>`;
}

/** The moon's lit part as a path on a disc of radius r. `e` is elongation in radians. */
export function moonLit(r, e, southern = false) {
  const waxing = e < Math.PI;
  const k = Math.cos(waxing ? e : 2 * Math.PI - e); // 1 new … -1 full
  const rx = Math.abs(k) * r;
  const sweep = k > 0 ? 0 : 1;
  const d = `M0 ${f(-r)}A${f(r)} ${f(r)} 0 0 1 0 ${f(r)}A${f(rx)} ${f(r)} 0 0 ${sweep} 0 ${f(-r)}Z`;
  const flip = waxing === southern; // lit on the right when waxing, seen from the north
  return { d, flip };
}
