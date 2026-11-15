import { $, api, bars, change, h, legend, lineChart, mount, num, skeleton, spark } from '../core.js';

const DAYS = [7, 14, 30, 90];
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

export async function render(ctx) {
  const { root } = ctx;
  let days = Number(ctx.query.days) || 30;
  let metric = 'active';

  async function load() {
    mount(root, skeleton(4));
    const d = await api.get(`admin/analytics/?days=${days}`);
    const t = d.totals;
    mount(root, h`
      <div class="page-head"><div><div class="eyebrow">Analytics</div><h1>Usage analytics</h1>
        <div class="sub">How people use Exerlio. Demo accounts are left out. Updated ${d.generated.rel}.</div></div>
        <div class="seg" id="rng">${DAYS.map((n) => h`<button class="${n === days ? 'on' : ''}" data-d="${n}">${n} days</button>`)}</div></div>
      <div class="grid g4">
        ${[['Active users', t.active_users, `in the last ${days} days`], ['App opens', t.sessions, `${t.avg_minutes || '—'} min average visit`],
           ['New signups', t.signups, `in the last ${days} days`], ['Events recorded', t.events, 'screens, taps and actions']].map(([l, v, f]) =>
          h`<div class="stat"><div class="label">${l}</div><div class="value">${num(v)}</div><div class="foot">${f}</div></div>`)}
      </div>
      <section class="card mt"><div class="card-head"><div><div class="card-title">Every day</div><div class="card-note">Hover for the numbers</div></div>
        <div class="seg" id="met">${[['active', 'Active users'], ['sessions', 'App opens'], ['signups', 'Signups'], ['avg_minutes', 'Minutes per visit']].map(([k, l]) =>
          h`<button class="${k === metric ? 'on' : ''}" data-m="${k}">${l}</button>`)}</div></div><div id="daily"></div></section>

      <section class="card flush mt"><div class="card-head" style="padding:16px 18px 0"><div><div class="card-title">Features</div>
        <div class="card-note">Uses and unique people in the period, compared with the ${days} days before. "Records" count saved items, so history before tracking is included.</div></div></div>
        <div class="table-wrap"><table><thead><tr><th>Feature</th><th class="num">Uses</th><th class="num">People</th><th>Change</th><th>Trend</th><th>Source</th></tr></thead>
        <tbody>${d.features.map((f) => h`<tr><td><b>${f.label}</b></td><td class="num">${num(f.uses)}</td><td class="num">${num(f.users)}</td>
          <td class="small">${f.uses || f.previous ? change(f.change, { suffix: '' }) : h`<span class="muted">—</span>`}</td><td>${spark(f.spark)}</td>
          <td><span class="pill plain">${f.source}</span></td></tr>`)}</tbody></table></div></section>

      <div class="grid g2 mt">
        <section class="card"><div class="card-title" style="margin-bottom:14px">Funnels</div>
          ${d.funnels.map((fn) => h`<div style="margin-bottom:18px"><div class="small" style="font-weight:600;margin-bottom:8px">${fn.title}</div>
            ${fn.steps.map((s) => h`<div class="funnel-step"><div class="row between"><span>${s.label}</span><span class="muted">${num(s.users)} · ${s.pct}%</span></div>
              <div class="funnel-bar"><div style="width:${s.pct}%"></div></div></div>`)}</div>`)}
          <p class="small muted">Unique people who reached each step within the period.</p></section>
        <section class="card"><div class="card-title" style="margin-bottom:4px">Retention</div>
          <div class="card-note" style="margin-bottom:12px">Of the people who joined each week, the share who came back in each later week</div>
          <div class="table-wrap"><table class="cohort"><thead><tr><th>Joined week of</th><th>People</th>${[1, 2, 3, 4, 5, 6, 7, 8].map((w) => h`<th>W${w}</th>`)}</tr></thead>
          <tbody>${d.cohorts.map((c) => h`<tr><td>${c.week}</td><td>${num(c.size)}</td>${[0, 1, 2, 3, 4, 5, 6, 7].map((i) => {
            const v = c.weeks[i];
            if (v == null || c.size === 0) return h`<td class="muted">${i < c.weeks.length ? '—' : ''}</td>`;
            return h`<td style="background:rgba(255,107,0,${(v / 100) * 0.85 + 0.05});color:${v > 55 ? '#fff' : 'inherit'}">${v}%</td>`;
          })}</tr>`)}</tbody></table></div></section>
      </div>

      <div class="grid g2 mt">
        <section class="card"><div class="card-title" style="margin-bottom:4px">When people open the app</div>
          <div class="card-note" style="margin-bottom:12px">App opens by weekday and hour (India time)</div><div class="heat" id="heat"></div></section>
        <section class="card"><div class="card-title" style="margin-bottom:12px">Most viewed screens</div>
          ${d.screens.length ? bars(d.screens.map((s) => ({ label: s.screen.replace(/Screen$/, '').replace(/(?!^)([A-Z])/g, ' $1'), users: s.views })), { orange: true })
            : h`<div class="empty">Screen views arrive with app version 3.3.</div>`}</section>
      </div>

      <div class="grid g3 mt">
        <section class="card"><div class="card-title" style="margin-bottom:12px">Goals people chose</div>${bars(d.people.goals)}</section>
        <section class="card"><div class="card-title" style="margin-bottom:12px">Level</div>${bars(d.people.levels)}
          <div class="card-title" style="margin:16px 0 12px">Sex</div>${bars(d.people.sex)}</section>
        <section class="card"><div class="card-title" style="margin-bottom:12px">Platforms and versions</div>
          ${d.versions.length ? bars(d.versions.map((v) => ({ label: `${v.platform || '?'} ${v.app_version}`, users: v.users }))) : h`<div class="empty">Reported from app 3.3 on.</div>`}</section>
      </div>

      <section class="card mt"><div class="card-title" style="margin-bottom:4px">Errors people hit</div>
        <div class="card-note" style="margin-bottom:12px">Failed requests reported by the app, grouped by endpoint</div>
        ${d.errors.length ? h`<div class="table-wrap"><table><thead><tr><th>Endpoint</th><th>Code</th><th class="num">Times</th></tr></thead>
          <tbody>${d.errors.map((e) => h`<tr><td class="mono">${e.path || '—'}</td><td>${e.code || '—'}</td><td class="num">${num(e.n)}</td></tr>`)}</tbody></table></div>`
          : h`<div class="empty">No errors reported in this period.</div>`}</section>`);

    const drawDaily = () => {
      const label = { active: 'Active users', sessions: 'App opens', signups: 'Signups', avg_minutes: 'Minutes per visit' }[metric];
      const series = [{ name: label, values: d.daily.map((x) => x[metric]) }];
      lineChart($('#daily', root), { labels: d.daily.map((x) => x.label), series, height: 240 });
    };
    drawDaily();
    $('#met', root).onclick = (e) => {
      const b = e.target.closest('[data-m]');
      if (!b) return;
      metric = b.dataset.m;
      $('#met', root).querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b));
      drawDaily();
    };
    $('#rng', root).onclick = (e) => {
      const b = e.target.closest('[data-d]');
      if (b) { days = Number(b.dataset.d); history.replaceState(null, '', `#/analytics?days=${days}`); load(); }
    };
    const max = Math.max(1, ...d.heat.flat());
    mount($('#heat', root), h`<em></em>${Array.from({ length: 24 }, (_, i) => h`<em style="text-align:center">${i % 3 === 0 ? i : ''}</em>`)}
      ${d.heat.map((row, wd) => h`<em>${WEEKDAYS[wd]}</em>${row.map((v, hr) => h`<span title="${WEEKDAYS[wd]} ${hr}:00 · ${v} opens" style="background:${v ? `rgba(255,107,0,${0.12 + (v / max) * 0.88})` : ''}"></span>`)}`)}`);
  }
  await load();
}

export { legend };
