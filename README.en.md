# D2 Survivors QoL Patch (D2S-MyPatch)

[한국어](README.md) | **English**

**Current patch: v1.61 · for game build 2026.1101.1** (previous build 2026.1030.2 also works)

<!-- notes -->
### Latest changes v1.61
- AFK 중에는 F키 말고 다른 키가 게임에 안 넘어감 (I · C · B 등이 눌려 인벤 창이 열리고 게임이 멈추던 문제)
- AFK 화면에 "티리엘 나오면 정지" 체크 (기본 꺼짐): 켜면 티리엘 등장(파편 10개 + 5막 보스 처치) 때 포털 자동 입장 안 함, 소리, AFK 중이면 자동 정지

<details><summary>Earlier changes (expand)</summary>

**v1.60**
- AFK 자동 정지: AFK 화면에서 시간(분, 0 = 무제한)과 꽉 참(인벤 · 개인 창고 · 공유 1 · 2 · 3 중 체크한 곳이 전부 꽉 차면) 설정. 정지하면 소리 + 게임 일시정지, 클리어 후 자동 진행도 멈춤
- AFK 기록 이어가기: 체크하면 AFK를 끄고 다시 켜도 게임 켠 뒤부터 합산 (끄면 켤 때마다 새로 시작)
- 드롭 알림 소리: F2에서 인벤 · 창고로 정한 아이템을 주우면 소리 (창고 3음, 인벤 2음). 패치 창 기능에서 끄기 가능
- 획득 · 판매 통계 창 (F1): 이번 실행 · 오늘 따로, 등록 · 교체 · 인벤 · 창고 · 판매 개수, 판매 골드, 판 수, 시간당
- F2 보관 설정 프리셋: 1 ~ 3번 칸에 지금 설정 저장 / 적용
- 세이브 자동 백업: 게임 켜고 1분 뒤 + 30분마다 %APPDATA%\D2S-MyPatch\backup (최근 48개). 패치 창 [세이브 백업 폴더], 복원은 게임 설정의 저장 데이터 가져오기
- 패치 창 [설정 내보내기] / [설정 가져오기]: 기능 체크 · 조절값 · 보관 설정을 파일 하나로
- 패치 창 위쪽에 마지막 패치 시각 · 적용 기능 수 · 안 된 기능 표시
- 빛의 파편 안내 (퀘스트 부서진 빛): 나타나기 전엔 남은 초, 나타나면 소리 + 캐릭터 주변에 깜빡이는 방향 화살표 · 거리 · 몬스터가 지키는지 표시 (AFK 화면 위에도)
- 설명서(F6) · 패치 창 단축키 상자에 F1 추가, 룬워드 한손 우선 설명 고침

**v1.59**
- 룬워드 교체 한손 우선: 무기 종류 상관없이 양손 등록본은 한손이 들어오면 교체, 한손 등록본은 양손으로 안 바꿈 (같은 손끼리는 옵션 비교)
- 비교: 옵션 총합이 같으면 바탕 방어력이 높은 쪽으로 교체 (전에는 같으면 중복으로 보고 판매)
- [판매] 이유 문구 정확히: "옵션 같음 · 바탕 방어력 낮음 (a < b)", "등록본과 같음 (중복) · F2에서 판매"
- 드롭 계산기(F3): 진행 중인 판의 공포 단계를 기본값으로 (마을에서는 마지막에 넣은 값), 검색할 때 이름과 확률이 붙어 보이던 문제 수정

**v1.58**
- 패치 창을 디아블로풍으로: 게임 메뉴 그림 배너 · 금색 제목, 어두운 배경, 게임 돌 버튼, 탭 · 표 · 입력칸 어두운 색 (게임 그림이 없으면 색만)
- 기능 탭 스크롤 없이 한 화면: 기능 · 조절값을 같은 폭의 상자(금색 테두리 · 제목 띠)에 2열로, 조절값 입력칸 줄 맞춤
- 보관 설정 탭: 맨 앞 선택 칸, 전체 선택 / 전체 해제(보이는 줄), "체크한 줄을 [인벤 · 판매 · 창고] (으)로 적용", 구분 · 검색 · 설정 필터(인벤만 · 판매만 · 창고만)
- 패치 창 배너에 움직이는 Diablo II 불꽃 로고 (게임 타이틀 그림), 인게임 단축키 상자, GitHub 버튼
- 패치 창 제목줄 · 선택칸 · 패치 기록 스크롤바 어두운 색
- 패치 창 언어 판별을 여러 값으로 (가끔 영어로 뜨던 문제)

**v1.57**
- 보관 설정: 옵션을 게임 옵션표의 옵션 하나하나로 나눔 (직업별 스킬 · 스킬 트리별 · 모든/화염/냉기/번개/독 저항 · 피해 종류별 · 속도별 · 능력치별 …), 이름은 게임 문구 그대로, 그 부위에 안 붙는 옵션은 없앰
- 모든 저항은 네 저항이 같이 붙은 공통값으로 따로 판정 (예: 작은 부적 모든 저항 3~5, 개별 저항 3~11)
- 부위 안의 옵션을 계열별로 접기 (스킬 · 저항 · 생명력/마나 · 능력치 · 피해 · 공격/흡수 · 방어 · 속도 · 매찬/골드 · 기타), 접힌 제목에 판매 아닌 설정 요약
- 룬워드 · 유니크 · 세트마다 변동 옵션(최소~최대) 표시, 옵션별 "이상 적용": 하나라도 못 미치면 판매
- 패치 창 보관 설정 탭에도 같은 목록 (변동 옵션 줄 포함)
- 예전 묶음 설정(스킬 · 저항 등)은 새 칸의 기본값으로 이어받음
- F2 검색: 아이템 이름(한글 · 영어), 옵션 줄, 룬워드 · 유니크 · 세트의 변동 옵션 줄까지 찾고, 찾은 것이 있는 묶음만 펼침 (띄어쓰기 무시: 공격속도 = 공격 속도, 패치 창 탭도 같음)
- 보관 설정에 "기타 › 호라드림의 고서" 추가 (판매 / 인벤 / 창고, 기본 판매)
- 보관 설정 "기타"에 퀘스트 아이템 9종 (기술 책 · 람 에센의 고서 · 생명력 물약 · 저항의 두루마리 · 면죄의 징표 · 호라드림 망치 · 호라드림의 두루마리 · 이니푸스의 두루마리 · 돌무덤 열쇠): 인벤 / 창고 (팔 수 없어 판매는 인벤으로)
- 유니크 부적(기드의 행운 등)은 "부적 › 유니크 부적"으로 옮김 (부적 바탕 유니크는 자동으로 여기에)

**v1.56**
- 보관 설정(F2 · 패치 창 탭): 옵션마다 그 부위에 붙을 수 있는 수치 범위 표시 (게임 옵션표 기준, 예: 작은 부적 저항 3~11), 그 부위에 안 붙는 옵션 줄은 숨김

</details>
<!-- /notes -->

An unofficial quality-of-life patch that makes farming in D2 Survivors much easier.
A **single bat file** handles feature selection, patching, restoring the original, and auto-updates.
The patch UI follows your Windows language (Korean / English).

> ⚠ While patched, your runs are **not sent to the leaderboard**. Restore the original before playing for the leaderboard.
> This is an unofficial patch. Back up your save (`%APPDATA%\D2 Survivors\save`) before first use.

## Download / Install

1. **[Download D2S-MyPatch.bat](https://github.com/mastree-master/D2S-MyPatch/raw/main/D2S-MyPatch.bat)** (save it anywhere and keep it there)
2. Close the game and run the bat → if "Windows protected your PC" appears, click **More info → Run anyway**
3. Check the features you want → **Apply checked** → start the game

To undo: run the bat → **Restore original**.

![Feature selection](docs/launcher.png)

## Auto-update

When a new version is released, a notice appears at the bottom right of the game. Click it → **Yes**: the game closes, the patcher opens, and the game restarts after applying.
If the game itself updates, the patch is removed automatically. Run the bat again and it **re-applies only what still works** on the new game version and tells you what doesn't.

![Update notice](docs/update-notice.png)

## Main features

![In game](docs/play.webp)
Top bar (version · enabled features · speed · FPS), HUD layout top-left, run info top-right, pickup log and upgrade popup

### Automatic item handling
- Items, gold and chests are picked up instantly at any distance
- New uniques / sets / runewords are **auto-stashed**; better copies **auto-upgrade** (skills > aura/proc > other stats > defense)
- Runewords only upgrade within the same weapon type, one-handed preferred, duplicates sorted per type
- Charms with skills go to the stash, everything else is auto-sold
- When the inventory is full, items go to the stash

### Pickup log (chat style)
- Time · stashed / upgraded / bag / stash / sold, scroll back with the mouse wheel
- Hover a line for item stats (game colors); upgrades show **only changed stats, old (red) → new (green)**
- Unique/set upgrades can be undone
- Drag to move, resize from the corner

![Item stats on hover](docs/log-hover.webp)

### AFK mode (F8)
Black screen showing only elapsed time · game time · runs · wave · gold · stashed/upgraded/kept/sold counts. Keeps running when minimized.

![AFK mode](docs/afk.webp)

### Runeword list (F4)
Every runeword read from the game data: runes · level · item types, **fixed stats (grey) / variable stats min~max (yellow)**, search.

![Runeword list](docs/runewords.webp)

### More
- Auto-enter portal; after a clear, repeat the same tier or go up one tier
- Game speed 1 / 1.5 / 2 / 3x (F7)
- Character / inventory / skill panels don't pause the game, B opens the stash, Ctrl+click sends to stash
- Compare boxes next to tooltips show where copies are; hidden values shown. Hold **Shift** to list every copy (stash / personal / shared tabs / inventory)
- Brightness / contrast (PageUp·PageDown / Home·End), hide corpses, render resolution, FPS display (F9) and cap
- HUD layout: pets and skills one row each top-left, run info top-right
- Top bar shows version · game build · enabled features (✓/✗)

### Compare boxes · Stash
![Find runeword copies (Shift)](docs/shift-compare.webp)
![B stash](docs/stash.webp)

### Guide (F6) · Patch log (F10)
![Guide](docs/guide.webp)
![Patch log](docs/patchlog.webp)

## Hotkeys

| Key | Action |
|---|---|
| F6 | Guide |
| F4 | Runeword list |
| F3 | Drop chance calculator |
| F1 | Loot · sales stats (this session / today) |
| F2 | Keep settings (sell / bag / stash per item, registered count) |
| F10 | Patch log |
| F7 | Game speed |
| F8 | AFK mode |
| F9 | FPS display |
| Shift (over an item) | Show every copy |
| B | Stash |
| Ctrl+click | Send inventory item to stash |
| PageUp / PageDown | Brightness |
| Home / End | Contrast |

## Font (optional)
Put `kodia.ttf` next to the bat and patch to replace the game font with it. (Font not included.)

## Notes
- Game numbers (damage, gold, stats) are not changed. Game speed only makes runs go faster.
- Screenshots show the Korean UI.
