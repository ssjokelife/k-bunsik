// 🧩 장날 모드 — 데모 (제안 원문: "지방엔 5일장이 있잖아. 장날엔 어르신들이 몰려와")
// 규칙: 끝자리 2·7일 = 장날. 장터 인파로 어르신·주민 수요 ×2.5, 대신 노점 자릿세 30,000원.
// 작성: Claude (방과후 스튜디오) · 요청자: 데모
(function () {
  const isJangnal = () => { const c = calInfo(S.day); return c.d % 5 === 2; };   // 2·7·12·17·22·27일
  modOn('dawn', () => {
    if (!isJangnal()) return;
    S.money = Math.max(0, S.money - 30000); S.led.spend += 30000;
    news('🧺 오늘은 장날!! 장터 인파가 골목까지 넘친다 — 노점 자릿세 30,000원');
  });
  modOn('pool', p => {
    if (isJangnal()) p.locals = Math.round(p.locals * 2.5);
    return p;
  });
})();
