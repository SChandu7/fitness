import { $, api, confirm, debounce, h, modal, mount, num, pill, toast } from '../core.js';

export async function render(ctx) {
  const { root } = ctx;
  let d;
  async function load() {
    d = await api.get('admin/announcements/');
    mount(root, h`
      <div class="page-head"><div><div class="eyebrow">Messaging</div><h1>Announcements</h1>
        <div class="sub">Send a message to everyone or a group. It lands in their in-app Notifications.</div></div>
        <div class="actions"><button class="btn orange" id="new">New announcement</button></div></div>
      ${d.can_send ? '' : h`<div class="notice gray">You can write drafts. An owner or admin reviews and sends them.</div>`}
      <section class="card flush">${d.items.length ? h`<div class="table-wrap"><table><thead><tr><th>Announcement</th><th>Audience</th><th>Status</th><th>Created</th><th></th></tr></thead>
        <tbody>${d.items.map((a) => h`<tr><td style="white-space:normal;max-width:420px"><b>${a.title}</b><div class="small muted">${a.body}</div></td>
          <td class="small">${a.audience_label}</td>
          <td>${pill(a.status, a.status === 'sent' ? `Sent to ${num(a.recipients)}` : 'Draft')}${a.sent ? h`<div class="small muted">${a.sent.rel} by ${a.sent_by}</div>` : ''}</td>
          <td class="small">${a.created.rel}<div class="muted">${a.created_by}</div></td>
          <td>${a.status === 'draft' ? h`<div class="row">${d.can_send ? h`<button class="btn orange sm" data-send="${a.id}">Send</button>` : ''}
            <button class="btn light sm" data-del="${a.id}">Delete</button></div>` : ''}</td></tr>`)}</tbody></table></div>`
        : h`<div class="empty">No announcements yet.</div>`}</section>`);
  }
  root.addEventListener('click', async (e) => {
    if (e.target.closest('#new')) return create();
    const s = e.target.closest('[data-send]'), x = e.target.closest('[data-del]');
    if (s) {
      const a = d.items.find((i) => i.id === Number(s.dataset.send));
      const n = (await api.get(`admin/announcements/?preview=${a.audience}&value=${encodeURIComponent(a.audience_value)}`)).count;
      if (!await confirm('Send announcement?', `"${a.title}" goes to ${num(n)} people (${a.audience_label}). This can't be undone.`, `Send to ${num(n)}`)) return;
      try { const r = await api.post(`admin/announcements/${a.id}/`); toast(r.message); load(); } catch (err) { toast(err.message, true); }
    }
    if (x) {
      if (!await confirm('Delete draft?', 'The draft is removed for good.', 'Delete', true)) return;
      await api.del(`admin/announcements/${x.dataset.del}/`);
      toast('Draft deleted');
      load();
    }
  });
  async function create() {
    const r = await modal({
      title: 'New announcement', save: 'Save draft',
      body: h`<div class="field"><label for="at">Title</label><input class="input" id="at" maxlength="80" placeholder="e.g. New: support chat"></div>
        <div class="field"><label for="ab">Message</label><textarea class="input" id="ab" maxlength="200" placeholder="Short and useful. Up to 200 characters."></textarea></div>
        <div class="grid g2"><div class="field"><label for="aa">Who gets it</label><select class="select" id="aa">${d.audiences.map((a) => h`<option value="${a.key}">${a.label}</option>`)}</select></div>
          <div class="field hidden" id="gf"><label for="ag">Goal</label><select class="select" id="ag">${d.goals.map((g) => h`<option value="${g.key}">${g.label}</option>`)}</select></div></div>
        <p class="small muted" id="cnt">Counting…</p>`,
      onOpen: (m) => {
        const count = debounce(async () => {
          $('#gf', m).classList.toggle('hidden', $('#aa', m).value !== 'goal');
          try {
            const n = (await api.get(`admin/announcements/?preview=${$('#aa', m).value}&value=${$('#ag', m).value}`)).count;
            $('#cnt', m).textContent = `${num(n)} people will get it (demo and suspended accounts left out).`;
          } catch { $('#cnt', m).textContent = ''; }
        }, 150);
        $('#aa', m).onchange = count;
        $('#ag', m).onchange = count;
        count();
      },
      onSave: async (m) => api.post('admin/announcements/', { title: $('#at', m).value, body: $('#ab', m).value, audience: $('#aa', m).value, audience_value: $('#ag', m).value }),
    });
    if (r) { toast('Draft saved'); load(); }
  }
  await load();
}
