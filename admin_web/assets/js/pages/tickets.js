import { $, api, debounce, fail, h, modal, mount, num, pager, pill, qs, refreshBadgesSafe, toast } from '../core.js';

export async function render(ctx) {
  const { root, session } = ctx;
  const f = { status: ctx.query.status || 'active', assignee: ctx.query.assignee || '', priority: '', category: '', q: '', sort: '', page: 1 };
  let selected = ctx.id ? Number(ctx.id) : null;
  let meta = null;
  const canManage = session.can('tickets.manage');

  mount(root, h`
    <div class="page-head"><div><div class="eyebrow">Support</div><h1>Support tickets</h1>
      <div class="sub">Questions and problems sent from the app. Replies reach the user as a notification.</div></div>
      <div class="actions">${canManage ? h`<button class="btn orange" id="new">New ticket</button>` : ''}</div></div>
    <div class="grid g4" id="stats"></div>
    <div class="tk-layout mt">
      <section class="card flush">
        <div style="padding:12px 12px 0" class="toolbar">
          <input class="input search" id="q" placeholder="Search subject, user or EX-number" aria-label="Search tickets" style="flex:1 1 100%">
          <select class="select" id="fs" aria-label="Status"></select>
          <select class="select" id="fa" aria-label="Assignee"><option value="">Anyone</option><option value="me">Assigned to me</option><option value="none">Unassigned</option></select>
          <select class="select" id="fp" aria-label="Priority"><option value="">Any priority</option></select>
        </div>
        <div class="tk-list" id="list"><div class="loading">Loading…</div></div><div id="pg"></div>
      </section>
      <section class="card" id="pane"><div class="empty">Pick a ticket to read the conversation.</div></section>
    </div>`);

  const listBox = $('#list', root), pane = $('#pane', root);

  async function loadList(keepScroll) {
    const top = listBox.scrollTop;
    try {
      const d = await api.get(`admin/tickets/?${qs(f)}`);
      meta = d;
      if (!$('#fs', root).options.length) {
        mount($('#fs', root), h`<option value="active">All active</option>${d.statuses.map((s) => h`<option value="${s.key}">${s.label}</option>`)}<option value="all">Everything</option>`);
        $('#fs', root).value = f.status;
        $('#fa', root).value = f.assignee;
        mount($('#fp', root), h`<option value="">Any priority</option>${d.priorities.map((p) => h`<option value="${p.key}">${p.label}</option>`)}`);
      }
      const c = d.counts;
      mount($('#stats', root), h`${[['Open', c.open + c.in_progress + c.escalated, 'Needs the team'], ['Waiting on users', c.waiting, 'We replied, they haven’t'],
        ['Unassigned', d.unassigned, 'Pick one up'], ['Resolved today', d.resolved_today, 'Nice work']].map(([l, v, ft]) =>
        h`<div class="stat"><div class="label">${l}</div><div class="value">${num(v)}</div><div class="foot">${ft}</div></div>`)}`);
      mount(listBox, d.items.length ? h`${d.items.map((t) => h`<div class="tk-row ${t.id === selected ? 'on' : ''}" data-id="${t.id}" tabindex="0">
          <div class="row between"><span class="t">${t.subject}</span>${pill(t.status, t.status_label)}</div>
          <div class="m"><span class="mono">${t.number}</span><span>${t.user ? t.user.name : 'No app user'}</span><span>${t.updated.rel}</span>
            ${t.priority === 'urgent' || t.priority === 'high' ? pill(t.priority, t.priority_label) : ''}
            ${t.awaiting_first_reply ? h`<span class="pill red">No reply · ${Math.round(t.age_hours)}h</span>` : ''}
            ${t.assignee ? h`<span>→ ${t.assignee.name.split(' ')[0]}</span>` : h`<span class="muted">Unassigned</span>`}</div></div>`)}`
        : h`<div class="empty">No tickets here. ${f.status === 'active' ? 'The queue is clear.' : ''}</div>`);
      mount($('#pg', root), '');
      if (d.pages > 1) {
        $('#pg', root).appendChild(pager(d, (p) => { f.page = p; loadList(); }));
      }
      if (keepScroll) listBox.scrollTop = top;
    } catch (e) { mount(listBox, h`<div class="empty">${e.message}</div>`); }
  }

  async function open(id) {
    selected = id;
    listBox.querySelectorAll('.tk-row').forEach((r) => r.classList.toggle('on', Number(r.dataset.id) === id));
    if (location.hash !== `#/tickets/${id}`) history.replaceState(null, '', `#/tickets/${id}`);
    mount(pane, h`<div class="loading">Loading…</div>`);
    let d;
    try { d = await api.get(`admin/tickets/${id}/`); } catch (e) { return mount(pane, h`<div class="empty">${e.message}</div>`); }
    const t = d.ticket;
    const opts = (list, cur) => list.map((o) => h`<option value="${o.key}" ${o.key === cur ? 'selected' : ''}>${o.label}</option>`);
    mount(pane, h`
      <div class="row between wrap"><div><div class="eyebrow mono">${t.number} · ${t.category_label}</div>
        <h2 style="margin:4px 0 2px;font-size:18px;letter-spacing:-.02em">${t.subject}</h2>
        <div class="small muted">Opened ${t.created.label}${t.source === 'admin' ? ' by the team' : ' from the app'}${t.platform ? ` · ${t.platform} ${t.app_version}` : ''}</div></div>
        ${pill(t.status, t.status_label)}</div>
      <div class="grid" style="grid-template-columns:minmax(0,1fr) 230px;gap:16px;align-items:start;margin-top:8px" id="tkgrid">
        <div>
          <div class="thread">${d.messages.map((m) => h`<div class="msg ${m.internal ? 'note' : m.from_team ? 'team' : 'user'}">
              <div class="who">${m.internal ? 'Internal note · ' : ''}${m.author} · ${m.time.rel}</div><div class="text">${m.body}</div></div>`)}</div>
          <div class="seg" id="mode" style="margin-bottom:8px"><button class="on" data-m="reply" ${t.user ? '' : 'disabled'}>Reply to user</button><button data-m="note">Internal note</button></div>
          <textarea class="input" id="body" placeholder="${t.user ? 'Write to the user. Be clear and kind; they see this in the app.' : 'Notes are visible to the team only.'}"></textarea>
          <div class="row wrap" style="margin-top:8px"><span id="after" class="row small"><span class="muted">Then</span>
            <select class="select" id="next"><option value="waiting">Wait for their reply</option><option value="in_progress">Keep working on it</option><option value="resolved">Mark resolved</option></select></span>
            <span class="spacer" style="flex:1"></span><button class="btn orange" id="send">Send reply</button></div>
          <p class="small muted" id="hint" style="margin-top:6px">${t.user ? 'Replies reach the user as a notification and in Settings → Support.' : 'No app user on this ticket, so only internal notes are possible.'}</p>
        </div>
        <aside class="tk-side">
          ${t.user ? h`<div class="card" style="padding:12px"><div class="eyebrow">Customer</div>
            <a href="#/users/${t.user.id}" style="text-decoration:none;display:block;margin-top:6px"><b>${t.user.name}</b><div class="small muted">@${t.user.handle}<br>${t.user.email || ''}</div></a>
            <div class="small muted" style="margin-top:6px">${d.user_detail.platform ? `${d.user_detail.platform} ${d.user_detail.version} · ` : ''}${d.other_tickets} other ticket${d.other_tickets === 1 ? '' : 's'}</div></div>` : ''}
          <div class="field" style="margin:0"><label>Status</label><select class="select" data-k="status" ${canManage ? '' : 'disabled'}>${opts(meta?.statuses || [], t.status)}</select></div>
          <div class="field" style="margin:0"><label>Priority</label><select class="select" data-k="priority" ${canManage ? '' : 'disabled'}>${opts(meta?.priorities || [], t.priority)}</select></div>
          <div class="field" style="margin:0"><label>Assigned to</label><select class="select" data-k="assignee" ${canManage ? '' : 'disabled'}><option value="">Nobody</option>
            ${(meta?.team || []).map((s) => h`<option value="${s.id}" ${t.assignee && t.assignee.id === s.id ? 'selected' : ''}>${s.name}</option>`)}</select></div>
          <div class="field" style="margin:0"><label>Category</label><select class="select" data-k="category" ${canManage ? '' : 'disabled'}>${opts(meta?.categories || [], t.category)}</select></div>
          ${canManage ? '' : h`<p class="small muted" style="margin:0">Your role can reply and add notes. An admin or support lead changes status and assignment.</p>`}
        </aside></div>`);
    if (window.innerWidth < 1100) $('#tkgrid', pane).style.gridTemplateColumns = 'minmax(0,1fr)';
    const thread = $('.thread', pane);
    thread.lastElementChild?.scrollIntoView({ block: 'nearest' });
    let mode = t.user ? 'reply' : 'note';
    const setMode = (m) => {
      mode = m;
      pane.querySelectorAll('#mode button').forEach((b) => b.classList.toggle('on', b.dataset.m === m));
      $('#after', pane).classList.toggle('hidden', m === 'note');
      $('#send', pane).textContent = m === 'note' ? 'Add note' : 'Send reply';
    };
    setMode(mode);
    $('#mode', pane).onclick = (e) => { const b = e.target.closest('[data-m]'); if (b && !b.disabled) setMode(b.dataset.m); };
    $('#send', pane).onclick = async (e) => {
      const body = $('#body', pane).value.trim();
      if (!body) return toast('Write something first.', true);
      e.target.disabled = true;
      try {
        const r = await api.post(`admin/tickets/${id}/reply/`, { body, internal: mode === 'note', status: $('#next', pane).value });
        toast(r.message);
        await Promise.all([open(id), loadList(true)]);
        refreshBadgesSafe();
      } catch (err) { fail(err); e.target.disabled = false; }
    };
    pane.querySelectorAll('select[data-k]').forEach((sel) => {
      sel.onchange = async () => {
        try {
          await api.patch(`admin/tickets/${id}/`, { [sel.dataset.k]: sel.value ? (sel.dataset.k === 'assignee' ? Number(sel.value) : sel.value) : null });
          toast('Saved');
          await Promise.all([open(id), loadList(true)]);
          refreshBadgesSafe();
        } catch (err) { fail(err); open(id); }
      };
    });
  }

  listBox.addEventListener('click', (e) => { const r = e.target.closest('.tk-row'); if (r) open(Number(r.dataset.id)); });
  listBox.addEventListener('keydown', (e) => { const r = e.target.closest('.tk-row'); if (r && e.key === 'Enter') open(Number(r.dataset.id)); });
  const reload = () => { f.page = 1; loadList(); };
  $('#q', root).addEventListener('input', debounce((e) => { f.q = e.target.value.trim(); f.status = e.target.value.trim() ? 'all' : $('#fs', root).value; reload(); }));
  $('#fs', root).onchange = (e) => { f.status = e.target.value; reload(); };
  $('#fa', root).onchange = (e) => { f.assignee = e.target.value; reload(); };
  $('#fp', root).onchange = (e) => { f.priority = e.target.value; reload(); };
  $('#new', root)?.addEventListener('click', async () => {
    const r = await modal({
      title: 'New ticket', save: 'Create',
      body: h`<div class="field"><label for="nu">App user · optional</label><input class="input" id="nu" placeholder="@handle, email or mobile"></div>
        <div class="field"><label for="ns">Subject</label><input class="input" id="ns" maxlength="140"></div>
        <div class="grid g2"><div class="field"><label for="nc">Category</label><select class="select" id="nc">${(meta?.categories || []).map((c) => h`<option value="${c.key}">${c.label}</option>`)}</select></div>
        <div class="field"><label for="np">Priority</label><select class="select" id="np">${(meta?.priorities || []).map((p) => h`<option value="${p.key}" ${p.key === 'medium' ? 'selected' : ''}>${p.label}</option>`)}</select></div></div>
        <div class="field"><label for="nm">What happened</label><textarea class="input" id="nm" placeholder="Saved as an internal note. Reply to the user from the ticket."></textarea></div>`,
      onSave: async (b) => api.post('admin/tickets/', { user: $('#nu', b).value, subject: $('#ns', b).value, category: $('#nc', b).value, priority: $('#np', b).value, message: $('#nm', b).value }),
    });
    if (r?.ticket) { toast(`${r.ticket.number} created`); await loadList(); open(r.ticket.id); }
  });

  await loadList();
  if (selected) open(selected);
  const timer = setInterval(() => { if (!document.hidden) loadList(true); }, 30000);
  ctx.cleanup = () => clearInterval(timer);
}
