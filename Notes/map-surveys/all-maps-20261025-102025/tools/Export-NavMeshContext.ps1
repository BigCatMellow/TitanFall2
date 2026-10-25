param([Parameter(Mandatory=$true)][string]$NavPath,[Parameter(Mandatory=$true)][string]$OutputDirectory,[string]$Observations)
# Read-only decoder for installed TF2 MSET v5 / DNAV v13 meshes.
# Layout references: local bp_ort/src/navmesh/bindings.rs and r-ex/r2recast Sample.cpp.
# Exports surface geometry, not collision geometry or a verified route graph.
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
$bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $NavPath))
function I([int]$o){[BitConverter]::ToInt32($bytes,$o)}
function F([int]$o){[double][BitConverter]::ToSingle($bytes,$o)}
if($bytes.Length-lt52 -or (I 0)-ne1297302868 -or (I 4)-ne5){throw 'Expected MSET v5 header'}
$tiles=I 8
if($tiles-lt1 -or $tiles-gt10000){throw 'Invalid tile count'}
$polys=[Collections.Generic.List[object]]::new();$o=52;$vertsTotal=0
for($tile=0;$tile-lt$tiles;$tile++){
    if($o+8-gt$bytes.Length){throw 'Truncated tile header'}
    $tileRef=I $o;$size=I ($o+4);$o+=8;$end=$o+$size
    if($size-lt104 -or $end-gt$bytes.Length){throw 'Invalid tile byte count'}
    if((I $o)-ne1145979222 -or (I ($o+4))-ne13){throw 'Expected DNAV v13 tile'}
    $np=I ($o+24);$nv=I ($o+32)
    if($np-lt0 -or $nv-lt0 -or 104+$nv*12+$np*48-gt$size){throw 'Invalid vertex/polygon counts'}
    $verts=@(for($v=0;$v-lt$nv;$v++){$p=$o+104+$v*12; ,@((F $p),(F ($p+4)),(F ($p+8)))})
    $vertsTotal+=$nv;$po=$o+104+$nv*12
    for($p=0;$p-lt$np;$p++){
        $base=$po+$p*48;$n=[int]$bytes[$base+30];$kind=[int]$bytes[$base+31]-shr6
        if($n-gt6 -or $n-lt2){throw 'Invalid polygon vertex count'}
        $points=@(for($v=0;$v-lt$n;$v++){$idx=[BitConverter]::ToUInt16($bytes,$base+4+$v*2);if($idx-ge$nv){throw 'Polygon vertex out of range'};,$verts[$idx]})
        foreach($point in $points){foreach($component in $point){if([double]::IsNaN($component)-or[double]::IsInfinity($component)-or[Math]::Abs($component)-gt1000000){throw 'Invalid world coordinate'}}}
        if($kind-eq0 -and $n-ge3){$polys.Add([pscustomobject]@{tile=$tile;tile_ref=$tileRef;index=$p;group=[BitConverter]::ToUInt16($bytes,$base+32);flags=[BitConverter]::ToUInt16($bytes,$base+28);area=[int]$bytes[$base+31]-band63;points=$points})}
    }
    $o=$end
}
$all=@($polys|ForEach-Object {$_.points|ForEach-Object {,[double[]]$_}})
$xs=@($all|ForEach-Object {$_[0]});$ys=@($all|ForEach-Object {$_[1]});$zs=@($all|ForEach-Object {$_[2]})
$bounds=@{min_x=($xs|Measure-Object -Minimum).Minimum;max_x=($xs|Measure-Object -Maximum).Maximum;min_y=($ys|Measure-Object -Minimum).Minimum;max_y=($ys|Measure-Object -Maximum).Maximum;min_z=($zs|Measure-Object -Minimum).Minimum;max_z=($zs|Measure-Object -Maximum).Maximum}
$stalls=@()
if($Observations){$stalls=@(Import-Csv $Observations|Where-Object {$_.bot-eq'1'-and$_.alive-eq'1'-and$_.titan-eq'0'-and$_.stalled-eq'1'})}
$meta=[ordered]@{source=(Resolve-Path $NavPath).Path;sha256=(Get-FileHash $NavPath).Hash;set_version=5;tile_version=13;tiles=$tiles;vertices=$vertsTotal;surface_polygons=$polys.Count;bounds=$bounds;trailing_bytes=$bytes.Length-$o;observations_source=$Observations;pilot_stall_samples=if($Observations){$stalls.Count}else{$null};limits='Read-only surface geometry from installed navmesh; no adjacency/traversal validation, collision scenery, or in-game visual observation. Rendered heights overlap in top-down views. Stalls are two-second samples, not unique incidents.'}
$meta|ConvertTo-Json -Depth 5|Set-Content "$OutputDirectory\metadata.json"
$polys.ToArray()|ConvertTo-Json -Depth 6 -Compress|Set-Content "$OutputDirectory\surface-polygons.json"
Add-Type -AssemblyName System.Drawing
function Render([string]$name,[double]$minX,[double]$maxX,[double]$minY,[double]$maxY){
    $img=[Drawing.Bitmap]::new(1400,1050);$g=[Drawing.Graphics]::FromImage($img)
    $font=[Drawing.Font]::new('Segoe UI',13);$small=[Drawing.Font]::new('Segoe UI',10)
    $g.Clear([Drawing.Color]::FromArgb(19,24,33))
    $scale=[Math]::Min(1280/($maxX-$minX),870/($maxY-$minY));$left=60;$top=90
    try{
        $g.SetClip([Drawing.Rectangle]::new(50,85,1300,880))
        foreach($poly in $polys){
            $points=$poly.points
            $cx=($points|ForEach-Object {$_[0]}|Measure-Object -Average).Average;$cy=($points|ForEach-Object {$_[1]}|Measure-Object -Average).Average
            if($cx-lt$minX-200 -or $cx-gt$maxX+200 -or $cy-lt$minY-200 -or $cy-gt$maxY+200){continue}
            $z=($points|ForEach-Object {$_[2]}|Measure-Object -Average).Average
            $ratio=[Math]::Min(1,[Math]::Max(0,($z-$bounds.min_z)/[Math]::Max(1,$bounds.max_z-$bounds.min_z)))
            $color=[Drawing.Color]::FromArgb(150,[int](45+150*$ratio),[int](100+100*$ratio),[int](165-65*$ratio))
            $brush=[Drawing.SolidBrush]::new($color);$pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(50,200,210,225),0.5)
            try{[Drawing.PointF[]]$screen=@($points|ForEach-Object {[Drawing.PointF]::new([single]($left+($_[0]-$minX)*$scale),[single]($top+($maxY-$_[1])*$scale))});$g.FillPolygon($brush,$screen);$g.DrawPolygon($pen,$screen)}finally{$brush.Dispose();$pen.Dispose()}
        }
        foreach($row in $stalls){$x=[double]$row.x;$y=[double]$row.y;if($x-lt$minX-or$x-gt$maxX-or$y-lt$minY-or$y-gt$maxY){continue};$g.FillEllipse([Drawing.Brushes]::Tomato,[single]($left+($x-$minX)*$scale-2),[single]($top+($maxY-$y)*$scale-2),4,4)}
        $hx=$left+(4120-$minX)*$scale;$hy=$top+($maxY+355)*$scale
        if([IO.Path]::GetFileName($NavPath)-like'mp_eden_*' -and $hx-ge$left-and$hx-le1340-and$hy-ge$top-and$hy-le960){$g.DrawEllipse([Drawing.Pens]::Gold,[single]($hx-10),[single]($hy-10),20,20);$g.DrawString('Known Eden hotspot (4120, -355)', $small,[Drawing.Brushes]::Gold,[single]($hx-220),[single]($hy-30))}
        $g.ResetClip()
        $g.DrawString(([IO.Path]::GetFileNameWithoutExtension($NavPath)+' - '+$name),$font,[Drawing.Brushes]::White,55,22)
        $legend=if($Observations){'Navigation surfaces only; red = stalled pilot samples; brighter = higher elevation. X right, Y up.'}else{'Navigation surfaces only; no match observations overlaid. Brighter = higher elevation. X right, Y up.'}
        $g.DrawString($legend,$small,[Drawing.Brushes]::LightGray,55,52)
        $g.DrawString(('World bounds X {0:0} to {1:0}; Y {2:0} to {3:0}. Overlapping floors remain ambiguous.' -f $minX,$maxX,$minY,$maxY),$small,[Drawing.Brushes]::LightGray,55,990)
        $img.Save("$OutputDirectory\$name.png",[Drawing.Imaging.ImageFormat]::Png)
    }finally{$g.Dispose();$img.Dispose();$font.Dispose();$small.Dispose()}
}
Render 'overview' ($bounds.min_x-100) ($bounds.max_x+100) ($bounds.min_y-100) ($bounds.max_y+100)
if([IO.Path]::GetFileName($NavPath)-like'mp_eden_*'){Render 'hotspot' 3300 4900 -1100 500}
$meta|ConvertTo-Json -Depth 4
