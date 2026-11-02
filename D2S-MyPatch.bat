@echo off
set "D2SF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$__root=Split-Path $env:D2SF; $s=[IO.File]::ReadAllText($env:D2SF,[Text.Encoding]::UTF8); & ([scriptblock]::Create($s.Substring($s.IndexOf('#PS'+'START'))))"
echo.
pause
exit /b
#PSSTART
# D2 Survivors 편의 패치: 기능 선택 창에서 체크한 기능만 적용, 자동 업데이트, 순위표 전송 차단
param([string]$Lang, [string]$Action, [string]$GameDir)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

if (-not $Lang) { $Lang = if (@((Get-UICulture).Name, [Globalization.CultureInfo]::InstalledUICulture.Name, (Get-Culture).Name) -like 'ko*') { 'ko' } else { 'en' } }
$ko = $Lang -ne 'en'
function T($k, $e) { if ($ko) { $k } else { $e } }
# bat를 더블클릭해 실행한 경우: cmd 창을 숨기고 모든 안내를 창(GUI)으로. 끝나면 숨긴 cmd도 닫는다
$gui = $env:D2SF -and -not $env:D2S_NOGUI
if ($gui) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    try { Add-Type -Name W -Namespace D2S -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);' } catch {}
    [void][D2S.W]::ShowWindow([D2S.W]::GetConsoleWindow(), 0)
}
function Msg($text, $icon = 'Information', $buttons = 'OK') {
    if ($gui) {
        # 맨 앞에 떠 있는 빈 창을 주인으로 삼아 메시지 창이 게임·다른 창 뒤로 숨지 않게
        $own = New-Object Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false; StartPosition = 'CenterScreen'; Size = '1,1'; Opacity = 0 }
        $own.Show(); $own.Activate()
        $r = [string][Windows.Forms.MessageBox]::Show($own, $text, "D2S-MyPatch", $buttons, $icon)
        $own.Close(); return $r
    }
    Write-Host $text; 'OK'
}
function Done($code) {
    if ($gui) {
        $pp = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
        $cmd = Get-CimInstance Win32_Process -Filter "ProcessId=$($pp.ParentProcessId)"
        # 사용자가 직접 연 cmd 창에서 실행한 경우는 닫지 않는다 (bat 경로가 명령줄에 있을 때만)
        if ($cmd.CommandLine -like "*$(Split-Path $env:D2SF -Leaf)*") { Stop-Process -Id $cmd.ProcessId -ErrorAction SilentlyContinue }
    }
    exit $code
}
function Fail($msg) { [void](Msg $msg 'Error'); Done 1 }

if (-not $GameDir) { $GameDir = Join-Path $env:LOCALAPPDATA 'Programs\D2 Survivors' }
$asar = Join-Path $GameDir 'resources\app.asar'
if (-not (Test-Path $asar)) {
    if ($gui) {
        $fb = New-Object Windows.Forms.FolderBrowserDialog; $fb.Description = T '게임 설치 폴더를 고르세요 (D2 Survivors.exe가 있는 폴더)' 'Choose the game folder (the one with D2 Survivors.exe)'
        if ($fb.ShowDialog() -ne 'OK') { Done 0 }
        $GameDir = $fb.SelectedPath
    } else { $GameDir = Read-Host (T '  게임 설치 폴더를 입력하세요 (D2 Survivors.exe가 있는 폴더)' '  Enter the game folder (the one with D2 Survivors.exe)') }
    $asar = Join-Path $GameDir.Trim('"') 'resources\app.asar'
    if (-not (Test-Path $asar)) { Fail (T "app.asar를 찾을 수 없습니다: $asar" "app.asar not found: $asar") }
}
$backup = "$asar.orig"

# 업데이트 확인: GitHub의 version.txt가 더 크면 새 bat를 받아 자기 자신을 바꾸고 다시 실행
$Ver = '1.63'
$Repo = 'mastree-master/D2S-MyPatch'
# raw.githubusercontent는 몇 분씩 예전 파일을 내주므로 캐시 없는 GitHub API로 받는다
$raw = "https://api.github.com/repos/$Repo/contents"
$raw2 = "https://raw.githubusercontent.com/$Repo/main"  # API 한도(IP당 1시간 60회) 초과 때 대신 쓰는 주소 (몇 분 늦을 수 있음)
$inv = [Globalization.CultureInfo]::InvariantCulture
# version.txt: 첫 줄 버전, 그 아래 줄은 패치 내용
try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    $wc = New-Object Net.WebClient
    $wc.Encoding = [Text.Encoding]::UTF8
    $wc.Headers['User-Agent'] = 'D2S-MyPatch'; $wc.Headers['Accept'] = 'application/vnd.github.raw'
    $vt = try { @($wc.DownloadString("$raw/version.txt") -split "`r?`n") } catch { $raw = $raw2; @($wc.DownloadString("$raw2/version.txt?" + [DateTime]::Now.Ticks) -split "`r?`n") }
    $nv = [decimal]::Parse($vt[0].Trim(), $inv)
} catch { $nv = 0; $vt = @() }
if ($nv -gt [decimal]::Parse($Ver, $inv) -and $env:D2SF) {
    $notes = ($vt | Select-Object -Skip 1 | Where-Object { $_.Trim() }) -join "`n"
    $ask = (T "새 버전 v$($vt[0].Trim()) 이 있습니다. (지금 v$Ver)" "New version v$($vt[0].Trim()) is available. (current v$Ver)") + "`n`n$notes`n`n" + (T '업데이트할까요?' 'Update now?')
    $yes = if ($gui) { (Msg $ask 'Question' 'YesNo') -eq 'Yes' } else { Write-Host $ask; (Read-Host '  (y/n)') -eq 'y' }
    if ($yes) {
        $wc.Headers['User-Agent'] = 'D2S-MyPatch'; $wc.Headers['Accept'] = 'application/vnd.github.raw'
        $nb = $wc.DownloadData("$raw/D2S-MyPatch.bat")
        $ns = [Text.Encoding]::UTF8.GetString($nb)
        if (-not $ns.Contains('#PS' + 'START') -or -not ($ns -match '\$Ver = ''([\d.]+)''' -and [decimal]::Parse($Matches[1], $inv) -gt [decimal]::Parse($Ver, $inv))) { Fail (T '받은 파일이 올바르지 않습니다.' 'Downloaded file is invalid.') }
        [IO.File]::WriteAllBytes($env:D2SF, $nb)
        & ([scriptblock]::Create($ns.Substring($ns.IndexOf('#PS' + 'START')))) -Lang $Lang -Action $Action -GameDir $GameDir
        Done 0
    }
}

for ($i = 0; $i -lt 30 -and (Get-Process -Name 'D2 Survivors' -ErrorAction SilentlyContinue); $i++) {
    if ($i -eq 0) { Write-Host (T '  게임이 꺼지기를 기다리는 중...' '  Waiting for the game to close...') }
    Start-Sleep -Milliseconds 500
}
if (Get-Process -Name 'D2 Survivors' -ErrorAction SilentlyContinue) {
    Fail (T '게임이 실행 중입니다. 게임을 완전히 끄고 다시 실행하세요.' 'The game is running. Close it completely and run this again.')
}

# --- asar 읽기: [4][헤더 pickle 크기][payload 크기][JSON 길이][JSON][패딩][파일 데이터...] ---
$utf8 = New-Object Text.UTF8Encoding($false)
$bytes = [IO.File]::ReadAllBytes($asar)
$headerSize = [BitConverter]::ToUInt32($bytes, 4)
$jsonLen = [BitConverter]::ToUInt32($bytes, 12)
$header = $utf8.GetString($bytes, 16, $jsonLen)
$dataStart = 8 + $headerSize

function Entry($prefix) {
    $m = [regex]::Matches($header, '"(' + $prefix + '-[A-Za-z0-9_-]{8}\.js)":\{"size":(\d+),"offset":"(\d+)","integrity":\{[^{}]*\}\}')
    if ($m.Count -ne 1) { Fail (T "이 게임 버전은 지원하지 않습니다 ($prefix 파일)." "This game version is not supported ($prefix file).") }
    $m[0]
}
function ReadFile($e) { $utf8.GetString($bytes, $dataStart + [long]$e.Groups[3].Value, [int]$e.Groups[2].Value) }

$gameEntry = Entry 'Game'
$keepEntry = if ($header -match '"moved-[A-Za-z0-9_-]{8}\.js"') { Entry 'moved' } else { Entry 'saveTransfer' }
$uiEntry = if ($keepEntry.Groups[1].Value -like 'moved-*') { Entry 'saveTransfer' } else { Entry 'leaderboardSend' }
$game = ReadFile $gameEntry
$build = try { $pj = ($header | ConvertFrom-Json).files.'package.json'; ($utf8.GetString($bytes, $dataStart + [long]$pj.offset, [int]$pj.size) | ConvertFrom-Json).version } catch { '?' }
$patched = $game.Contains('isNew:e=>')
# 기능 선택: 체크한 기능만 패치. 선택과 조절값은 %APPDATA%\D2S-MyPatch\options.json 에 저장
$optFile = Join-Path $env:APPDATA 'D2S-MyPatch\options.json'
$feat = [ordered]@{
    carry = T '보관함 자동 등록 · 상위 옵션 자동 교체 · 룬워드 중복 정리' 'Auto-register to collection · auto-upgrade · runeword dedupe'
    pickup = T '아이템 즉시 습득 · F2 미지정 아이템 자동 판매' 'Instant item pickup · auto-sell unassigned items'
    goldchest = T '골드 · 상자 원거리 자동 획득' 'Auto-collect gold · chests at any range'
    overflow = T '인벤토리 공간 부족 시 창고에 자동 보관' 'Store to stash when inventory is full'
    log = T '획득 목록 표시 (탭 분류, 마우스 오버 시 옵션)' 'Pickup log (tabs, hover for stats)'
    swpop = T '교체 시 변경 옵션 비교 창' 'Upgrade comparison popup'
    twins = T '툴팁 옆 동일 아이템 위치 · 비교 표시' 'Show same-item locations · comparison beside tooltip'
    hidden = T '툴팁에 숨겨진 수치 표시' 'Show hidden values in tooltip'
    auto = T '포털 자동 입장 · 클리어 후 자동 진행' 'Auto-enter portal · auto-continue after clear'
    nopause = T '캐릭터 · 인벤토리 · 스킬 창 열람 중 게임 진행 유지' 'Keep game running while panels are open'
    stash = T '창고 단축키 (B) · Ctrl+클릭 창고 이동' 'Stash hotkey (B) · Ctrl+click to stash'
    afk = T 'AFK 모드 (F8) · 창 최소화 시 속도 저하 방지' 'AFK mode (F8) · no slowdown when minimized'
    speed = T '게임 배속 (F7: 1 / 1.5 / 2 / 3배)' 'Game speed (F7: 1 / 1.5 / 2 / 3x)'
    bright = T '화면 밝기 · 명암 조절 (PageUp/PageDown, Home/End)' 'Brightness · contrast (PageUp/PageDown, Home/End)'
    hud = T 'HUD 재배치 (소환수 · 스킬 좌상단, 게임 정보 우상단)' 'HUD layout (pets · skills top-left, run info top-right)'
    corpse = T '시체 표시 끄기' 'Hide corpses'
    fps = T 'FPS 표시 (F9)' 'Show FPS (F9)'
    dropsnd = T '드롭 알림음 (F2 인벤 · 창고 지정 아이템)' 'Drop sound (items set to bag · stash in F2)'
    f2tip = T '툴팁에 F2 판정 표시 (주우면 등록 · 교체 · 인벤 · 창고 · 판매 중 어디로 가는지와 이유)' 'F2 verdict in tooltip (where it goes on pickup and why)'
    stats = T '획득 · 판매 통계 (F1)' 'Loot · sales stats (F1)'
    shard = T '빛의 파편 위치 안내 (퀘스트: 부서진 빛)' 'Light shard locator (quest: Shattered Light)'
    tyrael = T '티리엘 등장 시 자동 진행 정지 (날개 수령용, 기본 꺼짐)' 'Stop auto-continue at Tyrael (wings, off by default)'
    font = T '글꼴 교체 (kodia.ttf 필요, 재시작 필요)' 'Replace font (needs kodia.ttf, restart required)'
}
$O = @{ logw = 32; logsize = 0; automode = 'same'; delay = 4; brightness = 100; contrast = 100; logn = 15; res = 0; fpscap = 0 }
foreach ($k in $feat.Keys) { $O[$k] = $true }
$O.tyrael = $false
try { (Get-Content $optFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $O[$_.Name] = $_.Value } } catch {}
$hasFont = Test-Path (Join-Path $__root 'kodia.ttf')
$pv = if ($game -match 'globalThis\.__d2sv=([\d.]+);') { $Matches[1] } else { '' }

# 패치 기록 (선택 창 오른쪽에 표시). 새 버전은 맨 위에 추가
$changelog = @'
1.63
- 게임 빌드 2026.1102.2 대응 (비교 상자 · 숨은 값이 게임 함수 이름이 바뀌어도 찾아가게)
- 창고 정리 배치 방식 선택: 앞 탭부터 채우기 / 종류별로 탭 나누기 (무기 · 방어구 · 장신구 · 부적 · 기타) / 탭마다 따로 정리
- 창고에 넣을 때 가로로 채우기 (F5 창 체크): 오른쪽으로 채우고 줄이 차면 다음 줄 왼쪽부터. Ctrl+클릭 · 자동 보관 · 정리 모두 적용
- 창고 정리 (F5 창): 개인 · 공유 1 · 2 · 3 중 체크한 탭을 합쳐 종류별 / 같은 아이템끼리 / 등급별 / 크기순으로 다시 배치, [되돌리기]. 창고를 연 채로 눌러도 바로 다시 그려짐, 정리 전후 아이템을 비교해 하나라도 다르면 원래대로 둠
- 툴팁 맨 아래에 F2 판정 한 줄: 이 아이템을 주우면 보관함 등록 / 교체 / 인벤 / 창고 / 판매 중 어디로 가는지와 이유 (어떤 옵션이 기준을 넘었는지). F5에서 끄기 가능
- F5 창에 조절값: 클리어 후 같은 단계 / 다음 단계, 자동 진행 대기(초), 밝기 · 명암. 바로 적용, 패치 창과 연동
- 단축키 바꾸기 (F5 창): F1 ~ F10, B. 바꾼 뒤 원래 키는 안 먹힘, Delete로 원래대로
- 획득 목록 검색칸 (탭 줄 오른쪽, 띄어쓰기 무시)

1.62
- 기능 실시간 켜기 · 끄기: 게임 안 F5 창에서 바로 적용 (글꼴만 재시작 필요). 패치 창 체크와 서로 연동 (5초 안에 반영), 맨 위 줄 ✓/✗ 도 바로 바뀜
- 획득 목록 탭: 전체 / 등록 / 교체 / 인벤 / 창고 / 판매 (예전 기록도 분류)
- "스킬 붙은 부적은 무조건 창고로" 삭제: F2 부적 설정과 중복 (부적은 F2 설정대로)
- 기능 설명 문구 정리, 패치 창 기능 상자가 21번째부터 잘리던 문제 · 상자 오른쪽 테두리 가려지던 문제 · 패치 기록 칸 폭

1.61
- 1102.1: F4 룬워드 목록 · F2 옵션 이름이 내부 이름(item_fasterattackrate 등)으로 나오던 문제 (툴팁 함수가 룬워드에 mods 를 요구)
- 게임 빌드 2026.1102.1 대응 (게임 파일 구조가 바뀜: moved 파일 없어지고 화면 코드가 둘로 나뉨, 단축키 바꾸기 기능 생김). 이전 빌드 1101.1 · 1030.2도 그대로 가능
- AFK 중에는 F키 말고 다른 키가 게임에 안 넘어감 (I · C · B 등이 눌려 인벤 창이 열리고 게임이 멈추던 문제)
- 패치 창 기능에 "티리엘 나오면 멈춤" (기본 꺼짐): 켜면 티리엘 등장(파편 10개 + 5막 보스 처치) 때 포털 자동 입장 안 함, 소리, AFK 중이면 자동 정지

1.60
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

1.59
- 룬워드 교체 한손 우선: 무기 종류 상관없이 양손 등록본은 한손이 들어오면 교체, 한손 등록본은 양손으로 안 바꿈 (같은 손끼리는 옵션 비교)
- 비교: 옵션 총합이 같으면 바탕 방어력이 높은 쪽으로 교체 (전에는 같으면 중복으로 보고 판매)
- [판매] 이유 문구 정확히: "옵션 같음 · 바탕 방어력 낮음 (a < b)", "등록본과 같음 (중복) · F2에서 판매"
- 드롭 계산기(F3): 진행 중인 판의 공포 단계를 기본값으로 (마을에서는 마지막에 넣은 값), 검색할 때 이름과 확률이 붙어 보이던 문제 수정

1.58
- 패치 창을 디아블로풍으로: 게임 메뉴 그림 배너 · 금색 제목, 어두운 배경, 게임 돌 버튼, 탭 · 표 · 입력칸 어두운 색 (게임 그림이 없으면 색만)
- 기능 탭 스크롤 없이 한 화면: 기능 · 조절값을 같은 폭의 상자(금색 테두리 · 제목 띠)에 2열로, 조절값 입력칸 줄 맞춤
- 보관 설정 탭: 맨 앞 선택 칸, 전체 선택 / 전체 해제(보이는 줄), "체크한 줄을 [인벤 · 판매 · 창고] (으)로 적용", 구분 · 검색 · 설정 필터(인벤만 · 판매만 · 창고만)
- 패치 창 배너에 움직이는 Diablo II 불꽃 로고 (게임 타이틀 그림), 인게임 단축키 상자, GitHub 버튼
- 패치 창 제목줄 · 선택칸 · 패치 기록 스크롤바 어두운 색
- 패치 창 언어 판별을 여러 값으로 (가끔 영어로 뜨던 문제)

1.57
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

1.56
- 보관 설정(F2 · 패치 창 탭): 옵션마다 그 부위에 붙을 수 있는 수치 범위 표시 (게임 옵션표 기준, 예: 작은 부적 저항 3~11), 그 부위에 안 붙는 옵션 줄은 숨김

1.55
- 패치 창 아래가 잘려 "체크한 것 적용" 버튼이 안 보이던 문제 수정 (버튼을 탭 밖 맨 아래로, 탭 안은 넘치면 스크롤)

1.54
- 패치 창에 "보관 설정 (F2)" 탭: 게임의 F2 와 같은 설정을 표로 편집 (분류 · 검색 · 미등록만 · 보이는 줄 전부 바꾸기, 보이는 줄 상태 요약). 바꾸면 바로 저장되고 게임이 켜져 있으면 몇 초 안에 반영
- 게임 F2 와 패치 창이 같은 설정 파일(%APPDATA%\D2S-MyPatch\keep.json)을 씀
- F2 묶음 제목에 현재 상태 표시 (전부 판매 / 인벤 n · 창고 n · 판매 n), 누르면 가장 많은 것 말고 나머지 목록

1.53
- 보관 설정(F2): 글씨 조금 크게, 매직을 레어 위로, 최소 수치 칸에 "이상 적용" 표시

1.52
- 게임 아이템 필터(숨김 · 줍기 · 판매 · 보관)를 완전히 무시하고 F2 보관 설정만 따름 (숨김으로 둔 아이템도 주워서 F2대로 처리)

1.51
- 보관 설정(F2): 룬워드를 부위별로 (한손 · 양손 · 갑옷 · 투구 · 방패), 룬워드마다 만들 수 있는 부위만 표시. 기존 이름별 설정은 그대로 이어받음

1.50
- 보관 설정(F2): "전부 ~" 버튼은 확인 창을 한 번 더 띄움
- 되돌리기 (마지막 변경 취소), 설정 파일로 저장 / 불러오기

1.49
- 보관 설정(F2): 레어 · 매직 부위 세분화 (무기 · 투구 · 갑옷 · 방패 · 장갑 · 신발 · 허리띠 · 반지 · 목걸이 · 주얼), 부위마다 접기
- 옵션마다 최소 수치: 그 옵션 종류의 수치 합이 이 값 이상일 때만 설정 적용 (예: 레어 장갑 스킬 3 이상 → 창고)
- 접힌 부위 제목에 판매가 아닌 설정 요약 표시

1.48
- 보관 설정(F2): 레어 · 매직도 종류(무기 · 방어구 · 반지 · 목걸이 · 주얼) × 옵션별로 판매 / 인벤 / 창고 설정
- 옵션 분류 보강 (방어 · 막기 · 피해 감소, 생명력 · 마나 흡수 추가)
- 묶음은 접어 두고 펼쳤을 때만 표시, 검색하면 자동으로 펼침

1.47
- 보관 설정(F2): 부적을 크기(작은 · 큰 · 거대) × 옵션(스킬 · 저항 · 생명력 · 마나 · 피해 · 명중 · 매찬 골드 · 속도 · 능력치 · 그 밖)별로 판매 / 인벤 / 창고 설정
- 보관 설정 창 위쪽(등록 개수 · 검색칸) 고정, 버튼 글씨가 안 보이던 문제 수정

1.46
- 보관 설정 창 (F2): 룬워드 · 유니크 · 세트는 이름별로, 스킬 부적 · 그 밖의 부적 · 레어 · 매직은 종류별로 판매 / 인벤 / 창고를 고름 (검색, 전부 바꾸기)
- 등록 개수 표시 (유니크 · 세트 · 룬워드 등록 수 / 전체, 미등록 표시): F2 창과 AFK 화면
- [판매] 줄에 마우스를 올리면 판매 이유와 등록본 대비 바뀐 옵션 · 옵션 총합 표시

1.45
- 패치가 끝나면 완료 팝업 없이 게임을 바로 실행 (안 되는 기능이 있을 때만 경고)
- 이전 게임 빌드(2026.1030.2)도 패치 가능

1.44
- 드롭 계산기(F3): 새 공포 단계 매찬 보너스(단계당 +3%, 40단계 넘으면 +2%)와 공포 유니크 배율 x1.9 자동 반영, 단계 입력 제한 14 → 200

1.43
- 게임 빌드 20261101.1 대응

1.42
- B로 창고 닫을 때 일시정지 메뉴가 뜨던 문제 수정 (창 닫기 기능을 직접 호출)

1.41
- B로 연 창고를 B로 닫기가 안 되던 문제 수정
- 드롭 확률 계산기 (F3): 공포 단계 · 매직 찬스 · 몬스터 종류를 넣으면 룬워드 · 유니크별로 아이템 1개당 확률과 몇 개에 1번인지 (게임 공식과 데이터 그대로)

1.40
- B로 연 창고를 B로 다시 닫기 (1.41에서 D2 화면에서도 동작하게 수정)

1.39
- 비교 상자 위치 표시에 종류도 함께: 등록 · 방어구 · 방패 · ▲ … / 공용 창고 1 · 무기 · 양손 · 둔기 · ▲ …
- Shift 비교 때 3개 제한 없이 전부

1.38
- 획득 목록 옵션 보기 창을 게임 툴팁과 같은 색으로 (이름은 등급 색, 일반 옵션 파랑 · 기본 수치 흰색 · 세트 초록 · 룬 금색 · 회색 설명 · 사용 불가 빨강)

1.37
- 아이템에 마우스를 올리고 Shift: 같은 이름 아이템 위치를 종류 상관없이 전부 게임 비교 상자로 표시 (등록 / 개인 창고 / 공용 창고 1~3 / 인벤)

1.36
- 배속 표시를 맨 위 줄 오른쪽 (FPS 왼쪽)으로, 시간 표시와 안 겹치게

1.35
- HUD 배치: 소환수 1줄 · 스킬 줄마다 1줄로 화면 맨 왼쪽 위, 게임 정보(단계·처치·골드·초당 피해)는 화면 맨 오른쪽 위 (선택 창에서 끄기 가능)
- FPS 표시를 맨 위 줄 오른쪽 끝으로 (버전은 맨 위 줄 왼쪽)

1.34
- 획득 목록 줄을 짧게: (양손 석궁 · 등록본 양손 활) 처럼 손잡이·종류만 (자세한 건 마우스 올리면)

1.33
- 획득 목록을 화면 오른쪽에 두면 옵션 창이 목록 왼쪽에 뜨게 (자리가 모자라면 자동으로 반대쪽)

1.32
- 게임 업데이트 후 안 맞는 기능만 빼고 나머지는 적용, 안 되는 기능 목록을 알려 줌 (맨 위 줄에 "불가" 표시)
- 게임 새 빌드가 준비되면 "설치하면 패치가 풀림 · 설치 후 bat 실행" 알림

1.31
- 룬워드 목록 · 설명서 창 제목과 검색칸을 스크롤해도 위에 고정
- 룬워드 목록 옵션 한글 문장 표시 확인 (1.29)

1.30
- 업데이트 확인 · 완료 · 오류 창과 선택 창이 항상 맨 앞에 뜨게

1.29
- F4 룬워드 목록 옵션을 한글 문장으로 표시 (영문 이름으로 나오던 문제)

1.28
- 획득 목록 옵션 보기 창: 제목을 이름 · 부위 · 등록본 줄로 나눠 짧게, 폭 줄이고 줄바꿈
- 옵션 보기 창 · 획득 목록 배경 더 투명하게

1.27
- 룬워드 검색칸에 커서가 있어도 F4로 닫기 (F키는 항상 동작)

1.26
- F4 룬워드 옵션이 [object Object]로 나오던 문제 수정 (룬 옵션 포함, 최소~최대)

1.25
- 획득 목록 마우스 휠로 위로 올려 지난 기록 보기 (안 되던 문제 수정)
- 지난 기록 300줄 저장: 게임을 다시 켜도 이어서 보임

1.24
- 획득 목록 창: 위쪽 막대를 끌어서 이동, 오른쪽 아래 모서리로 크기 조절 (위치·크기 기억)

1.23
- F4 룬워드 목록이 안 열리던 문제 수정
- 맨 위 줄과 선택 창에 게임 빌드 번호 표시

1.22
- cmd 창 없이 바로 GUI: 업데이트 확인 · 오류 · 완료를 모두 창으로 표시
- 언어는 Windows 언어로 자동, 게임 폴더는 폴더 선택 창

1.21
- 획득 목록을 채팅창처럼: 화면 아래쪽, 스크롤로 지난 기록 보기 (최근 300개), 새 줄은 맨 아래
- 각 줄 앞에 [월/일 시:분] 표시
- [판매]는 이름만 짧게

1.20
- 설명서 F6, 룬워드 목록 F4 (고정 옵션 / 변하는 옵션 범위, 검색)
- 맨 위 줄에 F6 · F4 · F10 단축키 항상 표시
- 게임 안 업데이트 확인을 GitHub API로 (올리자마자 반영, 3분마다), 막히면 예비 주소로

1.19
- 적용 기능 한 줄을 화면 맨 위로, 색 구분 (적용 초록 / 안 함 빨강)

1.18
- 업데이트 알림이 떠 있을 때 더 새 버전이 나오면 알림도 최신 버전으로 바뀜

1.17
- 교체 창: 같은 종류 옵션끼리 짝지어 비교 (숫자만 다른 줄끼리), 없어진 옵션 · 새로 생긴 옵션 따로 표시
- 룬워드 등록은 한손 무기 우선, 한손/양손 겸용 무기는 양손으로 보고 따로 보관

1.16
- 화면 맨 아래에 버전 · F10 · 적용 기능 한 줄 표시 (AFK 화면 위에도)
- 획득 목록 폭(화면 %)을 선택 창에서 조절

1.15
- 화면 왼쪽 아래에 버전 · F10 패치 기록 안내
- F10 창 맨 위와 패치 창에 적용 기능 한 줄 요약 (✓ 적용 / ✗ 안 함)
- 획득 목록·교체 창 글자 크기를 화면 폭에 맞춤 (FHD 등), 선택 창에서 직접 지정 가능

1.14
- GitHub 사용 한도 초과로 업데이트가 안 받아지던 문제 수정
- 게임 안 확인은 한도 없는 주소로 1분마다

1.13
- 선택 창 오른쪽에 패치 기록 표시
- 게임 안 패치 기록 (F10)
- 알림에서 패치하고 게임이 다시 켜지면 패치 창 자동으로 닫힘

1.12
- 알림에서 패치 후 게임 다시 켤 때 패치 창에 게임 기록이 찍히지 않게

1.11
- 스킬 붙은 매직 부적도 창고로 (매직 부적 스킬 옵션 인식 수정)
- AFK 화면 위에도 업데이트 알림 표시

1.10
- 게임 안 업데이트 확인을 게임 본체에서 (알림 안 뜨던 문제 수정)

1.09
- 업데이트 확인 주기 2분

1.08
- FPS 표시 옆에 패치 버전 표시

1.07
- 업데이트 알림 클릭 → 게임 종료 → 패치 창 자동 실행 → 적용하면 게임 다시 실행

1.06
- 업데이트 확인 주기 30분 → 5분

1.05
- 교체 창: 이전 값 빨강 / 새 값 초록, 한 옵션 한 줄

1.04
- 게임 안 업데이트 알림은 패치할 때까지 계속 표시

1.03
- 클리어 후 자동 진행 방식: 같은 단계 계속 반복 / 한 단계씩 올라가기
- 업데이트 받기 오류 수정

1.02
- 업데이트 확인을 GitHub API로 (예전 버전이 잘못 뜨던 문제)
- 낮은 버전으로 덮어쓰지 않도록 막음

1.01
- 명암 조절 Home / End
- 시체 숨김
- FPS 표시 (F9), FPS 제한
- 렌더링 해상도 조절

1.00
- 기능 선택 창: 체크한 기능만 적용, 조절값 저장
- 밝기 조절 PageUp / PageDown
- 스킬 붙은 부적은 창고로
- 교체 창은 바뀐 옵션만, 획득 목록 줄에 마우스 올리면 옵션

v1 ~ v5 (이전 번호)
- bat 하나로 패치/복구, GitHub 자동 업데이트
- 배속 (F7), AFK 화면에 배속·게임 시간 표시
- 예전 버전 패치 위에 바로 덮어쓰기

처음 버전
- 자동 습득·등록·교체·판매, 룬워드 중복 정리
- 획득 목록, 교체 창, 되돌리기, 툴팁 비교 상자, 숨겨진 값
- 포털 자동 입장, 클리어 후 자동 재시작, 카운트다운
- 창 열어도 안 멈춤, B 창고, Ctrl+클릭 창고로
- AFK 모드 (F8), 최소화해도 안 멈춤
- 순위표 전송 차단, 폰트 교체
'@

# 패치 GUI 의 보관 설정 탭: 게임이 저장한 keep-meta.json(메뉴 목록)과 keep.json(설정)을 표로 보여 주고, 바꾸면 keep.json 에 바로 저장 (게임은 다음에 켤 때 가져감)
$KeepTab = { param($page)
    $dir = Split-Path $optFile; $kf = Join-Path $dir 'keep.json'; $mf = Join-Path $dir 'keep-meta.json'
    if (-not (Test-Path $mf)) {
        $l = New-Object Windows.Forms.Label; $l.AutoSize = $true; $l.Text = (T '아직 목록이 없습니다.' 'No list yet.') + [char]10 + (T '패치를 적용하고 게임을 한 번 켜서 캐릭터를 고르면 목록이 생깁니다.' 'Apply the patch, start the game and pick a hero once.') + [char]10 + (T '(게임 안에서는 F2 로 같은 설정을 할 수 있습니다)' '(In game, F2 opens the same settings)')
        $page.Controls.Add($l); return
    }
    $meta = [IO.File]::ReadAllText($mf) | ConvertFrom-Json
    $ks = @{}
    if (Test-Path $kf) { try { ([IO.File]::ReadAllText($kf).TrimStart([char]0xFEFF) | ConvertFrom-Json).ks.PSObject.Properties | ForEach-Object { $ks[$_.Name] = $_.Value } } catch {} }
    $names = @{ 1 = (T '인벤' 'Bag'); 2 = (T '판매' 'Sell'); 3 = (T '창고' 'Stash') }; $vals = @{}; foreach ($k in $names.Keys) { $vals[$names[$k]] = $k }
    $top = New-Object Windows.Forms.FlowLayoutPanel; $top.Dock = 'Top'; $top.AutoSize = $true; $top.WrapContents = $true
    $reg = New-Object Windows.Forms.Label; $reg.AutoSize = $true; $reg.Text = $meta.reg + '   ' + (T '(바꾸면 바로 저장, 게임이 켜져 있으면 몇 초 안에 반영)' '(saved at once, applied in game within seconds)'); $reg.Margin = '0,0,0,6'; $top.SetFlowBreak($reg, $true); $top.Controls.Add($reg)
    $cat = New-Object Windows.Forms.ComboBox; $cat.DropDownStyle = 'DropDownList'; $cat.Width = 110; [void]$cat.Items.Add((T '전체' 'All')); foreach ($c in ($meta.rows | ForEach-Object { $_.c } | Select-Object -Unique)) { [void]$cat.Items.Add($c) }; $cat.SelectedIndex = 0
    $q = New-Object Windows.Forms.TextBox; $q.Width = 160
    $miss = New-Object Windows.Forms.CheckBox; $miss.Text = T '미등록만' 'Missing only'; $miss.AutoSize = $true
    $bv = New-Object Windows.Forms.ComboBox; $bv.DropDownStyle = 'DropDownList'; $bv.Width = 70; [void]$bv.Items.AddRange(@($names[1], $names[2], $names[3])); $bv.SelectedIndex = 0
    $vf = New-Object Windows.Forms.ComboBox; $vf.DropDownStyle = 'DropDownList'; $vf.Width = 100; [void]$vf.Items.AddRange(@((T '전체 설정' 'Any action'), ($names[1] + (T '만' ' only')), ($names[2] + (T '만' ' only')), ($names[3] + (T '만' ' only')))); $vf.SelectedIndex = 0
    $lc = New-Object Windows.Forms.Label; $lc.Text = T '구분' 'Type'; $lc.AutoSize = $true; $lc.Padding = '0,6,0,0'
    $lf = New-Object Windows.Forms.Label; $lf.Text = T '   설정' '   Action'; $lf.AutoSize = $true; $lf.Padding = '0,6,0,0'
    $bAll = New-Object Windows.Forms.Button; $bAll.Text = T '전체 선택' 'Select all'; $bAll.AutoSize = $true
    $bNone = New-Object Windows.Forms.Button; $bNone.Text = T '전체 해제' 'Clear'; $bNone.AutoSize = $true
    $lb1 = New-Object Windows.Forms.Label; $lb1.Text = T '   체크한 줄을' '   Set checked rows to'; $lb1.AutoSize = $true; $lb1.Padding = '0,6,0,0'
    $bb = New-Object Windows.Forms.Button; $bb.Text = T '(으)로 적용' 'Apply'; $bb.AutoSize = $true
    $lq = New-Object Windows.Forms.Label; $lq.Text = T '검색' 'Search'; $lq.AutoSize = $true; $lq.Padding = '0,6,0,0'
    $sum = New-Object Windows.Forms.Label; $sum.AutoSize = $true; $sum.Padding = '8,6,0,0'; $sum.ForeColor = 'DarkBlue'
    $top.Controls.AddRange(@($lc, $cat, $lq, $q, $miss, $lf, $vf, $sum, $bAll, $bNone, $lb1, $bv, $bb)); $top.SetFlowBreak($sum, $true)
    foreach ($x in $top.Controls) {
        if ($x -eq $reg) { continue }
        if ($x -eq $sum) { $x.Margin = "3,8,3,2"; continue }
        $tw = [Windows.Forms.TextRenderer]::MeasureText($x.Text, $f.Font).Width
        if ($x -is [Windows.Forms.Label] -or $x -is [Windows.Forms.CheckBox]) { $w = $tw + $(if ($x -is [Windows.Forms.CheckBox]) { 26 } else { 6 }); $x.AutoSize = $false; $x.Padding = 0; $x.Size = New-Object Drawing.Size($w, 30); $x.Margin = '3,2,3,2'; if ($x -is [Windows.Forms.Label]) { $x.TextAlign = 'MiddleLeft' } else { $x.CheckAlign = 'MiddleLeft'; $x.TextAlign = 'MiddleLeft' } }
        elseif ($x -is [Windows.Forms.Button]) { $w = $tw + 36; $x.AutoSize = $false; $x.Size = New-Object Drawing.Size($w, 30); $x.Margin = '3,2,3,2' }
        else { $x.Margin = New-Object Windows.Forms.Padding(3, (2 + [Math]::Max(0, [int]((30 - $x.Height) / 2))), 3, 2) }
    }
    $g = New-Object Windows.Forms.DataGridView; $g.Dock = 'Fill'; $g.AllowUserToAddRows = $false; $g.AllowUserToDeleteRows = $false; $g.RowHeadersVisible = $false; $g.SelectionMode = 'CellSelect'; $g.EditMode = 'EditOnEnter'; $g.BackgroundColor = 'White'
    $cs = New-Object Windows.Forms.DataGridViewCheckBoxColumn; $cs.Name = 'sel'; $cs.HeaderText = T '선택' 'Pick'; $cs.Width = 50; [void]$g.Columns.Add($cs)
    foreach ($c in @(@('c', (T '구분' 'Type'), 70), @('n', (T '이름' 'Name'), 190), @('b', (T '부위 · 옵션' 'Slot · stat'), 260))) { $col = New-Object Windows.Forms.DataGridViewTextBoxColumn; $col.Name = $c[0]; $col.HeaderText = $c[1]; $col.Width = $c[2]; $col.ReadOnly = $true; [void]$g.Columns.Add($col) }
    $cv = New-Object Windows.Forms.DataGridViewComboBoxColumn; $cv.Name = 'v'; $cv.HeaderText = T '설정' 'Action'; $cv.Width = 70; [void]$cv.Items.AddRange(@($names[1], $names[2], $names[3])); $cv.FlatStyle = 'Flat'; [void]$g.Columns.Add($cv)
    $cm = New-Object Windows.Forms.DataGridViewTextBoxColumn; $cm.Name = 'm'; $cm.HeaderText = T '최소 수치 (이상 적용)' 'Min (or more)'; $cm.Width = 150; [void]$g.Columns.Add($cm)
    foreach ($r in $meta.rows) {
        $v = if ($r.o) { 0 } elseif ($ks.ContainsKey($r.k)) { [int]$ks[$r.k] } else { [int]$r.d }
        $i = $g.Rows.Add($false, $r.c, ($r.n + $(if ($r.x) { T '  (미등록)' '  (missing)' } else { '' })), $r.b, $names[$v], $(if ($r.m -and $ks.ContainsKey($r.k + '#')) { [string]$ks[$r.k + '#'] } else { '' }))
        $row = $g.Rows[$i]; $row.Tag = $r; if ($r.o) { $row.Cells['sel'].ReadOnly = $true; $row.Cells['v'].ReadOnly = $true; $row.Cells['v'].Style.BackColor = [Drawing.Color]::FromArgb(24, 19, 14); $row.DefaultCellStyle.ForeColor = 'Gray' }; if (-not $r.m) { $row.Cells['m'].ReadOnly = $true; $row.Cells['m'].Style.BackColor = [Drawing.Color]::FromArgb(24, 19, 14) }
        if ($v) { $row.Cells['v'].Style.ForeColor = @{ 1 = 'WhiteSmoke'; 2 = 'Salmon'; 3 = 'LightSkyBlue' }[$v] }
    }
    $save = { $o = @{ t = [long]([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); ks = $ks }; [IO.Directory]::CreateDirectory($dir) | Out-Null; [IO.File]::WriteAllText($kf, ($o | ConvertTo-Json -Depth 3 -Compress), (New-Object Text.UTF8Encoding($false))) }
    $set = { param($row)
        $r = $row.Tag; $v = $vals[[string]$row.Cells['v'].Value]; if ($v) { $ks[$r.k] = $v; $row.Cells['v'].Style.ForeColor = @{ 1 = 'WhiteSmoke'; 2 = 'Salmon'; 3 = 'LightSkyBlue' }[$v] }
        if ($r.m) { $n = 0; if ([int]::TryParse([string]$row.Cells['m'].Value, [ref]$n) -and $n -gt 0) { $ks[$r.k + '#'] = $n } else { $ks.Remove($r.k + '#'); $row.Cells['m'].Value = '' } }
    }
    $g.Add_CurrentCellDirtyStateChanged({ if ($g.IsCurrentCellDirty -and $g.CurrentCell.OwningColumn.Name -match '^(v|sel)$') { $g.CommitEdit('CurrentCellChange') | Out-Null } })
    $g.Add_CellValueChanged({ param($s, $e) if ($e.RowIndex -ge 0 -and $g.Columns[$e.ColumnIndex].Name -ne 'sel') { & $set $g.Rows[$e.RowIndex]; & $save; & $count } })
    $filter = { $c = $cat.SelectedIndex; $t = $q.Text -replace '\s', ''; foreach ($row in $g.Rows) { $r = $row.Tag; $row.Visible = ($c -eq 0 -or $r.c -eq $cat.SelectedItem) -and (-not $t -or (($r.n + $r.b + $r.k) -replace '\s', '').IndexOf($t, [StringComparison]::OrdinalIgnoreCase) -ge 0) -and (-not $miss.Checked -or $r.x) -and ($vf.SelectedIndex -eq 0 -or (-not $r.o -and $vals[[string]$row.Cells['v'].Value] -eq $vf.SelectedIndex)) } }
    $count = { $c = @{ 1 = 0; 2 = 0; 3 = 0 }; $n = 0; foreach ($row in $g.Rows) { if ($row.Visible -and -not $row.Tag.o) { $n++; $c[$vals[[string]$row.Cells['v'].Value]]++ } }; $m = @(1, 3, 2 | Where-Object { $c[$_] }); $sum.Text = if ($m.Count -eq 1) { (T '전부 ' 'all ') + $names[$m[0]] } else { ($m | ForEach-Object { $names[$_] + ' ' + $c[$_] }) -join ' · ' } }
    $filter = [scriptblock]::Create($filter.ToString() + '; & $count')
    $cat.Add_SelectedIndexChanged($filter); $q.Add_TextChanged($filter); $miss.Add_CheckedChanged($filter); $vf.Add_SelectedIndexChanged($filter)
    $bAll.Add_Click({ foreach ($row in $g.Rows) { if ($row.Visible -and -not $row.Tag.o) { $row.Cells['sel'].Value = $true } } })
    $bNone.Add_Click({ foreach ($row in $g.Rows) { $row.Cells['sel'].Value = $false } })
    $bb.Add_Click({
        $g.EndEdit() | Out-Null; $shown = @($g.Rows | Where-Object { $_.Cells['sel'].Value -eq $true -and -not $_.Tag.o }); if (-not $shown.Count) { [void](Msg (T '체크한 줄이 없습니다.' 'No rows checked.')); return }
        if ((Msg ((T '체크한 ' 'Set ') + $shown.Count + (T '줄을 "' ' rows to "') + $bv.SelectedItem + (T '"(으)로 바꿀까요?' '"?')) 'Question' 'YesNo') -ne 'Yes') { return }
        foreach ($row in $shown) { $row.Cells['v'].Value = $bv.SelectedItem; & $set $row }; & $save; & $count
    })
    $page.Controls.Add($g); $page.Controls.Add($top); & $count
}

if (-not $Action) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $f = New-Object Windows.Forms.Form
    $f.Text = "D2S-MyPatch v$Ver  ·  " + (T '게임 빌드 ' 'game build ') + $build; $f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false
    $f.Font = New-Object Drawing.Font('Malgun Gothic', 10); $f.AutoSize = $true; $f.AutoSizeMode = 'GrowAndShrink'; $f.Padding = 12; $f.TopMost = $true
    $p = New-Object Windows.Forms.FlowLayoutPanel; $p.FlowDirection = 'TopDown'; $p.AutoSize = $true; $p.WrapContents = $false
    $st = New-Object Windows.Forms.Label; $st.AutoSize = $true; $st.ForeColor = 'DarkBlue'
    $st.Text = if (-not $patched) { T '현재: 원본' 'Current: original' } elseif ($pv -eq $Ver) { T "현재: 패치 v$pv" "Current: patched v$pv" } else { T "현재: 예전 패치 ($pv) → 새 버전 v$Ver 로 덮어쓰기 가능" "Current: older patch ($pv) → can re-patch v$Ver" }
    if ($patched) { try { $lj = Get-Content (Join-Path (Split-Path $optFile) 'last.json') -Raw -Encoding UTF8 | ConvertFrom-Json; $st.Text += '   ·   ' + (T "마지막 패치 $($lj.t) · 기능 $($lj.on)/$($lj.all)개 적용 · " "Last patch $($lj.t) · $($lj.on)/$($lj.all) features · ") + $(if (@($lj.bad).Count) { (T '안 된 기능: ' 'failed: ') + (@($lj.bad) -join ', ') } else { T '실패 없음' 'no failures' }) } catch {} }
    $p.Controls.Add($st)
    function Box($title, $h) {
        $gb = New-Object Windows.Forms.Panel; $gb.Tag = $title; $gb.AutoSize = $true; $gb.AutoSizeMode = 'GrowAndShrink'; $gb.Padding = '10,34,12,10'; $gb.Margin = '0,8,0,0'
        $gb.Add_Paint({ param($s, $e)
            $g = $e.Graphics; $w = $s.Width; $h = $s.Height
            $g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush((New-Object Drawing.Rectangle(0, 0, $w, 26)), [Drawing.Color]::FromArgb(70, 50, 24), [Drawing.Color]::FromArgb(16, 12, 9), [single]0)), 1, 1, $w - 2, 25)
            $g.DrawRectangle((New-Object Drawing.Pen([Drawing.Color]::FromArgb(150, 118, 64))), 0, 0, $w - 1, $h - 1)
            $g.DrawRectangle((New-Object Drawing.Pen([Drawing.Color]::FromArgb(60, 46, 26))), 3, 3, $w - 7, $h - 7)
            $g.DrawLine((New-Object Drawing.Pen([Drawing.Color]::FromArgb(150, 118, 64))), 1, 26, $w - 2, 26)
            $g.TextRenderingHint = 'AntiAliasGridFit'; $g.DrawString($s.Tag, (New-Object Drawing.Font('Malgun Gothic', 11, [Drawing.FontStyle]::Bold)), (New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(232, 200, 120))), 10, 3)
        })
        $fl = New-Object Windows.Forms.FlowLayoutPanel; $fl.FlowDirection = 'TopDown'; $fl.WrapContents = $true; $fl.AutoSize = $true; $fl.Location = New-Object Drawing.Point(10, 34); $fl.MaximumSize = New-Object Drawing.Size(0, $h)
        $gb.Controls.Add($fl); $p.Controls.Add($gb); $fl
    }
    $cbp = Box (T '기능' 'Features') ([Math]::Ceiling($feat.Count / 2) * 28 + 4)
    $cb = @{}
    foreach ($k in $feat.Keys) {
        $c = New-Object Windows.Forms.CheckBox; $c.Text = $feat[$k]; $c.AutoSize = $true; $c.Checked = [bool]$O[$k]
        if ($k -eq 'font' -and -not $hasFont) { $c.Checked = $false; $c.Enabled = $false }
        $c.Margin = '3,2,16,2'; $cb[$k] = $c; $cbp.Controls.Add($c)
    }
    function Num($label, $v, $min, $max, $step) {
        $r = New-Object Windows.Forms.FlowLayoutPanel; $r.AutoSize = $true; $r.WrapContents = $false
        $l = New-Object Windows.Forms.Label; $l.Text = $label; $l.AutoSize = $false; $l.Size = New-Object Drawing.Size(230, 28); $l.Padding = '0,6,0,0'
        $n = New-Object Windows.Forms.NumericUpDown; $n.Minimum = $min; $n.Maximum = $max; $n.Increment = $step; $n.Value = [Math]::Min($max, [Math]::Max($min, [decimal]$v)); $n.Width = 70
        $r.Controls.Add($l); $r.Controls.Add($n); $r.Margin = '3,0,16,0'; $np.Controls.Add($r); $n
    }
    $np = Box (T '조절값' 'Settings') 175
    $mr = New-Object Windows.Forms.FlowLayoutPanel; $mr.AutoSize = $true; $mr.WrapContents = $false; $mr.Margin = '3,0,16,0'
    $ml = New-Object Windows.Forms.Label; $ml.Text = T '클리어 후 자동 진행' 'After clear'; $ml.AutoSize = $false; $ml.Size = New-Object Drawing.Size(230, 28); $ml.Padding = '0,6,0,0'
    $cMode = New-Object Windows.Forms.ComboBox; $cMode.DropDownStyle = 'DropDownList'; $cMode.Width = 170
    [void]$cMode.Items.AddRange(@((T '같은 단계 계속 반복' 'Repeat same tier'), (T '한 단계씩 올라가기' 'Go up one tier')))
    $cMode.SelectedIndex = [int]($O.automode -eq 'next')
    $mr.Controls.Add($ml); $mr.Controls.Add($cMode); $np.Controls.Add($mr)
    $hk = Box (T '인게임 단축키' 'In-game hotkeys') 172
    foreach ($x in @(@('F1', (T '획득 · 판매 통계' 'Loot stats')), @('F2', (T '보관 설정' 'Keep settings')), @('F5', (T '기능 켜기 · 끄기' 'Features on · off')), @('F3', (T '드롭 확률' 'Drop odds')), @('F4', (T '룬워드 목록' 'Runewords')), @('F6', (T '설명서' 'Guide')), @('F7', (T '배속' 'Speed')), @('F8', (T 'AFK 모드' 'AFK mode')), @('F9', (T 'FPS 표시' 'FPS')), @('F10', (T '패치 기록' 'Patch log')), @('B', (T '창고 열기 · 닫기' 'Stash')), @('Ctrl+Click', (T '창고로 보내기' 'To stash')), @('Shift', (T '같은 아이템 위치 전부' 'All copies')), @('PgUp/PgDn', (T '밝기' 'Brightness')), @('Home/End', (T '명암' 'Contrast')))) {
        $hr = New-Object Windows.Forms.FlowLayoutPanel; $hr.AutoSize = $true; $hr.WrapContents = $false; $hr.Margin = '3,2,18,2'
        $kl = New-Object Windows.Forms.Label; $kl.Text = $x[0]; $kl.AutoSize = $false; $kl.Size = New-Object Drawing.Size(92, 24); $kl.TextAlign = 'MiddleCenter'; $kl.Font = New-Object Drawing.Font('Consolas', 10, [Drawing.FontStyle]::Bold); $kl.Tag = 'key'
        $kl.Add_Paint({ param($s, $e) $e.Graphics.DrawRectangle((New-Object Drawing.Pen([Drawing.Color]::FromArgb(150, 118, 64))), 0, 0, $s.Width - 1, $s.Height - 1) })
        $dl = New-Object Windows.Forms.Label; $dl.Text = $x[1]; $dl.AutoSize = $true; $dl.Padding = '0,4,0,0'
        $hr.Controls.Add($kl); $hr.Controls.Add($dl); $hk.Controls.Add($hr)
    }
    $nDelay = Num (T '자동 진행 대기 (초)' 'Auto delay (s)') $O.delay 1 30 1
    $nBright = Num (T '기본 밝기 (%)' 'Default brightness (%)') $O.brightness 50 200 5
    $nLog = Num (T '획득 목록 처음 높이 (줄)' 'Pickup log height (lines)') $O.logn 5 40 1
    $nLogSize = Num (T '획득 목록 글자 (px, 0 = 자동)' 'Pickup log font (px, 0 = auto)') $O.logsize 0 30 1
    $nLogW = Num (T '획득 목록 폭 (화면 %)' 'Pickup log width (%)') $O.logw 10 70 2
    $nContrast = Num (T '기본 명암 (%)' 'Default contrast (%)') $O.contrast 50 200 5
    $nRes = Num (T '렌더링 해상도 (%, 0 = 자동)' 'Render resolution (%, 0 = auto)') $O.res 0 200 25
    $nCap = Num (T 'FPS 제한 (0 = 제한 없음)' 'FPS cap (0 = none)') $O.fpscap 0 240 10
    $bp = New-Object Windows.Forms.FlowLayoutPanel; $bp.AutoSize = $true; $bp.Padding = '0,10,0,0'
    $bApply = New-Object Windows.Forms.Button; $bApply.Text = T '체크한 것 적용' 'Apply checked'; $bApply.AutoSize = $true; $bApply.DialogResult = 'Yes'
    $bRestore = New-Object Windows.Forms.Button; $bRestore.Text = T '원본으로 복구' 'Restore original'; $bRestore.AutoSize = $true; $bRestore.DialogResult = 'No'; $bRestore.Enabled = $patched
    $bClose = New-Object Windows.Forms.Button; $bClose.Text = T '닫기' 'Close'; $bClose.AutoSize = $true; $bClose.DialogResult = 'Cancel'
    $bGit = New-Object Windows.Forms.Button; $bGit.Text = 'GitHub'; $bGit.AutoSize = $true; $bGit.Add_Click({ Start-Process "https://github.com/$Repo" })
    $bBak = New-Object Windows.Forms.Button; $bBak.Text = T '세이브 백업 폴더' 'Save backups'; $bBak.AutoSize = $true; $bBak.Add_Click({ $d = Join-Path (Split-Path $optFile) 'backup'; [void](New-Item -ItemType Directory -Force $d); [void](Msg (T "게임 세이브를 30분마다 이 폴더에 자동으로 백업합니다 (최근 48개).`n복원: 게임 설정 → 저장 데이터 가져오기에서 원하는 파일을 고르세요." "Game saves are backed up here every 30 min (last 48).`nRestore: game settings → import save, pick a file.")); Start-Process explorer.exe $d })
    $bExp = New-Object Windows.Forms.Button; $bExp.Text = T '설정 내보내기' 'Export settings'; $bExp.AutoSize = $true; $bExp.Add_Click({ $sd = New-Object Windows.Forms.SaveFileDialog; $sd.Filter = 'JSON|*.json'; $sd.FileName = 'd2s-mypatch-settings.json'; if ($sd.ShowDialog() -ne 'OK') { return }; $parts = foreach ($n in @('options', 'keep')) { $fp = Join-Path (Split-Path $optFile) "$n.json"; if (Test-Path $fp) { '"' + $n + '":' + (Get-Content $fp -Raw -Encoding UTF8).Trim([char]0xFEFF).Trim() } }; Set-Content $sd.FileName ('{' + ($parts -join ',') + '}') -Encoding UTF8; [void](Msg (T '저장했습니다 (기능 체크 · 조절값 · 보관 설정)' 'Saved (features · values · keep settings)')) })
    $bImp = New-Object Windows.Forms.Button; $bImp.Text = T '설정 가져오기' 'Import settings'; $bImp.AutoSize = $true; $bImp.Add_Click({ $od = New-Object Windows.Forms.OpenFileDialog; $od.Filter = 'JSON|*.json'; if ($od.ShowDialog() -ne 'OK') { return }; try { $j = Get-Content $od.FileName -Raw -Encoding UTF8 | ConvertFrom-Json; if (-not $j.options -and -not $j.keep) { throw 'x' }; $d = Split-Path $optFile; [void](New-Item -ItemType Directory -Force $d); if ($j.options) { $j.options | ConvertTo-Json -Depth 20 -Compress | Set-Content $optFile -Encoding UTF8 }; if ($j.keep) { $raw = Get-Content $od.FileName -Raw -Encoding UTF8; $i = $raw.IndexOf('"keep":'); $k = $raw.Substring($i + 7).Trim(); $k = $k.Substring(0, $k.Length - 1); $k = $k -replace '^\{"t":\d+', ('{"t":' + [DateTimeOffset]::Now.ToUnixTimeMilliseconds()); [IO.File]::WriteAllText((Join-Path $d 'keep.json'), $k) }; [void](Msg (T '가져왔습니다. 패치 창을 다시 엽니다.' 'Imported. Reopening.')); if ($env:D2SF) { Start-Process cmd.exe ('/c start "" "' + $env:D2SF + '"') }; $f.Close() } catch { [void](Msg (T '올바른 설정 파일이 아닙니다' 'Not a settings file') 'Warning') } })
    $bp.Controls.AddRange(@($bApply, $bRestore, $bClose, $bGit, $bBak, $bExp, $bImp))
    $row = New-Object Windows.Forms.FlowLayoutPanel; $row.AutoSize = $true; $row.WrapContents = $false
    $lg = New-Object Windows.Forms.TextBox; $lg.Multiline = $true; $lg.ReadOnly = $true; $lg.ScrollBars = 'Vertical'; $lg.BackColor = 'White'
    $lg.Text = (T '패치 기록' 'Patch log') + "`r`n`r`n" + ($changelog -replace "`r?`n", "`r`n"); $lg.Margin = '16,0,0,0'
    $row.Controls.Add($p); $row.Controls.Add($lg)
    foreach ($x in @($cbp, $np, $hk)) { $x.PerformLayout(); $x.Size = $x.PreferredSize; $x.Parent.PerformLayout() }
    $bw = [Math]::Max([Math]::Max($cbp.PreferredSize.Width, $np.PreferredSize.Width), $hk.PreferredSize.Width) + 34; foreach ($x in @($cbp, $np, $hk)) { $x.Parent.AutoSize = $false; $x.Parent.Size = New-Object Drawing.Size($bw, ($x.PreferredSize.Height + 46)); $x.AutoSize = $false; $x.Size = New-Object Drawing.Size(($bw - 30), $x.PreferredSize.Height) }; $p.PerformLayout()
    $p.AutoSize = $false; $p.Size = $p.PreferredSize; $row.PerformLayout(); $lg.Size = New-Object Drawing.Size(412, $p.PreferredSize.Height)
    $tc = New-Object Windows.Forms.Panel; $tc.Size = New-Object Drawing.Size(($row.PreferredSize.Width + 26), ($row.PreferredSize.Height + 70))
    $t1 = New-Object Windows.Forms.Panel; $t1.Controls.Add($row); $t1.Padding = 8; $t2 = New-Object Windows.Forms.Panel; $t2.Padding = 8; $t2.Visible = $false
    $tabs = New-Object Windows.Forms.FlowLayoutPanel; $tabs.Dock = 'Top'; $tabs.Height = 36; $tabs.WrapContents = $false
    foreach ($x in @($t1, $t2)) { $x.Dock = 'Fill'; $x.BorderStyle = 'FixedSingle' }
    $tb1 = New-Object Windows.Forms.Button; $tb1.Text = T '기능' 'Features'; $tb2 = New-Object Windows.Forms.Button; $tb2.Text = T '보관 설정 (F2)' 'Keep settings (F2)'
    foreach ($x in @($tb1, $tb2)) { $x.Size = New-Object Drawing.Size(170, 32); $x.Margin = '0,0,4,0'; $x.Font = New-Object Drawing.Font('Malgun Gothic', 10, [Drawing.FontStyle]::Bold); $tabs.Controls.Add($x) }
    $tabSel = { param($i) $t1.Visible = $i -eq 0; $t2.Visible = $i -eq 1; foreach ($x in @(@($tb1, 0), @($tb2, 1))) { $x[0].Tag = ($x[1] -eq $i) }; $tb1.Invalidate(); $tb2.Invalidate() }
    $tb1.Add_Click({ & $tabSel 0 }); $tb2.Add_Click({ & $tabSel 1; if ($dark) { & $dark $t2 } })
    $tc.Controls.Add($t2); $tc.Controls.Add($t1); $tc.Controls.Add($tabs)
    . $KeepTab $t2
    $fp = New-Object Windows.Forms.FlowLayoutPanel; $fp.FlowDirection = 'TopDown'; $fp.AutoSize = $true; $fp.WrapContents = $false; $fp.Controls.AddRange(@($tc, $bp)); $f.Controls.Add($fp); $f.AcceptButton = $bApply; $f.CancelButton = $bClose
    # 디아블로풍 꾸미기: 어두운 배경 · 금색 글씨, 게임 메뉴 그림 배너, 돌 버튼 (게임 그림이 없으면 색만)
    $fe = Join-Path $env:APPDATA 'D2 Survivors\d2\frontend'
    $cBg = [Drawing.Color]::FromArgb(16, 12, 9); $cBg2 = [Drawing.Color]::FromArgb(30, 23, 16); $cGold = [Drawing.Color]::FromArgb(222, 196, 132); $cTxt = [Drawing.Color]::FromArgb(214, 206, 188); $cEdge = [Drawing.Color]::FromArgb(92, 72, 42)
    $imgBtn = $null; try { $imgBtn = [Drawing.Image]::FromFile((Join-Path $fe 'button-wide.png')) } catch {}
    $imgBan = $null; try { $imgBan = [Drawing.Image]::FromFile((Join-Path $fe 'menu.png')) } catch {}
    $skin = {
        param($c)
        if ($c -is [Windows.Forms.DataGridView]) {
            $c.BackgroundColor = $cBg; $c.GridColor = $cEdge; $c.BorderStyle = 'FixedSingle'; $c.EnableHeadersVisualStyles = $false
            $c.DefaultCellStyle.BackColor = $cBg2; $c.DefaultCellStyle.ForeColor = $cTxt; $c.DefaultCellStyle.SelectionBackColor = [Drawing.Color]::FromArgb(80, 56, 24); $c.DefaultCellStyle.SelectionForeColor = [Drawing.Color]::White
            $c.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(44, 32, 18); $c.ColumnHeadersDefaultCellStyle.ForeColor = $cGold; $c.ColumnHeadersBorderStyle = 'Single'
        } elseif ($c -is [Windows.Forms.Button]) {
            $c.FlatStyle = 'Flat'; $c.FlatAppearance.BorderColor = $cEdge; $c.ForeColor = [Drawing.Color]::FromArgb(240, 228, 196); $c.BackColor = $cBg2; $c.Padding = '10,2,10,2'
            if ($imgBtn) { $c.BackgroundImage = $imgBtn; $c.BackgroundImageLayout = 'Stretch'; $c.FlatAppearance.BorderSize = 0 }
        } elseif ($c -is [Windows.Forms.TextBox] -or $c -is [Windows.Forms.ComboBox] -or $c -is [Windows.Forms.NumericUpDown]) {
            $c.BackColor = [Drawing.Color]::FromArgb(36, 28, 20); $c.ForeColor = $cTxt
            if ($c -is [Windows.Forms.ComboBox]) {
                $c.FlatStyle = 'Flat'; $c.DrawMode = 'OwnerDrawFixed'
                $c.Add_DrawItem({ param($s, $e) if ($e.Index -lt 0) { return }; $sel = ($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0
                    $e.Graphics.FillRectangle((New-Object Drawing.SolidBrush($(if ($sel) { [Drawing.Color]::FromArgb(80, 56, 24) } else { [Drawing.Color]::FromArgb(36, 28, 20) }))), $e.Bounds)
                    $e.Graphics.DrawString([string]$s.Items[$e.Index], $s.Font, (New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(230, 218, 190))), [single]($e.Bounds.X + 2), [single]($e.Bounds.Y + 1)) })
            } else { $c.BorderStyle = 'FixedSingle' }
        } elseif ($c -is [Windows.Forms.GroupBox]) { $c.ForeColor = $cGold; $c.BackColor = $cBg }
        elseif ($c -is [Windows.Forms.TabPage] -or $c -is [Windows.Forms.Panel] -or $c -is [Windows.Forms.Form]) { $c.BackColor = $cBg; $c.ForeColor = $cTxt }
        elseif ($c -is [Windows.Forms.Label] -and $c.Tag -eq 'key') { $c.ForeColor = $cGold; $c.BackColor = [Drawing.Color]::FromArgb(40, 30, 18) }
        elseif ($c -is [Windows.Forms.CheckBox] -or $c -is [Windows.Forms.Label]) { if ($c.ForeColor -eq [Drawing.Color]::DarkBlue) { $c.ForeColor = $cGold } else { $c.ForeColor = $cTxt } }
        foreach ($x in $c.Controls) { & $skin $x }
    }
    & $skin $f
    try { Add-Type -Namespace D2S -Name Dark -MemberDefinition '[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr h, string a, string b); [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);' } catch {}
    $dark = { param($c) if (($c -is [Windows.Forms.TextBox] -and $c.Multiline) -or $c -is [Windows.Forms.ScrollBar]) { try { [void][D2S.Dark]::SetWindowTheme($c.Handle, 'DarkMode_Explorer', $null) } catch {} }; foreach ($x in $c.Controls) { & $dark $x } }
    $f.Add_Load({ try { $v = 1; [void][D2S.Dark]::DwmSetWindowAttribute($f.Handle, 20, [ref]$v, 4) } catch {}; & $dark $f })
    # 탭: 어두운 바탕에 금색 글씨로 직접 그림
    foreach ($x in @($tb1, $tb2)) { $x.FlatAppearance.BorderSize = 1; $x.Add_Paint({ param($s, $e) if ($s.Tag) { $e.Graphics.DrawRectangle((New-Object Drawing.Pen($cGold, 2)), 1, 1, $s.Width - 3, $s.Height - 3) } }) }; & $tabSel 0
    # 맨 위 배너: 게임 메뉴 그림(가로로 잘라 채움) + 어둡게 + 금색 제목
    $ban = New-Object Windows.Forms.PictureBox; $ban.Size = New-Object Drawing.Size($tc.Width, 110); $lg0 = @(); foreach ($n in @(@('logo-d2logoblackleft.png', 25, 159, 122, 169, 75, 0), @('logo-d2logoblackright.png', 25, 159, 122, -9, 75, 0), @('logo-d2logofireleft.png', 23, 178, 165, 180, 111, 1), @('logo-d2logofireright.png', 22, 184, 171, 4, 110, 1))) { try { $lg0 += , @([Drawing.Image]::FromFile((Join-Path $fe $n[0])), $n[1], $n[2], $n[3], $n[4], $n[5], $n[6]) } catch {} }; $script:lgf = 0; $ia = New-Object Drawing.Imaging.ImageAttributes; $ia.SetColorKey([Drawing.Color]::FromArgb(0, 0, 0), [Drawing.Color]::FromArgb(48, 40, 40)); $tmr = New-Object Windows.Forms.Timer; $tmr.Interval = 40; $tmr.Add_Tick({ $script:lgf = ($script:lgf + 1) % 30; $ban.Invalidate() }); if ($lg0.Count -eq 4) { $tmr.Start() }; $ban.Margin = '0,0,0,6'
    $ban.Add_Paint({ param($s, $e)
        $g = $e.Graphics; $r = $s.ClientRectangle
        if ($imgBan) { $h = [int]($imgBan.Width * $r.Height / $r.Width); $g.DrawImage($imgBan, $r, (New-Object Drawing.Rectangle(0, [int](($imgBan.Height - $h) * 0.66), $imgBan.Width, $h)), [Drawing.GraphicsUnit]::Pixel) } else { $g.Clear($cBg2) }
        $g.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush($r, [Drawing.Color]::FromArgb(150, 8, 6, 4), [Drawing.Color]::FromArgb(0, 8, 6, 4), [single]0)), $r)
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $ft = New-Object Drawing.Font('Times New Roman', 26, [Drawing.FontStyle]::Bold); $fs = New-Object Drawing.Font('Malgun Gothic', 10)
        $g.DrawString('D2S-MyPatch', $ft, (New-Object Drawing.SolidBrush([Drawing.Color]::Black)), 22, 16); $g.DrawString('D2S-MyPatch', $ft, (New-Object Drawing.SolidBrush($cGold)), 20, 14)
        $g.DrawString(("v$Ver  ·  " + (T '게임 빌드 ' 'game build ') + $build + '   ·   ' + $st.Text), $fs, (New-Object Drawing.SolidBrush($cTxt)), 24, 60)
        if ($lg0.Count -eq 4) { $k = 0.62; $cx = $r.Width - 170; $cy = 62; foreach ($L in $lg0) { $fr = $script:lgf; $sx = ($fr % $L[1]) * $L[2]; $sy = [Math]::Floor($fr / $L[1]) * $L[3]; $d = New-Object Drawing.Rectangle([int]($cx - $L[4] * $k), [int]($cy - $L[5] * $k), [int]($L[2] * $k), [int]($L[3] * $k)); if ($L[6]) { $g.DrawImage($L[0], $d, $sx, $sy, $L[2], $L[3], [Drawing.GraphicsUnit]::Pixel, $ia) } else { $g.DrawImage($L[0], $d, $sx, $sy, $L[2], $L[3], [Drawing.GraphicsUnit]::Pixel) } } }
        $g.DrawRectangle((New-Object Drawing.Pen($cEdge)), 0, 0, $r.Width - 1, $r.Height - 1)
    })
    $fp.Controls.Add($ban); $fp.Controls.SetChildIndex($ban, 0); $st.Visible = $false
    if ($env:D2S_SHOT) { $f.Add_Shown({ $b = New-Object Drawing.Bitmap($f.Width, $f.Height); $f.DrawToBitmap($b, (New-Object Drawing.Rectangle(0, 0, $f.Width, $f.Height))); $b.Save($env:D2S_SHOT); $f.Close() }) }
    $f.Add_Shown({ $f.Activate(); $f.BringToFront() })
    $res = $f.ShowDialog()
    if ($res -eq 'Yes') {
        $Action = 'patch'
        foreach ($k in $feat.Keys) { $O[$k] = $cb[$k].Checked }
        $O.logsize = [int]$nLogSize.Value; $O.logw = [int]$nLogW.Value; $O.automode = @('same', 'next')[$cMode.SelectedIndex]; $O.delay = [int]$nDelay.Value; $O.brightness = [int]$nBright.Value; $O.logn = [int]$nLog.Value
        $O.contrast = [int]$nContrast.Value; $O.res = [int]$nRes.Value; $O.fpscap = [int]$nCap.Value
        New-Item -ItemType Directory -Force (Split-Path $optFile) | Out-Null
        $O | ConvertTo-Json | Set-Content $optFile -Encoding UTF8
    } elseif ($res -eq 'No') { $Action = 'restore' }
    else { Done 0 }
}
if (-not $hasFont) { $O.font = $false }
$on = $feat.Keys | Where-Object { $O[$_] } | ForEach-Object { $feat[$_] }
$beep = 'globalThis.__beep=t=>{try{let a=globalThis.__ac??=new AudioContext,n=a.currentTime;([[1047,1568],[880],[523,392]][t]??[880]).forEach((f,i)=>{let o=a.createOscillator(),v=a.createGain(),q=n+i*.13;o.type=`triangle`,o.frequency.value=f,v.gain.setValueAtTime(0,q),v.gain.linearRampToValueAtTime(.1,q+.01),v.gain.exponentialRampToValueAtTime(.001,q+.4),o.connect(v).connect(a.destination),o.start(q),o.stop(q+.45)})}catch{}};'
$short = [ordered]@{ carry = T '자동등록' 'stash'; pickup = T '즉시습득' 'pickup'; goldchest = T '골드상자' 'gold'; overflow = T '꽉차면창고' 'overflow'; log = T '획득목록' 'log'; swpop = T '교체창' 'swap'; twins = T '비교상자' 'compare'; hidden = T '숨은값' 'hidden'; auto = T '자동진행' 'auto'; nopause = T '창안멈춤' 'nopause'; stash = T 'B창고' 'Bstash'; afk = 'AFK'; speed = T '배속' 'speed'; bright = T '밝기명암' 'bright'; hud = T 'HUD배치' 'hud'; corpse = T '시체숨김' 'corpse'; fps = 'FPS'; dropsnd = T '드롭소리' 'dropsound'; shard = T '파편안내' 'shard'; tyrael = T '티리엘멈춤' 'tyrael'; stats = T '통계' 'stats'; f2tip = T 'F2판정' 'f2tip'; font = T '폰트' 'font' }
$live = @($feat.Keys | Where-Object { $_ -ne 'font' })
$On = @{}; foreach ($k in $feat.Keys) { $On[$k] = [bool]$O[$k] }
function MkApplied { (($short.Keys | ForEach-Object { $(if ($On[$_]) { [char]0x2713 } else { [char]0x2717 }) + $short[$_] }) -join ' · ') + ' | ' + $(if ($O.auto) { $(if ($O.automode -eq 'next') { T '다음 단계' 'next tier' } else { T '같은 단계' 'same tier' }) + " $($O.delay)" + (T '초' 's') + ' · ' } else { '' }) + (T '해상도 ' 'res ') + $(if ([int]$O.res -gt 0) { "$($O.res)%" } else { T '자동' 'auto' }) + ' · ' + (T 'FPS 제한 ' 'FPS cap ') + $(if ([int]$O.fpscap -gt 0) { $O.fpscap } else { T '없음' 'none' }) }
$applied = MkApplied
foreach ($k in $live) { $O[$k] = $true }

if ($Action -eq 'restore') {
    if (-not $patched) { Fail (T '패치가 적용되어 있지 않습니다. 복구할 것이 없습니다.' 'The patch is not applied. Nothing to restore.') }
    if (-not (Test-Path $backup)) { Fail (T "백업 파일이 없습니다: $backup" "Backup not found: $backup") }
    Copy-Item $backup $asar -Force
    [void](Msg (T '원래대로 복구했습니다.' 'Original restored.'))
    Done 0
}

# 이미 패치된 상태면 같은 버전의 백업 원본에서 다시 패치한다 (새 기능 반영)
$fromBackup = $false
if ($patched) {
    if (-not (Test-Path $backup)) { Fail (T "백업 파일이 없습니다: $backup" "Backup not found: $backup") }
    $bytes = [IO.File]::ReadAllBytes($backup)
    $headerSize = [BitConverter]::ToUInt32($bytes, 4)
    $jsonLen = [BitConverter]::ToUInt32($bytes, 12)
    $header = $utf8.GetString($bytes, 16, $jsonLen)
    $dataStart = 8 + $headerSize
    $gameEntry = Entry 'Game'
    $keepEntry = if ($header -match '"moved-[A-Za-z0-9_-]{8}\.js"') { Entry 'moved' } else { Entry 'saveTransfer' }
    $uiEntry = if ($keepEntry.Groups[1].Value -like 'moved-*') { Entry 'saveTransfer' } else { Entry 'leaderboardSend' }
    $game = ReadFile $gameEntry
    $fromBackup = $true
}

$bad = @()
try {
# --- 축약된 함수 이름은 버전마다 바뀌므로 주변 코드로 찾아낸다 ---
$id = '[\w$]+'
function Find($text, $pattern, $what) {
    $m = [regex]::Matches($text, $pattern)
    if ($m.Count -ne 1) { throw "D2SUNSUP:$what" }
    $m[0]
}
function Swap($text, $old, $new, $what) {
    $i = $text.IndexOf($old)
    if ($i -lt 0 -or $i -ne $text.LastIndexOf($old)) { throw "D2SUNSUP:$what" }
    $text.Substring(0, $i) + $new + $text.Substring($i + $old.Length)
}

$stash = Find $game "\?($id)\(i,n\)\?\($id\(s\(\),n\),($id)\(i,n\),this\.moved\(n\)" 'stash'
$canKeep = $stash.Groups[1].Value; $keep = $stash.Groups[2].Value
$moved = Find $game "moved\(e\)\{($id)\(this\.save\),($id)\(e\.base\)" 'moved'
$save = $moved.Groups[1].Value; $sound = $moved.Groups[2].Value
$banner = Find $game "carry\(e\)\{.{0,600}?this\.hud\.banner\(($id)\(e\.name,e\.rarity,e\.base\),e\.rarity\)" 'carry'
$name = $banner.Groups[1].Value
$price = (Find $game 'autoSell\(e\)\{let t=([\w$]+)\(this\.save,this\.world\.player\.cls,e\);' 'price').Groups[1].Value
$swap = (Find $game "let o=($id)\(this\.save,t\);if\(!o\)return this\.refuseTwin" 'swap').Groups[1].Value
$suffix = T ' - 보관함 등록' ' - Stashed'
$swapped = T ' - 보관함 교체' ' - Upgraded'

# 인벤토리가 꽉 차면 개인 창고 → 공용 창고 탭 순서로 빈자리에 넣는다
$si = Find $game ("swapIn\(e,t,n\)\{let r=$id\(this\.save,e,t\),i=r\?($id)\(this\.save,e,r\):this\.inventoryOf\(e\).{0,200}?let s=r\?($id):($id),c=$id\(i,o,a,s\),l=c\.fits&&!c\.swap\?a:($id)\(i,o,s\);if\(!l\)\{.{0,60}?($id)\(i,t,a\)") 'stash grid'
$rm = (Find $game (";($id)\(i,t\);let s=r\?") 'remove').Groups[1].Value
$tab = $si.Groups[1].Value; $sgrid = $si.Groups[2].Value; $igrid = $si.Groups[3].Value; $fit = $si.Groups[4].Value; $put = $si.Groups[5].Value
$movedText = ReadFile $keepEntry
$tabsLocal = (Find $movedText ('(' + $id + ')=\[`personal`,\.\.\.' + $id + '\]') 'tabs').Groups[1].Value
$tabsExp = (Find $movedText ('[{,]' + [regex]::Escape($tabsLocal) + ' as (' + $id + ')[,}]') 'tabs export').Groups[1].Value
$tabs = (Find $game ('[{,]' + [regex]::Escape($tabsExp) + ' as (' + $id + ')[,}]') 'tabs import').Groups[1].Value
# 창고 정리 함수 (F5 창의 창고 정리 버튼)
$game = 'globalThis.__saveNow=()=>' + $save + '(globalThis.__gm.save);globalThis.__sortStash=((__Sv,__T,__Fi,__Gr,__Pu)=>(m,ks)=>{let g=globalThis.__gm;if(!g?.save||g.state===`loading`)return`' + (T '게임 안에서 누르세요' 'Use it in game') + '`;let __rf=()=>{try{g.state===`character`?g.openCharacter(g.characterReturn):g.trade&&g.state===`town`&&g.showTown()}catch{}};let c=g.world?.player?.cls??g.kit?.id;if(!c)return`' + (T '영웅을 고른 뒤 누르세요' 'Pick a hero first') + '`;let S=__Sv,G=k=>__T(g.save,c,k);if(m===`undo`){let u=globalThis.__stU;if(!u||u.c!==c)return`' + (T '되돌릴 정리가 없습니다' 'Nothing to undo') + '`;let A=u.ks.map(G);if(A.flat().map(x=>x.id).sort().join()!==u.ids)return`' + (T '정리 뒤 창고가 바뀌어 되돌릴 수 없습니다' 'Stash changed since, cannot undo') + '`;A.forEach((a,i)=>{a.length=0,a.push(...u.B[i])}),u.B.flat().forEach((x,i)=>x.at=u.P[i]),S(g.save),globalThis.__stU=null,__rf();return`' + (T '되돌렸습니다' 'Undone') + '`}if(!ks.length)return`' + (T '탭을 하나 이상 고르세요' 'Pick at least one tab') + '`;let A=ks.map(G),I=A.flat(),B=A.map(a=>[...a]),P=B.flat().map(x=>x.at&&{...x.at}),ids=I.map(x=>x.id).sort().join(),snap=JSON.stringify({c,ks,t:Date.now(),tabs:B}),K=e=>{let d=globalThis.__kd?.(e)??``,w=/[12]$/.test(d)?0:[`head`,`body`,`shield`,`gloves`,`boots`,`belt`,`ring`,`amulet`,`jewel`,`charm`].indexOf(d);return/[12]$/.test(d)?0:w<0?11:w+1},R=e=>({unique:0,set:1,runeword:2,rare:3,magic:4}[e.rarity]??5),Z=e=>{let[w,h]=globalThis.__bsz?.(e)??[1,1];return w*h},N=e=>String(e.name??e.base??``),C={kind:(a,b)=>K(a)-K(b)||R(a)-R(b)||N(a).localeCompare(N(b)),name:(a,b)=>N(a).localeCompare(N(b))||R(a)-R(b),rarity:(a,b)=>R(a)-R(b)||K(a)-K(b)||N(a).localeCompare(N(b)),size:(a,b)=>Z(b)-Z(a)||K(a)-K(b)||N(a).localeCompare(N(b))}[m],Y=globalThis.__stLay??`fill`,T0=new Map(B.flatMap((a,i)=>a.map(x=>[x,i]))),Gp=e=>{let d=globalThis.__kd?.(e)??``;return/[12]$/.test(d)?0:[`head`,`body`,`shield`,`gloves`,`boots`,`belt`].includes(d)?1:[`ring`,`amulet`,`jewel`].includes(d)?2:d===`charm`?3:4},gs=[...new Set(I.map(Gp))].sort(),O=e=>{let n=A.length,o=[...Array(n).keys()];if(Y===`each`)return[T0.get(e)];if(Y===`kind`){let t=Math.min(gs.indexOf(Gp(e)),n-1);return[...o.slice(t),...o.slice(0,t)]}return o},F=L=>{for(let a of A)a.length=0;for(let e of L){let o=O(e);delete e.at;if(!o.some(i=>{let a=A[i],p=__Fi(a,e,__Gr);return p&&(__Pu(a,e,p),!0)}))return!1}return!0},back=()=>{A.forEach((a,i)=>{a.length=0,a.push(...B[i])}),B.flat().forEach((x,i)=>x.at=P[i])};if(!C)return``;if(!F([...I].sort(C))&&!F([...I].sort((a,b)=>Z(b)-Z(a)||C(a,b))))return back(),`' + (T '자리가 모자라 정리하지 못했습니다 (원래대로 둠)' 'Not enough room, left as is') + '`;let W=A.flat();if(W.length!==I.length||W.map(x=>x.id).sort().join()!==ids||W.some(x=>!x.at))return back(),`' + (T '확인 실패: 원래대로 둠' 'Check failed, left as is') + '`;try{localStorage.setItem(`d2s:stbak`,snap)}catch{}globalThis.__stU={c,ks,B,P,ids},S(g.save),__rf();return`${I.length}' + (T '개 정리했습니다 · 되돌리기 가능' 'items sorted · undo available') + '`})(' + $save + ',' + $tab + ',' + $fit + ',' + $sgrid + ',' + $put + ');' + $game
if ($O.overflow) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$game = Swap $game "let t=this.inventoryOf(this.world.player.cls),n=$fit(t,e,$igrid);if(!n)return!1;" "let t=this.inventoryOf(this.world.player.cls),n=$fit(t,e,$igrid);if(!n){if(globalThis.__on(``overflow``))for(let k of $tabs){let a=$tab(this.save,this.world.player.cls,k),p=$fit(a,e,$sgrid);if(p)return $put(a,e,p),$save(this.save),globalThis.__st=1,!0}return!1}" 'stash overflow'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'overflow' } }
$uiText = ReadFile $uiEntry
$keepText = ReadFile $keepEntry
# 창고(10줄) 빈칸 찾기: 가로 채우기를 켜면 오른쪽 먼저, 줄이 차면 다음 줄 왼쪽부터
$keepText = [regex]::Replace($keepText, ('function (' + $id + ')\(e,t\)\{let\[n,r\]=(' + $id + ')\(t\);(for\(let i=0;i<=e\[0\]\.length-n;i\+\+\)for\(let n=0;n<=e\.length-r;n\+\+\)if\((' + $id + ')\(e,t,\{x:i,y:n\}\)\))'), 'function $1(e,t){let[n,r]=$2(t);if(e.length===10&&globalThis.__rowFill){for(let y=0;y<=e.length-r;y++)for(let x=0;x<=e[0].length-n;x++)if($4(e,t,{x,y}))return{x,y};return null}$3')
try { try { $uiText = Swap $uiText 'function R_(e){if(!e||e.done)return``;' 'function R_(e){globalThis.__wave=e;if(!e||e.done)return``;' 'afk wave' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $uiText = Swap $uiText 'function I_(e){if(!e||e.done)return``;' 'function I_(e){globalThis.__wave=e;if(!e||e.done)return``;' 'afk wave' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $uiText = Swap $uiText 'function ns(e){if(!e||e.done)return``;' 'function ns(e){globalThis.__wave=e;if(!e||e.done)return``;' 'afk wave' }
if ($O.stash) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 창고 창이 닫혀 있어도 인벤토리에서 Ctrl+클릭하면 개인 → 공용 창고 빈자리로 보낸다
$game = Swap $game '...n&&{toStash:n=>{' ("__toStash:n=>{let a=s();if(!a.includes(n))return;for(let k of $tabs){let b=$tab(i,e,k),p=$fit(b,n,$sgrid);if(p)return r.change(()=>{$rm(a,n),$put(b,n,p)}),this.moved(n),t()}this.hud.refuse(``" + (T '창고가 가득 찼습니다' 'Stash is full') + "``)},...n&&{toStash:n=>{") 'ctrl stash'
try { $uiText = Swap $uiText 'click:r=>{r.shiftKey?n.sell(e.item):o&&(r.ctrlKey||r.metaKey)?' 'click:r=>{!o&&(r.ctrlKey||r.metaKey)&&n.__toStash&&globalThis.__on?.(`stash`)!==!1?n.__toStash(e.item):r.shiftKey?n.sell(e.item):o&&(r.ctrlKey||r.metaKey)?' 'ctrl click' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $keepText = Swap $keepText 'click:r=>{r.shiftKey?n.sell(e.item):o&&(r.ctrlKey||r.metaKey)?' 'click:r=>{!o&&(r.ctrlKey||r.metaKey)&&n.__toStash&&globalThis.__on?.(`stash`)!==!1?n.__toStash(e.item):r.shiftKey?n.sell(e.item):o&&(r.ctrlKey||r.metaKey)?' 'ctrl click' }
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'stash' } }
if ($O.nopause) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 런 도중 캐릭터/인벤토리/스킬/퀘스트 창을 열어도 게임이 멈추지 않고 계속 진행 (Esc 일시정지는 그대로)
try { try { $game = Swap $game 'let i=this.state===`playing`&&this.strayPlay();for(let e=0;e<M.speed*t&&i&&this.state===`playing`&&!r;e++)' 'let __lv=()=>this.state===`playing`||globalThis.__on(`nopause`)&&this.state===`character`&&this.characterReturn===`playing`&&!this.camp,i=__lv()&&this.strayPlay();for(let e=0;e<M.speed*t&&i&&__lv();e++)' 'live panels' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'let i=this.state===`playing`&&this.strayPlay();for(let e=0;e<I.speed*t&&i&&this.state===`playing`&&!r;e++)' 'let __lv=()=>this.state===`playing`||globalThis.__on(`nopause`)&&this.state===`character`&&this.characterReturn===`playing`&&!this.camp,i=__lv()&&this.strayPlay();for(let e=0;e<I.speed*t&&i&&__lv();e++)' 'live panels' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'let i=this.state===`playing`&&this.strayPlay();for(let e=0;e<j.speed*t&&i&&this.state===`playing`&&!r;e++)' 'let __lv=()=>this.state===`playing`||globalThis.__on(`nopause`)&&this.state===`character`&&this.characterReturn===`playing`&&!this.camp,i=__lv()&&this.strayPlay();for(let e=0;e<j.speed*t&&i&&__lv();e++)' 'live panels' }
try { try { $game = Swap $game 'this.state===`character`&&Kt(this.world,' 'this.state===`character`&&(this.characterReturn!==`playing`||!globalThis.__on(`nopause`))&&Kt(this.world,' 'live panels idle' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'this.state===`character`&&qt(this.world,' 'this.state===`character`&&(this.characterReturn!==`playing`||!globalThis.__on(`nopause`))&&qt(this.world,' 'live panels idle' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'this.state===`character`&&Ct(this.world,' 'this.state===`character`&&(this.characterReturn!==`playing`||!globalThis.__on(`nopause`))&&Ct(this.world,' 'live panels idle' }
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'nopause' } }
if ($O.twins) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 툴팁 옆 게임 비교 상자: 같은 이름·같은 종류만, 등록/개인 창고/공용 창고 1~3/인벤 위치와 좋고 나쁨 표시 (최대 3개)
$game = 'globalThis.__shift=0;addEventListener(`keydown`,e=>{e.key===`Shift`&&(globalThis.__shift=1)},!0);addEventListener(`keyup`,e=>{e.key===`Shift`&&(globalThis.__shift=0)},!0);addEventListener(`blur`,()=>globalThis.__shift=0);' + "globalThis.__twins=e=>{let g=globalThis.__gm;if(!g||!/^(unique|set|runeword)`$/.test(e.rarity))return null;let c=g.kit?.id,K=__kd(e),m=x=>x!==e&&x.rarity===e.rarity&&x.name===e.name&&(globalThis.__shift||__kd(x)===K),v=x=>__gt(x,e)?``$(T '▲ 보관본이 더 좋음' '▲ stored is better')``:__gt(e,x)?``$(T '▼ 보관본이 더 나쁨' '▼ stored is worse')``:``$(T '= 같음' '= same')``,q=x=>__gt(x,e)?``better``:__gt(e,x)?``worse``:``equipped``,r=[];for(let x of g.save.uniques??[])m(x)&&r.push({label:``$(T '등록' 'Stashed') · ``+v(x),item:x,cls:q(x)});for(let k of $tabs)for(let x of $tab(g.save,c,k))m(x)&&r.push({label:({personal:``$(T '개인 창고' 'Personal')``,shared1:``$(T '공용 창고 1' 'Shared 1')``,shared2:``$(T '공용 창고 2' 'Shared 2')``,shared3:``$(T '공용 창고 3' 'Shared 3')``}[k]??k)+`` · ``+v(x),item:x,cls:q(x)});for(let x of g.inventoryOf(c))m(x)&&r.push({label:``$(T '인벤' 'Inventory') · ``+v(x),item:x,cls:q(x)});return r.slice(0,globalThis.__shift?20:3).map(o=>{let p=(globalThis.__slot?.(o.item)??````).split(`` · ``);p.length>2&&(p.shift(),p.pop());p.length&&(o.label=o.label.replace(`` · ``,`` · ``+p.join(`` · ``)+`` · ``));return o})};" + $game
try { try { $uiText = Swap $uiText 'c=[...o?[{label:Et,item:o}]:[],' 'c=[...(globalThis.__twins?.(e)?.slice(0,globalThis.__shift?20:Math.max(1,3-(s?a.length:0)))??(o?[{label:Et,item:o}]:[])),' 'twin boxes' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $uiText = Swap $uiText 'c=[...o?[{label:xt,item:o}]:[],' 'c=[...(globalThis.__twins?.(e)?.slice(0,globalThis.__shift?20:Math.max(1,3-(s?a.length:0)))??(o?[{label:xt,item:o}]:[])),' 'twin boxes' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $L = (Find $keepText 'c=\[\.\.\.o\?\[\{label:([\w$]+),item:o\}\]:\[\],' 'twin boxes').Groups[1].Value; $keepText = Swap $keepText ('c=[...o?[{label:' + $L + ',item:o}]:[],') ('c=[...(globalThis.__twins?.(e)?.slice(0,globalThis.__shift?20:Math.max(1,3-(s?a.length:0)))??(o?[{label:' + $L + ',item:o}]:[])),') 'twin boxes' }
try { $uiText = Swap $uiText 'e.replaceChildren(R(`equipped`,c[t].label),' 'e.replaceChildren(R(c[t].cls??`equipped`,c[t].label),' 'twin colors' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $L = (Find $keepText 'e\.replaceChildren\(([\w$]+)\(`equipped`,c\[t\]\.label\),' 'twin colors').Groups[1].Value; $keepText = Swap $keepText ('e.replaceChildren(' + $L + '(`equipped`,c[t].label),') ('e.replaceChildren(' + $L + '(c[t].cls??`equipped`,c[t].label),') 'twin colors' }
try { try { $uiText = Swap $uiText ',!n)return tl(this.node);el(e,this.node,t,' ',!n&&!globalThis.__twins?.(e)?.length)return tl(this.node);el(e,this.node,t,' 'twin equipped' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $uiText = Swap $uiText ',!n)return el(this.node);$c(e,this.node,t,' ',!n&&!globalThis.__twins?.(e)?.length)return el(this.node);$c(e,this.node,t,' 'twin equipped' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $L = Find $keepText ',!n\)return ([\w$]+)\(this\.node\);([\w$]+)\(e,this\.node,t,' 'twin equipped'; $keepText = Swap $keepText $L.Value (',!n&&!globalThis.__twins?.(e)?.length)return ' + $L.Groups[1].Value + '(this.node);' + $L.Groups[2].Value + '(e,this.node,t,') 'twin equipped' }
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'twins' } }
if ($O.hidden) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 툴팁 맨 아래에 화면에 안 나오는 숨겨진 값 표시 (비교 계산에는 넣지 않음)
$game = "globalThis.__hid=e=>(e.stats??[]).flatMap(b=>b.stat===``coldlength``?[``$(T '숨겨진 값' 'Hidden'): $(T '냉기 지속 시간' 'cold duration') ``+(b.value/25).toFixed(1)+``$(T '초' 's')``]:b.stat===``item_extrablood``?[``$(T '숨겨진 값' 'Hidden'): $(T '피 튀김 효과 증가' 'extra blood') ``+b.value]:b.stat===``maxdurability``?[``$(T '숨겨진 값' 'Hidden'): $(T '최대 내구도' 'max durability') ``+b.value]:[]);" + $game
try { try { $uiText = Swap $uiText 'function Wc(e,t,n=Ei(I.held||I.tapped)){let r=' 'function Wc(e,...a){return[...Uc0(e,...a),...(globalThis.__hid?.(e)??[]).map(t=>R(`inert`,t)),...(globalThis.__f2t?.(e)??[]).map(t=>R(`unique`,t))]}function Uc0(e,t,n=Ei(I.held||I.tapped)){let r=' 'hidden stats' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $uiText = Swap $uiText 'function Uc(e,t,n=Di(I.held||I.tapped)){let r=' 'function Uc(e,...a){return[...Uc0(e,...a),...(globalThis.__hid?.(e)??[]).map(t=>R(`inert`,t)),...(globalThis.__f2t?.(e)??[]).map(t=>R(`unique`,t))]}function Uc0(e,t,n=Di(I.held||I.tapped)){let r=' 'hidden stats' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $L = Find $keepText 'function ([\w$]+)\(e,t,(n=[\w$]+\(([\w$]+)\.held\|\|\3\.tapped\)\)\{let r=)' 'hidden stats'; $R = (Find $keepText 'e\.replaceChildren\(([\w$]+)\((?:c\[t\]\.cls\?\?)?`equipped`,c\[t\]\.label\),' 'hidden stats').Groups[1].Value; $keepText = Swap $keepText $L.Value ('function ' + $L.Groups[1].Value + '(e,...a){return[...Uc0(e,...a),...(globalThis.__hid?.(e)??[]).map(t=>' + $R + '(`inert`,t)),...(globalThis.__f2t?.(e)??[]).map(t=>' + $R + '(`unique`,t))]}function Uc0(e,t,' + $L.Groups[2].Value) 'hidden stats' }
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'hidden' } }
if ($O.carry) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 미등록 유니크/세트/룬워드는 보관함에 등록. 스킬 옵션 합 > 오라·발동 기술 레벨 합 > 그 외 옵션 합 > 방어력 옵션 합 순서로 비교해 높으면 교체하고
# 밀려난 옛 아이템은 룬워드면 인벤토리, 아니면 판매. 중복 룬워드는 인벤토리로 (아래 일반 경로)
$game = Swap $game 'carry(e){let t=this.inventoryOf' "carry(e){if(globalThis.__on(``carry``)){if($canKeep(this.save,e))return $keep(this.save,e),$save(this.save),$sound(e.base),this.hud.banner($name(e.name,e.rarity,e.base)+``$suffix``,e.rarity),!0;if(!this.__nx){let o=__bt(this.save,e)&&$swap(this.save,e);if(o)return $save(this.save),$sound(e.base),this.hud.banner($name(e.name,e.rarity,e.base)+``$swapped``,e.rarity),__sw($name(e.name,e.rarity,e.base),o,e),globalThis.__swu=o.rarity===``runeword``?null:()=>{let s=this.save.uniques,i=s?.indexOf(e)??-1;if(i<0||!this.world)return!1;s[i]=o;this.world.gold-=$price(this.save,this.world.player.cls,o);$save(this.save);this.autoSell(e);return!0},o.rarity===``runeword``?(this.__nx=1,this.carry(o)||this.autoSell(o),this.__nx=0):this.autoSell(o),!0}if(e.rarity===``runeword``){if(globalThis.__ksv?.(e)===2)return this.autoSell(e),globalThis.__st=2,!0;let K=__kd(e),A=[this.inventoryOf(this.world.player.cls),...$tabs.map(k=>$tab(this.save,this.world.player.cls,k))],C=A.flatMap(a=>a.filter(x=>x!==e&&x.rarity===``runeword``&&x.name===e.name&&__kd(x)===K).map(x=>[a,x]));let g=this.save.uniques?.find(x=>x!==e&&x.rarity===``runeword``&&x.name===e.name),h=/1`$/.test(K),L=g&&__kd(g)===K?+h:h?2:1;if(!L)return this.autoSell(e),globalThis.__st=2,!0;if(C.length>=L){let w=C.reduce((m,c)=>__gt(m[1],c[1])?c:m);if(!__gt(e,w[1]))return this.autoSell(e),globalThis.__st=2,!0;$rm(w[0],w[1]),this.autoSell(w[1])}}}let t=this.inventoryOf" 'carry'
$game = Swap $game "let t=this.inventoryOf(this.world.player.cls),n=$fit(" ("if(globalThis.__on(``carry``)){let v=globalThis.__ksv?.(e);if(v===2)return this.autoSell(e),globalThis.__st=2,!0;if(v===3)for(let k of $tabs){let a=$tab(this.save,this.world.player.cls,k),p=$fit(a,e,$sgrid);if(p)return $put(a,e,p),$save(this.save),globalThis.__st=1,!0}}let t=this.inventoryOf(this.world.player.cls),n=$fit(") 'keep sell'
$game = 'globalThis.__rwg=T=>{let w=T.some(t=>!/^(tors|helm|shld|pala)$/.test(t));return[[`w1`,`' + (T '한손' '1H') + '`,w&&T.some(t=>!/^(staf|pole|miss|tors|helm|shld|pala)$/.test(t))],[`w2`,`' + (T '양손' '2H') + '`,w&&T.some(t=>!/^(wand|scep|h2h|club|tors|helm|shld|pala)$/.test(t))],[`b`,`' + (T '갑옷' 'Armor') + '`,T.includes(`tors`)],[`h`,`' + (T '투구' 'Helm') + '`,T.includes(`helm`)],[`s`,`' + (T '방패' 'Shield') + '`,T.some(t=>/^(shld|pala)$/.test(t))]].filter(g=>g[2])};globalThis.__ksIn=j=>{try{if(j&&j.ks&&+j.t>(+localStorage.getItem(`d2s:ks.t`)||0)){globalThis.__ks=j.ks,localStorage.setItem(`d2s:ks`,JSON.stringify(j.ks)),localStorage.setItem(`d2s:ks.t`,String(j.t))}}catch{}};globalThis.__ksDump=()=>{let r={};if(globalThis.__ksDirty){globalThis.__ksDirty=0;let t=0;try{t=+localStorage.getItem(`d2s:ks.t`)||Date.now()}catch{}r.keep={t,ks:__ks}}let D=globalThis.__drop?.(),L=globalThis.__rw?.()?.list,s=globalThis.__gm?.save;if(!globalThis.__ksMeta&&D&&L&&s){globalThis.__ksMeta=1;let has=new Set((s.uniques??[]).map(x=>x.rarity+`:`+x.name)),nm=(n,r)=>{try{return globalThis.__nm?.({name:n,rarity:r})||n}catch{return n}},R=[],add=(c,n,b,k,d,m,x)=>R.push({c,n,b,k,d,m,x}),q=(c,p,Z)=>{for(let[z,zn]of Z)for(let[t,,tn]of __kct){let g=t===`etc`?``:__krg(p,z,t);g!==null&&add(c,zn,tn+(g?` (${g})`:``),`${p}:${z}:${t}`,__ks[`${p}:${z}:${__kal(t)}`]??(p===`h`&&__kal(t)===`skill`?3:2),t!==`etc`)}};add(`' + (T '기타' 'Other') + '`,`' + (T '호라드림의 고서' 'Horadric Codex') + '`,``,`c:codex`,2,!1),__kqi.forEach(([c,n])=>add(`' + (T '기타' 'Other') + '`,n,`' + (T '퀘스트 (판매 = 인벤)' 'Quest (sell = bag)') + '`,`c:quest:`+c,1,!1)),q(`' + (T '매직' 'Magic') + '`,`q:m`,__kqz),q(`' + (T '레어' 'Rare') + '`,`q:r`,__kqz),q(`' + (T '부적' 'Charm') + '`,`h`,__kcz);let so=(a,r)=>[...a].sort((x,y)=>nm(x,r).localeCompare(nm(y,r)));for(let x of [...L].sort((a,b)=>nm(a.name,`runeword`).localeCompare(nm(b.name,`runeword`)))){for(let[g,gn]of __rwg(x.types??[]))add(`' + (T '룬워드' 'Runeword') + '`,nm(x.name,`runeword`),gn,`r:${x.name}:${g}`,__ks[`r:`+x.name]??1,!1,!has.has(`runeword:`+x.name));for(let[st,lo,hi,L]of __kvar(`runeword`,x.name))R.push({c:`' + (T '룬워드' 'Runeword') + '`,n:nm(x.name,`runeword`),b:`  ${L} (${lo}~${hi})`,k:`rv:${x.name}:${st}`,d:0,m:!0,o:1})}for(let n of so(new Set(Object.keys(D.R.setItems??{})),`set`)){add(`' + (T '세트' 'Set') + '`,nm(n,`set`),``,`s:`+n,2,!1,!has.has(`set:`+n));for(let[st,lo,hi,L]of __kvar(`set`,n))R.push({c:`' + (T '세트' 'Set') + '`,n:nm(n,`set`),b:`  ${L} (${lo}~${hi})`,k:`sv:${n}:${st}`,d:0,m:!0,o:1})}for(let n of so(new Set(D.U.map(x=>x.name)),`unique`)){let cc=/Charm$/.test(D.U.find(x=>x.name===n)?.base??``);add(cc?`' + (T '부적' 'Charm') + '`:`' + (T '유니크' 'Unique') + '`,nm(n,`unique`),``,`u:`+n,2,!1,!has.has(`unique:`+n));for(let[st,lo,hi,L]of __kvar(`unique`,n))R.push({c:`' + (T '유니크' 'Unique') + '`,n:nm(n,`unique`),b:`  ${L} (${lo}~${hi})`,k:`uv:${n}:${st}`,d:0,m:!0,o:1,...cc&&{c:`' + (T '부적' 'Charm') + '`}})}r.meta={reg:__regc().replace(/<[^>]+>/g,``),rows:R}}return r.keep||r.meta?JSON.stringify(r):null};' + $game
$game = 'globalThis.__ks=(()=>{try{return JSON.parse(localStorage.getItem(`d2s:ks`)||`{}`)}catch{return{}}})();globalThis.__ksk=e=>{let r=e.rarity;return e.base===`hcx`?`c:codex`:e.type===`quest`?`c:quest:`+e.base:r===`runeword`?`r:`+e.name+`:`+((d=>/2$/.test(d)?`w2`:/1$/.test(d)?`w1`:{head:`h`,shield:`s`}[d]??`b`)(globalThis.__kd?.(e)??``)):r===`unique`?`u:`+e.name:r===`set`?`s:`+e.name:e.type===`charm`||globalThis.__kd?.(e)===`charm`?`h:`:r===`rare`?`q:r`:r===`magic`?`q:m`:null};globalThis.__ksd={r:1,u:2,s:2,c:2,h:2};globalThis.__kold=[[`life`,/^(life|lifePerLevel|replenishLife)$/],[`mana`,/^(mana|manaPerLevel)$/],[`dmg`,/^(attackDamage|damage|enhancedDamage|minDamage|maxDamage|maxDamagePerLevel)$|(Min|Max)Damage$/],[`ar`,/^attackRating/],[`def`,/^(defense|defensePerLevel|enhancedDefense|block|damageReduc|damageReduced|magicReduced)/],[`leech`,/Leech$/],[`mf`,/magicfind|goldfind|magicbonus|goldbonus|reducedprices/i],[`spd`,/^(frw|fhr|fcr|attackSpeed|fasterBlock)$/],[`attr`,/^(strength|dexterity|vitality|energy|stamina)$/]];Object.defineProperty(globalThis,`__kct`,{configurable:!0,get(){if(globalThis.__kcC)return globalThis.__kcC;let A=globalThis.__afx?.()??[],F={maxDamagePerLevel:`' + (T '최대 피해 (레벨당)' 'Max damage (per level)') + '`,attackRatingPerLevel:`' + (T '공격 등급 (레벨당)' 'Attack rating (per level)') + '`,attackRatingPercentPerLevel:`' + (T '명중률 % (레벨당)' 'Attack rating % (per level)') + '`,defensePerLevel:`' + (T '방어력 (레벨당)' 'Defense (per level)') + '`,manaPerLevel:`' + (T '마나 (레벨당)' 'Mana (per level)') + '`,lifePerLevel:`' + (T '생명력 (레벨당)' 'Life (per level)') + '`,poisonDamage:`' + (T '독 피해' 'Poison damage') + '`,vitality:`' + (T '활력' 'Vitality') + '`},lab=st=>{if(F[st])return F[st];let t=``;try{t=(globalThis.__tip?.({base:`Amulet`,type:`amulet`,rarity:`magic`,name:`Amulet`,mods:[{stat:st,value:7}]})??[]).find(l=>/7/.test(l))??``}catch{}return t.replace(/\+?7%?/g,``).replace(/(최소|Minimum|Min) /i,``).replace(/\s+/g,` `).trim()||st},M=new Map,key=st=>/^(fire|cold|lightning|poison)(Min|Max)Damage$/.test(st)?st.replace(/(Min|Max)Damage$/,`Damage`):{fireResist:`rf`,coldResist:`rc`,lightningResist:`rl`,poisonResist:`rp`}[st]??(/^skill:/.test(st)?`sone`:st),put=(k,re,n,st)=>M.has(k)||M.set(k,[k,re,n,st]);put(`rall`,/$^/,`' + (T '모든 저항' 'All resist') + '`,`fireResist`);for(let a of A)for(let st of[a.stat,a.d2?.also?.stat]){if(!st)continue;let k=key(st);k===`sone`?put(k,/^skill:/,`' + (T '개별 스킬' 'Single skill') + '`,st):/Damage$/.test(k)&&k!==st?put(k,new RegExp(`^${k.replace(`Damage`,``)}(Min|Max)Damage$`),(F[k]??lab(k.replace(`Damage`,`MinDamage`))),st):put(k,new RegExp(`^${st}$`),lab(st),st)}let O=`classskills0,classskills1,classskills2,classskills3,classskills4,classskills5,classskills6,skilltab0,skilltab1,skilltab2,skilltab3,skilltab4,skilltab5,skilltab6,skilltab7,skilltab8,skilltab9,skilltab10,skilltab11,skilltab12,skilltab13,skilltab14,skilltab15,skilltab16,skilltab17,skilltab18,skilltab19,skilltab20,sone,sall,rall,rf,rc,rl,rp,life,lifePerLevel,replenishLife,mana,manaPerLevel,strength,dexterity,vitality,energy,stamina,enhancedDamage,minDamage,maxDamage,maxDamagePerLevel,fireDamage,coldDamage,lightningDamage,poisonDamage,attackRatingPoints,attackRating,attackRatingPerLevel,attackRatingPercentPerLevel,attackSpeed,lifeLeech,manaLeech,defense,enhancedDefense,defensePerLevel,block,fasterBlock,damageReduced,magicReduced,thorns,fcr,fhr,frw,magicFind,goldFind,lightRadius,pickup,poisonLength`.split(`,`),L=[...M.values()].sort((a,b)=>(O.indexOf(a[0])+1||999)-(O.indexOf(b[0])+1||999));return globalThis.__kcC=[...(L.length?L:__kold.map(([k,r])=>[k,r,k,k])),[`etc`,/$^/,`' + (T '그 밖의 옵션만' 'Other only') + '`]]}});globalThis.__kcz=[[`s`,`' + (T '작은' 'Small') + '`],[`l`,`' + (T '큰' 'Large') + '`],[`g`,`' + (T '거대' 'Grand') + '`]];globalThis.__kvar=(()=>{let C={};return(r,n)=>{let K=r+n;if(K in C)return C[K];let R=globalThis.__drop?.()?.R,W=globalThis.__rw?.(),d=r===`runeword`?R?.runewords?.[n]:r===`unique`?R?.uniques?.[n]:R?.setItems?.[n];if(!d?.props||!W?.make)return[];let l=d.level??99,a=[],b=[],m={};try{a=W.make(d.props,l,(x,y)=>x),b=W.make(d.props,l,(x,y)=>y)}catch{return C[K]=[]}a.forEach((x,i)=>{if(/durability/.test(x.stat))return;let t=m[x.stat]??={lo:0,hi:0};t.lo+=+x.value||0,t.hi+=+(b[i]?.value)||0});let FM={item_maxdamage_percent:`' + (T '피해 증가 % (최대)' 'Enhanced damage % (max)') + '`,item_mindamage_percent:`' + (T '피해 증가 % (최소)' 'Enhanced damage % (min)') + '`,item_aura:`' + (T '오라 레벨' 'Aura level') + '`,passive_pois_mastery:`' + (T '독 기술 피해 %' 'Poison skill damage %') + '`,item_nonclassskill:`' + (T '기술 레벨 (직업 무관)' 'Skill level (any class)') + '`,item_absorbmagic:`' + (T '마법 흡수' 'Magic absorb') + '`,coldlength:`' + (T '냉기 지속 시간' 'Cold duration') + '`,item_hp_perlevel:`' + (T '생명력 (레벨당)' 'Life (per level)') + '`,item_extrablood:`' + (T '피 튀김 증가' 'Extra blood') + '`,item_addskill_tab:`' + (T '스킬 트리 레벨' 'Skill tree level') + '`,item_addclassskills:`' + (T '직업 스킬 레벨' 'Class skill level') + '`,item_singleskill:`' + (T '개별 스킬 레벨' 'Single skill level') + '`,item_numsockets:`' + (T '소켓 수' 'Sockets') + '`,item_reducedprices:`' + (T '상점 가격 감소 %' 'Reduced prices %') + '`};return C[K]=Object.entries(m).filter(([,v])=>v.lo!==v.hi).map(([st,v])=>{let L=FM[st]??``;if(!L)try{L=(globalThis.__tip?.({base:`Amulet`,type:`amulet`,rarity:`unique`,name:n,stats:[{stat:st,value:7777}]})??[]).find(x=>/7777/.test(x))??``}catch{}return[st,Math.min(v.lo,v.hi),Math.max(v.lo,v.hi),L.replace(/[+-]?7777%?/,``).replace(/\s+/g,` `).trim()||st]})}})();globalThis.__kvp={r:`rv`,u:`uv`,s:`sv`};globalThis.__kqi=[[`ass`,`' + (T '기술 책 (트리 하나 +1)' 'Book of Skill') + '`],[`bbb`,`' + (T '람 에센의 고서 (능력치 +5)' 'Lam Esen''s Tome') + '`],[`xyz`,`' + (T '생명력 물약 (생명력 +20)' 'Potion of Life') + '`],[`tr2`,`' + (T '저항의 두루마리' 'Scroll of Resistance') + '`],[`toa`,`' + (T '면죄의 징표 (스탯 · 기술 초기화)' 'Token of Absolution') + '`],[`hdm`,`' + (T '호라드림 망치 (마법 부여 무료)' 'Horadric Malus') + '`],[`tr1`,`' + (T '호라드림의 두루마리 (모든 기술 +1)' 'Horadric Scroll') + '`],[`bks`,`' + (T '이니푸스의 두루마리' 'Scroll of Inifuss') + '`],[`bkd`,`' + (T '돌무덤 열쇠' 'Key to the Cairn Stones') + '`]];globalThis.__kgr=[[`skill`,/^(classskills|skilltab|sone|sall)/,`' + (T '스킬' 'Skills') + '`],[`res`,/^r(all|f|c|l|p)$/,`' + (T '저항' 'Resistances') + '`],[`life`,/^(life|lifePerLevel|replenishLife|mana|manaPerLevel)$/,`' + (T '생명력 · 마나' 'Life · mana') + '`],[`attr`,/^(strength|dexterity|vitality|energy|stamina)$/,`' + (T '능력치' 'Attributes') + '`],[`dmg`,/^(enhancedDamage|damage|minDamage|maxDamage|maxDamagePerLevel|fireDamage|coldDamage|lightningDamage|poisonDamage)$/,`' + (T '피해' 'Damage') + '`],[`atk`,/^(attackRating|lifeLeech|manaLeech)/,`' + (T '공격 · 흡수' 'Attack · leech') + '`],[`def`,/^(defense|enhancedDefense|defensePerLevel|block|damageReduced|magicReduced|thorns)$/,`' + (T '방어' 'Defense') + '`],[`spd`,/^(attackSpeed|fcr|fhr|frw|fasterBlock)$/,`' + (T '속도' 'Speed') + '`],[`mf`,/^(magicFind|goldFind)$/,`' + (T '매찬 · 골드' 'MF · gold') + '`],[`oth`,/./,`' + (T '기타' 'Other') + '`]];globalThis.__kal=t=>{if(/^(classskills|skilltab|sone|sall|scls|stab)/.test(t))return`skill`;if(/^r(all|f|c|l|p)$/.test(t))return`res`;let e=__kct.find(x=>x[0]===t);return e?__kold.find(([,r])=>r.test(e[3]))?.[0]??null:null};globalThis.__khv=(p,z,t)=>__ks[`${p}:${z}:${t}`]??__ks[`${p}:${z}:${__kal(t)}`]??(p===`h`&&__kal(t)===`skill`?3:2);globalThis.__khm=(p,z,t)=>__ks[`${p}:${z}:${t}#`]??__ks[`${p}:${z}:${__kal(t)}#`]??0;globalThis.__kvals=m=>{let V={};for(let[t,x]of __kct)for(let b of m)x.test(b.stat)&&(V[t]=(V[t]??0)+Math.abs(+b.value||0));let R=[`rf`,`rc`,`rl`,`rp`];if(R.every(t=>V[t])){let a=Math.min(...R.map(t=>V[t]));V.rall=a;for(let t of R)(V[t]-=a)||delete V[t]}return V};globalThis.__kqz=[[`w`,`' + (T '무기' 'Weapon') + '`],[`h`,`' + (T '투구' 'Helm') + '`],[`b`,`' + (T '갑옷' 'Body armor') + '`],[`s`,`' + (T '방패' 'Shield') + '`],[`g`,`' + (T '장갑' 'Gloves') + '`],[`o`,`' + (T '신발' 'Boots') + '`],[`t`,`' + (T '허리띠' 'Belt') + '`],[`r`,`' + (T '반지' 'Ring') + '`],[`a`,`' + (T '목걸이' 'Amulet') + '`],[`j`,`' + (T '주얼' 'Jewel') + '`]];globalThis.__krg=(()=>{let C={};return(p,z,t)=>{let A=globalThis.__afx?.();if(!A)return``;let K=p+z+t;if(K in C)return C[K];let W=/^(weap|mele|miss|swor|axe|mace|hamm|club|scep|wand|staf|pole|spea|knif|tkni|thro|jave|bow|xbow|h2h|h2h2|orb|abow|aspe|ajav|blun|tpot|taxe|tspe)$/,Z=p===`h`?{s:/^scha$/,l:/^mcha$/,g:/^lcha$/}[z]:{w:W,h:/^(helm|circ|phlm|pelt|armo)$/,b:/^(tors|armo|cloa)$/,s:/^(shld|ashd|head|pala|armo)$/,g:/^(glov|armo)$/,o:/^(boot|armo)$/,t:/^(belt|armo)$/,r:/^ring$/,a:/^amul$/,j:/^jewl$/}[z],X=__kct.find(x=>x[0]===t)?.[1],lo=1/0,hi=-1/0;for(let a of A){if(!(a.rows??[]).some(r=>(r.on??[]).some(c=>Z.test(c))))continue;let al=(a.d2?.alike?.length??0)>=3;if(t===`rall`){al&&(lo=Math.min(lo,a.min),hi=Math.max(hi,a.max));continue}if(al&&/^r[fclp]$/.test(t))continue;for(let[st,mn,mx]of[[a.stat,a.min,a.max],[a.d2?.also?.stat,a.d2?.also?.min,a.d2?.also?.max]])if(st&&X?.test(st)){lo=Math.min(lo,mn,mx),hi=Math.max(hi,mn,mx)}}return C[K]=hi<lo?null:lo===hi?`${lo}`:`${lo}~${hi}`}})();globalThis.__ksv=e=>{let k=__ksk(e);if(k===`h:`||k?.[0]===`q`){let d=globalThis.__kd?.(e)??``,p=k===`h:`?`h`:k.slice(0,3),z=k===`h:`?{Small:`s`,Large:`l`,Grand:`g`}[String(e.base).split(` `)[0]]??`s`:/[12]$/.test(d)?`w`:{head:`h`,body:`b`,shield:`s`,gloves:`g`,boots:`o`,belt:`t`,ring:`r`,amulet:`a`,jewel:`j`}[d]??`b`,V=__kvals([...(e.mods??[]),...(e.stats??[])]),T=Object.keys(V);if(!T.length)return __khv(p,z,`etc`);let v=T.map(t=>V[t]>=__khm(p,z,t)?__khv(p,z,t):2);return v.includes(3)?3:v.includes(1)?1:2}if(!k)return 0;let v=__ks[k]??(k[0]===`r`?__ks[k.replace(/:[^:]*$/,``)]:void 0)??(k.startsWith(`c:quest:`)?1:__ksd[k]??__ksd[k[0]]);if(k.startsWith(`c:quest:`)&&v===2)v=1;if(v!==2&&__kvp[k[0]]&&k[1]===`:`){let pre=`${__kvp[k[0]]}:${e.name}:`,S={};for(let b of[...(e.stats??[]),...(e.mods??[])])S[b.stat]=(S[b.stat]??0)+(+b.value||0);for(let q in __ks)if(q.startsWith(pre)&&q.endsWith(`#`)&&(S[q.slice(pre.length,-1)]??0)<__ks[q])return 2}return v};globalThis.__regc=()=>{let D=globalThis.__drop?.(),L=globalThis.__rw?.()?.list,s=globalThis.__gm?.save;if(!D||!L||!s)return``;let h=new Set((s.uniques??[]).map(x=>x.rarity+`:`+x.name)),c=(r,a)=>{a=[...new Set(a)];return`<b style="color:#fc6">${a.filter(n=>h.has(r+`:`+n)).length}</b> / ${a.length}`};return`' + (T '등록' 'Registered') + ': ' + (T '유니크' 'unique') + ' ${c(`unique`,D.U.map(x=>x.name))} · ' + (T '세트' 'set') + ' ${c(`set`,Object.keys(D.R.setItems??{}))} · ' + (T '룬워드' 'runeword') + ' ${c(`runeword`,L.map(x=>x.name))}`};globalThis.__ksOpen=()=>{let D=globalThis.__drop?.(),L=globalThis.__rw?.()?.list,s=globalThis.__gm?.save,ti=`' + (T '보관 설정 (판매 / 인벤 / 창고)' 'Keep settings (sell / bag / stash)') + '`;if(!D||!L||!s){__pnl(`__pks`,ti,`<div>' + (T '데이터를 아직 못 읽었습니다. 한 판 시작한 뒤 다시 여세요.' 'Data not loaded yet. Start a run and reopen.') + '</div>`);return}let has=new Set((s.uniques??[]).map(x=>x.rarity+`:`+x.name)),nm=(n,r)=>{try{return globalThis.__nm?.({name:n,rarity:r})||n}catch{return n}},srt=(r,a)=>[...new Set(a)].sort((x,y)=>nm(x,r).localeCompare(nm(y,r))),O=[[1,`' + (T '인벤' 'bag') + '`],[2,`' + (T '판매' 'sell') + '`],[3,`' + (T '창고' 'stash') + '`]],cl={1:`#fff`,2:`#e88`,3:`#8cf`},vh=(r,n)=>{let V=__kvar(r,n);if(!V.length)return``;let P=`${__kvp[r[0]==`r`?`r`:r[0]==`u`?`u`:`s`]}:${n}:`,on=V.filter(([st])=>__ks[P+st+`#`]);return`<details class="kv" style="flex-basis:100%;margin:0 0 2px 24px"><summary style="font-size:12px;color:#999;cursor:pointer">' + (T '변동 옵션' 'Variable stats') + ' ${V.length}${on.length?` <span style="color:#8cf">${on.map(([st,,,L])=>`${__esc(L)} ${__ks[P+st+`#`]}+`).join(` · `)}</span>`:``}</summary>${V.map(([st,lo,hi,L])=>`<div class="kvr" style="display:flex;gap:8px;align-items:center;font-size:13px;margin-left:12px"><span style="min-width:200px">${__esc(L)} <span style="color:#999">(${lo}~${hi})</span></span><input type="number" min="0" data-m="${__esc(P+st)}#" value="${__ks[P+st+`#`]??``}" placeholder="0" style="width:60px;background:#222;color:#ddd;border:1px solid #666"> <span style="color:#999;font-size:12px">' + (T '이상 적용' 'or more') + '</span></div>`).join(``)}</details>`},row=(k,t,c,m)=>{let v=__ks[k]??(k.startsWith(`c:quest:`)?1:__ksd[k]??__ksd[k[0]]);return`<div class="kr" data-q="${__esc((k+` `+t).toLowerCase())}" style="display:flex;gap:6px;align-items:center;flex-wrap:wrap"><select data-k="${__esc(k)}" style="color:${cl[v]}">${O.map(([a,b])=>`<option value="${a}"${a===v?` selected`:``}>${b}</option>`).join(``)}</select><span style="color:${c}">${__esc(t)}</span>${m?`<span style="color:#e88;font-size:12px">' + (T '미등록' 'missing') + '</span>`:``}${/^[us]:/.test(k)?vh(k[0]===`u`?`unique`:`set`,k.slice(2)):``}</div>`},nr=(p,r,a)=>srt(r,a).map(n=>row(p+n,nm(n,r),has.has(r+`:`+n)?{runeword:`#c7b377`,unique:`#c7b377`,set:`#0f0`}[r]:`#777`,!has.has(r+`:`+n))).join(``).replace(/^/,`<div>`)+`</div>`,tb=(p,Z)=>`<div style="color:#999;font-size:12px">' + (T '옵션이 여러 개면 창고 > 인벤 > 판매 순으로 우선. 최소 수치: 그 옵션 종류의 수치 합이 이 값 이상일 때만 적용 (못 미치면 판매)' 'With several stats: stash > bag > sell. Min: applies only when that stat group totals at least this much (else sold)') + '</div>`+Z.map(([z,zn])=>{let on=__kct.filter(([t])=>__khv(p,z,t)!==2&&(t===`etc`||__krg(p,z,t)!==null)).map(([t,,n])=>`<span style="color:${cl[__khv(p,z,t)]}">${n}${__khm(p,z,t)?` ${__khm(p,z,t)}+`:``}</span>`);return`<details style="margin-left:12px"><summary style="cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${zn} <span style="font-size:12px">${on.join(` · `)}</span></summary>${__kgr.map(([gk,gr,gn])=>{let TT=__kct.filter(([t])=>t!==`etc`&&gr.test(t)&&__kgr.find(([,r])=>r.test(t))[0]===gk&&__krg(p,z,t)!==null);if(!TT.length)return``;let on=TT.filter(([t])=>__khv(p,z,t)!==2);return`<details style="margin-left:12px"><summary style="cursor:pointer;color:#ccc">${gn} <span style="color:#888;font-size:12px">${TT.length}</span>${on.length?` <span style="font-size:12px">${on.map(([t,,n])=>`<span style="color:${cl[__khv(p,z,t)]}">${n}${__khm(p,z,t)?` ${__khm(p,z,t)}+`:``}</span>`).join(` · `)}</span>`:``}</summary><table style="border-collapse:collapse;margin:2px 0 6px 12px">${TT.map(([t,,n])=>{let k=`${p}:${z}:${t}`,v=__khv(p,z,t),g=t===`etc`?``:__krg(p,z,t);if(g===null)return``;return`<tr><td style="padding:1px 10px 1px 0;width:260px">${n}${g?` <span style="color:#999;font-size:12px">(${g})</span>`:``}</td><td><select data-k="${k}" style="color:${cl[v]}">${O.map(([a,b])=>`<option value="${a}"${a===v?` selected`:``}>${b}</option>`).join(``)}</select></td><td style="padding-left:8px;color:#999;font-size:12px">${t===`etc`?``:`<input type="number" min="0" data-m="${k}#" value="${__khm(p,z,t)||``}" placeholder="0" style="width:52px;background:#222;color:#ddd;border:1px solid #666"> ' + (T '이상 적용' 'or more') + '`}</td></tr>`}).join(``)}</table></details>`}).join(``)}<table style="border-collapse:collapse;margin:2px 0 6px 24px">${[__kct.find(([t])=>t===`etc`)].map(([t,,n])=>{let k=`${p}:${z}:${t}`,v=__khv(p,z,t);return`<tr><td style="padding:1px 10px 1px 0">${n}</td><td><select data-k="${k}" style="color:${cl[v]}">${O.map(([a,b])=>`<option value="${a}"${a===v?` selected`:``}>${b}</option>`).join(``)}</select></td></tr>`}).join(``)}</table></details>`}).join(``),sec=(t,p,h)=>`<details><summary style="color:#fc6;margin:8px 0 4px;cursor:pointer;white-space:nowrap">${t} ${O.map(([a,b])=>`<button data-all="${p}" data-v="${a}">' + (T '전부' 'all') + ' ${b}</button>`).join(` `)}</summary>${h}</details>`;let o=__pnl(`__pks`,ti,`<div class="__phx" style="font-weight:normal;color:#ddd"><div>${__regc()}</div><div style="color:#999;font-size:12px">' + (T '미등록이거나 더 좋은 유니크 · 세트 · 룬워드는 설정과 상관없이 등록 · 교체됩니다. 설정은 그 밖의 아이템을 어디로 보낼지입니다. 창고가 꽉 차면 인벤으로 갑니다.' 'New or better uniques/sets/runewords are always stashed/upgraded. These settings decide where other items go. If the stash is full they go to the bag.') + '</div><input id="__pksq" placeholder="' + (T '검색' 'search') + '" style="width:100%;box-sizing:border-box;margin:6px 0;padding:4px 6px;background:#111;color:#ddd;border:1px solid #555"><div style="display:flex;gap:6px;align-items:center"><button data-x="undo">' + (T '되돌리기' 'Undo') + '</button><button data-x="save">' + (T '파일로 저장' 'Save to file') + '</button><button data-x="load">' + (T '파일 불러오기' 'Load file') + '</button><input type="file" accept=".json" id="__pksf" style="display:none"><select id="__pksp" style="background:#111;color:#ddd;border:1px solid #555"><option value="1">' + (T '프리셋' 'Preset') + ' 1</option><option value="2">' + (T '프리셋' 'Preset') + ' 2</option><option value="3">' + (T '프리셋' 'Preset') + ' 3</option></select><button data-x="psave">' + (T '프리셋 저장' 'Save preset') + '</button><button data-x="pload">' + (T '프리셋 적용' 'Apply preset') + '</button><span id="__pksm" style="color:#8e8;font-size:12px"></span></div></div>`+sec(`' + (T '기타' 'Other') + '`,`c:`,`<div>${row(`c:codex`,`' + (T '호라드림의 고서 (기술 변형 포인트 +1, 최대 10)' 'Horadric Codex (+1 skill modifier point, max 10)') + '`,`#fc6`)}<div style="color:#999;font-size:12px;margin:6px 0 2px">' + (T '퀘스트 아이템 (팔 수 없어서 판매로 두면 인벤으로)' 'Quest items (cannot be sold; sell means bag)') + '</div>${__kqi.map(([c,n])=>row(`c:quest:`+c,n,`#fc6`)).join(``)}</div>`)+sec(`' + (T '매직' 'Magic') + '`,`q:m:`,tb(`q:m`,__kqz))+sec(`' + (T '레어' 'Rare') + '`,`q:r:`,tb(`q:r`,__kqz))+sec(`' + (T '부적' 'Charms') + '`,`h:`,tb(`h`,__kcz)+`<details style="margin-left:12px"><summary style="cursor:pointer">' + (T '유니크 부적' 'Unique charms') + '</summary>${nr(`u:`,`unique`,D.U.filter(x=>/Charm$/.test(x.base)).map(x=>x.name))}</details>`)+sec(`' + (T '룬워드' 'Runewords') + '`,`r:`,`<div>${srt(`runeword`,L.map(x=>x.name)).map(n=>{let G=__rwg(L.find(x=>x.name===n)?.types??[]),h=has.has(`runeword:`+n);return`<div class="kr" data-q="${__esc((n+` `+nm(n,`runeword`)).toLowerCase())}" style="display:flex;gap:6px;align-items:center;flex-wrap:wrap;margin:1px 0"><span style="min-width:120px;color:${h?`#c7b377`:`#777`}">${__esc(nm(n,`runeword`))}${h?``:` <span style="color:#e88;font-size:12px">' + (T '미등록' 'missing') + '</span>`}</span>${G.map(([g,gn])=>{let k=`r:${n}:${g}`,v=__ks[k]??__ks[`r:`+n]??1;return`<span style="color:#999;font-size:12px">${gn}</span><select data-k="${__esc(k)}" style="color:${cl[v]}">${O.map(([a,b])=>`<option value="${a}"${a===v?` selected`:``}>${b}</option>`).join(``)}</select>`}).join(``)}${vh(`runeword`,n)}</div>`}).join(``)}</div>`)+sec(`' + (T '세트' 'Sets') + '`,`s:`,nr(`s:`,`set`,Object.keys(D.R.setItems??{})))+sec(`' + (T '유니크' 'Uniques') + '`,`u:`,nr(`u:`,`unique`,D.U.filter(x=>!/Charm$/.test(x.base)).map(x=>x.name))));if(!o)return;o.style.zoom=1.12;o.querySelectorAll(`select,button`).forEach(i=>i.style.cssText+=`;background:#222;border:1px solid #666;padding:1px 4px;font:13px sans-serif`),o.querySelectorAll(`button`).forEach(i=>(i.style.color=`#ddd`,i.style.cursor=`pointer`));let sv=()=>{try{localStorage.setItem(`d2s:ks`,JSON.stringify(__ks)),localStorage.setItem(`d2s:ks.t`,String(Date.now()))}catch{}globalThis.__ksDirty=1},st=i=>{__ks[i.dataset.k]=+i.value,i.style.color=cl[i.value]};o.onchange=x=>{let m=x.target.dataset?.m;m?(+x.target.value>0?__ks[m]=+x.target.value:delete __ks[m],sv()):x.target.dataset?.k&&(st(x.target),sv())};let bk=()=>{try{localStorage.setItem(`d2s:ks.bak`,JSON.stringify(__ks))}catch{}},msg=t=>{let m=o.querySelector(`#__pksm`);m.textContent=t;clearTimeout(m.__t);m.__t=setTimeout(()=>m.textContent=``,4e3)},re=()=>{o.remove(),__ksOpen()};o.addEventListener(`change`,x=>{x.target.id===`__pksf`||x.target.id===`__pksp`||bk()},!0);o.querySelector(`#__pksf`).onchange=x=>{let f=x.target.files?.[0];f&&f.text().then(t=>{let j=JSON.parse(t);if(!j||typeof j!==`object`)throw 0;bk(),globalThis.__ks=j,sv(),re()}).catch(()=>msg(`' + (T '불러오기 실패: 올바른 설정 파일이 아닙니다' 'Load failed: not a settings file') + '`))};o.onclick=x=>{let c=x.target.dataset?.x;if(c){x.preventDefault();if(c===`save`){let a=document.createElement(`a`),d=new Date;a.href=URL.createObjectURL(new Blob([JSON.stringify(__ks,null,1)],{type:`application/json`})),a.download=`d2s-keep-${d.getFullYear()}${String(d.getMonth()+1).padStart(2,0)}${String(d.getDate()).padStart(2,0)}.json`,a.click(),setTimeout(()=>URL.revokeObjectURL(a.href),5e3),msg(`' + (T '저장했습니다' 'Saved') + '`)}else if(c===`load`)o.querySelector(`#__pksf`).click();else if(c===`psave`||c===`pload`){let n=o.querySelector(`#__pksp`).value,k=`d2s:ks.p${n}`;if(c===`psave`){if(localStorage.getItem(k)&&!confirm(`' + (T '프리셋' 'Preset') + ' ${n} ' + (T '을(를) 지금 설정으로 덮어쓸까요?' 'overwrite with current settings?') + '`))return;localStorage.setItem(k,JSON.stringify(__ks)),msg(`' + (T '프리셋' 'Preset') + ' ${n} ' + (T '저장했습니다' 'saved') + '`)}else{let j;try{j=JSON.parse(localStorage.getItem(k)||`null`)}catch{}if(!j)return msg(`' + (T '프리셋' 'Preset') + ' ${n} ' + (T '이(가) 비어 있습니다' 'is empty') + '`);bk(),globalThis.__ks=j,sv(),re()}}else{let b;try{b=JSON.parse(localStorage.getItem(`d2s:ks.bak`)||`null`)}catch{}if(!b)return msg(`' + (T '되돌릴 내용이 없습니다' 'Nothing to undo') + '`);localStorage.setItem(`d2s:ks.bak`,JSON.stringify(__ks)),globalThis.__ks=b,sv(),re()}return}let p=x.target.dataset?.all;if(!p)return;x.preventDefault();if(!confirm(`${x.target.closest(`summary`)?.firstChild?.textContent?.trim()??``} ' + (T '전부를' 'all to') + ' "${x.target.textContent.replace(/^\S+ /,``)}"' + (T '(으)로 바꿀까요? (되돌리기로 취소 가능)' '? (Undo can revert)') + '`))return;bk();o.querySelectorAll(`select[data-k^="${p}"]`).forEach(i=>{i.value=x.target.dataset.v,st(i)}),sv()};o.querySelector(`#__pksq`).oninput=x=>{let W=t=>String(t).toLowerCase().replace(/\s+/g,``),q=W(x.target.value),D=[...o.querySelectorAll(`details:not(.kv)`)];D.forEach(d=>d.style.display=``);o.querySelectorAll(`.kr`).forEach(l=>{let n=!q||W(l.dataset.q).includes(q),R=[...l.querySelectorAll(`.kvr`)],m=0;R.forEach(r=>{let h=n||W(r.firstChild.textContent).includes(q);r.style.display=h?``:`none`,h&&!n&&m++});let k=l.querySelector(`.kv`);k&&(k.open=!!q&&m>0);l.style.display=n||m?``:`none`});o.querySelectorAll(`#__pks tr`).forEach(r=>r.style.display=!q||W(r.cells[0]?.textContent??``).includes(q)?``:`none`);D.reverse().forEach(d=>{if(!q){d.style.display=``,d.open=!1;return}let h=[...d.querySelectorAll(`.kr,tr`)].some(e=>e.style.display!==`none`&&!e.closest(`details[style*="display: none"]`));d.style.display=h?``:`none`,d.open=h})};let up=()=>{for(let d of o.children){if(d.tagName!==`DETAILS`)continue;let S=[...d.querySelectorAll(`select[data-k]`)],c={1:0,2:0,3:0};S.forEach(i=>c[i.value]++);let m=+Object.keys(c).sort((a,b)=>c[b]-c[a])[0],sm=d.querySelector(`summary`),k=sm.querySelector(`.__kc`);k||(k=document.createElement(`span`),k.className=`__kc`,k.style.cssText=`margin-left:8px;font-size:13px;cursor:pointer;text-decoration:underline dotted`,sm.append(k),k.onclick=x=>{x.preventDefault(),x.stopPropagation();d.open=!0;let l=d.querySelector(`.__kl`);if(l)return l.remove();l=document.createElement(`div`),l.className=`__kl`,l.style.cssText=`margin:2px 0 6px 12px;font-size:13px;line-height:1.5`;let M=+k.dataset.m,g={};for(let i of d.querySelectorAll(`select[data-k]`)){if(+i.value===M)continue;let r=i.closest(`tr`),n=r?i.closest(`details`).querySelector(`summary`).firstChild.textContent.trim()+` `+r.firstChild.textContent:i.closest(`.kr`).querySelector(`span`).firstChild.textContent.trim()+(i.previousSibling?.tagName===`SPAN`?` `+i.previousSibling.textContent:``);(g[i.value]??=[]).push(n)}l.innerHTML=Object.keys(g).length?Object.entries(g).map(([v,a])=>`<div><b style="color:${cl[v]}">${O.find(x=>x[0]==v)[1]} ${a.length}</b>: ${a.map(__esc).join(` · `)}</div>`).join(``):`' + (T '모두 같은 설정입니다' 'All the same') + '`,sm.after(l)});k.dataset.m=m,k.innerHTML=S.length&&c[m]===S.length?`<b style="color:${cl[m]}">' + (T '전부' 'all') + ' ${O.find(x=>x[0]===m)[1]}</b>`:[1,3,2].filter(v=>c[v]).map(v=>`<span style="color:${cl[v]}">${O.find(x=>x[0]===v)[1]} ${c[v]}</span>`).join(` · `);d.querySelector(`.__kl`)?.remove()}};up();o.addEventListener(`change`,()=>setTimeout(up));o.addEventListener(`click`,x=>x.target.dataset?.all&&setTimeout(up));};document.addEventListener(`keydown`,e=>{if(e.code!==`F2`||e.repeat)return;e.preventDefault(),e.stopPropagation(),__ksOpen()},!0);' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'carry' } }
# 주운 아이템을 화면 왼쪽 목록에 표시 (금색: 등록, 하늘색: 교체, 흰색: 인벤토리). 최근 15개
$tags = '[`[' + (T '인벤' 'bag') + '] `,`[' + (T '등록' 'stashed') + '] `,`[' + (T '교체' 'upgraded') + '] `,`[' + (T '창고' 'stash') + '] `,`[' + (T '판매' 'sold') + '] `]'
$game = 'globalThis.__sc=x=>{let r=[0,0,0,0];for(let b of x.stats??[]){let v=+b.value||0,s=b.stat;if(/^(coldlength|poisonlength|poisoncount|durability|maxdurability|item_extrablood)$/.test(s))continue;/^item_(allskills|addclassskills|addskill_tab|singleskill|nonclassskill|elemskill)$/.test(s)?r[0]+=v:s===`item_aura`?r[1]+=v:/^item_(skillon|charged_skill)/.test(s)?(r[1]+=+b.level||0,r[2]+=v):/^(item_armor|armorclass)/.test(s)?r[3]+=v:r[2]+=v}return r};globalThis.__gt=(x,y)=>{let a=__sc(x),b=__sc(y);for(let i=0;i<4;i++)if(a[i]!==b[i])return a[i]>b[i];return(+x.defense||0)>(+y.defense||0)};globalThis.__bt=(s,e)=>{let u=s.uniques?.find(u=>u!==e&&u.rarity===e.rarity&&u.name===e.name);if(!u)return!1;if(e.rarity===`runeword`){let p=globalThis.__kd?.(u),q=globalThis.__kd?.(e);if(p!==q){if(!/[12]$/.test(p??``)||!/[12]$/.test(q??``))return!1;if(p.slice(-1)!==q.slice(-1))return p.endsWith(`2`)&&q.endsWith(`1`)}}return __gt(e,u)};globalThis.__lgTabs=d=>{let b=document.createElement(`div`),f=(()=>{try{return localStorage.getItem(`d2s:lgtab`)??``}catch{return``}})();document.getElementById(`__lgcss`)||document.head.append(Object.assign(document.createElement(`style`),{id:`__lgcss`,textContent:[0,1,2,3,4].map(i=>`#__lg[data-f="${i}"]>div:not([data-k="${i}"]){display:none}`).join(``)}));b.style.cssText=`display:flex;gap:2px;padding:2px 4px;background:#000a;flex:none;font:12px sans-serif;user-select:none`;let S=v=>{d.dataset.f=v;for(let x of b.children){let o=x.dataset.v===v;x.style.background=o?`#5a4520`:`#222c`,x.style.color=o?`#fc6`:`#aaa`}try{localStorage.setItem(`d2s:lgtab`,v)}catch{}requestAnimationFrame(()=>d.scrollTop=d.scrollHeight)};for(let[v,l]of[[``,`' + (T '전체' 'All') + '`],[`1`,`' + (T '등록' 'Stashed') + '`],[`2`,`' + (T '교체' 'Upgraded') + '`],[`0`,`' + (T '인벤' 'Bag') + '`],[`3`,`' + (T '창고' 'Stash') + '`],[`4`,`' + (T '판매' 'Sold') + '`]]){let x=document.createElement(`span`);x.dataset.v=v,x.textContent=l,x.style.cssText=`padding:1px 7px;cursor:pointer;border-radius:3px`,x.onpointerdown=e=>{e.stopPropagation(),e.preventDefault(),S(v)},b.append(x)}let q=document.createElement(`input`);q.placeholder=`' + (T '검색' 'search') + '`,q.style.cssText=`margin-left:auto;width:90px;background:#111c;color:#ddd;border:1px solid #555;font:12px sans-serif;padding:0 4px`,q.onpointerdown=e=>e.stopPropagation(),q.addEventListener(`keydown`,e=>{e.stopPropagation(),e.key===`Escape`&&(q.value=``,q.oninput(),q.blur())}),q.oninput=()=>{let v=q.value.replace(/\s+/g,``).toLowerCase();d.dataset.q=v;for(let x of d.children)x.style.display=!v||x.textContent.replace(/\s+/g,``).toLowerCase().includes(v)?``:`none`},b.append(q);S(f);return b};globalThis.__lg=(t,k,s,it)=>{let d=document.getElementById(`__lg`);d||(()=>{let W=document.createElement(`div`),H=document.createElement(`div`),g={};try{g=JSON.parse(localStorage.getItem(`d2s:lgpos`)||`{}`)}catch{}W.id=`__lgw`,W.style.cssText=`position:fixed;left:${g.x??8}px;${g.y!=null?`top:${g.y}px`:`bottom:16%`};width:${g.w??Math.round(innerWidth*' + [int]$O.logw + '/100)}px;height:${g.h?g.h+`px`:`calc(' + $O.logn + '*1.35em + 26px)`};z-index:9999;display:flex;flex-direction:column;background:#0005;border-radius:4px;resize:both;overflow:hidden;min-width:160px;min-height:60px;font:bold ' + $(if ([int]$O.logsize -gt 0) { "$($O.logsize)px" } else { 'clamp(11px,0.75vw,16px)' }) + ' sans-serif;line-height:1.35`,H.textContent=`\u283f ' + (T '획득 목록 (끌어서 이동 · 오른쪽 아래 모서리로 크기 조절)' 'Pickup log (drag to move · corner to resize)') + '`,H.style.cssText=`cursor:move;font:11px sans-serif;color:#aaa;padding:2px 6px;background:#000a;user-select:none;flex:none`,d=document.createElement(`div`),d.id=`__lg`,d.style.cssText=`flex:1;overflow-y:auto;overflow-x:hidden;padding:2px 8px;scrollbar-width:thin;scrollbar-color:#666 transparent;text-shadow:0 0 3px #000,0 0 3px #000`,W.append(H,__lgTabs(d),d),document.body.append(W),d.addEventListener(`wheel`,e=>{d.scrollTop+=e.deltaY,e.preventDefault(),e.stopPropagation()},{passive:!1});try{for(let[t,c,q]of JSON.parse(localStorage.getItem(`d2s:lglog`)||`[]`)){let x=document.createElement(`div`);x.textContent=t,x.style.color=c,x.dataset.k=q??[`' + (T '인벤' 'bag') + '`,`' + (T '등록' 'stashed') + '`,`' + (T '교체' 'upgraded') + '`,`' + (T '창고' 'stash') + '`,`' + (T '판매' 'sold') + '`].findIndex(z=>String(t).includes(`] [${z}] `)),x.style.opacity=`.7`,d.append(x)}}catch{}requestAnimationFrame(()=>d.scrollTop=d.scrollHeight);let sv=()=>{let r=W.getBoundingClientRect();try{localStorage.setItem(`d2s:lgpos`,JSON.stringify({x:Math.round(r.left),y:Math.round(r.top),w:Math.round(r.width),h:Math.round(r.height)}))}catch{}};H.onpointerdown=e=>{e.preventDefault(),e.stopPropagation();let r=W.getBoundingClientRect(),ox=e.clientX-r.left,oy=e.clientY-r.top,mv=e=>{W.style.left=Math.max(0,Math.min(innerWidth-60,e.clientX-ox))+`px`,W.style.top=Math.max(0,Math.min(innerHeight-24,e.clientY-oy))+`px`,W.style.bottom=``},up=()=>{removeEventListener(`pointermove`,mv),removeEventListener(`pointerup`,up),sv()};addEventListener(`pointermove`,mv),addEventListener(`pointerup`,up)};W.onpointerdown=e=>e.stopPropagation();new ResizeObserver(()=>W.offsetWidth&&sv()).observe(W)})();let l=document.createElement(`div`);l.dataset.k=k,l.style.color=[`#fff`,`#e8c060`,`#8cf`,`#c9a`,`#999`][k];let D=new Date,P=x=>String(x).padStart(2,`0`);l.textContent=`[${D.getMonth()+1}/${D.getDate()} ${P(D.getHours())}:${P(D.getMinutes())}] `+' + $tags + '[k]+t+(s&&k!==4?` (`+String(s).split(` → `).map((x,i)=>{let p=x.replace(/^[^:]*: /,``).split(` · `);p.length>2&&p.pop();p=p.filter(q=>!/^(' + (T '룬워드|유니크|세트|매직|레어|무기|방어구|장신구|부적' 'Runeword|Unique|Set|Magic|Rare|Weapon|Armor|Jewelry|Charm') + ')$/.test(q));return(i?`' + (T '등록본 ' 'stashed ') + '`:``)+p.join(` `)}).filter(x=>x.trim()).join(` · `)+`)`:``);(k===2&&globalThis.__swh?(l.__h=globalThis.__swh,globalThis.__swh=null):k===4&&it&&(l.__h=globalThis.__rsn?.(it))?0:it&&(l.__h=`<div style="font-weight:bold"><span style="color:${l.style.color}">${' + $tags + '[k]}</span><span style="color:${globalThis.__rcol?.(it.rarity)??`#fff`}">${String(t).replace(/</g,`&lt;`)}</span></div>`+String(s??``).split(` → `).map(x=>`<div style="color:#999">${x.replace(/</g,`&lt;`)}</div>`).join(``)+(globalThis.__tipc?.(it)??[]).map(x=>`<div style="color:${x.c}">${String(x.t).replace(/</g,`&lt;`)}</div>`).join(``)),l.__h)&&(l.style.pointerEvents=`auto`,l.onpointerenter=()=>{let w=__swd(),r=l.getBoundingClientRect();w.innerHTML=l.__h;w.style.display=``;{let c=document.getElementById(`__lgw`)?.getBoundingClientRect()??r;w.style.left=(c.right+10+w.offsetWidth>innerWidth?Math.max(4,c.left-10-w.offsetWidth):c.right+10)+`px`}w.style.top=Math.max(4,Math.min(r.top,innerHeight-w.offsetHeight-4))+`px`;clearTimeout(w.__t)},l.onpointerleave=()=>{document.getElementById(`__sw`).style.display=`none`});k===2&&globalThis.__swu&&(()=>{let f=globalThis.__swu,b=document.createElement(`span`);globalThis.__swu=null;b.textContent=` [' + (T '되돌리기' 'Undo') + ']`;b.style.cssText=`color:#f96;cursor:pointer;pointer-events:auto`;b.onpointerdown=b.onmousedown=x=>{x.stopPropagation();x.preventDefault();f()?(l.style.textDecoration=`line-through`,b.textContent=` [' + (T '되돌림' 'Undone') + ']`,b.onpointerdown=b.onmousedown=null):b.textContent=` [' + (T '불가' 'Failed') + ']`};l.append(b)})();let B=d.scrollHeight-d.scrollTop-d.clientHeight<10;d.append(l),d.dataset.q&&!l.textContent.replace(/\s+/g,``).toLowerCase().includes(d.dataset.q)&&(l.style.display=`none`);for(;d.children.length>300;)d.firstChild.remove();B&&(d.scrollTop=d.scrollHeight);clearTimeout(d.__sv),d.__sv=setTimeout(()=>{try{localStorage.setItem(`d2s:lglog`,JSON.stringify([...d.children].map(x=>[x.firstChild?.nodeType===3?x.firstChild.nodeValue:x.textContent,x.style.color,x.dataset.k])))}catch{}},1e3)};' + $game
$game = 'globalThis.__rsn=e=>{let g=globalThis.__gm?.save;if(!g)return null;let v=globalThis.__ksv?.(e),u=/^(unique|set|runeword)$/.test(e.rarity)?g.uniques?.find(x=>x!==e&&x.rarity===e.rarity&&x.name===e.name&&(e.rarity!==`runeword`||__kd(x)===__kd(e)))??g.uniques?.find(x=>x!==e&&x.rarity===e.rarity&&x.name===e.name):null;if(!u)return null;let a=__sc(e),b=__sc(u),i=a.findIndex((x,j)=>x!==b[j]),N=[`' + (T '스킬' 'skills') + '`,`' + (T '오라 · 발동 기술' 'aura/proc') + '`,`' + (T '그 밖의 옵션' 'other stats') + '`,`' + (T '방어력' 'defense') + '`],w=e.rarity===`runeword`&&/2$/.test(__kd(e)??``)&&/1$/.test(__kd(u)??``)?`' + (T '등록본이 한손 (한손 우선이라 양손으로 안 바꿈)' 'stashed copy is one-handed (one-handed preferred)') + '`:i>=0&&a[i]<b[i]?N[i]+` ' + (T '합이 등록본보다 낮음' 'total lower than stashed') + ' (${a[i]} < ${b[i]})`:i<0&&(+e.defense||0)<(+u.defense||0)?`' + (T '옵션 같음 · 바탕 방어력 낮음' 'same stats, lower base defense') + ' (${e.defense} < ${u.defense})`:v===2?(i<0?`' + (T '등록본과 같음 (중복) · F2에서 판매' 'same as stashed (duplicate) · sell in F2') + '`:`' + (T 'F2에서 판매로 설정됨' 'set to sell in F2') + '`):i<0?`' + (T '등록본과 같음 (중복)' 'same as stashed (duplicate)') + '`:0?N[i]+` ' + (T '합이 등록본보다 낮음' 'total lower than stashed') + ' (${a[i]} < ${b[i]})`:`' + (T '같은 종류 중복' 'duplicate of same kind') + '`;let h=globalThis.__swh;__sw(__nm(e),u,e,[`[' + (T '판매' 'Sold') + '] ' + (T '이유' 'reason') + ': ${w} · `,`' + (T '등록본' 'Stashed') + '`,`' + (T '판매한 것' 'Sold') + '`]);let r=globalThis.__swh,d=document.getElementById(`__sw`);clearTimeout(d?.__t),d&&(d.style.display=`none`),globalThis.__swh=h;return r};' + $game
# 교체 창: 왼쪽 목록 옆에 이전/새 옵션 비교 (바뀐 줄만 색 표시), 20초 뒤 닫힘. 왼쪽 목록의 [교체] 줄에 마우스를 올리면 다시 표시
$game = 'globalThis.__swd=()=>{let d=document.getElementById(`__sw`);d||(d=document.createElement(`div`),d.id=`__sw`,d.style.cssText=`position:fixed;z-index:9999;pointer-events:none;font:' + $(if ([int]$O.logsize -gt 0) { "$([int]$O.logsize - 1)px" } else { 'clamp(11px,0.7vw,15px)' }) + ' sans-serif;line-height:1.35;background:#0009;border:1px solid #8cf;padding:6px 10px;max-width:min(380px,28vw);color:#ccc`,document.body.append(d));return d};globalThis.__sw=(n,o,e,l)=>{let d=__swd();let a=globalThis.__tip?.(o)??[],b=globalThis.__tip?.(e)??[],h=(t,c)=>`<div style="color:${c}">${String(t).replace(/</g,`&lt;`)}</div>`;globalThis.__swh=d.innerHTML=h((l?.[0]??`[' + (T '교체' 'Upgraded') + '] `)+n,`#8cf`)+h(globalThis.__slot?.(e)??``,`#aaa`)+h(`' + (T '바뀐 옵션' 'Changes') + '`,`#fc6`)+(()=>{let x=t=>String(t).replace(/</g,`&lt;`),c=(t,k)=>`<span style="color:${k}">${x(t)}</span>`,K=t=>String(t).replace(/[0-9.]+/g,`#`),A=new Set,B=new Set,r=``;a.forEach((p,i)=>{let j=b.findIndex((q,J)=>!B.has(J)&&q===p);j>=0&&(A.add(i),B.add(j))});a.forEach((p,i)=>{if(A.has(i))return;let j=b.findIndex((q,J)=>!B.has(J)&&K(q)===K(p));j<0?r+=`<div>${c(p,`#e88`)}${c(` → ' + (T '없어짐' 'removed') + '`,`#888`)}</div>`:(B.add(j),r+=`<div>${c(p,`#e88`)}${c(` → `,`#888`)}${c(b[j],`#8e8`)}</div>`)});b.forEach((q,J)=>{B.has(J)||(r+=`<div>${c(`' + (T '새로 생김' 'added') + ' `,`#888`)}${c(q,`#8e8`)}</div>`)});return r})()+h(`' + (T '옵션 총합' 'Total') + '`,`#fc6`)+[[o,`' + (T '이전' 'Old') + '`,`#e88`],[e,`' + (T '새것' 'New') + '`,`#8e8`]].map(([x,t,c])=>{let[s,u,a,f]=__sc(x);return h(`${t}: ' + (T '스킬' 'skill') + ' ${s} · ' + (T '오라·발동' 'aura·proc') + ' ${u} · ' + (T '그 외' 'other') + ' ${a} · ' + (T '방어' 'def') + ' ${f}`,c)}).join(``);d.style.display=``;requestAnimationFrame(()=>{let g=document.getElementById(`__lg`)?.getBoundingClientRect();{let c=document.getElementById(`__lgw`)?.getBoundingClientRect()??g;d.style.left=(c&&c.right+10+d.offsetWidth>innerWidth?Math.max(4,c.left-10-d.offsetWidth):(c?c.right:250)+10)+`px`}d.style.top=Math.max(4,Math.min(g?g.top:innerHeight*.35,innerHeight-d.offsetHeight-4))+`px`});clearTimeout(d.__t);d.__t=setTimeout(()=>d.style.display=`none`,2e4)};' + $game
# 자동 진행 카운트다운 표시 (화면 위쪽 가운데)
$game = 'globalThis.__cdx=()=>{let d=document.getElementById(`__cd`);d&&(clearInterval(d.__i),d.remove())};globalThis.__cd=(s,t)=>{__cdx();let d=document.createElement(`div`),e=Date.now()+s*1e3;d.id=`__cd`;d.style.cssText=`position:fixed;left:50%;top:18%;transform:translateX(-50%);z-index:9999;pointer-events:none;font:bold 20px sans-serif;color:#e8c060;text-shadow:0 0 4px #000,0 0 4px #000`;document.body.append(d);let u=()=>{let r=Math.ceil((e-Date.now())/1e3);r<=0?__cdx():d.textContent=t.replace(`#`,r)};u();d.__i=setInterval(u,200)};' + $game
$game = Swap $game 'carry:e=>this.carry(e),' "carry:e=>{let k=$canKeep(this.save,e)?1:__bt(this.save,e)?2:0,r=(globalThis.__st=0,this.carry(e));globalThis.__st&&!k&&(k=globalThis.__st===2?4:3);let q=e.rarity===``runeword``&&k!==1&&k!==2&&this.save.uniques?.find(x=>x!==e&&x.rarity===e.rarity&&x.name===e.name);return r&&globalThis.__stC?.(k,e),r&&globalThis.__dsnd?.(e),r&&globalThis.__afk&&__afkAdd(k,e.rarity),r&&__lg($name(e.name,e.rarity,e.base),k,(globalThis.__slot?.(e)??````)+(q?`` → $(T '등록본' 'stashed'): ``+__slot(q):````),e),r},isNew:e=>$canKeep(this.save,e)||__bt(this.save,e)||e.rarity===``runeword``||globalThis.__ksv?.(e)===1||globalThis.__ksv?.(e)===3," 'world'
# 인벤토리/창고 아이템에 마우스를 올리면 보관함 등록본과 비교 창을 아이템 옆에 띄운다 (유니크/세트/룬워드)
$game = "globalThis.__nm=e=>$name(e.name,e.rarity,e.base);" + 'globalThis.__cmp=(e,a)=>{let g=globalThis.__gm?.save;if(!g||!/^(unique|set|runeword)$/.test(e.rarity))return;let u=g.uniques?.find(x=>x!==e&&x.rarity===e.rarity&&x.name===e.name&&(e.rarity!==`runeword`||__kd(x)===__kd(e)));if(!u)return;let v=__gt(e,u)?`▲ ' + (T '더 좋음' 'better') + '`:__gt(u,e)?`▼ ' + (T '더 나쁨' 'worse') + '`:`= ' + (T '같음' 'same') + '`;__sw(__nm(e),u,e,[`[' + (T '등록본 비교' 'vs stashed') + ' ${v}] `,`' + (T '등록본' 'Stashed') + '`,`' + (T '이 아이템' 'This') + '`]);globalThis.__swh=null;let d=document.getElementById(`__sw`);clearTimeout(d.__t);requestAnimationFrame(()=>{let r=a.getBoundingClientRect(),x=r.left-d.offsetWidth-12;d.style.left=(x<4?r.right+12:x)+`px`;d.style.top=Math.max(4,Math.min(r.top,innerHeight-d.offsetHeight-4))+`px`})};globalThis.__cmpx=()=>{let d=document.getElementById(`__sw`);d&&(d.style.display=`none`)};' + $game
$game = Swap $game 'openCharacter(e,t=this.kit.id){' 'openCharacter(e,t=this.kit.id){globalThis.__gm=this;' 'compare save'
$game = Swap $game 'carry:e=>{let k=' 'carry:e=>{globalThis.__gm=this;let k=' 'compare save run'
if ($O.stash) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 런 도중 B 키로 창고를 연다 (캐릭터 창 + 창고 탭). 닫으면 원래대로
$game = Swap $game 'this.characterView(n,t,e===`town`),{...this.gearActions(t,()=>this.openCharacter(e,t),e===`town`)' 'this.characterView(n,t,e===`town`||!!this.__stash),{...this.gearActions(t,()=>this.openCharacter(e,t),e===`town`||!!this.__stash)' 'stash key view'
$game = Swap $game 'close:()=>{this.putBack(),this.tomeRead=null,' 'close:()=>{this.__stash=0,this.putBack(),this.tomeRead=null,' 'stash key close'
try { $game = Swap $game '(e.code===`KeyC`||e.code===`KeyI`)&&this.state===`playing`?this.openCharacter(`playing`)' 'e.code===`KeyB`&&globalThis.__on(`stash`)&&Date.now()-(globalThis.__bjust||0)>300&&(this.state===`playing`||this.state===`camp`&&!this.swapping)?(this.__stash=1,this.openCharacter(this.state)):(e.code===`KeyC`||e.code===`KeyI`)&&this.state===`playing`?(this.__stash=0,this.openCharacter(`playing`))' 'stash key' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game '(G(e,`character`)||G(e,`inventory`))&&this.state===`playing`?this.openCharacter(`playing`)' 'e.code===`KeyB`&&globalThis.__on(`stash`)&&Date.now()-(globalThis.__bjust||0)>300&&(this.state===`playing`||this.state===`camp`&&!this.swapping)?(this.__stash=1,this.openCharacter(this.state)):(G(e,`character`)||G(e,`inventory`))&&this.state===`playing`?(this.__stash=0,this.openCharacter(`playing`))' 'stash key' }
$game = 'addEventListener(`keydown`,e=>{let g=globalThis.__gm;if(e.code!==`KeyB`||e.repeat||!g||g.state!==`character`||!g.__stash)return;e.preventDefault(),e.stopImmediatePropagation(),globalThis.__bjust=Date.now();let h=g.hud;(h?.d2?.onPanelClose??h?.charClose?.onclick)?.()},!0);' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'stash' } }
if ($O.auto) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 공포 단계 클리어 화면에서 4초 뒤 자동 진행: 다시 하기(replay) 단계면 같은 단계 재시작, 아니면 Enter와 같은 동작. 상점·종료로 나가면 취소
$game = Swap $game 'showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();' ('showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();clearTimeout(this.__ar);let __n=globalThis.__cfg?.automode===`next`,__d=+globalThis.__cfg?.delay||4;__cd(__d,__n?`' + (T '#초 뒤 다음 단계' 'Next tier in #s') + '`:`' + (T '#초 뒤 같은 단계 재시작' 'Restarting in #s') + '`),this.__ar=setTimeout(()=>{this.tierDone===e&&!globalThis.__halt&&globalThis.__on(`auto`)&&(__n?(e.replay?(this.tierDone=null,this.startReplay(this.kit,e.tier+1)):this.nextTier()):(this.tierDone=null,this.startReplay(this.kit,e.tier)))},__d*1e3);') 'auto repeat'
# 공포 단계 보스 처치 후 포털이 열리면 4초 뒤 자동 입장 (클리어 화면으로)
$portal = Find $game ('this\.hud\.banner\(`A portal to \$\{' + $id + '\(t,' + $id + '\)\} has opened`\),!1\}') 'portal'
$game = Swap $game $portal.Value ($portal.Value.Substring(0, $portal.Value.Length - 3) + 't.terror&&(__cd(+globalThis.__cfg?.delay||4,`' + (T '#초 뒤 포털 입장' 'Entering portal in #s') + '`)),!1}') 'portal'
try { try { $game = Swap $game 'o=Dr(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5))' ('o=Dr(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5)||!!(globalThis.__on(`auto`)&&t.terror&&a!==null&&a>=(+globalThis.__cfg?.delay||4)&&!(globalThis.__on(`tyrael`)&&n.tyrael&&!n.tyrael.spoke)))') 'portal enter' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'o=jr(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5))' ('o=jr(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5)||!!(globalThis.__on(`auto`)&&t.terror&&a!==null&&a>=(+globalThis.__cfg?.delay||4)&&!(globalThis.__on(`tyrael`)&&n.tyrael&&!n.tyrael.spoke)))') 'portal enter' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'o=Ze(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5))' ('o=Ze(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5)||!!(globalThis.__on(`auto`)&&t.terror&&a!==null&&a>=(+globalThis.__cfg?.delay||4)&&!(globalThis.__on(`tyrael`)&&n.tyrael&&!n.tyrael.spoke)))') 'portal enter' }
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'auto' } }
# AFK 모드 (F8): 화면을 검게 덮고 진행 상황·획득 목록·종료 버튼만 표시. 창을 내리거나 가려도 멈추지 않음
if ($O.speed) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 배속 (F7): 1 → 1.5 → 2 → 3배 순환. 프레임당 게임 업데이트 횟수를 늘림 (1.5배는 남는 0.5를 다음 프레임으로 넘김)
$game = 'globalThis.__spd=1;globalThis.__spdA=0;globalThis.__spdS=(x,d,on)=>{let a=globalThis.__spdA+x*globalThis.__spd,k=Math.floor(a);return globalThis.__spdA=a-k,on&&globalThis.__afk&&(globalThis.__afkG=(globalThis.__afkG||0)+k*d),k};document.addEventListener(`keydown`,e=>{if(e.code!==`F7`)return;e.preventDefault(),e.stopPropagation();let l=[1,1.5,2,3];globalThis.__spd=l[(l.indexOf(globalThis.__spd)+1)%l.length],globalThis.__spdA=0;let o=document.getElementById(`__spd`);o||(o=document.createElement(`div`),o.id=`__spd`,o.style.cssText=`position:fixed;right:76px;top:1px;z-index:10001;background:#000;color:#fc6;border:1px solid #fc6;padding:0 8px;font:bold 12px sans-serif;pointer-events:none`,document.body.append(o)),o.textContent=`' + (T '배속' 'Speed') + ' x${globalThis.__spd} (F7)`,o.style.display=globalThis.__spd===1?`none`:``},!0);' + $game
try { try { $game = Swap $game 'for(let e=0;e<M.speed*t&&i&&' 'for(let e=0,S=globalThis.__spdS(M.speed*t,n,i&&this.state===`playing`&&!r);e<S&&i&&' 'speed' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'for(let e=0;e<I.speed*t&&i&&' 'for(let e=0,S=globalThis.__spdS(I.speed*t,n,i&&this.state===`playing`&&!r);e<S&&i&&' 'speed' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'for(let e=0;e<j.speed*t&&i&&' 'for(let e=0,S=globalThis.__spdS(j.speed*t,n,i&&this.state===`playing`&&!r);e<S&&i&&' 'speed' }
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'speed' } }

# HUD 배치: 소환수(용병 포함) 1줄 · 스킬 줄마다 1줄로 화면 맨 왼쪽 위, 게임 정보(단계·처치·골드·초당 피해)는 화면 맨 오른쪽 위
# 게임 HUD는 800x600 틀을 화면 아래 가운데에 맞춰 확대하므로, 화면 끝 좌표 = 틀 기준 400 - 50vw/배율, 600 - 100vh/배율
if ($O.hud) {
$hudCss = '.d2ui #merc{left:calc(406px - 50vw / var(--ui-scale,1)) !important;top:calc(606px - (100vh - 24px) / var(--ui-scale,1)) !important}.d2ui #pets{grid-template-columns:none !important;grid-auto-flow:column !important;grid-auto-columns:46px;top:calc(606px - (100vh - 24px) / var(--ui-scale,1)) !important;left:calc(406px - 50vw / var(--ui-scale,1)) !important}.d2ui.has-merc #pets{left:calc(458px - 50vw / var(--ui-scale,1)) !important}.d2ui #build{left:calc(406px - 50vw / var(--ui-scale,1)) !important;top:calc(606px - (100vh - 24px) / var(--ui-scale,1) + var(--d2s-row,0px)) !important}.d2ui.has-pets #build,.d2ui.has-merc #build{--d2s-row:54px}.d2ui #build .strip .slot-row.wide{display:flex !important;flex-wrap:nowrap}.d2ui #run-info{right:calc(406px - 50vw / var(--ui-scale,1)) !important;top:calc(606px - (100vh - 24px) / var(--ui-scale,1)) !important}'
$game = 'setTimeout(()=>{let s=document.createElement(`style`);s.id=`__hudcss`,s.textContent=`' + $hudCss + '`,document.head.append(s)},0);' + $game
}
# 밝기·명암: 게임 화면 canvas에 필터. PageUp/PageDown 밝기, Home/End 명암. 기본값은 선택 창 값
if ($O.bright) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$game = 'globalThis.__br=' + ([decimal]$O.brightness / 100).ToString($inv) + ';globalThis.__ct=' + ([decimal]$O.contrast / 100).ToString($inv) + ';globalThis.__brA=()=>{let f=globalThis.__on?.(`bright`)===!1?``:(globalThis.__br===1?``:`brightness(${globalThis.__br}) `)+(globalThis.__ct===1?``:`contrast(${globalThis.__ct})`);document.querySelectorAll(`canvas`).forEach(c=>{c.classList.contains(`d2-text`)||(c.style.filter=f)})};setInterval(globalThis.__brA,2e3);document.addEventListener(`keydown`,e=>{let k={PageUp:[`__br`,.1],PageDown:[`__br`,-.1],Home:[`__ct`,.1],End:[`__ct`,-.1]}[e.code];if(!k)return;e.preventDefault(),e.stopPropagation(),globalThis[k[0]]=Math.min(2,Math.max(.5,Math.round((globalThis[k[0]]+k[1])*10)/10)),globalThis.__brA();let o=document.getElementById(`__brt`);o||(o=document.createElement(`div`),o.id=`__brt`,o.style.cssText=`position:fixed;left:50%;top:52px;transform:translateX(-50%);z-index:9999;background:#000a;color:#fc6;border:1px solid #fc6;padding:2px 10px;font:bold 15px sans-serif;pointer-events:none`,document.body.append(o)),o.textContent=`' + (T '밝기' 'Brightness') + ' ${Math.round(globalThis.__br*100)}% · ' + (T '명암' 'Contrast') + ' ${Math.round(globalThis.__ct*100)}%`,o.style.display=``,clearTimeout(o.__t),o.__t=setTimeout(()=>o.style.display=`none`,1500)},!0);' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'bright' } }
# FPS 표시 (F9로 켜고 끔): 오른쪽 위
if ($O.dropsnd) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# F2에서 인벤(1) · 창고(3)로 정한 아이템을 주우면 소리 (창고: 높은 3음, 인벤: 2음), 3초 안에 겹치면 한 번만
$game = '' + $beep + 'globalThis.__dsnd=e=>{let v=globalThis.__ksv?.(e),n=performance.now();(v===1||v===3)&&n-(globalThis.__dsT||0)>3e3&&(globalThis.__dsT=n,globalThis.__beep(v===3?0:1))};' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'dropsnd' } }
if ($O.stats) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 통계: 게임 켠 뒤(이번 실행) · 오늘(localStorage d2s:st:날짜). 행 = 등록/교체/인벤/창고/판매, 열 = 유니크/세트/룬워드/기타
$sell = Find $game ('autoSell\(e\)\{let t=' + $id + '\(this\.save,this\.world\.player\.cls,e\);this\.world\.gold\+=t;') 'stats sell'
$game = Swap $game $sell.Value ($sell.Value + 'globalThis.__stS?.(e,t);') 'stats sell'
$game = 'globalThis.__stD=()=>new Date().toLocaleDateString(`sv`);globalThis.__stA={n:{},g:0,r:0,t:Date.now()};globalThis.__stB=(()=>{try{let j=JSON.parse(localStorage.getItem(`d2s:st:${__stD()}`)||`null`);return j&&j.d===__stD()?j:null}catch{return null}})()??{d:__stD(),n:{},g:0,r:0,t:0};globalThis.__stW=f=>{__stB.d!==__stD()&&(globalThis.__stB={d:__stD(),n:{},g:0,r:0,t:0});for(let o of[__stA,__stB])f(o);try{localStorage.setItem(`d2s:st:${__stB.d}`,JSON.stringify(__stB))}catch{}};globalThis.__stI=(a,r)=>__stW(o=>{(o.n[a]??=[0,0,0,0])[{unique:0,set:1,runeword:2}[r]??3]++});globalThis.__stC=(k,e)=>k!==4&&__stI([2,0,1,3][k],e.rarity);globalThis.__stS=(e,t)=>{__stI(4,e.rarity),__stW(o=>o.g+=+t||0)};globalThis.__stRun=()=>__stW(o=>o.r++);setInterval(()=>__stB.t+=1e4,1e4);globalThis.__stT=()=>{let o=document.getElementById(`__st`);if(o)return clearInterval(globalThis.__stI2),o.remove();o=document.createElement(`div`),o.id=`__st`,o.style.cssText=`position:fixed;left:50%;top:12%;transform:translateX(-50%);z-index:9997;background:rgba(10,8,6,.94);border:1px solid #8a6d3b;color:#ccc;font:15px sans-serif;padding:14px 20px;min-width:520px;line-height:1.5`,document.body.append(o);let C=[`' + (T '유니크' 'Unique') + '`,`' + (T '세트' 'Set') + '`,`' + (T '룬워드' 'Runeword') + '`,`' + (T '기타' 'Other') + '`],R=[`' + (T '등록' 'Stashed') + '`,`' + (T '교체' 'Upgraded') + '`,`' + (T '인벤' 'Bag') + '`,`' + (T '창고' 'Stash') + '`,`' + (T '판매' 'Sold') + '`],t=(x,h)=>{let S=Object.values(x.n).flat().reduce((a,b)=>a+b,0);return`<div style="color:#fc6;font-weight:bold;margin-top:8px">${h}</div><table style="border-collapse:collapse;margin:4px 0"><tr style="color:#888"><td></td>${C.map(c=>`<td style="padding:1px 12px">${c}</td>`).join(``)}</tr>${R.map((l,i)=>`<tr><td style="padding:1px 12px;text-align:right;color:#aaa">${l}</td>${(x.n[i]??[0,0,0,0]).map(v=>`<td style="padding:1px 12px;text-align:center">${v}</td>`).join(``)}</tr>`).join(``)}</table><div>' + (T '판 수' 'Runs') + ' ${x.r} · ' + (T '판매 골드' 'Sale gold') + ' ${Math.floor(x.g).toLocaleString()} · ' + (T '시간' 'Time') + ' ${(m=>`${Math.floor(m/60)}:${String(m%60).padStart(2,0)}`)(Math.floor(x.h/6e4))} · ' + (T '시간당' 'Per hour') + ' ${x.h>6e4?`${(S/(x.h/36e5)).toFixed(1)}' + (T '개' '') + ' · ${Math.floor(x.g/(x.h/36e5)).toLocaleString()}' + (T '골드' 'g') + '`:`-`}</div>`},u=()=>{__stA.h=Date.now()-__stA.t,__stB.h=__stB.t;o.innerHTML=`<div style="display:flex;justify-content:space-between"><b style="color:#fc6;font-size:18px">' + (T '획득 · 판매 통계' 'Loot · sales stats') + '</b><span style="color:#888">F1 ' + (T '닫기' 'close') + '</span></div>${t(__stA,`' + (T '이번 실행 (게임 켠 뒤)' 'This session') + '`)}${t(__stB,`' + (T '오늘' 'Today') + ' ${__stB.d}`)}`};u(),globalThis.__stI2=setInterval(u,1e3)};document.addEventListener(`keydown`,e=>{e.code===`F1`&&(e.preventDefault(),e.stopPropagation(),globalThis.__stT())},!0);' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'stats' } }
if ($O.shard) {
# 빛의 파편(퀘스트 부서진 빛) 안내: 게임의 shards.planned(몇 번째 · 나타날 시각) / shards.at(위치)를 읽어 화면에 표시만 함
$game = 'globalThis.__shd=()=>{let g=globalThis.__gm,w=g?.world,S=g?.shards,p=S?.planned,a=S?.at,P=w?.player,o=document.getElementById(`__shd`);if(!w||!P||!p||S.taken||w.farm||w.tristram||g.state!==`playing`){o&&(o.style.display=`none`);return}o||(o=document.createElement(`div`),o.id=`__shd`,o.style.cssText=`position:fixed;z-index:9999;pointer-events:none;font:bold 20px sans-serif;color:#fff6c8;text-shadow:0 0 4px #000,0 0 10px #fc6,0 0 18px #fc6;text-align:center;transform:translate(-50%,-50%);white-space:nowrap`,document.body.append(o));o.style.display=``;if(!a){let r=Math.max(0,Math.ceil(p.at-(w.time-w.actStart)));o.style.left=`50%`,o.style.top=`16%`,o.textContent=`' + (T '빛의 파편' 'Light shard') + ' ${p.shard}/10: ${r}' + (T '초 뒤 근처에 나타남' 's until it appears nearby') + '`;return}globalThis.__shdB!==p&&(globalThis.__shdB=p,globalThis.__beep?.(0));let x=a.x-P.x,y=a.y-P.y,v=w.view,W=v?.halfW||960,H=v?.halfH||540;if(!globalThis.__afk&&Math.abs(x)<W*.8&&Math.abs(y)<H*.8){o.style.display=`none`;return}let A=Math.atan2(y,x),R=Math.min(innerWidth,innerHeight)*.3;o.style.left=`${innerWidth/2+Math.cos(A)*R*1.3}px`,o.style.top=`${innerHeight/2+Math.sin(A)*R}px`,o.style.opacity=.55+.45*Math.abs(Math.sin(performance.now()/300)),o.innerHTML=`<div style="font-size:72px;line-height:1;color:#ffd75a;display:inline-block;transform:rotate(${A}rad)">➜</div><div>' + (T '빛의 파편' 'Light shard') + ' ${p.shard}/10 · ${Math.hypot(x/(2*W),y/(2*H)).toFixed(1)} ' + (T '화면' 'screens') + '${p.guarded?` · ' + (T '몬스터가 지킴' 'guarded') + '`:``}</div>`};setInterval(()=>{try{globalThis.__shd()}catch{}},100);setInterval(()=>{let y=globalThis.__gm?.clearing?.tyrael;if(!y||y.spoke||globalThis.__tyB===y||!globalThis.__on(`tyrael`))return;globalThis.__tyB=y,globalThis.__beep?.(0),globalThis.__afk&&!globalThis.__halt&&(globalThis.__halt=`' + (T '티리엘 등장: AFK를 끄고 티리엘에게 가세요' 'Tyrael is here: exit AFK and walk to him') + '`,globalThis.__gm.state===`playing`&&globalThis.__gm.pause())},500);' + $game
}
if ($O.fps) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$game = 'globalThis.__fpsN=0;(function f(){globalThis.__fpsN++,requestAnimationFrame(f)})();setInterval(()=>{let o=document.getElementById(`__fps`);o&&(o.textContent=`FPS ${globalThis.__fpsN*2}`),globalThis.__fpsN=0},500);globalThis.__fpsT=()=>{let o=document.getElementById(`__fps`);if(o)return o.remove();o=document.createElement(`div`),o.id=`__fps`,o.style.cssText=`position:fixed;right:8px;top:2px;z-index:10001;background:#000;color:#8e8;padding:0 6px;font:bold 12px monospace;pointer-events:none`,o.textContent=`FPS`,document.body.append(o)};setTimeout(globalThis.__fpsT,3e3);document.addEventListener(`keydown`,e=>{e.code===`F9`&&(e.preventDefault(),e.stopPropagation(),globalThis.__fpsT())},!0);' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'fps' } }
# FPS 제한 (0 = 제한 없음): 낮추면 CPU/GPU 부담이 줄어듦. 게임 진행 속도는 그대로
if ([int]$O.fpscap -gt 0) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
    $mf = Find $game ('e\.ticker\.minFPS=1/' + $id + ',') 'fps cap'
    $game = Swap $game $mf.Value ($mf.Value + 'e.ticker.maxFPS=' + [int]$O.fpscap + ',') 'fps cap'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'fpscap' } }
# 렌더링 해상도 고정 (0 = 게임 자동): 낮추면 빨라지고 흐려짐
if ([int]$O.res -gt 0) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
    $rv = ([decimal]$O.res / 100).ToString($inv)
    $ri = Find $uiText ('static initial\(e,t,n=\{width:innerWidth,height:innerHeight\}\)\{return t\?\?' + $id + '\(n\.width,n\.height,devicePixelRatio\|\|1,e\)\}') 'render res'
    $uiText = Swap $uiText $ri.Value ($ri.Value.Replace('{return t??', '{return ' + $rv + '||(t??').TrimEnd('}') + ')}') 'render res'
    $uiText = Swap $uiText 'apply(e){let t=this.app.renderer;' ('apply(e){e=' + $rv + ';let t=this.app.renderer;') 'render res apply'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'res' } }

# 게임 안 설명서(F6)와 룬워드 목록(F4): 오른쪽 창으로 열고 닫기
$guide = @'
[기본 단축키]
F6  설명서 (이 창)
F10 패치 기록
F4  룬워드 목록 (고정 옵션 / 변하는 옵션 범위)
F3  드롭 확률 계산기 (단계 · 매찬별 룬워드 · 유니크 확률)
F5  기능 켜기 · 끄기 (바로 적용)
F2  보관 설정: 아이템마다 판매 / 인벤 / 창고 선택, 등록 개수
F7  배속 1 → 1.5 → 2 → 3배
F1  획득 · 판매 통계 (이번 실행 / 오늘, 시간당)
F8  AFK 모드 (검은 화면 + 진행 상황, 자동 정지 · 기록 이어가기 설정)
F9  FPS · 버전 표시
B   창고 열기 (런 중, 마을)
Ctrl+클릭  인벤토리 아이템을 창고로
PageUp / PageDown  밝기,  Home / End  명암

[아이템 자동 처리]
- 새 유니크/세트/룬워드는 보관함(고유)에 자동 등록
- 등록본보다 좋으면 자동 교체 (스킬 > 오라·발동 > 그 외 옵션 > 방어력 순으로 비교)
- 룬워드: 한손 우선 (양손 등록본은 한손이 나오면 교체, 한손 등록본은 양손으로 안 바꿈), 한손/양손 겸용은 양손으로 따로 보관
- 룬워드 중복: 같은 종류는 판매 (한손은 1개 더 보관), 다른 종류는 종류별 1개 보관
- 부적 · 매직 · 레어 등은 F2 보관 설정대로 판매 / 인벤 / 창고 (퀘스트 아이템은 인벤토리)
- 인벤토리가 꽉 차면 개인 창고 → 공용 창고 순서로

[화면 표시]
- 왼쪽 획득 목록: 줄에 마우스를 올리면 옵션, [교체] 줄은 바뀐 옵션
- [되돌리기]: 유니크/세트 교체 취소
- 아이템 툴팁 옆 비교 상자: 같은 아이템 위치와 좋고 나쁨 (초록 ▲ 좋음 / 빨강 ▼ 나쁨)
- 툴팁 맨 아래 "숨겨진 값"
- 맨 위 줄: 적용된 기능 (초록 ✓ 적용 / 빨강 ✗ 안 함)

[자동 진행]
- 공포 영역 보스 처치 후 포털 자동 입장
- 클리어 후 같은 단계 반복 또는 한 단계씩 올라가기 (패치 창에서 선택)
- 상점(T)이나 Esc 로 나가면 취소

[패치 / 업데이트]
- D2S-MyPatch.bat 실행 → 기능 체크 → [체크한 것 적용]
- 새 버전이 나오면 오른쪽 아래 알림 → 클릭 → 예: 게임 종료, 패치, 다시 실행
- 패치 상태에서는 순위표에 기록을 보내지 않음
'@
$game = 'globalThis.__guide=' + ($guide | ConvertTo-Json) + ';globalThis.__pnl=(id,title,html)=>{let o=document.getElementById(id);for(let x of[`__plog`,`__pguide`,`__prw`,`__pdrop`,`__pks`])document.getElementById(x)?.remove();if(o)return null;o=document.createElement(`div`),o.id=id,o.style.cssText=`position:fixed;right:20px;top:40px;bottom:40px;width:min(600px,46vw);overflow:auto;z-index:10003;background:#000e;color:#ddd;border:1px solid #fc6;padding:10px 14px;font:14px sans-serif;line-height:1.5`,o.innerHTML=`<div style="position:sticky;top:-10px;margin:-10px -14px 6px;padding:10px 14px 6px;background:#000;border-bottom:1px solid #333;z-index:1"><div style="color:#fc6;font-weight:bold">${title}</div></div>`+html;let x=o.querySelector(`.__phx`);x&&o.firstChild.append(x),document.body.append(o);return o};globalThis.__esc=t=>String(t).replace(/&/g,`&amp;`).replace(/</g,`&lt;`);globalThis.__rwHtml=()=>{try{return globalThis.__rwHtml0()}catch(x){return`<div style="color:#f77">' + (T '룬워드 목록 오류' 'Runeword list error') + ': ${__esc(x?.stack??x)}</div>`}};globalThis.__rwHtml0=()=>{let w=globalThis.__rw?.();if(!w?.R?.runewords)return`' + (T '룬워드 데이터를 아직 못 읽었습니다. 게임을 한 판 시작한 뒤 다시 열어 보세요.' 'Runeword data not loaded yet. Start a run and try again.') + '`;let ty={weap:`' + (T '무기' 'weapon') + '`,mele:`' + (T '근접 무기' 'melee') + '`,miss:`' + (T '원거리 무기' 'missile') + '`,swor:`' + (T '검' 'sword') + '`,axe:`' + (T '도끼' 'axe') + '`,pole:`' + (T '미늘창' 'polearm') + '`,spea:`' + (T '창' 'spear') + '`,hamm:`' + (T '망치' 'hammer') + '`,club:`' + (T '둔기' 'club') + '`,mace:`' + (T '철퇴' 'mace') + '`,scep:`' + (T '홀' 'scepter') + '`,staf:`' + (T '지팡이' 'staff') + '`,wand:`' + (T '마법봉' 'wand') + '`,knif:`' + (T '단검' 'dagger') + '`,h2h:`' + (T '손톱' 'claw') + '`,bow:`' + (T '활' 'bow') + '`,xbow:`' + (T '석궁' 'crossbow') + '`,helm:`' + (T '투구' 'helm') + '`,tors:`' + (T '갑옷' 'armor') + '`,shld:`' + (T '방패' 'shield') + '`,pala:`' + (T '성기사 방패' 'paladin shield') + '`,head:`' + (T '강령술사 머리' 'necro head') + '`,orb:`' + (T '오브' 'orb') + '`,abow:`' + (T '아마존 활' 'amazon bow') + '`,aspe:`' + (T '아마존 창' 'amazon spear') + '`,jave:`' + (T '투창' 'javelin') + '`},K=t=>String(t).replace(/[0-9.]+/g,`#`),out=[];for(let v of w.list??[]){try{let d=w.R.runewords[v.name];if(!d?.props?.length)continue;let sl=v.types?.some(t=>/^(shld|pala|head)$/.test(t))?`shield`:v.types?.some(t=>/^(helm|tors)$/.test(t))?`helm`:`weapon`,mk=m=>{let st=w.make([...d.props,...(v.runes??[]).flatMap(r=>w.R.runes?.[r]?.[sl]??[])],v.lvl,(a,b)=>m===`min`?Math.min(a,b):Math.max(a,b));try{let bs=sl===`shield`?`Ward`:sl===`helm`?(v.types?.includes(`tors`)?`Russet Armor`:`Shako`):`Flanged Mace`,tp=x=>globalThis.__tip?.({name:v.name,rarity:`runeword`,base:bs,stats:x})??[],l=tp(st),z=tp([]),c={};for(let x of z)c[x]=(c[x]||0)+1;l=l.filter(x=>c[x]>0?(c[x]--,!1):!0);if(l.length)return l}catch{}return st.map(s=>s.stat+(s.param!=null?`(${s.param})`:``)+` `+s.value+(s.level!=null?` lv${s.level}`:``))},a=mk(`min`),b=mk(`max`),B=new Set,L=a.map(p=>{let j=b.findIndex((q,J)=>!B.has(J)&&K(q)===K(p));if(j<0)return`<div style="color:#aaa">${__esc(p)}</div>`;B.add(j);return b[j]===p?`<div style="color:#aaa">${__esc(p)}</div>`:`<div style="color:#fc6">${__esc(p)} <span style="color:#888">~</span> ${__esc(b[j])}</div>`}).join(``),nm=v.name;try{nm=globalThis.__nm?.({name:v.name,rarity:`runeword`})||v.name}catch{}out.push(`<div class="rw" data-k="${__esc((nm+` `+v.name+` `+v.runes.join(` `)).toLowerCase())}" style="margin:8px 0;padding-top:6px;border-top:1px solid #333"><div><b style="color:#c9a">${__esc(nm)}</b></div><div style="color:#8cf">${v.runes.join(` + `)} · ' + (T '레벨' 'lvl') + ' ${v.lvl} · ${(v.types??[]).map(t=>ty[t]??t).join(`, `)}</div>${L}</div>`)}catch(x){out.push(`<div style="color:#f77">${__esc(v.name)}: ${__esc(x?.message??x)}</div>`)}}return`<div class="__phx"><div style="color:#888;margin-bottom:4px">' + (T '노랑 = 변하는 옵션 (최소 ~ 최대), 회색 = 고정 옵션' 'yellow = variable (min ~ max), grey = fixed') + '</div><input id="__prwq" placeholder="' + (T '검색 (이름, 룬)' 'search (name, rune)') + '" style="width:100%;box-sizing:border-box;padding:4px 6px;background:#111;color:#ddd;border:1px solid #555;font:14px sans-serif"></div>`+out.join(``)};document.addEventListener(`keydown`,e=>{if((/^(__prwq|__dt|__dm|__dx|__pksq)$/.test(e.target?.id??``)||e.target?.closest?.(`#__pks input`))&&!/^F[0-9]+$/.test(e.code)){e.stopPropagation();return}let k={F6:1,F4:2}[e.code];if(!k)return;e.preventDefault(),e.stopPropagation();if(k===1)globalThis.__pnl(`__pguide`,`' + (T '설명서' 'Guide') + ' v' + $Ver + ' (F6 ' + (T '닫기' 'close') + ')`,`<div style="white-space:pre-line">${__esc(globalThis.__guide)}</div>`);else{let o=globalThis.__pnl(`__prw`,`' + (T '룬워드 목록' 'Runewords') + ' (F4 ' + (T '닫기' 'close') + ')`,globalThis.__rwHtml());let q=o?.querySelector(`#__prwq`);q&&(q.oninput=()=>{let t=q.value.toLowerCase();o.querySelectorAll(`.rw`).forEach(x=>x.style.display=x.dataset.k.includes(t)?``:`none`)},q.focus())}},!0);' + $game

# 게임 새 빌드가 준비되면 알림: 설치하면 패치가 풀리고, 설치 후 bat를 실행하면 되는 기능만 다시 적용 (안 맞으면 이 알림만 생략)
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$gu = Find $game ('(' + $id + ')\.onReady\(e=>\{this\.state!==`select`') 'game update'
$game = Swap $game $gu.Value ($gu.Value.Replace('onReady(e=>{', 'onReady(e=>{globalThis.__gupd?.(e);')) 'game update'
$game = 'globalThis.__gupd=v=>{if(document.getElementById(`__gupd`))return;let d=document.createElement(`div`);d.id=`__gupd`,d.textContent=`' + (T '게임 새 빌드 ' 'Game build ') + '${v}' + (T ' 준비됨. 설치하면 패치가 풀립니다. 설치 후 D2S-MyPatch.bat 를 실행하면 이 빌드에서 되는 기능만 다시 적용하고 안 되는 기능을 알려 줍니다.' ' is ready. Installing removes the patch. After installing, run D2S-MyPatch.bat to re-apply what still works.') + '`,d.style.cssText=`position:fixed;right:8px;bottom:120px;z-index:10001;background:#000d;color:#8cf;border:1px solid #8cf;padding:6px 10px;font:14px sans-serif;max-width:420px`,document.body.append(d)};' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap }

# 게임 안 패치 기록 (F10으로 열고 닫기)
$game = 'globalThis.__plog=' + ($changelog | ConvertTo-Json) + ';document.addEventListener(`keydown`,e=>{if(e.code!==`F10`)return;e.preventDefault(),e.stopPropagation();let o=document.getElementById(`__plog`);if(o)return o.remove();o=document.createElement(`div`),o.id=`__plog`,o.style.cssText=`position:fixed;right:20px;top:60px;bottom:60px;width:440px;overflow:auto;z-index:10003;background:#000e;color:#ddd;border:1px solid #fc6;padding:10px 14px;font:14px sans-serif;line-height:1.5;white-space:pre-line`,o.textContent=`' + (T '패치 기록' 'Patch log') + ' v' + $Ver + ' (F10 ' + (T '닫기' 'close') + ')\n`+globalThis.__papp+`\n\n`+globalThis.__plog,document.body.append(o)},!0);setTimeout(()=>{let h=document.createElement(`div`);h.id=`__pbar`,h.style.cssText=`position:fixed;left:0;right:0;top:0;z-index:10000;background:#000b;color:#ccc;padding:2px 170px 2px 8px;font:12px sans-serif;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;pointer-events:none`,h.innerHTML=`<span style="color:#fc6;font-weight:bold">D2S v' + $Ver + '</span> <span style="color:#999">(' + (T '게임 빌드 ' 'build ') + $build + ')</span> · <span style="color:#8cf">F6 ' + (T '설명서' 'guide') + ' · F4 ' + (T '룬워드' 'runewords') + ' · F3 ' + (T '드롭 확률' 'drop odds') + ' · F2 ' + (T '보관 설정' 'keep') + ' · F10 ' + (T '패치 기록' 'patch log') + '</span> · `+globalThis.__papp.replace(/</g,`&lt;`).replace(/\u2713([^ ·|]+)/g,`<span style="color:#7e7">\u2713$1</span>`).replace(/\u2717([^ ·|]+)/g,`<span style="color:#f77">\u2717$1</span>`),document.body.append(h)},3e3);' + $game
$game = 'globalThis.__papp=' + ($applied | ConvertTo-Json) + ';' + $game

# 패치 버전 표시: 다음 실행 때 예전 버전인지 판단용
$game = 'globalThis.__d2sv=' + $Ver + ';' + $game

# 업데이트 알림 표시 함수 (게임 본체가 새 버전을 찾으면 호출) GitHub 버전 확인, 새 버전 있으면 오른쪽 아래 알림 (클릭하면 닫힘)
$game = 'globalThis.__updShow=t=>{let L=t.split(/\r?\n/);let o=document.getElementById(`__upd`);if(+L[0]>' + $Ver + '&&!(o&&o.__v>=+L[0])){o&&o.remove();let d=document.createElement(`div`);d.id=`__upd`,d.__v=+L[0],d.__s=`' + (T '패치 업데이트 있음 v' 'Patch update v') + '${L[0].trim()} (' + (T '클릭하면 바로 패치' 'click to patch now') + ')`,d.__n=L.slice(1).filter(x=>x.trim()).join(`\n`),d.textContent=d.__s+`\n`+d.__n,d.style.cssText=`position:fixed;right:8px;bottom:8px;z-index:10001;background:#000d;color:#fc6;border:1px solid #fc6;padding:6px 10px;font:14px sans-serif;cursor:pointer;white-space:pre-line;max-width:420px`,d.onclick=()=>{if(document.getElementById(`__updq`))return;let q=document.createElement(`div`),b=(t,f)=>{let x=document.createElement(`button`);x.textContent=t,x.style.cssText=`font:bold 15px sans-serif;margin:10px 6px 0;padding:6px 20px;background:#222;color:#fc6;border:1px solid #fc6;cursor:pointer`,x.onclick=f,q.append(x)};q.id=`__updq`,q.style.cssText=`position:fixed;left:50%;top:40%;transform:translate(-50%,-50%);z-index:10002;background:#000e;color:#ddd;border:1px solid #fc6;padding:16px 22px;font:15px sans-serif;text-align:center;white-space:pre-line`,q.textContent=`' + (T '게임을 끄고 지금 패치할까요?
(진행 중인 판은 저장되지 않을 수 있습니다)' 'Close the game and patch now?
(the current run may not be saved)') + '
`,b(`' + (T '예' 'Yes') + '`,()=>{q.textContent=`' + (T '게임을 종료합니다...' 'Closing...') + '`,fetch(`https://d2s-update.invalid/run`).catch(()=>{})}),b(`' + (T '아니오' 'No') + '`,()=>q.remove()),document.body.append(q)},document.body.append(d)}};' + $game
if ($O.afk) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$game = 'globalThis.__afkC=(()=>{try{return JSON.parse(localStorage.getItem(`d2s:afkstop`)||`{}`)}catch{return{}}})();globalThis.__afkFull=((__Fi,__T,__Ig,__Gr)=>k=>{let g=globalThis.__gm,c=g?.world?.player?.cls??g?.kit?.id;return!!g&&!!c&&!__Fi(k===`inv`?g.inventoryOf(c):__T(g.save,c,k),{base:`?`},k===`inv`?__Ig:__Gr)})(' + $fit + ',' + $tab + ',' + $igrid + ',' + $sgrid + ');' + $beep + 'globalThis.__afkN={};globalThis.__afkAdd=(k,r)=>{let a=[2,0,1,2,3][k],c={unique:0,set:1,runeword:2}[r]??3,n=globalThis.__afkN;(n[a]??=[0,0,0,0])[c]++};globalThis.__afk=0;globalThis.__afkT=()=>{let o=document.getElementById(`__afk`);if(globalThis.__afk){globalThis.__afk=0,globalThis.__halt=0,globalThis.__afkE=(globalThis.__afkE||0)+Date.now()-globalThis.__afkS,o&&o.remove(),clearInterval(globalThis.__afkI);return}let C=globalThis.__afkC;globalThis.__afk=1,globalThis.__halt=0,globalThis.__afkS=Date.now();C.keep&&globalThis.__afkN0||(globalThis.__afkE=0,globalThis.__afkG=0,globalThis.__afkR=0,globalThis.__afkN={},globalThis.__afkL=0,globalThis.__afkTot=0);globalThis.__afkN0=1;o=document.createElement(`div`),o.id=`__afk`,o.style.cssText=`position:fixed;inset:0;z-index:9998;background:#000;color:#ccc;font:16px sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;line-height:1.6;text-align:center`;let s=document.createElement(`div`),b=document.createElement(`button`);b.textContent=`' + (T 'AFK 모드 종료 (F8)' 'Exit AFK mode (F8)') + '`,b.style.cssText=`font:bold 18px sans-serif;padding:10px 28px;background:#222;color:#fc6;border:1px solid #fc6;cursor:pointer`,b.onclick=()=>globalThis.__afkT();let c=document.createElement(`div`);c.style.cssText=`font:14px sans-serif;color:#aaa;display:flex;flex-direction:column;gap:6px;align-items:center;border:1px solid #333;padding:8px 14px`;c.innerHTML=`<div><label><input type=checkbox data-x=keep ${C.keep?`checked`:``}> ' + (T '기록 이어가기 (끄고 다시 켜도 게임 켠 뒤부터 합산)' 'Keep stats (sum since game start)') + '</label></div><div>' + (T '자동 정지' 'Auto stop') + ' <input id=__afm type=number min=0 value=${C.min??0} style="width:56px;background:#111;color:#fc6;border:1px solid #555"> ' + (T '분 (0 = 무제한)' 'min (0 = no limit)') + '</div><div>' + (T '꽉 차면 정지 (체크한 곳이 전부 꽉 찼을 때)' 'Stop when full (all checked)') + ': <label style="margin-left:8px"><input type=checkbox data-k=inv ${C.full?.includes(`inv`)?`checked`:``}> ' + (T '인벤' 'Inventory') + '</label><label style="margin-left:8px"><input type=checkbox data-k=personal ${C.full?.includes(`personal`)?`checked`:``}> ' + (T '개인 창고' 'Personal') + '</label><label style="margin-left:8px"><input type=checkbox data-k=shared1 ${C.full?.includes(`shared1`)?`checked`:``}> ' + (T '공유 1' 'Shared 1') + '</label><label style="margin-left:8px"><input type=checkbox data-k=shared2 ${C.full?.includes(`shared2`)?`checked`:``}> ' + (T '공유 2' 'Shared 2') + '</label><label style="margin-left:8px"><input type=checkbox data-k=shared3 ${C.full?.includes(`shared3`)?`checked`:``}> ' + (T '공유 3' 'Shared 3') + '</label></div>`;c.addEventListener(`keydown`,e=>e.code!==`F8`&&e.stopPropagation());c.oninput=()=>{C.keep=c.querySelector(`[data-x]`).checked,C.min=Math.max(0,+c.querySelector(`#__afm`).value||0),C.full=[...c.querySelectorAll(`[data-k]:checked`)].map(x=>x.dataset.k);try{localStorage.setItem(`d2s:afkstop`,JSON.stringify(C))}catch{}};o.append(s,c,b),document.body.append(o);let u=()=>{let g=globalThis.__gm,w=g?.world,m=Math.floor(((globalThis.__afkE||0)+Date.now()-globalThis.__afkS)/1e3),N={inv:`' + (T '인벤' 'Inventory') + '`,personal:`' + (T '개인 창고' 'Personal') + '`,shared1:`' + (T '공유 1' 'Shared 1') + '`,shared2:`' + (T '공유 2' 'Shared 2') + '`,shared3:`' + (T '공유 3' 'Shared 3') + '`},H=globalThis.__halt||(C.min>0&&(Date.now()-globalThis.__afkS)/6e4>=C.min?`${C.min}' + (T '분 지남' 'min passed') + '`:C.full?.length&&C.full.every(k=>globalThis.__afkFull(k))?`${C.full.map(k=>N[k]).join(` · `)} ' + (T '꽉 참' 'full') + '`:0);H&&!globalThis.__halt&&(globalThis.__halt=H,g?.state===`playing`&&g.pause(),globalThis.__beep(2));s.innerHTML=(H?`<div style="color:#f66;font:bold 20px sans-serif">' + (T '자동 정지' 'Auto stopped') + ': ${H}</div>`:``)+`<div style="font:bold 26px sans-serif;color:#fc6">' + (T 'AFK 모드' 'AFK mode') + '</div><div>${globalThis.__regc?.()??``}</div><div>' + (T '경과' 'Elapsed') + ' ${Math.floor(m/3600)}:${String(Math.floor(m/60)%60).padStart(2,0)}:${String(m%60).padStart(2,0)} · ' + (T '게임 시간' 'Game time') + ' ${(q=>`${Math.floor(q/3600)}:${String(Math.floor(q/60)%60).padStart(2,0)}:${String(q%60).padStart(2,0)}`)(Math.floor(globalThis.__afkG||0))}</div><div>' + (T '완료한 판' 'Runs cleared') + ' ${globalThis.__afkR}${(f=>globalThis.__afkR?` · ' + (T '이전 판' 'Last') + ' ${f(globalThis.__afkL)} · ' + (T '평균' 'Avg') + ' ${f(globalThis.__afkTot/globalThis.__afkR)}`:``)(x=>`${Math.floor(x/60)}:${String(Math.floor(x%60)).padStart(2,0)}`)}</div><div>${w?.terror?`' + (T '공포 영역' 'Terror') + ' ${w.terror.tier} · `:``}' + (T '처치' 'Kills') + ' ${w?.kills??0} · ' + (T '이번 판 골드' 'Run gold') + ' ${Math.floor(w?.gold??0).toLocaleString()}</div>${(v=>v&&!v.done?`<div style="color:#fc6">' + (T '웨이브' 'Wave') + ' ${v.wave}/${v.of} · ${v.left} ' + (T '남음' 'left') + '${v.elites?` · ' + (T '정예' 'elites') + ' ${v.elites}`:``}</div>`:``)(globalThis.__wave)}<div>' + (T '보유 골드' 'Gold') + ' ${Math.floor(g?.save?.gold??0).toLocaleString()}</div><div>' + (T '배속' 'Speed') + ' x${globalThis.__spd??1} (F7)</div><table style="margin:8px auto;border-collapse:collapse"><tr style="color:#888"><td></td><td style="padding:2px 10px;color:#c7b377">' + (T '유니크' 'Unique') + '</td><td style="padding:2px 10px;color:#4fd04f">' + (T '세트' 'Set') + '</td><td style="padding:2px 10px;color:#c7b377">' + (T '룬워드' 'Runeword') + '</td><td style="padding:2px 10px">' + (T '기타' 'Other') + '</td></tr>${[`' + (T '등록' 'Stashed') + '`,`' + (T '교체' 'Upgraded') + '`,`' + (T '보관' 'Kept') + '`,`' + (T '판매' 'Sold') + '`].map((l,i)=>`<tr><td style="padding:2px 10px;text-align:right;color:${[`#e8c060`,`#8cf`,`#fff`,`#999`][i]}">${l}</td>${(globalThis.__afkN[i]??[0,0,0,0]).map(v=>`<td style="padding:2px 10px">${v}</td>`).join(``)}</tr>`).join(``)}</table>`};u(),globalThis.__afkI=setInterval(u,1e3)};document.addEventListener(`keydown`,e=>{e.code===`F8`&&(e.preventDefault(),e.stopPropagation(),globalThis.__afkT())},!0);window.addEventListener(`keydown`,e=>{globalThis.__afk&&!/^F([1-9]|1[0-2])$/.test(e.code)&&!globalThis.__kr?.[e.code]&&e.stopImmediatePropagation()},!0);window.addEventListener(`keyup`,e=>{globalThis.__afk&&!/^F([1-9]|1[0-2])$/.test(e.code)&&!globalThis.__kr?.[e.code]&&e.stopImmediatePropagation()},!0);' + $game
try { try { $game = Swap $game 'By(document,window,e=>{e||this.pause(),this.bankHidden()})' '(globalThis.__gm=this,By(document,window,e=>{e||globalThis.__afk||this.pause(),this.bankHidden()}))' 'afk no pause' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'Ny(document,window,e=>{e||this.pause(),this.bankHidden()})' '(globalThis.__gm=this,Ny(document,window,e=>{e||globalThis.__afk||this.pause(),this.bankHidden()}))' 'afk no pause' } } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $game = Swap $game 'lb(document,window,e=>{e||this.pause(),this.bankHidden()})' '(globalThis.__gm=this,lb(document,window,e=>{e||globalThis.__afk||this.pause(),this.bankHidden()}))' 'afk no pause' }
$game = Swap $game 'showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();' 'showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();globalThis.__stRun?.(),globalThis.__afkR=(globalThis.__afkR||0)+1,globalThis.__afkL=e.time,globalThis.__afkTot=(globalThis.__afkTot||0)+e.time;' 'afk run count'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'afk' } }
if ($O.auto) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$game = Swap $game 'visitAfterTier(){' 'visitAfterTier(){clearTimeout(this.__ar),__cdx();' 'auto repeat town'
$game = Swap $game 'endAfterTier(){' 'endAfterTier(){clearTimeout(this.__ar),__cdx();' 'auto repeat end'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'auto' } }

# 미등록 표시는 2026.1026 업데이트부터 게임에 공식으로 들어가서 따로 고치지 않는다
if ($O.pickup) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 떨어진 아이템은 거리와 상관없이 즉시 처리한다 (원래는 몸에 닿아야 주움)
# 게임 아이템 필터(숨김·판매·보관)는 쓰지 않는다. 모든 아이템을 바로 줍고, 등록·교체 외에는 F2 보관 설정대로 판매/인벤/창고
# 그 밖의 아이템(등록된 유니크 포함)은 바로 판매한다. 퀘스트 아이템·부적은 인벤토리로
$quest = (Find $keepText ('=(' + $id + ')\(t\)\?' + $id + '\(' + $id + '\(t\.name\),`red`\)') 'quest item').Groups[1].Value
$reach = Find $keepText ('let t=n\.radius\+(' + $id + '),i=e\.reaching===r;if\(i&&c<t&&\(r\.dropped=!1\),r\.loot===`hide`&&!i\)continue;let a=r\.loot===`sell`&&!!e\.sell;') 'pickup radius'
$keepText = Swap $keepText $reach.Value ('let __pk=globalThis.__on?.(`pickup`)!==!1,__nw=e.isNew?.(r.item),t=__pk?1/0:n.radius+' + $reach.Groups[1].Value + ',i=e.reaching===r;if(i&&c<t&&(r.dropped=!1),!__pk&&r.loot===`hide`&&!i)continue;let a=__pk?!__nw&&(!' + $quest + '(r.item)||r.item.base===`hcx`)&&r.item.type!==`charm`&&!!e.sell:r.loot===`sell`&&!!e.sell;') 'pickup radius'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'pickup' } }
if ($O.goldchest) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
# 골드도 거리와 상관없이 즉시 줍는다
$gold = Find $keepText ('if\(!r\.magnet&&c<n\.pickupRadius&&\(r\.magnet=!0\),!r\.magnet\)continue;if\(c<n\.radius\+4\)\{a\+=(' + $id + ')\(e,r\);continue\}') 'gold'
$keepText = Swap $keepText $gold.Value ('if(r.kind===`gold`&&globalThis.__on?.(`goldchest`)!==!1){a+=' + $gold.Groups[1].Value + '(e,r);continue}' + $gold.Value) 'gold'
# 상자도 거리와 상관없이 즉시 연다
$chest = Find $keepText ('if\(r\.kind===`chest`\)\{if\(' + $id + '\(r\.x,r\.y,i,n\)>=n\.radius\+' + $id + '\)continue;') 'chest'
$keepText = Swap $keepText $chest.Value ('if(r.kind===`chest`){if(globalThis.__on?.(`goldchest`)===!1){' + $chest.Value.Substring(21) + '}') 'chest'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'goldchest' } }

# 시체 숨김: 시체 그림만 안 보이게 (시체 폭발 등 게임 판정은 그대로)
if ($O.corpse) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
    $keepText = Swap $keepText 'e.layer.addChild(a);let o={anim:r,direction:i,time:0,dead:!1,floor:!0,sprite:a};return e.corpses.push(o),o}' 'e.layer.addChild(a),a.visible=globalThis.__on?.(`corpse`)===!1;let o={anim:r,direction:i,time:0,dead:!1,floor:!0,sprite:a};return e.corpses.push(o),o}' 'corpse'
    $keepText = Swap $keepText 'e.layer.addChild(i),e.corpses.push({anim:r,direction:0,time:0,dead:!1,sprite:i})}' 'e.layer.addChild(i),i.visible=globalThis.__on?.(`corpse`)===!1,e.corpses.push({anim:r,direction:0,time:0,dead:!1,sprite:i})}' 'corpse 2'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'corpse' } }

# 교체 창·목록용 헬퍼: 아이템 옵션 줄(한국어)과 부위/종류
$tip = (Find $keepText ('function (' + $id + ')\(e,t,n=1,r,i=\{\},a\)\{if\(') 'tooltip').Groups[1].Value
$bases = (Find $keepText ('(' + $id + ')=new Map\((' + $id + ')\.map\(e=>\[e\.name,e\]\)\),' + $id + '=\2\.filter\(e=>e\.type===`charm`\)') 'bases').Groups[1].Value
$cats = (Find $keepText ('(' + $id + ')=\[\[`head`,`Helms`\]') 'categories').Groups[1].Value
$tr = (Find $keepText ('import\{[^}]*\bd as (' + $id + ')[^}]*\}from"\./lang-') 'translate').Groups[1].Value
$rwR = (Find $keepText ('function ' + $id + '\(e\)\{let t=(' + $id + ')\?\.runewords\?\.\[e\];return!!t&&') 'runeword data').Groups[1].Value
$rwRoll = (Find $keepText ('function (' + $id + ')\(e,t\)\{return ' + $id + '\(e\.props\.flatMap\(\(\{stats:e,min:n,max:r\}\)') 'runeword roll').Groups[1].Value
$rwList = (Find $keepText ('lvl:a\}\},(' + $id + ')=\[' + $id + '\(') 'runeword list').Groups[1].Value
$rwMake = (Find $keepText ('function (' + $id + ')\(e,t,n=' + $id + '\)\{let r=\[\];for\(let i of e\)\{let e=n\(i\.min,i\.max\)') 'runeword props').Groups[1].Value
$keepText += ";globalThis.__rw=()=>({R:$rwR,list:$rwList,roll:$rwRoll,make:$rwMake})"
# 드롭 확률 계산기 (F3): 게임의 등급 판정(Dze) · 베이스 뽑기 · 룬워드/유니크 가중치를 그대로 써서 아이템 1개당 확률 계산
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$dz = (Find $keepText ('function (' + $id + ')\(e,t,n,\{uniqueBoost:r=1,rareBoost:i=1\}=\{\}\)\{let a=') 'drop rarity').Groups[1].Value
$db = Find $keepText ('let a=(' + $id + ')\(i,n\.cls,(' + $id + ')\),o=' + $id + '\(a,r,t,n\);if\(o===`unique`') 'drop base'
$dc = (Find $keepText ('function (' + $id + ')\(e\)\{return Math\.max\(\.\.\.' + $id + '\(' + $id + '\(e\)\[1\]\)\.map\(\(\[e\]\)=>e\)\)\}') 'drop tc').Groups[1].Value
$dv = (Find $keepText ('function (' + $id + ')\(e,t,n\)\{return ' + [regex]::Escape($rwList) + '\.filter\(r=>r\.lvl<=e&&') 'drop rw').Groups[1].Value
$du = Find $keepText ('function ' + $id + '\(e,t,n\)\{return ' + $id + '\((' + $id + ')\((' + $id + '),e=>(' + $id + ')\.get\(e\),e,t,n\)\)\}') 'drop unique'
$dx = (Find $keepText ('Math\.random\(\)<(' + $id + ')\?t:e\)\}') 'drop own').Groups[1].Value
$dq = Find $keepText '=\{hell:[\d.]+,terror:([\d.]+)\}' 'drop terror boost'
$dm = try { Find $keepText ('\{magicFind:(\d+),gold:\d+,experience:\d+,items:\d+\},' + $id + '=\{magicFind:(\d+),gold:\d+\},' + $id + '=\(e,t\)=>' + $id + '\[t\]\*Math\.min\(e,(\d+)\)') 'drop tier mf' } catch { $null }
$af = try { (Find $keepText (',(' + $id + ')=\[\.\.\.' + $id + '\(\),\.\.\.' + $id + '\(\),\{name:`of Attraction`') 'affixes').Groups[1].Value } catch { $null }
if ($af) { $keepText += ";globalThis.__afx=()=>$af" }
$keepText += ";globalThis.__drop=()=>({ub:$($dq.Groups[1].Value),tm:$(if ($dm) { 't=>' + $dm.Groups[1].Value + '*Math.min(t,' + $dm.Groups[3].Value + ')+' + $dm.Groups[2].Value + '*Math.max(0,t-' + $dm.Groups[3].Value + ')' } else { 't=>0' }),R:$rwR,dz:$dz,ab:$($db.Groups[1].Value),Y:$($db.Groups[2].Value),tc:$dc,rw:$dv,kz:$($du.Groups[1].Value),U:$($du.Groups[2].Value),W:$($du.Groups[3].Value),own:$dx})"
$game = 'globalThis.__dropHtml=(T,M,X)=>{let D=globalThis.__drop?.();if(!D?.R?.runewords)return`<div>' + (T '데이터를 아직 못 읽었습니다. 한 판 시작한 뒤 다시 여세요.' 'Data not loaded yet. Start a run and reopen.') + '</div>`;let c=globalThis.__gm?.kit?.id,L=Math.min(99,85+T+X),tc=D.tc(L),N=4e3,pu=0,pr=0;for(let i=0;i<N;i++){let b=D.ab(L,c,D.Y),h=D.dz(b,L,M+D.tm(T),{uniqueBoost:D.ub}),p=k=>h[k]===1/0?0:Math.min(1,128/h[k]),u=p(`unique`);pu+=u,pr+=(1-u)*p(`runeword`)}pu/=N,pr/=N;let rv=D.rw(L,tc,c),rs=rv.reduce((s,[,w])=>s+w,0),q=D.kz(D.U,e=>D.W.get(e),L,tc,c),S=a=>a.reduce((s,[,w])=>s+w,0),sa=S(q.all),so=S(q.own),om=new Map(q.own),nm=(n,r)=>{try{return globalThis.__nm?.({name:n,rarity:r})||n}catch{return n}},f=p=>p>0?`${(p*100).toFixed(p<1e-4?5:4)}% <span style="color:#888">(${Math.round(1/p).toLocaleString()}' + (T '개에 1번' ' items per drop') + ')</span>`:`0%`,row=(n,p,k)=>`<div class="rw" data-k="${__esc(n.toLowerCase())}" style="display:flex;justify-content:space-between;gap:10px"><span style="color:${k}">${__esc(n)}</span><span>${f(p)}</span></div>`,R=rv.map(([e,w])=>[nm(e.name,`runeword`),pr*w/rs]).sort((a,b)=>b[1]-a[1]),U=q.all.map(([e,w])=>[nm(e.name,`unique`),pu*((q.own.length?D.own*(om.get(e)??0)/so:0)+(q.own.length?1-D.own:1)*w/sa)]).sort((a,b)=>b[1]-a[1]);return`<div style="color:#aaa;margin-bottom:6px">' + (T '아이템 레벨' 'Item level') + ' ${L} · ' + (T '아이템 1개가 떨어질 때 그 아이템이 될 확률 (마법 이상 드롭 기준, 등급 판정은 게임 공식, 베이스는' 'Chance that one dropped item is this (game formula, bases sampled') + ' ${N}' + (T '번 뽑아 평균)' ' times)') + '</div><div>' + (T '유니크' 'Unique') + ': <b style="color:#c7b377">${f(pu)}</b> · ' + (T '룬워드' 'Runeword') + ': <b style="color:#c7b377">${f(pr)}</b></div><div style="color:#fc6;margin:8px 0 2px">' + (T '룬워드' 'Runewords') + ' (${R.length})</div>${R.map(([n,p])=>row(n,p,`#c7b377`)).join(``)}<div style="color:#fc6;margin:8px 0 2px">' + (T '유니크' 'Uniques') + ' (${U.length})</div>${U.map(([n,p])=>row(n,p,`#c7b377`)).join(``)}`};globalThis.__dropOpen=()=>{let g={};try{g=JSON.parse(localStorage.getItem(`d2s:drop`)||`{}`)}catch{}let t=globalThis.__gm?.world?.terror?.tier??g.t??12,m=g.m??0,x=g.x??0,o=globalThis.__pnl(`__pdrop`,`' + (T '드롭 확률 계산기 (F3 닫기)' 'Drop chance calculator (F3 close)') + '`,`<div class="__phx" style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;font-size:13px">' + (T '공포 단계' 'Terror tier') + ' <input id="__dt" type="number" min="1" max="200" value="${t}" style="width:52px"> ' + (T '캐릭터 매찬' 'Character MF') + ' <input id="__dm" type="number" min="0" value="${m}" style="width:70px">% <select id="__dx"><option value="0">' + (T '일반 몬스터' 'Normal') + '</option><option value="2">' + (T '챔피언' 'Champion') + ' (+2)</option><option value="3">' + (T '유니크·보스' 'Unique/boss') + ' (+3)</option></select><input id="__prwq" placeholder="' + (T '검색' 'search') + '" style="flex:1;min-width:100px"></div><div id="__dres"></div>`);if(!o)return;let q=i=>o.querySelector(i),run=()=>{let t=+q(`#__dt`).value||1,m=+q(`#__dm`).value||0,x=+q(`#__dx`).value||0;try{localStorage.setItem(`d2s:drop`,JSON.stringify({t,m,x}))}catch{}try{q(`#__dres`).innerHTML=`<div style="color:#c7b377;margin:4px 0">' + (T '단계 보너스' 'Tier bonus') + ' +${globalThis.__drop?.().tm(t)}% → ' + (T '총 매찬' 'total MF') + ' ${m+globalThis.__drop?.().tm(t)}% · ' + (T '공포 유니크 배율' 'Terror unique boost') + ' x${globalThis.__drop?.().ub}</div>`+__dropHtml(t,m,x)}catch(e){q(`#__dres`).textContent=String(e?.stack??e)}filt()},filt=()=>{let s=q(`#__prwq`).value.toLowerCase();o.querySelectorAll(`.rw`).forEach(x=>x.style.display=x.dataset.k.includes(s)?`flex`:`none`)};q(`#__dx`).value=x,q(`#__dt`).onchange=q(`#__dm`).onchange=q(`#__dx`).onchange=run,q(`#__prwq`).oninput=filt,o.querySelectorAll(`input,select`).forEach(i=>i.style.cssText+=`;background:#111;color:#ddd;border:1px solid #555;padding:2px 4px`),run()};document.addEventListener(`keydown`,e=>{if(e.code!==`F3`)return;e.preventDefault(),e.stopPropagation(),globalThis.__dropOpen()},!0);' + $game
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'dropcalc' }
$keepText += ";globalThis.__tip=e=>{let f=x=>$tip(x).lines.map(l=>$tr(l.text));e={mods:[],...e};try{return f(e)}catch{try{return f({...e,rarity:`unique`})}catch{return[]}}};globalThis.__tipc=e=>{try{return $tip(e).lines.map(l=>({t:$tr(l.text),c:l.unusable?``#ff5050``:l.inert?``#9a9a9a``:l.tone===``set``?``#0f0``:l.tone===``gold``?``#c7b377``:l.implicit?``#fff``:``#6969ff``}))}catch{return[]}};globalThis.__rcol=r=>({unique:``#c7b377``,runeword:``#c7b377``,set:``#0f0``,magic:``#6969ff``,rare:``#ffff64``})[r]??``#fff``;globalThis.__kd=e=>{let o=$bases.get(e.base);return o?.type===``weapon``?o.kind+(o.twoHand?2:1):o?.type};globalThis.__bsz=e=>$bases.get(e.base)?.size;globalThis.__slot=e=>{let o=$bases.get(e.base),w=o?.type===``weapon``,c=w?o.kind:o?.type,n=$cats.find(x=>x[0]===c)?.[1],g=!o?null:w?``$(T '무기' 'Weapon')``:c===``ring``||c===``amulet``?``$(T '장신구' 'Jewelry')``:c===``charm``?null:``$(T '방어구' 'Armor')``,h=w?(o.oneHand&&o.twoHand?``$(T '한손/양손' '1H/2H')``:o.twoHand?``$(T '양손' '2H')``:``$(T '한손' '1H')``):null;return[{unique:``$(T '유니크' 'Unique')``,set:``$(T '세트' 'Set')``,runeword:``$(T '룬워드' 'Runeword')``}[e.rarity],g,h,n&&$tr(n),o&&$tr(e.base)].filter(Boolean).join(``` · ``)};"
# kodia.ttf가 있으면 숫자·영문·기호도 디아2 그림 글꼴 대신 그 폰트로 그린다 (공백 제외 전부)
$langEntry = Entry 'lang'
$langText = ReadFile $langEntry
if ($O.font) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
    $keepText = Swap $keepText 'let t=e.charCodeAt(0);return t>=44032&&t<=55203' 'let t=e.charCodeAt(0);return t>32&&t!==160||t>=44032&&t<=55203' 'all glyphs foreign'
    $langText = Swap $langText '{unicodeRange:`U+1100-11FF, U+3130-318F, U+AC00-D7A3`}' '{}' 'font range'
    # 아이템 툴팁 글자만 4배 해상도로 그려 선명하게 (메뉴처럼 글자 이미지를 복사해 쓰는 곳은 그대로)
    try { $uiText = Swap $uiText 'printTooltip(e){let t=' 'printTooltip(e){globalThis.__sharp=1;try{this.__pt(e)}finally{globalThis.__sharp=0}}__pt(e){let t=' 'sharp tooltip' } catch { if ("$_" -notlike 'D2SUNSUP:*') { throw }; $keepText = Swap $keepText 'printTooltip(e){let t=' 'printTooltip(e){globalThis.__sharp=1;try{this.__pt(e)}finally{globalThis.__sharp=0}}__pt(e){let t=' 'sharp tooltip' }
    $keepText = Swap $keepText 'u.className=`d2-text`,u.textContent=e;' 'u.className=`d2-text`,u.textContent=e,u.__s=globalThis.__sharp;' 'sharp mark'
    $keepText = Swap $keepText 'f=()=>{let e=u.getContext(`2d`),t=e.createImageData(u.width,u.height);' 'f=()=>{if(u.__s&&!u.__k){let w=u.width,h=u.height;u.__k=4,u.width=w*4,u.height=h*4,u.style.width=w+`px`,u.style.height=h+`px`,u.style.imageRendering=`auto`}let e=u.getContext(`2d`);e.setTransform(1,0,0,1,0,0);let t=e.createImageData(u.width,u.height);' 'sharp ctx'
    $keepText = Swap $keepText 'e.putImageData(t,0,0);for(let{line:t,x:r,y:i}of d)o&&this.drawForeign' 'e.putImageData(t,0,0);e.setTransform(u.__k||1,0,0,u.__k||1,0,0);for(let{line:t,x:r,y:i}of d)o&&this.drawForeign' 'sharp draw'
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'font' } }
# --- 고친 두 파일은 데이터 끝에 붙이고 헤더의 위치·크기·해시만 바꾼다 ---
function Hex($b, $off, $len) {
    $h = [Security.Cryptography.SHA256]::Create().ComputeHash($b, $off, $len)
    ([BitConverter]::ToString($h) -replace '-', '').ToLower()
}
function NewEntry($e, $b, $offset) {
    $block = 4194304
    $blocks = for ($i = 0; $i -lt $b.Length; $i += $block) { '"' + (Hex $b $i ([Math]::Min($block, $b.Length - $i))) + '"' }
    '"{0}":{{"size":{1},"offset":"{2}","integrity":{{"algorithm":"SHA256","hash":"{3}","blockSize":{4},"blocks":[{5}]}}}}' -f `
        $e.Groups[1].Value, $b.Length, $offset, (Hex $b 0 $b.Length), $block, ($blocks -join ',')
}

# 안 되는 기능은 맨 위 줄 요약에 (불가)로 표시
if ($bad.Count) { $old = $applied | ConvertTo-Json; foreach ($k in $bad) { $O[$k] = $false; $On[$k] = $false; $short[$k] += (T '(불가)' '(n/a)') }; $applied = MkApplied; $game = $game.Replace($old, ($applied | ConvertTo-Json)) }

# 꺼 둔 표시 기능은 빈 함수로 바꿔 둔다
if (-not $O.log) { $game += ';globalThis.__lg=()=>{};' }
if (-not $O.swpop) { $game += ';globalThis.__sw=()=>{};' }

# 기능 실시간 켜고 끄기: 사용자 선택($On)을 시작값으로, F5 창 · 함수형 기능 감싸기는 Game 끝에 붙임
$now = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$offJs = '{' + ((@($feat.Keys | Where-Object { -not $On[$_] }) | ForEach-Object { '"' + $_ + '":1' }) -join ',') + '}'
$liveJs = '[' + (($live | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
$shortJs = '{' + (($live | ForEach-Object { '"' + $_ + '":' + ($short[$_] | ConvertTo-Json) }) -join ',') + '}'
$labJs = '{' + (($live | ForEach-Object { '"' + $_ + '":' + ($feat[$_] | ConvertTo-Json) }) -join ',') + '}'
$game = 'globalThis.__off=(()=>{let d=globalThis.__off0=' + $offJs + ';try{let j=JSON.parse(localStorage.getItem(`d2s:on`)||`null`);if(j&&j.t>' + $now + ')return j.off}catch{}return d})();globalThis.__on=k=>!globalThis.__off?.[k];globalThis.__cfg=(()=>{let d={delay:' + [int]$O.delay + ',automode:`' + $O.automode + '`,brightness:' + [int]$O.brightness + ',contrast:' + [int]$O.contrast + '};try{let j=JSON.parse(localStorage.getItem(`d2s:on`)||`null`);if(j&&j.t>' + $now + '&&j.cfg)return{...d,...j.cfg}}catch{}return d})();' + $game
$game += ';globalThis.__f2t=e=>{try{let g=globalThis.__gm?.save;if(!g||!e?.base||!globalThis.__ksv)return[];let W=[`' + (T '인벤' 'bag') + '`,`' + (T '인벤' 'bag') + '`,`' + (T '판매' 'sell') + '`,`' + (T '창고' 'stash') + '`],H=`F2 ' + (T '판정' 'verdict') + ': `;if(/^(unique|set|runeword)$/.test(e.rarity)){let u=g.uniques?.find(x=>x.rarity===e.rarity&&x.name===e.name);if(u===e)return[H+`' + (T '보관함 등록본' 'collection copy') + '`];if(!u)return[H+`' + (T '보관함 등록 (처음 나온 것)' 'register (first one)') + '`];if(globalThis.__bt?.(g,e))return[H+`' + (T '보관함 교체 (등록본보다 좋음)' 'upgrade (better than stashed)') + '`]}let v=__ksv(e),k=__ksk(e),r=``;if(k===`h:`||k?.[0]===`q`){let d=globalThis.__kd?.(e)??``,p=k===`h:`?`h`:k.slice(0,3),z=k===`h:`?{Small:`s`,Large:`l`,Grand:`g`}[String(e.base).split(` `)[0]]??`s`:/[12]$/.test(d)?`w`:{head:`h`,body:`b`,shield:`s`,gloves:`g`,boots:`o`,belt:`t`,ring:`r`,amulet:`a`,jewel:`j`}[d]??`b`,V=__kvals([...(e.mods??[]),...(e.stats??[])]),L=globalThis.__f2L??=Object.fromEntries(__kct.map(x=>[x[0],x[2]])),m=Object.keys(V).filter(t=>__khv(p,z,t)===v&&V[t]>=__khm(p,z,t)).map(t=>`${L[t]??t} ${V[t]}`+(__khm(p,z,t)?` ≥ ${__khm(p,z,t)}`:``));r=v===2?`' + (T '창고 · 인벤으로 정한 옵션 중 기준 넘는 것 없음' 'no stash/bag option over its minimum') + '`:m.slice(0,3).join(` · `)}else if(k)r={r:`' + (T '룬워드 설정' 'runeword setting') + '`,u:`' + (T '유니크 설정' 'unique setting') + '`,s:`' + (T '세트 설정' 'set setting') + '`,c:`' + (T '기타 설정' 'other setting') + '`}[k[0]]??``;return[H+(W[v]??`' + (T '처리 없음' 'none') + '`)+(r?`  (${r})`:``)]}catch{return[]}};globalThis.__onL=' + $liveJs + ';globalThis.__keys=(()=>{try{return JSON.parse(localStorage.getItem(`d2s:pkeys`)||`{}`)}catch{return{}}})();globalThis.__krB=()=>{globalThis.__kr={};for(let d in __keys)__keys[d]&&__keys[d]!==d&&(__kr[__keys[d]]=d)};__krB();globalThis.__kn=c=>String(c).replace(/^Key/,``).replace(/^Digit/,``);(()=>{let S=new WeakSet,H=e=>{if(S.has(e)||globalThis.__kcap)return;let t=e.target;if(t&&/^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName))return;let d=__kr[e.code];if(d){e.preventDefault(),e.stopImmediatePropagation();let n=new KeyboardEvent(e.type,{code:d,key:d.replace(/^Key/,``).toLowerCase(),bubbles:!0,cancelable:!0,repeat:e.repeat,shiftKey:e.shiftKey,ctrlKey:e.ctrlKey,altKey:e.altKey});S.add(n),document.body.dispatchEvent(n);return}__keys[e.code]&&__keys[e.code]!==e.code&&(e.preventDefault(),e.stopImmediatePropagation())};addEventListener(`keydown`,H,!0),addEventListener(`keyup`,H,!0)})();globalThis.__stTabs=(()=>{try{return JSON.parse(localStorage.getItem(`d2s:sttabs`)||`null`)}catch{}})();try{globalThis.__stLay=localStorage.getItem(`d2s:stlay`)||`fill`,globalThis.__rowFill=localStorage.getItem(`d2s:prow`)===`1`}catch{}globalThis.__onS=' + $shortJs + ';globalThis.__onN=' + $labJs + ';globalThis.__onSave=()=>{try{localStorage.setItem(`d2s:on`,JSON.stringify({t:Date.now(),off:__off,cfg:__cfg}))}catch{}globalThis.__onDirty=1};globalThis.__onFx=()=>{let s=document.getElementById(`__hudcss`);s&&(s.disabled=!__on(`hud`));__on(`fps`)||document.getElementById(`__fps`)?.remove();let l=document.getElementById(`__lg`);l&&(l.style.display=__on(`log`)?``:`none`);__on(`speed`)||(globalThis.__spd=1);__on(`shard`)||document.getElementById(`__shd`)?.style.setProperty(`display`,`none`);try{globalThis.__brA?.()}catch{}document.querySelectorAll(`#__pbar span`).forEach(x=>{let m=/^[\u2713\u2717](.+)$/.exec(x.textContent),k=m&&__onL.find(k=>__onS[k]===m[1]);k&&(x.textContent=(__on(k)?`\u2713`:`\u2717`)+m[1],x.style.color=__on(k)?`#7e7`:`#f77`)})};globalThis.__onIn=(j,mt)=>{try{let L=JSON.parse(localStorage.getItem(`d2s:on`)||`null`);if(L&&L.t>=mt)return;let o={};for(let k of __onL)(j[k]===!1||j[k]==null&&globalThis.__off0?.[k])&&(o[k]=1);globalThis.__off=o;for(let k of[`delay`,`brightness`,`contrast`])j[k]!=null&&(__cfg[k]=+j[k]);j.automode&&(__cfg.automode=j.automode);globalThis.__br=__cfg.brightness/100,globalThis.__ct=__cfg.contrast/100,localStorage.setItem(`d2s:on`,JSON.stringify({t:mt,off:o,cfg:__cfg})),__onFx(),globalThis.__onR?.()}catch{}};globalThis.__onDump=()=>{if(!globalThis.__onDirty)return null;globalThis.__onDirty=0;let r={...__cfg};for(let k of __onL)r[k]=!__off[k];return JSON.stringify(r)};(()=>{let W=(n,k,d)=>{let f=globalThis[n];typeof f==`function`&&(globalThis[n]=(...a)=>__on(k)?f(...a):typeof d==`function`?d(f,a):d)};W(`__twins`,`twins`,null),W(`__hid`,`hidden`,[]),W(`__lg`,`log`),W(`__sw`,`swpop`),W(`__dsnd`,`dropsnd`),W(`__stT`,`stats`),W(`__f2t`,`f2tip`,[]),W(`__fpsT`,`fps`),W(`__cd`,`auto`),W(`__shd`,`shard`,()=>document.getElementById(`__shd`)?.style.setProperty(`display`,`none`)),W(`__spdS`,`speed`,(f,a)=>(globalThis.__spd=1,f(...a))),W(`__afkT`,`afk`,(f,a)=>globalThis.__afk?f(...a):void 0)})();setTimeout(()=>globalThis.__onFx(),4e3);globalThis.__onT=()=>{let o=document.getElementById(`__onw`);if(o)return o.remove(),globalThis.__onR=null;o=document.createElement(`div`),o.id=`__onw`,o.style.cssText=`position:fixed;left:50%;top:6%;transform:translateX(-50%);z-index:9999;background:rgba(10,8,6,.97);border:1px solid #8a6d3b;color:#ccc;font:15px sans-serif;max-height:86vh;overflow:auto;min-width:460px`;let R=()=>{o.innerHTML=`<div style="position:sticky;top:0;background:#0d0a07;padding:10px 16px;border-bottom:1px solid #4a3a20;display:flex;justify-content:space-between;gap:24px"><b style="color:#fc6;font-size:18px">' + (T '기능 켜기 · 끄기' 'Features on · off') + '</b><span style="color:#888">' + (T 'F5 닫기 · 바로 적용 · 패치 창과 연동' 'F5 close · applies now · synced with patch window') + '</span></div><div style="padding:6px 16px 12px">`+__onL.map(k=>`<label style="display:block;margin:5px 0;cursor:pointer"><input type=checkbox data-k=${k} ${__on(k)?`checked`:``}> ${__onN[k]}</label>`).join(``)+`</div><div style=\"padding:8px 16px 12px;border-top:1px solid #4a3a20\"><div style=\"color:#fc6;font-weight:bold;margin-bottom:4px\">' + (T '조절값' 'Settings') + '</div><label style=\"display:flex;justify-content:space-between;align-items:center;gap:16px;margin:5px 0\">' + (T '클리어 후 자동 진행' 'After clear') + '<select data-c=automode style=\"background:#111;color:#fc6;border:1px solid #555\"><option value=same ${__cfg.automode===`same`?`selected`:``}>' + (T '같은 단계 계속 반복' 'Repeat same tier') + '</option><option value=next ${__cfg.automode===`next`?`selected`:``}>' + (T '한 단계씩 올라가기' 'Go up one tier') + '</option></select></label><label style=\"display:flex;justify-content:space-between;align-items:center;gap:16px;margin:5px 0\">' + (T '자동 진행 대기 (초)' 'Auto-continue delay (s)') + '<input type=number data-c=delay min=1 max=60 step=1 value=${__cfg.delay} style=\"width:70px;background:#111;color:#fc6;border:1px solid #555\"></label><label style=\"display:flex;justify-content:space-between;align-items:center;gap:16px;margin:5px 0\">' + (T '기본 밝기 (%)' 'Brightness (%)') + '<input type=number data-c=brightness min=50 max=200 step=5 value=${__cfg.brightness} style=\"width:70px;background:#111;color:#fc6;border:1px solid #555\"></label><label style=\"display:flex;justify-content:space-between;align-items:center;gap:16px;margin:5px 0\">' + (T '기본 명암 (%)' 'Contrast (%)') + '<input type=number data-c=contrast min=50 max=200 step=5 value=${__cfg.contrast} style=\"width:70px;background:#111;color:#fc6;border:1px solid #555\"></label></div><div style="padding:8px 16px 12px;border-top:1px solid #4a3a20"><div style="color:#fc6;font-weight:bold;margin-bottom:4px">' + (T '창고 정리' 'Sort stash') + ' <span style="color:#888;font-weight:normal">' + (T '(창고를 연 채로 눌러도 됨)' '(works with the stash open)') + '</span></div><div>${[`personal`,`shared1`,`shared2`,`shared3`].map((k,i)=>`<label style="margin-right:12px"><input type=checkbox data-st=${k} ${(globalThis.__stTabs??[`shared1`,`shared2`,`shared3`]).includes(k)?`checked`:``}> ${[`' + (T '개인' 'Personal') + '`,`' + (T '공유 1' 'Shared 1') + '`,`' + (T '공유 2' 'Shared 2') + '`,`' + (T '공유 3' 'Shared 3') + '`][i]}</label>`).join(``)}</div><div style="margin-top:6px">' + (T '배치' 'Layout') + ': ${[[`fill`,`' + (T '앞 탭부터 채우기' 'Fill from first tab') + '`],[`kind`,`' + (T '종류별로 탭 나누기 (무기 · 방어구 · 장신구 · 부적 · 기타)' 'One kind per tab (weapon/armor/jewelry/charm/other)') + '`],[`each`,`' + (T '탭마다 따로 정리 (탭 사이 이동 없음)' 'Each tab on its own (no moving between tabs)') + '`]].map(([k,l])=>`<label style="margin-right:12px"><input type=radio name=__stlay data-lay=${k} ${(globalThis.__stLay??`fill`)===k?`checked`:``}> ${l}</label>`).join(``)}</div><div style="margin-top:4px"><label><input type=checkbox data-prow ${globalThis.__rowFill?`checked`:``}> ' + (T '창고에 넣을 때 가로로 채우기 (오른쪽으로 채우고 줄이 차면 다음 줄 왼쪽부터 · Ctrl+클릭 · 자동 보관 · 정리 모두 적용)' 'Fill stash rows first (left to right, then next row · Ctrl+click, auto stash and sort)') + '</label></div><div style="margin-top:6px;display:flex;gap:6px;flex-wrap:wrap"><button data-sort=kind style="background:#2a2015;color:#fc6;border:1px solid #8a6d3b;padding:3px 10px;cursor:pointer">' + (T '종류별' 'By type') + '</button><button data-sort=name style="background:#2a2015;color:#fc6;border:1px solid #8a6d3b;padding:3px 10px;cursor:pointer">' + (T '같은 아이템끼리' 'Same items together') + '</button><button data-sort=rarity style="background:#2a2015;color:#fc6;border:1px solid #8a6d3b;padding:3px 10px;cursor:pointer">' + (T '등급별' 'By rarity') + '</button><button data-sort=size style="background:#2a2015;color:#fc6;border:1px solid #8a6d3b;padding:3px 10px;cursor:pointer">' + (T '크기순 (빈칸 최소)' 'By size (fewest gaps)') + '</button><button data-sort=undo style="background:#2a2015;color:#8ef;border:1px solid #8a6d3b;padding:3px 10px;cursor:pointer">' + (T '되돌리기' 'Undo') + '</button></div><div id=__stmsg style="color:#8e8;margin-top:4px"></div></div><div style="padding:8px 16px 12px;border-top:1px solid #4a3a20"><div style="color:#fc6;font-weight:bold;margin-bottom:4px">' + (T '단축키' 'Hotkeys') + ' <span style="color:#888;font-weight:normal">' + (T '(누르고 새 키 입력 · Delete 원래대로 · Esc 취소)' '(click, press a key · Delete resets · Esc cancels)') + '</span></div>${[[`F1`,`' + (T '획득 · 판매 통계' 'Loot stats') + '`],[`F2`,`' + (T '보관 설정' 'Keep settings') + '`],[`F3`,`' + (T '드롭 확률' 'Drop odds') + '`],[`F4`,`' + (T '룬워드 목록' 'Runewords') + '`],[`F5`,`' + (T '기능 · 설정' 'Features') + '`],[`F6`,`' + (T '설명서' 'Guide') + '`],[`F7`,`' + (T '배속' 'Speed') + '`],[`F8`,`' + (T 'AFK 모드' 'AFK mode') + '`],[`F9`,`' + (T 'FPS 표시' 'FPS') + '`],[`F10`,`' + (T '패치 기록' 'Patch log') + '`],[`KeyB`,`' + (T '창고 열기' 'Open stash') + '`]].map(([c,l])=>`<label style="display:flex;justify-content:space-between;align-items:center;gap:16px;margin:3px 0">${l}<button data-key=${c} style="min-width:90px;background:#2a2015;color:${__keys[c]&&__keys[c]!==c?`#8ef`:`#fc6`};border:1px solid #8a6d3b;padding:2px 8px;cursor:pointer">${__kn(__keys[c]||c)}</button></label>`).join(``)}</div>`};globalThis.__onR=R,R(),o.addEventListener(`keydown`,e=>e.code!==`F5`&&e.stopPropagation()),o.onclick=e=>{let q=e.target.dataset?.key;if(q){let b=e.target;b.textContent=`' + (T '키 입력…' 'press a key…') + '`,globalThis.__kcap=1;let f=x=>{x.preventDefault(),x.stopImmediatePropagation(),removeEventListener(`keydown`,f,!0),globalThis.__kcap=0;let u=null;if(x.code!==`Escape`){let v=x.code===`Delete`||x.code===`Backspace`?q:x.code;u=Object.keys(__keys).find(d=>d!==q&&(__keys[d]||d)===v)||(v!==q&&!__keys[v]&&[[`F1`,`' + (T '획득 · 판매 통계' 'Loot stats') + '`],[`F2`,`' + (T '보관 설정' 'Keep settings') + '`],[`F3`,`' + (T '드롭 확률' 'Drop odds') + '`],[`F4`,`' + (T '룬워드 목록' 'Runewords') + '`],[`F5`,`' + (T '기능 · 설정' 'Features') + '`],[`F6`,`' + (T '설명서' 'Guide') + '`],[`F7`,`' + (T '배속' 'Speed') + '`],[`F8`,`' + (T 'AFK 모드' 'AFK mode') + '`],[`F9`,`' + (T 'FPS 표시' 'FPS') + '`],[`F10`,`' + (T '패치 기록' 'Patch log') + '`],[`KeyB`,`' + (T '창고 열기' 'Open stash') + '`]].some(([c])=>c===v)?v:null);if(u)b.textContent=`' + (T '이미 사용 중' 'in use') + ': ${__kn(v)}`;else{v===q?delete __keys[q]:__keys[q]=v;try{localStorage.setItem(`d2s:pkeys`,JSON.stringify(__keys))}catch{}__krB()}}setTimeout(()=>globalThis.__onR?.(),u?900:0)};addEventListener(`keydown`,f,!0);return}let m=e.target.dataset?.sort;if(!m)return;let ks=[...o.querySelectorAll(`[data-st]:checked`)].map(x=>x.dataset.st);globalThis.__stTabs=ks;try{localStorage.setItem(`d2s:sttabs`,JSON.stringify(ks))}catch{}o.querySelector(`#__stmsg`).textContent=globalThis.__sortStash(m,ks)},o.onchange=e=>{let k=e.target.dataset?.k,c=e.target.dataset?.c,y=e.target.dataset?.lay;y&&(globalThis.__stLay=y);e.target.dataset?.prow!=null&&(globalThis.__rowFill=e.target.checked);try{y&&localStorage.setItem(`d2s:stlay`,y),e.target.dataset?.prow!=null&&localStorage.setItem(`d2s:prow`,e.target.checked?`1`:`0`)}catch{}k&&(e.target.checked?delete __off[k]:__off[k]=1,__onSave(),__onFx());c&&(__cfg[c]=c===`automode`?e.target.value:Math.max(+e.target.min,Math.min(+e.target.max,+e.target.value||+e.target.min)),c===`brightness`&&(globalThis.__br=__cfg.brightness/100),c===`contrast`&&(globalThis.__ct=__cfg.contrast/100),__onSave(),__onFx())},document.body.append(o)};document.addEventListener(`keydown`,e=>{e.code===`F5`&&(e.preventDefault(),e.stopPropagation(),globalThis.__onT())},!0);'
$gameBytes = $utf8.GetBytes($game)
$keepBytes = $utf8.GetBytes($keepText)
$uiBytes = $utf8.GetBytes($uiText)
$langBytes = $utf8.GetBytes($langText)
$dataLen = $bytes.Length - $dataStart
$header = $header.Replace($gameEntry.Value, (NewEntry $gameEntry $gameBytes $dataLen))
$header = $header.Replace($keepEntry.Value, (NewEntry $keepEntry $keepBytes ($dataLen + $gameBytes.Length)))
$header = $header.Replace($uiEntry.Value, (NewEntry $uiEntry $uiBytes ($dataLen + $gameBytes.Length + $keepBytes.Length)))
$header = $header.Replace($langEntry.Value, (NewEntry $langEntry $langBytes ($dataLen + $gameBytes.Length + $keepBytes.Length + $uiBytes.Length)))
# AFK 모드용: 창을 최소화/숨겨도 게임 속도를 늦추지 않게 main.cjs의 throttle 두 줄 제거
$mainBytes = New-Object byte[] 0
$mm = [regex]::Matches($header, '"(main\.cjs)":\{"size":(\d+),"offset":"(\d+)","integrity":\{[^{}]*\}\}')
if ($mm.Count -ne 1) { Fail (T '이 게임 버전은 지원하지 않습니다 (main.cjs).' 'This game version is not supported (main.cjs).') }
$mainText = ReadFile $mm[0]
if ($O.afk) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
$throttle = 'win\.on\("(minimize|hide)", throttle\(true\)\);'
if ([regex]::Matches($mainText, $throttle).Count -ne 2) { Fail (T '이 게임 버전은 지원하지 않습니다 (throttle).' 'This game version is not supported (throttle).') }
$mainText = [regex]::Replace($mainText, $throttle, '')
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'afk' } }
# 패치된 게임은 순위표에 아무것도 보내지 않는다: 모든 POST를 보낸 것처럼(200) 처리하고 대기열에서 지운다 (조회 GET은 그대로)
$mainText = Swap $mainText 'if (method === "POST" && (typeof body !== "string" || body.length > MAX_BODY3)) return { status: 413, body: null };' ('if (method === "POST" && (typeof body !== "string" || body.length > MAX_BODY3)) return { status: 413, body: null };' + "`n    " + 'if (method === "POST") return { status: 200, body: "{}", retryAfter: null };') 'no send'
# 게임 안 업데이트 알림용: 이 패치 저장소의 파일만 인터넷 접근 허용 (게임은 원래 외부 접속을 모두 막음)
$mainText = Swap $mainText 'const own = /^(app|devtools|data|blob):/.test(details.url);' ('const own = /^(app|devtools|data|blob):/.test(details.url) || details.url.startsWith("' + $raw + '/");' + $(if ($env:D2SF) { 'if (details.url === "https://d2s-update.invalid/run") { require("child_process").spawn("cmd.exe", ["/c", "start", "\"\"", "\"" + ' + ($env:D2SF | ConvertTo-Json) + ' + "\""], { detached: true, stdio: "ignore", windowsVerbatimArguments: true, env: { ...process.env, D2S_RELAUNCH: "1" } }).unref(); setTimeout(() => import_electron4.app.quit(), 300); }' })) 'update allow'
# 보관 설정 동기화: 5초마다 keep.json 을 게임에 넘겨 주고(더 최신이면 게임이 받음), 바뀐 설정과 메뉴 목록을 파일로 저장 (패치 GUI 의 보관 설정 탭이 읽고 씀)
$mainText += ';(() => { const fs = require("fs"), path = require("path"), dir = path.join(process.env.APPDATA || "", "D2S-MyPatch"), kf = path.join(dir, "keep.json"), mf = path.join(dir, "keep-meta.json"), of = path.join(dir, "options.json"); const { webContents } = require("electron"); setInterval(() => { let j = null; try { j = fs.readFileSync(kf, "utf8").replace(/^\uFEFF/, ""); JSON.parse(j); } catch { j = null; } let oj = null, om = 0; try { oj = fs.readFileSync(of, "utf8").replace(/^\uFEFF/, ""); JSON.parse(oj); om = fs.statSync(of).mtimeMs; } catch { oj = null; } for (const w of webContents.getAllWebContents()) { oj && w.executeJavaScript("globalThis.__onIn && globalThis.__onIn(" + oj + "," + om + ")").catch(() => {}); w.executeJavaScript("globalThis.__onDump ? globalThis.__onDump() : null").then((r) => { if (!r) return; let o = {}; try { o = JSON.parse(fs.readFileSync(of, "utf8").replace(/^\uFEFF/, "")); } catch {} Object.assign(o, JSON.parse(r)); fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(of, JSON.stringify(o, null, 1)); }).catch(() => {}); j && w.executeJavaScript("globalThis.__ksIn && globalThis.__ksIn(" + j + ")").catch(() => {}); w.executeJavaScript("globalThis.__ksDump ? globalThis.__ksDump() : null").then((r) => { if (!r) return; const o = JSON.parse(r); fs.mkdirSync(dir, { recursive: true }); o.keep && fs.writeFileSync(kf, JSON.stringify(o.keep)); o.meta && fs.writeFileSync(mf, JSON.stringify(o.meta)); }).catch(() => {}); } }, 5e3); })();'
# 게임 본체에서 3분마다 GitHub API로 버전 확인 (IP당 1시간 60회 한도 → 20회 사용), 실패하면 raw 주소(몇 분 늦음). 새 버전이면 화면의 __updShow 호출
$mainText += ';(() => { const https = require("https"); const get = (host, path, headers, done) => https.get({ host, path, headers: { "User-Agent": "D2S-MyPatch", ...headers } }, (r) => { let b = ""; r.setEncoding("utf8"); r.on("data", (d) => b += d); r.on("end", () => done(r.statusCode === 200 ? b : null)); }).on("error", () => done(null)); const show = (b) => { if (!b || !(+b.split(/\r?\n/)[0] > ' + $Ver + ')) return; for (const w of require("electron").webContents.getAllWebContents()) w.executeJavaScript("globalThis.__updShow && globalThis.__updShow(" + JSON.stringify(b) + ")").catch(() => {}); }; const check = () => get("api.github.com", "/repos/' + $Repo + '/contents/version.txt", { Accept: "application/vnd.github.raw" }, (b) => b ? show(b) : get("raw.githubusercontent.com", "/' + $Repo + '/main/version.txt", {}, show)); setTimeout(check, 15e3); setInterval(check, 18e4); })();'
# 세이브 자동 백업: 켜고 1분 뒤 + 30분마다, save.json 이 바뀌었으면 %APPDATA%\D2S-MyPatch\backup 에 복사 (최근 48개). 복원은 게임 설정의 저장 데이터 가져오기
$mainText += ';(() => { const fs = require("fs"), path = require("path"), src = path.join(require("electron").app.getPath("userData"), "save", "save.json"), dir = path.join(process.env.APPDATA || "", "D2S-MyPatch", "backup"); let last = ""; const run = () => { try { const t = fs.readFileSync(src, "utf8"); if (t === last) return; last = t; fs.mkdirSync(dir, { recursive: true }); const d = new Date(), p = (n) => String(n).padStart(2, "0"); fs.writeFileSync(path.join(dir, "save-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "-" + p(d.getHours()) + p(d.getMinutes()) + ".json"), t); const f = fs.readdirSync(dir).filter((x) => /^save-\d{8}-\d{4}\.json$/.test(x)).sort(); for (const x of f.slice(0, -48)) fs.unlinkSync(path.join(dir, x)); } catch {} }; setTimeout(run, 6e4); setInterval(run, 18e5); })();'
$mainBytes = $utf8.GetBytes($mainText)
$header = $header.Replace($mm[0].Value, (NewEntry $mm[0] $mainBytes ($dataLen + $gameBytes.Length + $keepBytes.Length + $uiBytes.Length + $langBytes.Length)))
# 패치 폴더에 kodia.ttf가 있으면 게임 한글 폰트 두 개(fonts-ko/kodia.woff2, irisl.woff2)를 모두 그 파일로 바꾼다
$fontBytes = New-Object byte[] 0
$fontFile = Join-Path $__root 'kodia.ttf'
if ($O.font) {
$snap = @($game, $keepText, $uiText, $mainText, $langText, $header); try {
    $ttf = [IO.File]::ReadAllBytes($fontFile)
    $fontOut = New-Object IO.MemoryStream
    foreach ($fn in 'kodia', 'irisl') {
        $fm = [regex]::Matches($header, '"(' + $fn + '\.woff2)":\{"size":(\d+),"offset":"(\d+)","integrity":\{[^{}]*\}\}')
        if ($fm.Count -eq 1) {
            $header = $header.Replace($fm[0].Value, (NewEntry $fm[0] $ttf ($dataLen + $gameBytes.Length + $keepBytes.Length + $uiBytes.Length + $langBytes.Length + $mainBytes.Length + $fontOut.Length)))
            $fontOut.Write($ttf, 0, $ttf.Length)
        }
    }
    $fontBytes = $fontOut.ToArray()
} catch { if ("$_" -notlike 'D2SUNSUP*') { throw }; $game, $keepText, $uiText, $mainText, $langText, $header = $snap; $bad += 'font' } }

} catch { if ("$_" -like 'D2SUNSUP*') { Fail ((T '이 게임 버전은 지원하지 않습니다. 필수 부분이 바뀌어 패치하지 않았습니다' 'This game version is not supported. A required part changed, nothing was patched') + " (" + "$_".Substring(9) + ')') } else { throw } }

$json = $utf8.GetBytes($header)
$payload = (4 + $json.Length + 3) -band -bnot 3
$out = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter($out)
$w.Write([uint32]4); $w.Write([uint32]($payload + 4)); $w.Write([uint32]$payload); $w.Write([uint32]$json.Length)
$w.Write($json)
$w.Write((New-Object byte[] ($payload - 4 - $json.Length)))
$w.Write($bytes, $dataStart, $dataLen)
$w.Write($gameBytes); $w.Write($keepBytes); $w.Write($uiBytes); $w.Write($langBytes); $w.Write($mainBytes); $w.Write($fontBytes)
$w.Flush()

if (-not $fromBackup) { Copy-Item $asar $backup -Force }
[IO.File]::WriteAllBytes($asar, $out.ToArray())
try { @{ t = (Get-Date).ToString('yyyy-MM-dd HH:mm'); ver = $Ver; build = $build; on = @($feat.Keys | Where-Object { $On[$_] }).Count; all = $feat.Count; bad = @($bad | ForEach-Object { $feat[$_] }) } | ConvertTo-Json | Set-Content (Join-Path (Split-Path $optFile) 'last.json') -Encoding UTF8 } catch {}
Write-Host (T '  [OK] 패치 완료. 게임을 실행하세요.' '  [OK] Patched. Start the game.') -ForegroundColor Green
Write-Host "  $applied"
# 패치가 끝나면 게임을 바로 켠다 (explorer로 켜야 게임 로그가 이 창에 안 찍힘)
if (($env:D2S_RELAUNCH -or $gui) -and $bad.Count) { [void](Msg ((T '이 게임 버전에서 안 되는 기능 (패치 수정 필요): ' 'Not working on this game version: ') + (($bad | ForEach-Object { $feat[$_] }) -join ', ')) 'Warning') }
if ($env:D2S_RELAUNCH -or $gui) { Start-Process explorer.exe ('"' + (Join-Path $GameDir 'D2 Survivors.exe') + '"') }
Done 0
