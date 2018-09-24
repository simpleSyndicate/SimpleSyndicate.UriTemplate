@echo off
rem check nugetutil is available
set simplesyndicatenugetutil=..\tools\SimpleSyndicate.NuGetUtil.exe
if not exist %simplesyndicatenugetutil% (
    set simplesyndicatenugetutil=..\..\tools\SimpleSyndicate.NuGetUtil.exe
)

if not exist %simplesyndicatenugetutil% (
    echo Fatal: SimpleSyndicate.NuGetUtil.exe not found in ..\tools or ..\..\tools
    goto :end
)

rem check input argument
for /F "delims=" %%i in ('%simplesyndicatenugetutil% checkversionupdatearg %1') do set nugetutil=%%i
set nugetutilprefix=%nugetutil:~0,5%
if /i "%nugetutilprefix%" == "Valid" (
    goto :precheck
)
echo Fatal: No version update component specified
echo Usage: nuget-push ^<major^|minor^|point^|prerelease^> [path]
echo   If path is specified, the package will not be pushed, but instead
echo   copied to the specified path.
goto :end

:precheck

:checkTools
rem check Visual Studio is available
if not defined VSINSTALLDIR (
    echo Fatal: Visual Studio not found
    goto :end
)

rem check nuget is available
for /F "delims=" %%i in ('nuget') do set nugetversion=%%i
if not defined nugetversion (
    echo Fatal: nuget not found
    goto :end
)

rem check git is available
for /F "delims=" %%i in ('git --version') do set gitversion=%%i
if not defined gitversion (
    echo Fatal: git not found
    goto :end
)

rem if %home% isn't defined, set it to the home drive and path
if not defined HOME (
    set HOME=%HOMEDRIVE%%HOMEPATH%
)

rem if the home drive and path aren't defined, home will still be undefined so set it to the user profile
if not defined HOME (
    set HOME=%USERPROFILE%
)

rem sanity check %home% is defined, otherwise git won't be able to find its global config
if not defined HOME (
    echo Fatal: No HOME environment variable defined
    echo Fatal: Without this git won't be able to find its global config
    goto :end
)

:push
rem update version and store new version number
%simplesyndicatenugetutil% versionupdatenoreleasenotes %1

rem build release package and push to nuget
nuget pack SimpleSyndicate.UriTemplate.csproj -Prop Configuration=Release -Build
if /i "%~2"=="" (
    nuget push *.nupkg
) else (
    copy *.nupkg %2
)

rem build symbols package and push to nuget
nuget pack SimpleSyndicate.UriTemplate.csproj -Prop Configuration=Release -Symbols
if /i "%~2"=="" (
    nuget push *.symbols.nupkg -source https://nuget.smbsrc.net/
) else (
    copy *.symbols.nupkg %2
)

rem remove the packages as we don't need them after they've been pushed, and we don't want to commit them to source control
del *.nupkg

rem work out the git tags and messages
for /F "delims=" %%i in ('%simplesyndicatenugetutil% currentversion') do set currentversion=%%i
set tag=%currentversion%
if /i "%~2"=="" (
    set message=Set version to %currentversion%; pushed to NuGet.
) else (
    set message=Set version to %currentversion%; files copied (package not pushed to NuGet^).
)

rem commit the changes for this version
pushd .
cd ..
git add --all *
git commit -a -m "%message%"
git tag -a %tag% -m "%message%"
git push --all
git push --tags
popd

:end
