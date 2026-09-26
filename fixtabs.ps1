$p = 'ThreeOneOSFive.xcodeproj\project.pbxproj'
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$tb = [char]9
$p2 = $tb * 2
$p4 = $tb * 4
$find_6P200 = ($tb*6) + '3105P200 /* FirebaseAuthenticationClient.swift in Sources */'
$repl_6P200 = $p2 + '3105P200 /* FirebaseAuthenticationClient.swift in Sources */'
$find_4F108 = ($tb*4) + '3105F108 /* OnboardingView.swift */'
$repl_4F108 = $p2 + '3105F108 /* OnboardingView.swift */'
$find_7L104 = ($tb*7) + '3105L104 /* RepositorySourcesView.swift */'
$repl_7L104 = $p4 + '3105L104 /* RepositorySourcesView.swift */'
$find_7P200 = ($tb*7) + '3105P200,'
$repl_7P200 = $p4 + '3105P200,'
$t = $t.Replace($find_6P200, $repl_6P200)
$t = $t.Replace($find_4F108, $repl_4F108)
$t = $t.Replace($find_7L104, $repl_7L104)
$t = $t.Replace($find_7P200, $repl_7P200)
[System.IO.File]::WriteAllText($p, $t, [System.Text.Encoding]::UTF8)
Write-Output 'fixed'