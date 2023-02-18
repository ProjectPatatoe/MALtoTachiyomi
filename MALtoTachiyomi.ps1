param(
    [Parameter()]
    [int]$mangaID
)
#CONFIG
$CFG_preferEnglishTitles = $true
$CFG_getCoverImage = $true
#you can get a test API url from https://jikan.docs.apiary.io/ and trying a request via 'Development Proxy'
#$CFG_APIurl = "https://private-anon-xxxxxxxx-jikan.apiary-proxy.com/v4"
$CFG_APIurl = "https://api.jikan.moe/v4"
$DebugPreference = "Continue" #comment to hide

#test manga
#hinamatsuri 36413 - 1 author story+art
#log horizon 46024 - has english title, 1author story+art
#maou 28123 - 1 author 1 artist, null english title
#citrus anthology 112903 - lots of story+art

#####Prompt
"this will create the metadata files for Tachiyomi from MyAnimeList"
if ($mangaID -eq 0) {
    $mangaID = Read-Host -Prompt "Enter MyAnimeList ID of Manga:"
}
$response = Invoke-WebRequest -Uri "$CFG_APIurl/manga/$mangaID"
#TODO:test if fail
Write-Debug $response
$data = $response.Content | ConvertFrom-Json
$data | ConvertTo-Json | Out-File "data.json"
$data = $data.data
$output = New-Object PSObject
#####title
Write-Debug "Title"
if ($CFG_preferEnglishTitles -And ($null -ne $data.title_english) )
{
    Write-Debug "title_english not null"
    Add-Member -InputObject $output -MemberType NoteProperty -Name title -Value $data.title_english
}
else
{
    Write-Debug "title_english is null"
    Add-Member -InputObject $output -MemberType NoteProperty -Name title -Value $data.title
}
Write-Debug $output.title
#####author/artist

Write-Debug "Author/Artist"
#NOTE: Tachiyomi doesn't handle actual multi-author/artists, must mix into 1 string, NO ARRAY!
#      Gotta smush it into 1 string ): hopefully fixed in Tachoyomi in the future
#NOTE: Jikan v4 doesn't list author vs artist! dump everyone into author ):
$authorStr = $data.authors[0].name
for ($idx = 1; $idx -lt $data.authors.Length; ++$idx)
{
    $authorStr += ("; " + $data.authors[$idx].name)
}
Add-Member -InputObject $output -MemberType NoteProperty -Name author -Value $authorStr

#####description
Write-Debug "Description"
Add-Member -InputObject $output -MemberType NoteProperty -Name description -Value $data.synopsis
#####genre
Write-Debug "Genre"
$tempGenre = @()
foreach ($genre in $data.genres)
{
    $tempGenre += $genre.name
}
Add-Member -InputObject $output -MemberType NoteProperty -Name genre -Value $tempGenre
#####status
Write-Debug "Status"
switch ($data.status) {
    "Publishing" { Add-Member -InputObject $output -MemberType NoteProperty -Name status -Value "1" }
    "Finished" { Add-Member -InputObject $output -MemberType NoteProperty -Name status -Value "2" }
    Default {
        Add-Member -InputObject $output -MemberType NoteProperty -Name status -Value "0"
    }
}
$statusValues = @(
    "0 = Unknown",
    "1 = Ongoing",
    "2 = Completed",
    "3 = Licensed"
)
Add-Member -InputObject $output -MemberType NoteProperty -Name '_status values' -Value $statusValues
#####save
Write-Debug "Save"
"Saving details..."
#TODO If it didn't work, dont make a details.json!
$output
ConvertTo-Json $output | Out-File -Encoding utf8 "details.json"
if ($CFG_getCoverImage)
{
    "Saving cover..."
    Invoke-WebRequest -Uri $data.images.jpg.image_url -OutFile "cover.jpg"
    #TODO:test if fail
}