// cloud.js — 팀 공유(Supabase) 선택적 동기화.
// sb_config(localStorage: {url, key})가 있으면 supabase-js를 동적 로드해 제출/응시를 클라우드에 기록·조회.
// 미설정이면 모든 호출이 no-op → 기존 로컬 저장만 동작(폴백). 실패는 조용히 무시(교육 도구 신뢰성).
// 팀 기본 서버(방과후 콘솔 아카데미). anon 키는 공개용(프런트 노출 전제) — RLS로 보호.
// 다른 팀/프로젝트로 쓰려면 아카데미 ☁ 설정에서 override(localStorage sb_config).
const DEFAULT_CFG = {
  url: 'https://iwslrkoonyxyausvclxv.supabase.co',
  key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3c2xya29vbnl4eWF1c3ZjbHh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwNTQyNDcsImV4cCI6MjA4OTYzMDI0N30.6gyJ5TW61-P9twYyoZZ9u6iqOfd7hk34w-xHPiwLog0',
};
const Cloud = (() => {
  let cfg = null, client = null;
  try { cfg = JSON.parse(localStorage.getItem('sb_config') || 'null'); } catch (e) {}
  if (!cfg || !cfg.url || !cfg.key) cfg = DEFAULT_CFG;   // 설정 없으면 팀 기본 서버
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
  const S = 'consoltrain';   // 전용 스키마 (대시보드 Exposed schemas에 추가 필요)
  return {
    enabled,
    async saveSubmission(row) { try { const c = await conn(); if (c) await c.schema(S).from('submissions').insert(row); } catch (e) {} },
    async saveAttempt(row)    { try { const c = await conn(); if (c) await c.schema(S).from('attempts').insert(row); } catch (e) {} },
    async leaderboard(caseIdx) {
      try { const c = await conn(); if (!c) return null;
        const { data } = await c.schema(S).from('leaderboard').select('*').eq('case_idx', caseIdx).order('best_margin', { ascending: false }).limit(10);
        return data || null;
      } catch (e) { return null; }
    },
    async caseStats() {
      try { const c = await conn(); if (!c) return null;
        const { data } = await c.schema(S).from('case_stats').select('*');
        return data || null;
      } catch (e) { return null; }
    },
    async saveAiRuns(rows) { try { const c = await conn(); if (c && rows && rows.length) await c.schema(S).from('ai_runs').insert(rows); } catch (e) {} },
    async aiBaseline() {
      try { const c = await conn(); if (!c) return null;
        const { data } = await c.schema(S).from('ai_baseline').select('*');
        return data || null;
      } catch (e) { return null; }
    },
  };
})();
window.Cloud = Cloud;
