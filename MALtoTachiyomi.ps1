#https://api.jikan.moe/v3/manga/28123

#CONFIG
$CFG_preferEnglishTitles = $true
$CFG_getCoverImage = $true
#you can get a test API url from https://jikan.docs.apiary.io/ and trying a request via 'Development Proxy'
#$CFG_APIurl = "https://private-anon-xxxxxxxx-jikan.apiary-proxy.com/v3"
$CFG_APIurl = "https://api.jikan.moe/v3"
$DebugPreference = "Continue" #comment to hide

#hinamatsuri 36413 - 1 author story+art
#log horizon 46024 - has english title, 1author story+art
#maou 28123 - 1 author 1 artist, null english title
#citrus anthology 112903 - lots of story+art

#####Prompt
"this will create the metadata files for Tachiyomi from MyAnimeList"
$mangaID = Read-Host -Prompt "Enter MyAnimeList ID of Manga:"
$response = Invoke-WebRequest -Uri "$CFG_APIurl/manga/$mangaID"
#TODO:test if fail
$data = $response | ConvertFrom-Json
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
#####author/artist

Write-Debug "Author/Artist"
$author = @()
$artist = @()
$personDelay = 1
if ($data.authors.Length -ge 3)
    {
        Write-Debug "At least 3 people, delay now 4 seconds"
        $personDelay = 4
        Start-Sleep -Seconds $personDelay #delay once because we just got the initial info
    }
foreach ($person in $data.authors)
{
    Write-Host ("Person: {0}" -f $person.name)
    Start-Sleep -Seconds $personDelay #prevent making the jikan api angry
    $personID = $person.mal_id
    $personResponseRaw = Invoke-WebRequest -Uri "$CFG_APIurl/person/$personID"
    #TODO:test if fail
    $personResponse = ConvertFrom-Json $personResponseRaw.content
    foreach ($personManga in $personResponse.published_manga)
    {
        Write-Debug ("Trying to match: {0}" -f $personManga.manga.mal_id)
        if ($personManga.manga.mal_id -eq $mangaID)
        {
            Write-Debug "Person-Manga Match"
            if ($personManga.position -eq "Story & Art")
            {
                $author += $personResponse.name
                $artist += $personResponse.name
                break
            }
            elseif ($personManga.position -eq "Story")
            {
                $author += $personResponse.name
                break
            }
            elseif ($personManga.position -eq "Art")
            {
                $artist += $personResponse.name
                break
            }
            else
            {
                Write-Debug ("unknown position: {0}" -f $personManga.position)
            }
        }#if match
    }#foreach person-manga
}#for eachperson
#NOTE: Tachiyomi doesn't handle actual multi-author/artists, must mix into 1 string, NO ARRAY!
#      Gotta smush it into 1 string ): hopefully fixed in Tachoyomi in the future
$authorStr = $author[0]
$artistStr = $artist[0]
for ($idx = 1; $idx -lt $author.Length; ++$idx)
{
    $authorStr += (", " + $author[$idx])
}
for ($idx = 1; $idx -lt $artist.Length; ++$idx)
{
    $artistStr += (", " + $artist[$idx])
}
Add-Member -InputObject $output -MemberType NoteProperty -Name author -Value $authorStr
Add-Member -InputObject $output -MemberType NoteProperty -Name artist -Value $artistStr
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
ConvertTo-Json $output | Out-File -Encoding utf8 "details.json"
if ($CFG_getCoverImage)
{
    "Saving cover..."
    Invoke-WebRequest -Uri $data.image_url -OutFile "cover.jpg"
    #TODO:test if fail
}