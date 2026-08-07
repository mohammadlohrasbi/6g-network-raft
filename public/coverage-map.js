/* ═══════════════════════════════════════════════════════════════
   coverage-map.js — shared renderer for the 10 x 10 km deployment.

   Two layers:
     1. <canvas>  nearest-site raster = the real coverage cell of every
                  macro transmitter (a Voronoi tessellation), plus cell
                  boundaries detected where ownership changes.
     2. <svg>     serving links, transmitters, receivers, labels.

   Entity classes follow the radio vocabulary:
     macro TX  (organization antenna)  triangle, teal-family org colour
     small TX  (IoT node)              filled dot with emission arc
     RX        (user)                  hollow square
   ═══════════════════════════════════════════════════════════════ */

const ORG_COLORS = [
  '#35D6C4', '#F2A93B', '#E36FA8', '#6C8CFF',
  '#57D06B', '#C88BFF', '#FF8C6B', '#4FC3E8'
];

function orgColor(n) { return ORG_COLORS[(n - 1) % ORG_COLORS.length]; }

function hexToRgb(hex) {
  const v = parseInt(hex.slice(1), 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}

/**
 * Paint coverage cells + markers into a stage element.
 * @param {HTMLElement} stage  container holding <canvas> and <svg>
 * @param {object} data        { areaMeters, topology:{antennas,iots,users} }
 * @param {object} [opts]      { compact: hide labels and links }
 */
function renderCoverage(stage, data, opts = {}) {
  const compact = !!opts.compact;
  const canvas = stage.querySelector('canvas');
  const svg = stage.querySelector('svg');
  if (!canvas || !svg || !data || !data.topology) return;

  const area = data.areaMeters || 10000;
  const ants = data.topology.antennas || [];
  const iots = data.topology.iots || [];
  const users = data.topology.users || [];

  const box = stage.getBoundingClientRect();
  const size = Math.max(220, Math.round(Math.min(box.width, box.height) || 520));

  /* ---- layer 1: coverage raster ---------------------------------- */
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const px = Math.round(size * dpr);
  canvas.width = px; canvas.height = px;
  const ctx = canvas.getContext('2d');

  if (ants.length) {
    const step = 2;                       // raster at 2 device px for speed
    const n = Math.ceil(px / step);
    const owner = new Int16Array(n * n);
    const ax = ants.map(a => (a.x / area) * n);
    const ay = ants.map(a => (1 - a.y / area) * n);

    for (let gy = 0; gy < n; gy++) {
      for (let gx = 0; gx < n; gx++) {
        let best = 0, bestD = Infinity;
        for (let k = 0; k < ants.length; k++) {
          const dx = gx - ax[k], dy = gy - ay[k];
          const d = dx * dx + dy * dy;
          if (d < bestD) { bestD = d; best = k; }
        }
        owner[gy * n + gx] = best;
      }
    }

    const img = ctx.createImageData(px, px);
    const rgb = ants.map(a => hexToRgb(orgColor(a.orgNum)));
    for (let gy = 0; gy < n; gy++) {
      for (let gx = 0; gx < n; gx++) {
        const k = owner[gy * n + gx];
        // boundary where the serving cell changes
        const edge =
          (gx + 1 < n && owner[gy * n + gx + 1] !== k) ||
          (gy + 1 < n && owner[(gy + 1) * n + gx] !== k);
        const [r, g, b] = rgb[k];
        const a = edge ? 150 : (compact ? 30 : 38);
        for (let sy = 0; sy < step; sy++) {
          const yy = gy * step + sy; if (yy >= px) break;
          for (let sx = 0; sx < step; sx++) {
            const xx = gx * step + sx; if (xx >= px) break;
            const o = (yy * px + xx) * 4;
            img.data[o] = r; img.data[o + 1] = g; img.data[o + 2] = b; img.data[o + 3] = a;
          }
        }
      }
    }
    ctx.putImageData(img, 0, 0);
  } else {
    ctx.clearRect(0, 0, px, px);
  }

  /* ---- layer 2: markers ------------------------------------------ */
  const P = compact ? 6 : 14;
  const X = v => P + (v / area) * (size - 2 * P);
  const Y = v => size - P - (v / area) * (size - 2 * P);
  const byOrg = {};
  ants.forEach(a => { byOrg[a.orgNum] = a; });
  const out = [];

  // km grid
  const gridStep = 2000;
  for (let m = 0; m <= area; m += gridStep) {
    out.push(`<line x1="${X(m)}" y1="${Y(0)}" x2="${X(m)}" y2="${Y(area)}" stroke="#24314F" stroke-width=".5"/>`);
    out.push(`<line x1="${X(0)}" y1="${Y(m)}" x2="${X(area)}" y2="${Y(m)}" stroke="#24314F" stroke-width=".5"/>`);
    if (!compact && m > 0 && m < area) {
      out.push(`<text x="${X(m)}" y="${size - 3}" font-size="8.5" fill="#5C6C8C" text-anchor="middle" font-family="IBM Plex Mono, monospace">${m / 1000}</text>`);
    }
  }

  if (!compact) {
    // serving links: receivers solid, small transmitters dashed
    users.forEach(u => {
      const a = byOrg[u.orgNum]; if (!a) return;
      out.push(`<line x1="${X(u.x)}" y1="${Y(u.y)}" x2="${X(a.x)}" y2="${Y(a.y)}" stroke="${orgColor(u.orgNum)}" stroke-width="1" stroke-opacity=".38"/>`);
    });
    iots.forEach(t => {
      const a = byOrg[t.orgNum]; if (!a) return;
      out.push(`<line x1="${X(t.x)}" y1="${Y(t.y)}" x2="${X(a.x)}" y2="${Y(a.y)}" stroke="${orgColor(t.orgNum)}" stroke-width=".8" stroke-opacity=".2" stroke-dasharray="3 4"/>`);
    });
  }

  // small-cell transmitters
  const rIot = compact ? 2 : 4;
  iots.forEach(t => {
    const c = orgColor(t.orgNum), x = X(t.x), y = Y(t.y);
    out.push(`<circle cx="${x}" cy="${y}" r="${rIot}" fill="${c}"><title>Small-cell TX ${t.id} — serving org${t.orgNum}, ${t.distToAntenna} m</title></circle>`);
    if (!compact) out.push(`<circle cx="${x}" cy="${y}" r="8" fill="none" stroke="${c}" stroke-width=".8" stroke-opacity=".42"/>`);
  });

  // receivers
  const rU = compact ? 2.4 : 4.4;
  users.forEach(u => {
    const c = orgColor(u.orgNum), x = X(u.x), y = Y(u.y);
    out.push(`<rect x="${x - rU}" y="${y - rU}" width="${rU * 2}" height="${rU * 2}" fill="#0A1020" stroke="${c}" stroke-width="1.9"><title>RX ${u.id} — serving org${u.orgNum}, ${u.distToAntenna} m</title></rect>`);
  });

  // macro transmitters
  const s = compact ? 5 : 10;
  ants.forEach(a => {
    const c = orgColor(a.orgNum), x = X(a.x), y = Y(a.y);
    if (!compact) {
      [17, 27, 38].forEach((r, i) =>
        out.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="none" stroke="${c}" stroke-width="1" stroke-opacity="${0.34 - i * 0.09}"/>`));
    }
    out.push(`<polygon points="${x},${y - s * 1.2} ${x - s},${y + s * .85} ${x + s},${y + s * .85}" fill="${c}" stroke="#0A1020" stroke-width="1.4"><title>Macro TX ${a.id} — (${a.x}, ${a.y}) m</title></polygon>`);
    if (!compact) {
      out.push(`<text x="${x}" y="${y + s * 2.4}" font-size="9.5" fill="#8A9AB8" text-anchor="middle" font-family="IBM Plex Mono, monospace">org${a.orgNum}</text>`);
    }
  });

  svg.setAttribute('viewBox', `0 0 ${size} ${size}`);
  svg.innerHTML = out.join('');
}
