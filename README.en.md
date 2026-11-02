# D2 Survivors QoL Patch (D2S-MyPatch)

[한국어](README.md) | **English**

**Current patch: v1.63 · for game build 2026.1102.2** (previous builds 2026.1102.1 · 2026.1101.1 · 2026.1030.2 also work)

<!-- notes -->
### Latest changes v1.63
**게임 버전**

- 게임 빌드 2026.1102.2 대응 (이전 빌드 1102.1 · 1101.1 · 1030.2도 사용 가능)

**새 기능**

- 창고 정리 (F5): 개인 · 공유 1~3 중 체크한 탭을 종류별 · 같은 아이템끼리 · 등급별 · 크기순으로 정리, 되돌리기 지원
- 정리 배치 방식 선택: 앞 탭부터 채우기 / 종류별로 탭 나누기 / 탭마다 따로 정리
- 창고 가로 채우기 (F5): 오른쪽으로 채우고 줄이 차면 다음 줄로 (Ctrl+클릭 · 자동 보관 · 정리에 적용)
- 툴팁 F2 판정: 아이템을 주우면 어디로 가는지(등록 · 교체 · 인벤 · 창고 · 판매)와 그 이유 표시
- 단축키 변경 (F5): F1~F10 · B 키를 원하는 키로
- 획득 목록 검색

**개선**

- F5에서 자동 진행 대기 시간 · 같은/다음 단계 · 밝기 · 명암 바로 조절 (패치 창과 연동)
- 창고 정리 전후 아이템을 대조해 하나라도 다르면 자동으로 원래대로 복구

<details><summary>Earlier changes (expand)</summary>

**v1.62**
**새 기능**

- 게임 안에서 기능 켜기 · 끄기 (F5): 재시작 없이 바로 적용 (글꼴 제외), 패치 창과 자동 연동
- 획득 목록 분류 탭: 전체 / 등록 / 교체 / 인벤 / 창고 / 판매

**변경**

- "스킬 부적은 무조건 창고로" 삭제 (F2 부적 설정으로 통합)
- 기능 설명 문구 정리

**수정**

- 패치 창 기능 목록이 잘리거나 테두리가 가려지던 문제

**v1.61**
**게임 버전**

- 게임 빌드 2026.1102.1 대응

**새 기능**

- 티리엘 등장 시 멈춤 (패치 창, 기본 꺼짐): 포털 자동 입장 중지 + 알림음, AFK 중이면 자동 정지

**수정**

- AFK 중 다른 키가 눌려 인벤 창이 열리고 게임이 멈추던 문제
- F4 룬워드 목록 · F2 옵션 이름이 영문 내부 이름으로 나오던 문제

**v1.60**
**새 기능**

- AFK 자동 정지: 지정 시간(0 = 무제한)이 지나거나 선택한 인벤 · 창고가 모두 차면 정지 + 알림음
- AFK 기록 이어가기 선택
- 드롭 알림음: F2에서 인벤 · 창고로 정한 아이템을 주우면 소리
- 통계 창 (F1): 이번 실행 · 오늘 기준 등록 · 교체 · 보관 · 판매 개수, 골드, 시간당 수치
- F2 보관 설정 프리셋 3칸
- 세이브 자동 백업 (30분마다, 최근 48개)
- 패치 창 설정 내보내기 / 가져오기
- 빛의 파편 안내: 등장까지 남은 시간, 등장하면 알림음 + 방향 화살표 · 거리 표시

**개선**

- 패치 창에 마지막 패치 시각과 적용 결과 표시

**v1.59**
**개선**

- 룬워드 교체 시 한손 무기를 양손보다 우선
- 옵션이 같으면 바탕 방어력이 높은 쪽으로 교체
- 판매 이유 문구를 더 정확하게

**수정**

- 드롭 계산기(F3): 진행 중인 공포 단계를 기본값으로, 검색 결과에서 이름과 확률이 붙어 보이던 문제

**v1.58**
**개선**

- 패치 창을 디아블로 스타일로 새 단장 (배너 · 불꽃 로고 · 어두운 테마)
- 기능 탭을 스크롤 없이 한 화면에
- 보관 설정 탭: 선택 칸 · 전체 선택/해제 · 일괄 적용 · 필터
- 인게임 단축키 안내 상자, GitHub 버튼 추가

**수정**

- 패치 창이 가끔 영어로 뜨던 문제

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
| F5 | Features on · off · settings · stash sort · hotkeys |
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
