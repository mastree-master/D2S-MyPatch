<!-- 1.60 편의 기능 작업 중 내린 결정과 이유 -->
# 1.60 작업 메모

- 4번(판매 기록 + 다시 사기)은 만들지 않음: 게임에 마을 상점 "되사기(B)"가 이미 있음 (Game buyBackPage).
- AFK 정지 조건은 AFK 화면 안에서 설정 (localStorage `d2s:afkstop`): 다시 패치할 필요 없이 바로 바꿈.
  - 꽉 참 판정: 1x1 가짜 아이템({base:'?'})이 안 들어가면 꽉 참. TZ()가 모르는 base는 [1,1].
  - 인벤 = inventoryByClass[cls] + 인벤 격자, 창고 = $tabs(personal + 공유 탭) 전부 + 창고 격자.
  - 정지 = AFK 화면에 이유 표시 + 소리 + 게임 일시정지(__gm.pause()).
- 드롭 알림: carry 성공 후 __ksv(e)가 1(인벤) 또는 3(창고)이면 WebAudio로 만든 소리 (파일 없음). 창고·인벤 소리 다르게.
- 세이브: 게임은 localStorage `d2-survivors/save/v1`이 본체, `%APPDATA%\D2 Survivors\save\save.json`은 사본(localStorage가 비었을 때만 읽음).
  - 그래서 백업은 save.json 파일 복사, 복원은 게임 자체 "가져오기"를 사용 (직접 localStorage 쓰기는 seal 문제 위험).
