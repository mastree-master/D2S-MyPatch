# D2 Survivors QoL Patch (D2S-MyPatch)

[한국어](README.md) | **English**

**Current patch: v1.65 · for game build 2026.1102.2** (previous builds 2026.1102.1 · 2026.1101.1 · 2026.1030.2 also work)

<!-- notes -->
### Latest changes v1.65
**새 기능**

- F2 보관 설정에 "그리고" 조건을 추가했습니다. 옵션 줄의 [+]로 함께 붙어 있어야 할 옵션을 최대 2개까지 고를 수 있습니다. (예: 거대 부적 스킬 + 생명력 30 이상만 창고)
- 창고 정리에 "최근 먹은 순" · "오래전 먹은 순"을 추가했습니다.
- 아이템 잠금을 추가했습니다. Alt+클릭으로 잠그면 창고 정리와 자동 교체에서 빠집니다.
- 판을 마치고 캠프 · 마을에 오면 창고를 자동으로 정리할 수 있습니다. (F5, 기본 꺼짐)
- 창고가 정한 만큼(50~100%) 차면 미리 알려 줍니다. (F5)
- 알림음을 상황별로 고르고 음량을 조절할 수 있습니다. (F5)
- 게임 창이 안 보일 때 AFK 정지 · 빛의 파편 · 티리엘 · 창고 꽉 참을 윈도우 알림으로 알려 줍니다.

**개선**

- 게임이 업데이트되면 설치가 끝난 뒤 저장된 설정으로 자동으로 다시 패치하고 게임을 켭니다.
- 게임 업데이트로 내부 이름이 바뀌어도 더 많은 기능이 그대로 동작하도록 고쳤습니다.

<details><summary>Earlier changes (expand)</summary>

**v1.64**
**새 기능**

- 창고 정리에 "같은 룬워드끼리"를 추가했습니다. 룬워드 · 유니크 · 세트를 같은 이름끼리 가나다순으로 모읍니다.
- 창고 정리에 "빈칸 최소화" 선택을 추가했습니다. 끄면 정렬 순서 그대로 놓고, 켜면 작은 아이템이 앞쪽 빈칸을 메웁니다.

**개선**

- "같은 아이템끼리" 정렬이 한글 이름(옵션을 뺀 본래 이름) 가나다순을 따릅니다.
- 패치 기록을 간단히 / 자세히로 나눠 볼 수 있습니다. (패치 창 · F10)

**v1.63**
**게임 버전**

- 게임 빌드 2026.1102.2를 지원합니다. 이전 빌드(1102.1 · 1101.1 · 1030.2)도 그대로 사용할 수 있습니다.

**새 기능**

- 창고 정리(F5)를 추가했습니다. 체크한 탭(개인 · 공유 1~3)을 종류별 · 같은 아이템끼리 · 등급별 · 크기순으로 정리하고, 되돌리기도 할 수 있습니다.
- 정리할 때 배치 방식을 고를 수 있습니다. (앞 탭부터 채우기 / 종류별로 탭 나누기 / 탭마다 따로 정리)
- 창고 가로 채우기(F5)를 추가했습니다. 켜면 오른쪽으로 먼저 채우고, 줄이 차면 다음 줄로 넘어갑니다.
- 아이템 툴팁에 F2 판정을 표시합니다. 주웠을 때 어디로 가는지(등록 · 교체 · 인벤 · 창고 · 판매)와 그 이유를 알려 줍니다.
- 단축키를 원하는 키로 바꿀 수 있습니다. (F5)
- 획득 목록에서 검색할 수 있습니다.

**개선**

- 자동 진행 대기 시간, 같은/다음 단계, 밝기 · 명암을 게임 안(F5)에서 바로 바꿀 수 있습니다.
- 창고 정리 결과에 이상이 있으면 자동으로 원래대로 되돌립니다.

**v1.62**
**새 기능**

- 게임 안(F5)에서 기능을 바로 켜고 끌 수 있습니다. 재시작이 필요 없고, 패치 창 설정과 자동으로 맞춰집니다. (글꼴 제외)
- 획득 목록을 탭으로 나눠 볼 수 있습니다. (전체 / 등록 / 교체 / 인벤 / 창고 / 판매)

**변경**

- "스킬 부적은 무조건 창고로" 기능을 없앴습니다. F2 부적 설정과 겹쳐 하나로 합쳤습니다.
- 기능 설명 문구를 알기 쉽게 고쳤습니다.

**수정**

- 패치 창 기능 목록이 잘리거나 테두리가 가려지던 문제를 고쳤습니다.

**v1.61**
**게임 버전**

- 게임 빌드 2026.1102.1을 지원합니다.

**새 기능**

- 티리엘 등장 시 멈춤을 추가했습니다. (패치 창, 기본 꺼짐) 포털 자동 입장을 멈추고 알림음을 울리며, AFK 중이면 자동으로 정지합니다.

**수정**

- AFK 중 다른 키가 눌려 인벤 창이 열리고 게임이 멈추던 문제를 고쳤습니다.
- F4 룬워드 목록과 F2 옵션 이름이 영문 내부 이름으로 나오던 문제를 고쳤습니다.

**v1.60**
**새 기능**

- AFK 자동 정지를 추가했습니다. 정한 시간이 지나거나 선택한 인벤 · 창고가 모두 차면 알림음과 함께 멈춥니다. (0분 = 무제한)
- AFK 기록을 이어서 셀지, 매번 새로 셀지 고를 수 있습니다.
- F2에서 인벤 · 창고로 정한 아이템을 주우면 알림음이 울립니다.
- 통계 창(F1)을 추가했습니다. 이번 실행과 오늘의 획득 · 판매 개수, 골드, 시간당 수치를 보여 줍니다.
- F2 보관 설정을 프리셋 3칸에 저장하고 불러올 수 있습니다.
- 세이브를 30분마다 자동으로 백업합니다. (최근 48개 보관)
- 패치 창에서 설정을 파일로 내보내고 가져올 수 있습니다.
- 빛의 파편 안내를 추가했습니다. 등장까지 남은 시간을 보여 주고, 등장하면 알림음과 함께 방향과 거리를 표시합니다.

**개선**

- 패치 창에 마지막 패치 시각과 적용 결과를 표시합니다.

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
