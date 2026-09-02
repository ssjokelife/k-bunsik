// cloud.js — 팀 공유(Supabase) 선택적 동기화.
// sb_config(localStorage: {url, key})가 있으면 supabase-js를 동적 로드해 제출/응시를 클라우드에 기록·조회.
// 미설정이면 모든 호출이 no-op → 기존 로컬 저장만 동작(폴백). 실패는 조용히 무시(교육 도구 신뢰성).
const Cloud = (() => {
  let cfg = null, client = null;
  try { cfg = JSON.parse(localStorage.getItem('sb_config') || 'null'); } catch (e) {}
  const enabled = () => !!(cfg && cfg.url && cfg.key);
  async function conn() {
    if (!enabled()) return null;
    if (client !== null) return client;               // false = 로드 실패 캐시
    try {
      const m = await import('https://esm.sh/@supabase/supabase-js@2');
      client = m.createClient(cfg.url, cfg.key);
    } catch (e) { client = false; }
    return client || null;
  }
  return {
    enabled,
    async saveSubmission(row) { try { const c = await conn(); if (c) await c.from('consol_submissions').insert(row); } catch (e) {} },
    async saveAttempt(row)    { try { const c = await conn(); if (c) await c.from('consol_attempts').insert(row); } catch (e) {} },
    async leaderboard(caseIdx) {
      try { const c = await conn(); if (!c) return null;
        const { data } = await c.from('consol_leaderboard').select('*').eq('case_idx', caseIdx).order('best_margin', { ascending: false }).limit(10);
        return data || null;
      } catch (e) { return null; }
    },
    async caseStats() {
      try { const c = await conn(); if (!c) return null;
        const { data } = await c.from('consol_case_stats').select('*');
        return data || null;
      } catch (e) { return null; }
    },
  };
})();
window.Cloud = Cloud;
