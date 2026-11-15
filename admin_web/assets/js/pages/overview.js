import { $, api, change, h, legend, lineChart, mount, num, person, skeleton } from '../core.js';

const greet = () => { const hr = new Date().getHours(); return hr < 12 ? 'Good morning' : hr < 17 ? 'Good afternoon' : 'Good evening'; };

export async function render(ctx) {
  const { root, session } = ctx;
  mount(root, skeleton(4));
  const d = await api.get('admin/overview/');
  const first = session.me.staff.name.split(' ')[0];
  const u = d.users, a = d.active, s = d.sessions, sp = d.support;
  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Overview</div><h1>${greet()}, ${first}.</h1>
      <div class="sub">What's happening across Exerlio today. Numbers refresh every minute.</div></div>
      <div class="actions">${a.online ? h`<span class="pill green">${num(a.online)} using the app now</span>` : ''}
        ${session.can('analytics.view') ? h`<a class="btn light" href="#/analytics">Full analytics</a>` : ''}</div></div>
    ${!d.tracking_since ? h`<div class="notice">In-app usage tracking starts with app version 3.3. Until people update, sessions and screen data stay empty; users, signups and saved activity are already real.</div>` : ''}
    <div class="grid g4">
      <div class="stat"><div class="label">Real users</div><div class="value">${num(u.total)}</div>
        <div class="foot">+${num(u.d7)} this week · ${change(u.d7_change, { suffix: 'vs last week' })}</div></div>
      <div class="stat"><div class="label">Active today</div><div class="value">${num(a.dau)}</div>
        <div class="foot">${change(a.dau_change, { suffix: 'vs yesterday' })}</div></div>
      <div class="stat"><div class="label">Active this week / month</div><div class="value">${num(a.wau)} <span class="muted" style="font-size:16px">/ ${num(a.mau)}</span></div>
        <div class="foot">${a.stickiness}% of monthly users came today</div></div>
      <div class="stat"><div class="label">App opens today</div><div class="value">${num(s.today)}</div>
        <div class="foot">${s.avg_minutes != null ? `${s.avg_minutes} min average visit` : 'Visit length comes with 3.3'} · ${num(s.users)} people</div></div>
    </div>
    <div class="grid g-wide mt">
      <section class="card"><div class="card-head"><div><div class="card-title">Growth and activity</div><div class="card-note">Last 30 days</div></div>
        <div id="lg"></div></div><div id="growth"></div></section>
      <section class="card"><div class="card-head"><div class="card-title">Support and safety</div>
        ${session.can('tickets.view') ? h`<a class="btn light sm" href="#/tickets">Open queue</a>` : ''}</div>
        ${[['Open tickets', sp.open, '#/tickets'], ['Waiting on users', sp.waiting, '#/tickets?status=waiting'],
           ['Not assigned to anyone', sp.unassigned, '#/tickets?assignee=none'], ['No reply yet', sp.no_reply, '#/tickets'],
           ['Reported posts and reels', sp.reports, '#/moderation']].map(([l, n, href]) => h`
          <a class="list-item" style="text-decoration:none;align-items:center" href="${href}"><div class="grow"><strong>${l}</strong></div>
          <span class="pill ${n ? 'orange' : 'plain'}">${num(n)}</span></a>`)}
        <div class="card-note" style="margin-top:10px">${num(u.onboarded_pct)}% of users finished setup · ${num(u.today)} joined today</div>
      </section>
    </div>
    <div class="grid g-wide mt">
      <section class="card flush"><div class="card-head" style="padding:16px 18px 0"><div><div class="card-title">Feature use today</div>
        <div class="card-note">Saved records and app events, compared with yesterday</div></div></div>
        <div class="table-wrap"><table><thead><tr><th>Feature</th><th class="num">Today</th><th class="num">People</th><th class="num">Yesterday</th></tr></thead>
        <tbody>${d.features.map((f) => h`<tr><td>${f.label}</td><td class="num"><b>${num(f.today)}</b></td><td class="num">${num(f.users)}</td>
          <td class="num muted">${num(f.yesterday)}</td></tr>`)}</tbody></table></div></section>
      <section class="card"><div class="card-head"><div class="card-title">Newest users</div>
        ${session.can('users.view') ? h`<a class="btn light sm" href="#/users">All users</a>` : ''}</div>
        ${d.recent_users.length ? d.recent_users.map((x) => h`<a class="list-item" style="text-decoration:none;align-items:center" href="#/users/${x.id}">
          ${person(x, `${x.joined.rel}${x.onboarded ? '' : ' · setup not finished'}`)}</a>`) : h`<div class="empty">No users yet.</div>`}
      </section>
    </div>
    ${d.recent_audit ? h`<section class="card mt"><div class="card-head"><div class="card-title">Recent team actions</div><a class="btn light sm" href="#/audit">Audit log</a></div>
      ${d.recent_audit.length ? d.recent_audit.map((x) => h`<div class="list-item"><div class="grow"><strong>${x.summary}</strong><p>${x.staff} · ${x.when.rel}</p></div>
        <span class="pill plain mono">${x.action}</span></div>`) : h`<div class="empty">Nothing yet.</div>`}</section>` : ''}
  `);
  const series = [{ name: 'Signups', values: d.signups.map((x) => x.value) }, { name: 'Active users', values: d.dau_series.map((x) => x.value) }];
  lineChart($('#growth', root), { labels: d.signups.map((x) => x.label), series });
  mount($('#lg', root), legend(series));
}
