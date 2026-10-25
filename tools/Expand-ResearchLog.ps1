param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $OutputPath){throw 'Choose a new output file; existing files are not overwritten'}
$inputStream=[IO.File]::OpenRead((Resolve-Path -LiteralPath $Path))
$gzip=[IO.Compression.GZipStream]::new($inputStream,[IO.Compression.CompressionMode]::Decompress)
$outputStream=[IO.File]::Open([IO.Path]::GetFullPath($OutputPath),[IO.FileMode]::CreateNew)
try{$gzip.CopyTo($outputStream)}finally{$outputStream.Dispose();$gzip.Dispose();$inputStream.Dispose()}
