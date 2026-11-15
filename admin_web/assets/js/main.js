import { $, $$, api, fail, h, icon, mount, store, toast } from './core.js';

// route -> [module, title, permission, nav icon, nav group]
const ROUTES = {
  overview: ['overview', 'Overview', 'dashboard.view', 'home', 'Workspace'],
  analytics: ['analytics', 'Usage analytics', 'analytics.view', 'chart', 'Workspace'],
  live: ['live', 'Live activity', 'analytics.view', 'pulse', 'Workspace'],
  users: ['users', 'Users', 'users.view', 'users', 'Workspace'],
  tickets: ['tickets', 'Support tickets', 'tickets.view', 'ticket', 'Workspace'],
  moderation: ['moderation', 'Moderation', 'moderation.view', 'flag', 'Workspace'],
  announcements: ['announcements', 'Announcements', 'announce.draft', 'megaphone', 'Workspace'],
  team: ['team', 'Team and roles', 'staff.view', 'team', 'Administration'],
  audit: ['audit', 'Audit log', 'audit.view', 'log', 'Administration'],
  system: ['system', 'System status', 'system.view', 'server', 'Administration'],
  account: ['account', 'My account', null, 'key', null],
};

export const session = { me: null, can: (p) => !p || session.me?.permissions.includes(p) };
const app = $('#app');
let current = null; // { cleanup }

function logoMark() {
  return h`<span class="wordmark"><img src="assets/logo.png" alt="">EXERLIO<b>.</b></span>`;
}

// ---------- sign-in ----------
function showLogin(message = '') {
  stopTimers();
  document.title = 'Sign in · Exerlio Control Centre';
  mount(app, h`<div class="auth">
    <aside class="auth-side">${logoMark()}
      <div><h1>The Exerlio Control Centre.</h1><p>Support, moderation, announcements and live usage for the Exerlio team. Every action here is recorded.</p></div>
      <small style="color:#5d5f64;position:relative;z-index:1">Authorised staff only</small></aside>
    <main class="auth-main"><form class="auth-card" id="login" novalidate>
      <div class="mobile-logo">${logoMark()}</div>
      <h2>Sign in</h2><p class="sub">Use the work login your admin gave you.</p>
      ${message ? h`<div class="form-error" role="alert">${message}</div>` : ''}
      <div class="field"><label for="em">Work email</label><input class="input" id="em" type="email" autocomplete="username" required></div>
      <div class="field"><label for="pw">Password</label><input class="input" id="pw" type="password" autocomplete="current-password" required></div>
      <label class="check" style="margin:-2px 0 18px"><input type="checkbox" id="keep"> Keep me signed in on this computer</label>
      <button class="btn orange block" type="submit">Sign in</button>
      <p class="small muted" style="margin-top:18px">Forgot your password? Ask an owner or admin to reset it from Team and roles.</p>
    </form></main></div>`);
  $('#em').focus();
  $('#login').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = e.target.querySelector('button[type=submit]');
    btn.disabled = true;
    try {
      const r = await api.req('POST', 'admin/auth/login/', { email: $('#em').value.trim(), password: $('#pw').value });
      api.token = r.token;
      store.set('cc.token', r.token, $('#keep').checked);
      session.me = r;
      r.staff.must_change_password ? showPasswordChange(true) : start();
    } catch (err) {
      showLogin(err.message);
      $('#em').value = e.target.em?.value || '';
    } finally { btn.disabled = false; }
  });
}

function showPasswordChange(first) {
  stopTimers();
  mount(app, h`<div class="auth"><aside class="auth-side">${logoMark()}<div><h1>Set your own password.</h1>
    <p>Your temporary password works only once. Choose one you don't use anywhere else.</p></div><span></span></aside>
    <main class="auth-main"><form class="auth-card" id="pwf" novalidate>
      <h2>${first ? 'Welcome, ' + session.me.staff.name.split(' ')[0] : 'Change password'}</h2>
      <p class="sub">At least 10 characters, with upper and lower case letters and a number.</p>
      <div id="pwerr"></div>
      <div class="field"><label for="cur">Current or temporary password</label><input class="input" id="cur" type="password" autocomplete="current-password"></div>
      <div class="field"><label for="n1">New password</label><input class="input" id="n1" type="password" autocomplete="new-password"></div>
      <div class="field"><label for="n2">Repeat new password</label><input class="input" id="n2" type="password" autocomplete="new-password"></div>
      <button class="btn orange block" type="submit">Save password</button>
      <button class="btn light block" type="button" id="so" style="margin-top:8px">Sign out</button>
    </form></main></div>`);
  $('#cur').focus();
  $('#so').onclick = signOut;
  $('#pwf').addEventListener('submit', async (e) => {
    e.preventDefault();
    const say = (m) => mount($('#pwerr'), h`<div class="form-error" role="alert">${m}</div>`);
    if ($('#n1').value !== $('#n2').value) return say('The new passwords don’t match.');
    try {
      const r = await api.post('admin/me/password/', { current: $('#cur').value, new: $('#n1').value });
      session.me = { ...session.me, ...r };
      toast(r.message);
      start();
    } catch (err) { say(err.message); }
  });
}

async function signOut() {
  try { await api.post('admin/auth/logout/'); } catch { /* already gone */ }
  api.token = null;
  store.del('cc.token');
  session.me = null;
  location.hash = '';
  showLogin();
}

// ---------- shell ----------
let badgeTimer = null;
function stopTimers() {
  clearInterval(badgeTimer);
  current?.cleanup?.();
  current = null;
}

function shell() {
  const me = session.me.staff;
  const groups = {};
  for (const [key, [, title, perm, ic, group]] of Object.entries(ROUTES)) {
    if (group && session.can(perm)) (groups[group] ||= []).push([key, title, ic]);
  }
  mount(app, h`<aside class="sidebar" id="side">
      ${logoMark()}<div class="side-tag">Control Centre</div>
      <nav class="nav" aria-label="Main">${Object.entries(groups).map(([g, items]) => h`<div class="nav-label">${g}</div>
        ${items.map(([k, t, ic]) => h`<a href="#/${k}" data-nav="${k}">${icon(ic)}<span>${t}</span>${k === 'tickets' ? h`<span class="count hidden" id="b-tickets"></span>` : ''}${k === 'moderation' ? h`<span class="count hidden" id="b-mod"></span>` : ''}</a>`)}`)}
      </nav>
      <div class="side-me"><div class="avatar">${me.initials}</div><div style="min-width:0;flex:1"><strong>${me.name}</strong><small>${me.role_label}</small></div></div>
      <nav class="nav" style="margin-top:6px"><a href="#/account" data-nav="account">${icon('key')}<span>My account</span></a>
        <a href="#" id="signout">${icon('out')}<span>Sign out</span></a></nav>
    </aside><div class="overlay" id="ov"></div>
    <div class="main"><header class="topbar"><button class="menu-btn" id="mb" aria-label="Open menu">${icon('menu')}</button>
      <div class="crumb">Exerlio / <b id="crumb"></b></div>
      <a class="btn light sm" href="#/tickets?assignee=me" title="Tickets assigned to me">${icon('ticket')}<span id="mine">My tickets</span></a></header>
      <main class="content" id="page" tabindex="-1"></main></div>`);
  $('#signout').onclick = (e) => { e.preventDefault(); signOut(); };
  const side = $('#side'), ov = $('#ov');
  $('#mb').onclick = () => { side.classList.add('open'); ov.classList.add('show'); };
  ov.onclick = () => { side.classList.remove('open'); ov.classList.remove('show'); };
  if (!session.can('tickets.view')) $('.topbar .btn').classList.add('hidden');
  refreshBadges();
  badgeTimer = setInterval(refreshBadges, 60000);
}

export async function refreshBadges(fresh) {
  try {
    const me = fresh || await api.get('admin/me/');
    session.me = { ...session.me, ...me };
    const set = (id, n) => { const b = $(id); if (b) { b.textContent = n; b.classList.toggle('hidden', !n); } };
    set('#b-tickets', me.open_tickets);
    set('#b-mod', session.can('moderation.view') ? me.open_reports : 0);
    const mine = $('#mine');
    if (mine) mine.textContent = me.my_tickets ? `My tickets (${me.my_tickets})` : 'My tickets';
  } catch { /* the page shows its own errors */ }
}

// ---------- router ----------
function parse() {
  const raw = location.hash.replace(/^#\/?/, '');
  const [path, query = ''] = raw.split('?');
  const parts = path.split('/').filter(Boolean);
  return { name: parts[0] || '', id: parts[1] || null, query: Object.fromEntries(new URLSearchParams(query)) };
}

async function route() {
  if (!session.me) return;
  const r = parse();
  const first = Object.keys(ROUTES).find((k) => ROUTES[k][4] && session.can(ROUTES[k][2])) || 'account';
  if (!ROUTES[r.name] || !session.can(ROUTES[r.name][2])) {
    if (r.name && ROUTES[r.name]) toast('Your role can’t open that page.', true);
    location.replace(`#/${first}`);
    return;
  }
  const [mod, title] = ROUTES[r.name];
  current?.cleanup?.();
  current = null;
  $$('[data-nav]').forEach((a) => a.classList.toggle('active', a.dataset.nav === r.name));
  $('#side')?.classList.remove('open');
  $('#ov')?.classList.remove('show');
  $('#crumb').textContent = title;
  document.title = `${title} · Exerlio Control Centre`;
  const old = $('#page');
  const page = old.cloneNode(false);
  old.replaceWith(page);
  mount(page, h`<div class="loading">Loading…</div>`);
  try {
    const m = await import(`./pages/${mod}.js`);
    const ctx = { root: page, id: r.id, query: r.query, session, cleanup: null };
    current = ctx;
    await m.render(ctx);
  } catch (e) {
    if (e?.status === 401) return;
    mount(page, h`<div class="card empty"><p>${e.message || 'This page failed to load.'}</p><button class="btn light sm" id="retry">Try again</button></div>`);
    $('#retry', page).onclick = route;
    if (!(e?.status)) console.error(e);
  }
  page.focus({ preventScroll: true });
  window.scrollTo(0, 0);
}

async function start() {
  shell();
  if (!location.hash || location.hash === '#') location.replace('#/overview');
  await route();
}

api.onAuthLost = (msg) => { api.token = null; store.del('cc.token'); session.me = null; showLogin(msg); };
api.onPasswordChange = () => showPasswordChange(true);
window.addEventListener('hashchange', route);
window.addEventListener('cc:badges', () => { if (session.me) refreshBadges(); });

(async function boot() {
  if (!api.token) return showLogin();
  try {
    session.me = await api.get('admin/me/');
    session.me.staff.must_change_password ? showPasswordChange(true) : start();
  } catch (e) {
    if (e.status !== 401) showLogin(e.message);
  }
}());

window.addEventListener('unhandledrejection', (e) => { if (e.reason?.status !== 401) fail(e.reason); });
