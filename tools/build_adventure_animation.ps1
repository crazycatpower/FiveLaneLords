$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$asset = 'assets/manuscript-v1'
$frames = "$asset/adventure-lord-attack"
# Source atlas uses uneven cells. Regions include complete swords; corner masks
# exclude a neighbouring frame where its bounding rectangle overlaps this one.
$regions = @(
    @{ crop='512:516:0:0'; pad='28:40'; mask='' },
    @{ crop='448:516:512:0'; pad='35:40'; mask='' },
    @{ crop='576:516:960:0'; pad='28:40'; mask='' },
    @{ crop='540:508:0:516'; pad='20:66'; mask="geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='if(gte(X,528)*lt(Y,380),0,alpha(X,Y))'," },
    @{ crop='496:508:528:516'; pad='50:66'; mask="geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='if(lt(X,14)*gt(Y,400),0,alpha(X,Y))'," },
    @{ crop='512:508:1024:516'; pad='34:66'; mask='' }
)
for ($i=0; $i -lt $regions.Count; $i++) {
    $r = $regions[$i]
    $filter = "crop=$($r.crop),$($r.mask)format=rgba,pad=640:576:$($r.pad):color=black@0"
    & ffmpeg -v error -y -i "$asset/adventure-lord-attack-source.png" -vf $filter -frames:v 1 "$frames/frame-$i.png"
    if ($LASTEXITCODE -ne 0) { throw "Frame $i failed" }
}
$durations = @(0.32,0.16,0.06,0.12,0.14,0.28)
$lines = @('ffconcat version 1.0')
for ($i=0; $i -lt 6; $i++) {
    $lines += "file 'frame-$i.png'"
    $lines += 'duration '+$durations[$i].ToString([Globalization.CultureInfo]::InvariantCulture)
}
$lines += "file 'frame-0.png'"
[IO.File]::WriteAllLines((Join-Path (Get-Location) "$frames/attack.ffconcat"), $lines, [Text.UTF8Encoding]::new($false))
& ffmpeg -v error -y -f concat -safe 0 -i "$frames/attack.ffconcat" -filter_complex "fps=50,split[a][b];[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=alpha_threshold=128" -t 1.08 -loop 0 docs/adventure-art-preview/attack.gif
if ($LASTEXITCODE -ne 0) { throw 'GIF failed' }
# Opaque proof images ensure the actual alpha is viewed on a light background.
& ffmpeg -v error -y -f lavfi -i 'color=c=0xE8D7AE:s=1536x1024' -i "$asset/village.png" -filter_complex '[0:v][1:v]overlay=0:0:format=auto' -frames:v 1 docs/adventure-art-preview/village.png
if ($LASTEXITCODE -ne 0) { throw 'Village proof failed' }
& ffmpeg -v error -y -f lavfi -i 'color=c=0xE8D7AE:s=640x576' -i "$frames/frame-3.png" -filter_complex '[0:v][1:v]overlay=0:0:format=auto' -frames:v 1 docs/adventure-art-preview/impact.png
if ($LASTEXITCODE -ne 0) { throw 'Impact proof failed' }
