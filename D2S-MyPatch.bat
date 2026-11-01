@echo off
set "D2SF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$__root=Split-Path $env:D2SF; $s=[IO.File]::ReadAllText($env:D2SF,[Text.Encoding]::UTF8); & ([scriptblock]::Create($s.Substring($s.IndexOf('#PS'+'START'))))"
echo.
pause
exit /b
#PSSTART
# D2 Survivors 편의 패치: 자동 습득·등록·교체·판매, 비교 표시, 자동 반복, AFK 모드, 창고 단축키, 순위표 전송 차단, 폰트 교체
param([string]$Lang, [string]$Action, [string]$GameDir)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

if (-not $Lang) {
    Write-Host ''
    Write-Host '  1. 한국어'
    Write-Host '  2. English'
    $Lang = if ((Read-Host '  언어 / Language') -eq '2') { 'en' } else { 'ko' }
}
$ko = $Lang -ne 'en'
function T($k, $e) { if ($ko) { $k } else { $e } }
function Fail($msg) { Write-Host ''; Write-Host "  [X] $msg" -ForegroundColor Red; exit 1 }

if (-not $GameDir) { $GameDir = Join-Path $env:LOCALAPPDATA 'Programs\D2 Survivors' }
$asar = Join-Path $GameDir 'resources\app.asar'
if (-not (Test-Path $asar)) {
    $GameDir = Read-Host (T '  게임 설치 폴더를 입력하세요 (D2 Survivors.exe가 있는 폴더)' '  Enter the game folder (the one with D2 Survivors.exe)')
    $asar = Join-Path $GameDir.Trim('"') 'resources\app.asar'
    if (-not (Test-Path $asar)) { Fail (T "app.asar를 찾을 수 없습니다: $asar" "app.asar not found: $asar") }
}
$backup = "$asar.orig"

# 업데이트 확인: GitHub의 version.txt가 더 크면 새 bat를 받아 자기 자신을 바꾸고 다시 실행
$Ver = 2
$Repo = 'mastree-master/D2S-MyPatch'
$raw = "https://raw.githubusercontent.com/$Repo/main"
try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    $wc = New-Object Net.WebClient
    $nv = [int]$wc.DownloadString("$raw/version.txt?" + [DateTime]::Now.Ticks).Trim()
} catch { $nv = 0 }
if ($nv -gt $Ver -and $env:D2SF) {
    Write-Host ''
    Write-Host (T "  새 버전(v$nv)이 있습니다. 지금 버전 v$Ver" "  New version (v$nv) available. Current v$Ver") -ForegroundColor Cyan
    if ((Read-Host (T '  업데이트할까요? (y/n)' '  Update now? (y/n)')) -eq 'y') {
        $nb = $wc.DownloadData("$raw/D2S-MyPatch.bat?" + [DateTime]::Now.Ticks)
        $ns = [Text.Encoding]::UTF8.GetString($nb)
        if (-not $ns.Contains('#PS' + 'START')) { Fail (T '받은 파일이 올바르지 않습니다.' 'Downloaded file is invalid.') }
        [IO.File]::WriteAllBytes($env:D2SF, $nb)
        Write-Host (T '  업데이트 완료. 새 버전으로 다시 실행합니다.' '  Updated. Restarting with new version.') -ForegroundColor Green
        & ([scriptblock]::Create($ns.Substring($ns.IndexOf('#PS' + 'START')))) -Lang $Lang -Action $Action -GameDir $GameDir
        exit
    }
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
$keepEntry = Entry 'moved'
$uiEntry = Entry 'saveTransfer'
$game = ReadFile $gameEntry
$patched = $game.Contains('isNew:e=>')
if (-not $Action) {
    Write-Host ''
    if ($patched) {
        Write-Host (T '  현재: 패치 상태입니다.' '  Current: patched.') -ForegroundColor Yellow
        $Action = 'restore'; $q = T '  원본으로 복구할까요? (y/n)' '  Restore original? (y/n)'
    } else {
        Write-Host (T '  현재: 원본 상태입니다.' '  Current: original.') -ForegroundColor Yellow
        $Action = 'patch'; $q = T '  패치를 적용할까요? (y/n)' '  Apply patch? (y/n)'
    }
    if ((Read-Host $q) -ne 'y') { Write-Host (T '  취소했습니다.' '  Cancelled.'); exit 0 }
}

if ($Action -eq 'restore') {
    if (-not $patched) { Fail (T '패치가 적용되어 있지 않습니다. 복구할 것이 없습니다.' 'The patch is not applied. Nothing to restore.') }
    if (-not (Test-Path $backup)) { Fail (T "백업 파일이 없습니다: $backup" "Backup not found: $backup") }
    Copy-Item $backup $asar -Force
    Write-Host ''
    Write-Host (T '  [OK] 원래대로 복구했습니다.' '  [OK] Original restored.') -ForegroundColor Green
    exit 0
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
    $keepEntry = Entry 'moved'
    $uiEntry = Entry 'saveTransfer'
    $game = ReadFile $gameEntry
    $fromBackup = $true
}

# --- 축약된 함수 이름은 버전마다 바뀌므로 주변 코드로 찾아낸다 ---
$id = '[\w$]+'
function Find($text, $pattern, $what) {
    $m = [regex]::Matches($text, $pattern)
    if ($m.Count -ne 1) { Fail (T "이 게임 버전은 지원하지 않습니다 ($what)." "This game version is not supported ($what).") }
    $m[0]
}
function Swap($text, $old, $new, $what) {
    $i = $text.IndexOf($old)
    if ($i -lt 0 -or $i -ne $text.LastIndexOf($old)) { Fail (T "이 게임 버전은 지원하지 않습니다 ($what)." "This game version is not supported ($what).") }
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
$game = Swap $game "let t=this.inventoryOf(this.world.player.cls),n=$fit(t,e,$igrid);if(!n)return!1;" "let t=this.inventoryOf(this.world.player.cls),n=$fit(t,e,$igrid);if(!n){for(let k of $tabs){let a=$tab(this.save,this.world.player.cls,k),p=$fit(a,e,$sgrid);if(p)return $put(a,e,p),$save(this.save),globalThis.__st=1,!0}return!1}" 'stash overflow'
# 창고 창이 닫혀 있어도 인벤토리에서 Ctrl+클릭하면 개인 → 공용 창고 빈자리로 보낸다
$game = Swap $game '...n&&{toStash:n=>{' ("__toStash:n=>{let a=s();if(!a.includes(n))return;for(let k of $tabs){let b=$tab(i,e,k),p=$fit(b,n,$sgrid);if(p)return r.change(()=>{$rm(a,n),$put(b,n,p)}),this.moved(n),t()}this.hud.refuse(``" + (T '창고가 가득 찼습니다' 'Stash is full') + "``)},...n&&{toStash:n=>{") 'ctrl stash'
$uiText = ReadFile $uiEntry
$uiText = Swap $uiText 'function I_(e){if(!e||e.done)return``;' 'function I_(e){globalThis.__wave=e;if(!e||e.done)return``;' 'afk wave'
$uiText = Swap $uiText 'click:r=>{r.shiftKey?n.sell(e.item):o&&(r.ctrlKey||r.metaKey)?' 'click:r=>{!o&&(r.ctrlKey||r.metaKey)&&n.__toStash?n.__toStash(e.item):r.shiftKey?n.sell(e.item):o&&(r.ctrlKey||r.metaKey)?' 'ctrl click'
# 런 도중 캐릭터/인벤토리/스킬/퀘스트 창을 열어도 게임이 멈추지 않고 계속 진행 (Esc 일시정지는 그대로)
$game = Swap $game 'let i=this.state===`playing`&&this.strayPlay();for(let e=0;e<I.speed*t&&i&&this.state===`playing`&&!r;e++)' 'let __lv=()=>this.state===`playing`||this.state===`character`&&this.characterReturn===`playing`&&!this.camp,i=__lv()&&this.strayPlay();for(let e=0;e<I.speed*t&&i&&__lv();e++)' 'live panels'
$game = Swap $game 'this.state===`character`&&qt(this.world,' 'this.state===`character`&&this.characterReturn!==`playing`&&qt(this.world,' 'live panels idle'
# 툴팁 옆 게임 비교 상자: 같은 이름·같은 종류만, 등록/개인 창고/공용 창고 1~3/인벤 위치와 좋고 나쁨 표시 (최대 3개)
$game = "globalThis.__twins=e=>{let g=globalThis.__gm;if(!g||!/^(unique|set|runeword)`$/.test(e.rarity))return null;let c=g.kit?.id,K=__kd(e),m=x=>x!==e&&x.rarity===e.rarity&&x.name===e.name&&__kd(x)===K,v=x=>__gt(x,e)?``$(T '▲ 보관본이 더 좋음' '▲ stored is better')``:__gt(e,x)?``$(T '▼ 보관본이 더 나쁨' '▼ stored is worse')``:``$(T '= 같음' '= same')``,q=x=>__gt(x,e)?``better``:__gt(e,x)?``worse``:``equipped``,r=[];for(let x of g.save.uniques??[])m(x)&&r.push({label:``$(T '등록' 'Stashed') · ``+v(x),item:x,cls:q(x)});for(let k of $tabs)for(let x of $tab(g.save,c,k))m(x)&&r.push({label:({personal:``$(T '개인 창고' 'Personal')``,shared1:``$(T '공용 창고 1' 'Shared 1')``,shared2:``$(T '공용 창고 2' 'Shared 2')``,shared3:``$(T '공용 창고 3' 'Shared 3')``}[k]??k)+`` · ``+v(x),item:x,cls:q(x)});for(let x of g.inventoryOf(c))m(x)&&r.push({label:``$(T '인벤' 'Inventory') · ``+v(x),item:x,cls:q(x)});return r.slice(0,3)};" + $game
$uiText = Swap $uiText 'c=[...o?[{label:xt,item:o}]:[],' 'c=[...(globalThis.__twins?.(e)?.slice(0,Math.max(1,3-(s?a.length:0)))??(o?[{label:xt,item:o}]:[])),' 'twin boxes'
$uiText = Swap $uiText 'e.replaceChildren(R(`equipped`,c[t].label),' 'e.replaceChildren(R(c[t].cls??`equipped`,c[t].label),' 'twin colors'
$uiText = Swap $uiText ',!n)return el(this.node);$c(e,this.node,t,' ',!n&&!globalThis.__twins?.(e)?.length)return el(this.node);$c(e,this.node,t,' 'twin equipped'
# 툴팁 맨 아래에 화면에 안 나오는 숨겨진 값 표시 (비교 계산에는 넣지 않음)
$game = "globalThis.__hid=e=>(e.stats??[]).flatMap(b=>b.stat===``coldlength``?[``$(T '숨겨진 값' 'Hidden'): $(T '냉기 지속 시간' 'cold duration') ``+(b.value/25).toFixed(1)+``$(T '초' 's')``]:b.stat===``item_extrablood``?[``$(T '숨겨진 값' 'Hidden'): $(T '피 튀김 효과 증가' 'extra blood') ``+b.value]:b.stat===``maxdurability``?[``$(T '숨겨진 값' 'Hidden'): $(T '최대 내구도' 'max durability') ``+b.value]:[]);" + $game
$uiText = Swap $uiText 'function Uc(e,t,n=Di(I.held||I.tapped)){let r=' 'function Uc(e,...a){return[...Uc0(e,...a),...(globalThis.__hid?.(e)??[]).map(t=>R(`inert`,t))]}function Uc0(e,t,n=Di(I.held||I.tapped)){let r=' 'hidden stats'
# 미등록 유니크/세트/룬워드는 보관함에 등록. 스킬 옵션 합 > 오라·발동 기술 레벨 합 > 그 외 옵션 합 > 방어력 옵션 합 순서로 비교해 높으면 교체하고
# 밀려난 옛 아이템은 룬워드면 인벤토리, 아니면 판매. 중복 룬워드는 인벤토리로 (아래 일반 경로)
$game = Swap $game 'carry(e){let t=this.inventoryOf' "carry(e){if($canKeep(this.save,e))return $keep(this.save,e),$save(this.save),$sound(e.base),this.hud.banner($name(e.name,e.rarity,e.base)+``$suffix``,e.rarity),!0;if(!this.__nx){let o=__bt(this.save,e)&&$swap(this.save,e);if(o)return $save(this.save),$sound(e.base),this.hud.banner($name(e.name,e.rarity,e.base)+``$swapped``,e.rarity),__sw($name(e.name,e.rarity,e.base),o,e),globalThis.__swu=o.rarity===``runeword``?null:()=>{let s=this.save.uniques,i=s?.indexOf(e)??-1;if(i<0||!this.world)return!1;s[i]=o;this.world.gold-=$price(this.save,this.world.player.cls,o);$save(this.save);this.autoSell(e);return!0},o.rarity===``runeword``?(this.__nx=1,this.carry(o)||this.autoSell(o),this.__nx=0):this.autoSell(o),!0}if(e.rarity===``runeword``){let K=__kd(e),A=[this.inventoryOf(this.world.player.cls),...$tabs.map(k=>$tab(this.save,this.world.player.cls,k))],C=A.flatMap(a=>a.filter(x=>x!==e&&x.rarity===``runeword``&&x.name===e.name&&__kd(x)===K).map(x=>[a,x]));let g=this.save.uniques?.find(x=>x!==e&&x.rarity===``runeword``&&x.name===e.name),h=/1`$/.test(K),L=g&&__kd(g)===K?+h:h?2:1;if(!L)return this.autoSell(e),globalThis.__st=2,!0;if(C.length>=L){let w=C.reduce((m,c)=>__gt(m[1],c[1])?c:m);if(!__gt(e,w[1]))return this.autoSell(e),globalThis.__st=2,!0;$rm(w[0],w[1]),this.autoSell(w[1])}}let t=this.inventoryOf" 'carry'
# 주운 아이템을 화면 왼쪽 목록에 표시 (금색: 등록, 하늘색: 교체, 흰색: 인벤토리). 최근 15개
$tags = '[`[' + (T '인벤' 'bag') + '] `,`[' + (T '등록' 'stashed') + '] `,`[' + (T '교체' 'upgraded') + '] `,`[' + (T '창고' 'stash') + '] `,`[' + (T '판매' 'sold') + '] `]'
$game = 'globalThis.__sc=x=>{let r=[0,0,0,0];for(let b of x.stats??[]){let v=+b.value||0,s=b.stat;if(/^(coldlength|poisonlength|poisoncount|durability|maxdurability|item_extrablood)$/.test(s))continue;/^item_(allskills|addclassskills|addskill_tab|singleskill|nonclassskill|elemskill)$/.test(s)?r[0]+=v:s===`item_aura`?r[1]+=v:/^item_(skillon|charged_skill)/.test(s)?(r[1]+=+b.level||0,r[2]+=v):/^(item_armor|armorclass)/.test(s)?r[3]+=v:r[2]+=v}return r};globalThis.__gt=(x,y)=>{let a=__sc(x),b=__sc(y);for(let i=0;i<4;i++)if(a[i]!==b[i])return a[i]>b[i];return!1};globalThis.__bt=(s,e)=>{let u=s.uniques?.find(u=>u!==e&&u.rarity===e.rarity&&u.name===e.name);if(!u||e.rarity===`runeword`&&globalThis.__kd?.(u)!==globalThis.__kd?.(e))return!1;return __gt(e,u)};globalThis.__lg=(t,k,s)=>{let d=document.getElementById(`__lg`);d||(d=document.createElement(`div`),d.id=`__lg`,d.style.cssText=`position:fixed;left:8px;top:30%;z-index:9999;pointer-events:none;font:bold 16px sans-serif;line-height:1.35;text-shadow:0 0 3px #000,0 0 3px #000`,document.body.append(d));let l=document.createElement(`div`);l.style.color=[`#fff`,`#e8c060`,`#8cf`,`#c9a`,`#999`][k];l.textContent=' + $tags + '[k]+t+(s?` (`+s+`)`:``);k===2&&globalThis.__swh&&(l.__h=globalThis.__swh,globalThis.__swh=null,l.style.pointerEvents=`auto`,l.onpointerenter=()=>{let w=document.getElementById(`__sw`),r=l.getBoundingClientRect();w.innerHTML=l.__h;w.style.display=``;w.style.left=r.right+10+`px`;w.style.top=Math.max(4,Math.min(r.top,innerHeight-w.offsetHeight-4))+`px`;clearTimeout(w.__t)},l.onpointerleave=()=>{document.getElementById(`__sw`).style.display=`none`});k===2&&globalThis.__swu&&(()=>{let f=globalThis.__swu,b=document.createElement(`span`);globalThis.__swu=null;b.textContent=` [' + (T '되돌리기' 'Undo') + ']`;b.style.cssText=`color:#f96;cursor:pointer;pointer-events:auto`;b.onpointerdown=b.onmousedown=x=>{x.stopPropagation();x.preventDefault();f()?(l.style.textDecoration=`line-through`,b.textContent=` [' + (T '되돌림' 'Undone') + ']`,b.onpointerdown=b.onmousedown=null):b.textContent=` [' + (T '불가' 'Failed') + ']`};l.append(b)})();d.prepend(l);for(;d.children.length>15;)d.lastChild.remove()};' + $game
# 교체 창: 왼쪽 목록 옆에 이전/새 옵션 비교 (바뀐 줄만 색 표시), 20초 뒤 닫힘. 왼쪽 목록의 [교체] 줄에 마우스를 올리면 다시 표시
$game = 'globalThis.__sw=(n,o,e,l)=>{let d=document.getElementById(`__sw`);d||(d=document.createElement(`div`),d.id=`__sw`,d.style.cssText=`position:fixed;z-index:9999;pointer-events:none;font:15px sans-serif;line-height:1.35;background:#000d;border:1px solid #8cf;padding:8px 10px;max-width:460px;color:#ccc`,document.body.append(d));let a=globalThis.__tip?.(o)??[],b=globalThis.__tip?.(e)??[],h=(t,c)=>`<div style="color:${c}">${String(t).replace(/</g,`&lt;`)}</div>`;globalThis.__swh=d.innerHTML=h((l?.[0]??`[' + (T '교체' 'Upgraded') + '] `)+n,`#8cf`)+h(globalThis.__slot?.(e)??``,`#aaa`)+h(`' + (T '바뀐 옵션' 'Changes') + '`,`#fc6`)+a.map((t,i)=>t!==b[i]?h(`${t} → ${b[i]??`-`}`,`#fc6`):``).join(``)+h(`' + (T '옵션 총합' 'Total') + ': `+[o,e].map(x=>{let[s,u,a,c]=__sc(x);return`' + (T '스킬' 'skill') + ' ${s} / ' + (T '오라·발동' 'aura·proc') + ' ${u} / ${a} (' + (T '방어' 'def') + ' ${c})`}).join(` → `),`#fc6`)+h((l?.[1]??`' + (T '이전' 'Old') + '`)+`: `+n+` (`+(globalThis.__slot?.(o)??``)+`)`,`#e88`)+a.map(t=>h(t,b.includes(t)?`#888`:`#e88`)).join(``)+h((l?.[2]??`' + (T '새것' 'New') + '`)+`: `+n+` (`+(globalThis.__slot?.(e)??``)+`)`,`#8e8`)+b.map(t=>h(t,a.includes(t)?`#888`:`#8e8`)).join(``);d.style.display=``;requestAnimationFrame(()=>{let g=document.getElementById(`__lg`)?.getBoundingClientRect();d.style.left=(g?g.right:250)+10+`px`;d.style.top=Math.max(4,Math.min(g?g.top:innerHeight*.35,innerHeight-d.offsetHeight-4))+`px`});clearTimeout(d.__t);d.__t=setTimeout(()=>d.style.display=`none`,2e4)};' + $game
# 자동 진행 카운트다운 표시 (화면 위쪽 가운데)
$game = 'globalThis.__cdx=()=>{let d=document.getElementById(`__cd`);d&&(clearInterval(d.__i),d.remove())};globalThis.__cd=(s,t)=>{__cdx();let d=document.createElement(`div`),e=Date.now()+s*1e3;d.id=`__cd`;d.style.cssText=`position:fixed;left:50%;top:18%;transform:translateX(-50%);z-index:9999;pointer-events:none;font:bold 20px sans-serif;color:#e8c060;text-shadow:0 0 4px #000,0 0 4px #000`;document.body.append(d);let u=()=>{let r=Math.ceil((e-Date.now())/1e3);r<=0?__cdx():d.textContent=t.replace(`#`,r)};u();d.__i=setInterval(u,200)};' + $game
$game = Swap $game 'carry:e=>this.carry(e),' "carry:e=>{let k=$canKeep(this.save,e)?1:__bt(this.save,e)?2:0,r=(globalThis.__st=0,this.carry(e));globalThis.__st&&!k&&(k=globalThis.__st===2?4:3);let q=e.rarity===``runeword``&&k!==1&&k!==2&&this.save.uniques?.find(x=>x!==e&&x.rarity===e.rarity&&x.name===e.name);return r&&globalThis.__afk&&__afkAdd(k,e.rarity),r&&__lg($name(e.name,e.rarity,e.base),k,(globalThis.__slot?.(e)??````)+(q?`` → $(T '등록본' 'stashed'): ``+__slot(q):````)),r},isNew:e=>$canKeep(this.save,e)||__bt(this.save,e)||e.rarity===``runeword``," 'world'
# 인벤토리/창고 아이템에 마우스를 올리면 보관함 등록본과 비교 창을 아이템 옆에 띄운다 (유니크/세트/룬워드)
$game = "globalThis.__nm=e=>$name(e.name,e.rarity,e.base);" + 'globalThis.__cmp=(e,a)=>{let g=globalThis.__gm?.save;if(!g||!/^(unique|set|runeword)$/.test(e.rarity))return;let u=g.uniques?.find(x=>x!==e&&x.rarity===e.rarity&&x.name===e.name&&(e.rarity!==`runeword`||__kd(x)===__kd(e)));if(!u)return;let v=__gt(e,u)?`▲ ' + (T '더 좋음' 'better') + '`:__gt(u,e)?`▼ ' + (T '더 나쁨' 'worse') + '`:`= ' + (T '같음' 'same') + '`;__sw(__nm(e),u,e,[`[' + (T '등록본 비교' 'vs stashed') + ' ${v}] `,`' + (T '등록본' 'Stashed') + '`,`' + (T '이 아이템' 'This') + '`]);globalThis.__swh=null;let d=document.getElementById(`__sw`);clearTimeout(d.__t);requestAnimationFrame(()=>{let r=a.getBoundingClientRect(),x=r.left-d.offsetWidth-12;d.style.left=(x<4?r.right+12:x)+`px`;d.style.top=Math.max(4,Math.min(r.top,innerHeight-d.offsetHeight-4))+`px`})};globalThis.__cmpx=()=>{let d=document.getElementById(`__sw`);d&&(d.style.display=`none`)};' + $game
$game = Swap $game 'openCharacter(e,t=this.kit.id){' 'openCharacter(e,t=this.kit.id){globalThis.__gm=this;' 'compare save'
$game = Swap $game 'carry:e=>{let k=' 'carry:e=>{globalThis.__gm=this;let k=' 'compare save run'
# 런 도중 B 키로 창고를 연다 (캐릭터 창 + 창고 탭). 닫으면 원래대로
$game = Swap $game 'this.characterView(n,t,e===`town`),{...this.gearActions(t,()=>this.openCharacter(e,t),e===`town`)' 'this.characterView(n,t,e===`town`||!!this.__stash),{...this.gearActions(t,()=>this.openCharacter(e,t),e===`town`||!!this.__stash)' 'stash key view'
$game = Swap $game 'close:()=>{this.putBack(),this.tomeRead=null,' 'close:()=>{this.__stash=0,this.putBack(),this.tomeRead=null,' 'stash key close'
$game = Swap $game '(e.code===`KeyC`||e.code===`KeyI`)&&this.state===`playing`?this.openCharacter(`playing`)' 'e.code===`KeyB`&&(this.state===`playing`||this.state===`camp`&&!this.swapping)?(this.__stash=1,this.openCharacter(this.state)):(e.code===`KeyC`||e.code===`KeyI`)&&this.state===`playing`?(this.__stash=0,this.openCharacter(`playing`))' 'stash key'
# 공포 단계 클리어 화면에서 4초 뒤 자동 진행: 다시 하기(replay) 단계면 같은 단계 재시작, 아니면 Enter와 같은 동작. 상점·종료로 나가면 취소
$game = Swap $game 'showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();' ('showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();clearTimeout(this.__ar),__cd(4,e.replay?`' + (T '#초 뒤 같은 단계 재시작' 'Restarting in #s') + '`:`' + (T '#초 뒤 다음 단계' 'Next tier in #s') + '`),this.__ar=setTimeout(()=>{this.tierDone===e&&(e.replay?(this.tierDone=null,this.startReplay(this.kit,e.tier)):this.nextTier())},4e3);') 'auto repeat'
# 공포 단계 보스 처치 후 포털이 열리면 4초 뒤 자동 입장 (클리어 화면으로)
$portal = Find $game ('this\.hud\.banner\(`A portal to \$\{' + $id + '\(t,' + $id + '\)\} has opened`\),!1\}') 'portal'
$game = Swap $game $portal.Value ($portal.Value.Substring(0, $portal.Value.Length - 3) + 't.terror&&(__cd(4,`' + (T '#초 뒤 포털 입장' 'Entering portal in #s') + '`)),!1}') 'portal'
$game = Swap $game 'o=jr(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5))' 'o=jr(r,a,!!n.portal?.through(t,e,a!==null&&a>=1.5)||!!(t.terror&&a!==null&&a>=4))' 'portal enter'
# AFK 모드 (F8): 화면을 검게 덮고 진행 상황·획득 목록·종료 버튼만 표시. 창을 내리거나 가려도 멈추지 않음
# 배속 (F7): 1 → 1.5 → 2 → 3배 순환. 프레임당 게임 업데이트 횟수를 늘림 (1.5배는 남는 0.5를 다음 프레임으로 넘김)
$game = 'globalThis.__spd=1;globalThis.__spdA=0;globalThis.__spdS=x=>{let a=globalThis.__spdA+x*globalThis.__spd,k=Math.floor(a);return globalThis.__spdA=a-k,k};document.addEventListener(`keydown`,e=>{if(e.code!==`F7`)return;e.preventDefault(),e.stopPropagation();let l=[1,1.5,2,3];globalThis.__spd=l[(l.indexOf(globalThis.__spd)+1)%l.length],globalThis.__spdA=0;let o=document.getElementById(`__spd`);o||(o=document.createElement(`div`),o.id=`__spd`,o.style.cssText=`position:fixed;left:50%;top:6px;transform:translateX(-50%);z-index:9997;background:#000a;color:#fc6;border:1px solid #fc6;padding:2px 10px;font:bold 15px sans-serif;pointer-events:none`,document.body.append(o)),o.textContent=`' + (T '배속' 'Speed') + ' x${globalThis.__spd} (F7)`,o.style.display=globalThis.__spd===1?`none`:``},!0);' + $game
$game = Swap $game 'for(let e=0;e<I.speed*t&&i&&' 'for(let e=0,S=globalThis.__spdS(I.speed*t);e<S&&i&&' 'speed'

# 게임 실행 중 30분마다 GitHub 버전 확인, 새 버전 있으면 오른쪽 아래 알림 (클릭하면 닫힘)
$game = 'setTimeout(function c(){fetch(`' + $raw + '/version.txt?`+Date.now()).then(r=>r.text()).then(t=>{if(+t>' + $Ver + '&&!document.getElementById(`__upd`)){let d=document.createElement(`div`);d.id=`__upd`,d.textContent=`' + (T '패치 업데이트 있음 (v' 'Patch update available (v') + '${+t}). ' + (T '게임을 끄고 D2S-MyPatch.bat 실행' 'Close the game and run D2S-MyPatch.bat') + '`,d.style.cssText=`position:fixed;right:8px;bottom:8px;z-index:9999;background:#000c;color:#fc6;border:1px solid #fc6;padding:6px 10px;font:14px sans-serif;cursor:pointer`,d.onclick=()=>d.remove(),document.body.append(d)}}).catch(()=>{}),setTimeout(c,18e5)},5e3);' + $game
$game = 'globalThis.__afkN={};globalThis.__afkAdd=(k,r)=>{let a=[2,0,1,2,3][k],c={unique:0,set:1,runeword:2}[r]??3,n=globalThis.__afkN;(n[a]??=[0,0,0,0])[c]++};globalThis.__afk=0;globalThis.__afkT=()=>{let o=document.getElementById(`__afk`);if(globalThis.__afk){globalThis.__afk=0,o&&o.remove(),clearInterval(globalThis.__afkI);return}globalThis.__afk=1,globalThis.__afkS=Date.now(),globalThis.__afkR=0,globalThis.__afkN={},globalThis.__afkL=0,globalThis.__afkTot=0;o=document.createElement(`div`),o.id=`__afk`,o.style.cssText=`position:fixed;inset:0;z-index:9998;background:#000;color:#ccc;font:16px sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;line-height:1.6;text-align:center`;let s=document.createElement(`div`),b=document.createElement(`button`);b.textContent=`' + (T 'AFK 모드 종료 (F8)' 'Exit AFK mode (F8)') + '`,b.style.cssText=`font:bold 18px sans-serif;padding:10px 28px;background:#222;color:#fc6;border:1px solid #fc6;cursor:pointer`,b.onclick=()=>globalThis.__afkT(),o.append(s,b),document.body.append(o);let u=()=>{let g=globalThis.__gm,w=g?.world,m=Math.floor((Date.now()-globalThis.__afkS)/1e3);s.innerHTML=`<div style="font:bold 26px sans-serif;color:#fc6">' + (T 'AFK 모드' 'AFK mode') + '</div><div>' + (T '경과' 'Elapsed') + ' ${Math.floor(m/3600)}:${String(Math.floor(m/60)%60).padStart(2,0)}:${String(m%60).padStart(2,0)}</div><div>' + (T '완료한 판' 'Runs cleared') + ' ${globalThis.__afkR}${(f=>globalThis.__afkR?` · ' + (T '이전 판' 'Last') + ' ${f(globalThis.__afkL)} · ' + (T '평균' 'Avg') + ' ${f(globalThis.__afkTot/globalThis.__afkR)}`:``)(x=>`${Math.floor(x/60)}:${String(Math.floor(x%60)).padStart(2,0)}`)}</div><div>${w?.terror?`' + (T '공포 영역' 'Terror') + ' ${w.terror.tier} · `:``}' + (T '처치' 'Kills') + ' ${w?.kills??0} · ' + (T '이번 판 골드' 'Run gold') + ' ${Math.floor(w?.gold??0).toLocaleString()}</div>${(v=>v&&!v.done?`<div style="color:#fc6">' + (T '웨이브' 'Wave') + ' ${v.wave}/${v.of} · ${v.left} ' + (T '남음' 'left') + '${v.elites?` · ' + (T '정예' 'elites') + ' ${v.elites}`:``}</div>`:``)(globalThis.__wave)}<div>' + (T '보유 골드' 'Gold') + ' ${Math.floor(g?.save?.gold??0).toLocaleString()}</div><table style="margin:8px auto;border-collapse:collapse"><tr style="color:#888"><td></td><td style="padding:2px 10px;color:#c7b377">' + (T '유니크' 'Unique') + '</td><td style="padding:2px 10px;color:#4fd04f">' + (T '세트' 'Set') + '</td><td style="padding:2px 10px;color:#c7b377">' + (T '룬워드' 'Runeword') + '</td><td style="padding:2px 10px">' + (T '기타' 'Other') + '</td></tr>${[`' + (T '등록' 'Stashed') + '`,`' + (T '교체' 'Upgraded') + '`,`' + (T '보관' 'Kept') + '`,`' + (T '판매' 'Sold') + '`].map((l,i)=>`<tr><td style="padding:2px 10px;text-align:right;color:${[`#e8c060`,`#8cf`,`#fff`,`#999`][i]}">${l}</td>${(globalThis.__afkN[i]??[0,0,0,0]).map(v=>`<td style="padding:2px 10px">${v}</td>`).join(``)}</tr>`).join(``)}</table>`};u(),globalThis.__afkI=setInterval(u,1e3)};document.addEventListener(`keydown`,e=>{e.code===`F8`&&(e.preventDefault(),e.stopPropagation(),globalThis.__afkT())},!0);' + $game
$game = Swap $game 'Ny(document,window,e=>{e||this.pause(),this.bankHidden()})' '(globalThis.__gm=this,Ny(document,window,e=>{e||globalThis.__afk||this.pause(),this.bankHidden()}))' 'afk no pause'
$game = Swap $game 'showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();clearTimeout(this.__ar),' 'showTierCleared(){let e=this.tierDone;if(!e)return this.toMenu();globalThis.__afkR=(globalThis.__afkR||0)+1,globalThis.__afkL=e.time,globalThis.__afkTot=(globalThis.__afkTot||0)+e.time,clearTimeout(this.__ar),' 'afk run count'
$game = Swap $game 'visitAfterTier(){' 'visitAfterTier(){clearTimeout(this.__ar),__cdx();' 'auto repeat town'
$game = Swap $game 'endAfterTier(){' 'endAfterTier(){clearTimeout(this.__ar),__cdx();' 'auto repeat end'

$keepText = ReadFile $keepEntry
# 미등록 표시는 2026.1026 업데이트부터 게임에 공식으로 들어가서 따로 고치지 않는다
# 떨어진 아이템은 거리와 상관없이 즉시 처리한다 (원래는 몸에 닿아야 주움)
# 미등록 유니크/세트는 거리·숨김·자동판매와 상관없이 바로 주워 등록한다
# 그 밖의 아이템(등록된 유니크 포함)은 바로 판매한다. 퀘스트 아이템·부적은 인벤토리로
$quest = (Find $keepText ('=(' + $id + ')\(t\)\?' + $id + '\(' + $id + '\(t\.name\),`red`\)') 'quest item').Groups[1].Value
$reach = Find $keepText ('let t=n\.radius\+(' + $id + '),i=e\.reaching===r;if\(i&&c<t&&\(r\.dropped=!1\),r\.loot===`hide`&&!i\)continue;let a=r\.loot===`sell`&&!!e\.sell;') 'pickup radius'
$keepText = Swap $keepText $reach.Value ('let __nw=e.isNew?.(r.item),t=1/0,i=e.reaching===r;if(i&&c<t&&(r.dropped=!1),r.loot===`hide`&&!i&&!__nw)continue;let a=!__nw&&(!' + $quest + '(r.item)||r.item.base===`hcx`)&&r.item.type!==`charm`&&!!e.sell;') 'pickup radius'
# 골드도 거리와 상관없이 즉시 줍는다
$gold = Find $keepText ('if\(!r\.magnet&&c<n\.pickupRadius&&\(r\.magnet=!0\),!r\.magnet\)continue;if\(c<n\.radius\+4\)\{a\+=(' + $id + ')\(e,r\);continue\}') 'gold'
$keepText = Swap $keepText $gold.Value ('if(r.kind===`gold`){a+=' + $gold.Groups[1].Value + '(e,r);continue}' + $gold.Value) 'gold'
# 상자도 거리와 상관없이 즉시 연다
$chest = Find $keepText ('if\(r\.kind===`chest`\)\{if\(' + $id + '\(r\.x,r\.y,i,n\)>=n\.radius\+' + $id + '\)continue;') 'chest'
$keepText = Swap $keepText $chest.Value 'if(r.kind===`chest`){' 'chest'

# 교체 창·목록용 헬퍼: 아이템 옵션 줄(한국어)과 부위/종류
$tip = (Find $keepText ('function (' + $id + ')\(e,t,n=1,r,i=\{\},a\)\{if\(') 'tooltip').Groups[1].Value
$bases = (Find $keepText ('(' + $id + ')=new Map\((' + $id + ')\.map\(e=>\[e\.name,e\]\)\),' + $id + '=\2\.filter\(e=>e\.type===`charm`\)') 'bases').Groups[1].Value
$cats = (Find $keepText ('(' + $id + ')=\[\[`head`,`Helms`\]') 'categories').Groups[1].Value
$tr = (Find $keepText ('import\{[^}]*\bd as (' + $id + ')[^}]*\}from"\./lang-') 'translate').Groups[1].Value
$keepText += ";globalThis.__tip=e=>{try{return $tip(e).lines.map(l=>$tr(l.text))}catch{return[]}};globalThis.__kd=e=>{let o=$bases.get(e.base);return o?.type===``weapon``?o.kind+(o.twoHand&&!o.oneHand?2:1):o?.type};globalThis.__slot=e=>{let o=$bases.get(e.base),w=o?.type===``weapon``,c=w?o.kind:o?.type,n=$cats.find(x=>x[0]===c)?.[1],g=!o?null:w?``$(T '무기' 'Weapon')``:c===``ring``||c===``amulet``?``$(T '장신구' 'Jewelry')``:c===``charm``?null:``$(T '방어구' 'Armor')``,h=w?(o.oneHand&&o.twoHand?``$(T '한손/양손' '1H/2H')``:o.twoHand?``$(T '양손' '2H')``:``$(T '한손' '1H')``):null;return[{unique:``$(T '유니크' 'Unique')``,set:``$(T '세트' 'Set')``,runeword:``$(T '룬워드' 'Runeword')``}[e.rarity],g,h,n&&$tr(n),o&&$tr(e.base)].filter(Boolean).join(``` · ``)};"
# kodia.ttf가 있으면 숫자·영문·기호도 디아2 그림 글꼴 대신 그 폰트로 그린다 (공백 제외 전부)
$langEntry = Entry 'lang'
$langText = ReadFile $langEntry
if (Test-Path (Join-Path $__root 'kodia.ttf')) {
    $keepText = Swap $keepText 'let t=e.charCodeAt(0);return t>=44032&&t<=55203' 'let t=e.charCodeAt(0);return t>32&&t!==160||t>=44032&&t<=55203' 'all glyphs foreign'
    $langText = Swap $langText '{unicodeRange:`U+1100-11FF, U+3130-318F, U+AC00-D7A3`}' '{}' 'font range'
    # 아이템 툴팁 글자만 4배 해상도로 그려 선명하게 (메뉴처럼 글자 이미지를 복사해 쓰는 곳은 그대로)
    $uiText = Swap $uiText 'printTooltip(e){let t=' 'printTooltip(e){globalThis.__sharp=1;try{this.__pt(e)}finally{globalThis.__sharp=0}}__pt(e){let t=' 'sharp tooltip'
    $keepText = Swap $keepText 'u.className=`d2-text`,u.textContent=e;' 'u.className=`d2-text`,u.textContent=e,u.__s=globalThis.__sharp;' 'sharp mark'
    $keepText = Swap $keepText 'f=()=>{let e=u.getContext(`2d`),t=e.createImageData(u.width,u.height);' 'f=()=>{if(u.__s&&!u.__k){let w=u.width,h=u.height;u.__k=4,u.width=w*4,u.height=h*4,u.style.width=w+`px`,u.style.height=h+`px`,u.style.imageRendering=`auto`}let e=u.getContext(`2d`);e.setTransform(1,0,0,1,0,0);let t=e.createImageData(u.width,u.height);' 'sharp ctx'
    $keepText = Swap $keepText 'e.putImageData(t,0,0);for(let{line:t,x:r,y:i}of d)o&&this.drawForeign' 'e.putImageData(t,0,0);e.setTransform(u.__k||1,0,0,u.__k||1,0,0);for(let{line:t,x:r,y:i}of d)o&&this.drawForeign' 'sharp draw'
}
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
$throttle = 'win\.on\("(minimize|hide)", throttle\(true\)\);'
if ([regex]::Matches($mainText, $throttle).Count -ne 2) { Fail (T '이 게임 버전은 지원하지 않습니다 (throttle).' 'This game version is not supported (throttle).') }
$mainText = [regex]::Replace($mainText, $throttle, '')
# 패치된 게임은 순위표에 아무것도 보내지 않는다: 모든 POST를 보낸 것처럼(200) 처리하고 대기열에서 지운다 (조회 GET은 그대로)
$mainText = Swap $mainText 'if (method === "POST" && (typeof body !== "string" || body.length > MAX_BODY3)) return { status: 413, body: null };' ('if (method === "POST" && (typeof body !== "string" || body.length > MAX_BODY3)) return { status: 413, body: null };' + "`n    " + 'if (method === "POST") return { status: 200, body: "{}", retryAfter: null };') 'no send'
$mainBytes = $utf8.GetBytes($mainText)
$header = $header.Replace($mm[0].Value, (NewEntry $mm[0] $mainBytes ($dataLen + $gameBytes.Length + $keepBytes.Length + $uiBytes.Length + $langBytes.Length)))
# 패치 폴더에 kodia.ttf가 있으면 게임 한글 폰트 두 개(fonts-ko/kodia.woff2, irisl.woff2)를 모두 그 파일로 바꾼다
$fontBytes = New-Object byte[] 0
$fontFile = Join-Path $__root 'kodia.ttf'
if (Test-Path $fontFile) {
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
}

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
Write-Host ''
Write-Host (T '  [OK] 패치 완료. 게임을 실행하세요.' '  [OK] Patched. Start the game.') -ForegroundColor Green
Write-Host (T "  원본 백업: $backup" "  Original backup: $backup")
